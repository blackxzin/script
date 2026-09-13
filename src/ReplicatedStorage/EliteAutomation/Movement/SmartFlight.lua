-- ============================================================
--  Elite Automation Framework :: Movement.SmartFlight
--  Sistema de Voo e Tween de Alta Eficácia para GPO:
--  - Noclip contínuo via RunService.Stepped (elimina flings e colisões)
--  - Neutralização de inércia e gravidade (zero AssemblyLinearVelocity)
--  - Trajetória em 3 fases (Subida Segura → Cruzeiro Horizontal → Descida)
--  - Proteção estrita anti-mar (impede afogamento de usuários de fruta)
-- ============================================================

local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local Players       = game:GetService("Players")

local SmartFlight = {}
SmartFlight.__index = SmartFlight

-- ─── Utilitário: número aleatório no intervalo ──────────────
local function randBetween(a, b)
	return a + math.random() * (b - a)
end

-- ponytail: sem pathfinding; linha reta chunkada. Upgrade: waypoints desviando de ilhas.
local SEG_LEN = 200 -- studs por tween; tween gigante = flag teleport + disconnect
local SEG_TIME_MAX = 8 -- s por segmento; evita tween preso

local function aliveChar(self)
	local char = self.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not char.Parent or not root or not root.Parent then return nil end
	if hum and hum.Health <= 0 then return nil end
	return root
end

-- ─── Utilitário: aguarda tween terminar de forma segura ──────
local function awaitTween(tween, timeout)
	if not tween then return end
	timeout = timeout or SEG_TIME_MAX
	local done = false
	local conn
	conn = tween.Completed:Connect(function()
		done = true
	end)
	local t0 = os.clock()
	while not done and tween.PlaybackState == Enum.PlaybackState.Playing do
		if os.clock() - t0 > timeout then
			pcall(function() tween:Cancel() end)
			break
		end
		task.wait()
	end
	if conn then conn:Disconnect() end
end

local function lookCFrame(pos, dir)
	if dir and dir.Magnitude > 1 then
		return CFrame.new(pos, pos + dir.Unit)
	end
	return CFrame.new(pos) -- sem Unit de vetor zero (NaN = fling pro void)
end

function SmartFlight.new(character, settings)
	local self = setmetatable({}, SmartFlight)

	self.Character     = character
	self.Settings      = settings or {}
	self.HoverOffset   = self.Settings.HoverOffset   or 25
	self.SeaFloor      = self.Settings.SeaFloorOffset or 35
	self.SeaLevel      = self.Settings.SeaLevel       or 0
	self.SpeedBase     = self.Settings.DefaultSpeed   or 52
	self.JitterMin     = self.Settings.SpeedJitterMin or -6
	self.JitterMax     = self.Settings.SpeedJitterMax or  6
	self.TweenStyle    = self.Settings.TweenStyle     or Enum.EasingStyle.Sine
	self.TweenDir      = self.Settings.TweenDirection or Enum.EasingDirection.InOut

	self._flying       = false
	self._safeLoop     = nil
	self._noclipConn   = nil
	self._currentTween = nil
	self._flightId     = 0 -- token: novo FlyTo/Stop cancela o anterior (voo sobreposto = fling)

	return self
end

function SmartFlight:_getRoot()
	local char = self.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChildOfClass("BasePart")
end

function SmartFlight:_getHumanoid()
	local char = self.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

-- ─── Noclip e Bypass de Física Contínuo (100% eficaz para GPO) ────
function SmartFlight:_startNoclip()
	if self._noclipConn then return end

	local root = self:_getRoot()
	local hum  = self:_getHumanoid()

	-- NOTA: sem BodyVelocity/BodyMovers no character. GPO escaneia
	-- BodyMovers estranhos no RootPart e kicka. Tween de CFrame +
	-- noclip + velocidade zerada já estabilizam sem assinatura.
	-- Desabilita temporariamente o controle do Humanoid para evitar atrito com o tween
	if hum and hum.Health > 0 then
		hum.PlatformStand = true
	end

	self._noclipConn = RunService.Stepped:Connect(function()
		local char = self.Character
		if not char then return end

		-- Desativa colisões de todas as partes a cada frame de física
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end

		-- Zera velocidades no RootPart para anular gravidade acumulada
		local r = self:_getRoot()
		if r then
			r.AssemblyLinearVelocity = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end

		-- NOTA: sem ChangeState por frame. ChangeState(Physics) a cada
		-- Stepped é assinatura conhecida de noclip e causa kick no GPO.
		-- PlatformStand + velocidade zerada já estabilizam o tween.
	end)
end

function SmartFlight:_stopNoclip()
	if self._noclipConn then
		self._noclipConn:Disconnect()
		self._noclipConn = nil
	end

	local root = self:_getRoot()
	if root then
		root.CanCollide = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	-- Restaura estado padrão do Humanoid
	local hum = self:_getHumanoid()
	if hum and hum.Health > 0 then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end
end

-- ─── Calcula altitude segura sobre um ponto do mundo ─────────
function SmartFlight:_safeY(targetPos)
	local groundY = self.SeaLevel
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { self.Character }
		local res = workspace:Raycast(
			Vector3.new(targetPos.X, 5000, targetPos.Z),
			Vector3.new(0, -6000, 0),
			params
		)
		if res then groundY = res.Position.Y end
	end)

	-- Proteção rigorosa contra mar no GPO (águas profundas causam dano letal a usuários de fruta)
	-- Se groundY estiver próximo ao nível do mar (<= SeaLevel + 2), força SeaFloorOffset seguro (mínimo 35 studs)
	local safeMin = self.SeaLevel + self.SeaFloor
	if groundY <= (self.SeaLevel + 5) then
		return safeMin
	end

	return math.max(groundY + self.HoverOffset, safeMin)
end

-- ─── Pre-carregamento de chunk para StreamingEnabled de GPO ───
function SmartFlight:_requestStream(pos)
	local lp = Players.LocalPlayer
	if lp and lp.RequestStreamAroundAsync then
		pcall(function()
			lp:RequestStreamAroundAsync(pos, 5)
		end)
	end
end

-- ─── Executa um segmento de Tween de CFrame ───────────────────
function SmartFlight:_tweenTo(targetCFrame, speed)
	local root = aliveChar(self)
	if not root then return false end

	local dist = (targetCFrame.Position - root.Position).Magnitude
	if dist < 0.5 then return true end

	-- Pre-requisita streaming da área de destino
	self:_requestStream(targetCFrame.Position)

	local duration = dist / math.max(speed, 5)
	duration = math.min(duration, SEG_TIME_MAX)

	local tween
	pcall(function()
		tween = TweenService:Create(root,
			TweenInfo.new(duration, self.TweenStyle, self.TweenDir),
			{ CFrame = targetCFrame })
	end)
	if not tween then return false end
	self._currentTween = tween
	tween:Play()

	awaitTween(tween, math.max(duration + 2, 3))

	-- Limpa referência
	if self._currentTween == tween then
		self._currentTween = nil
	end

	return aliveChar(self) ~= nil
end

-- ─── Voa até uma posição com trajetória otimizada ────────────
--[[
	targetPos : Vector3 do destino
	Usa estratégia de voo em 3 fases:
	  1. Subida até a altitude segura de cruzeiro (evita bater em montanhas/ilhas)
	  2. Cruzeiro horizontal em segmentos curtos até as coordenadas X, Z
	  3. Descida suave até o alvo final
]]
function SmartFlight:FlyTo(targetPos)
	if typeof(targetPos) ~= "Vector3" then return false end
	-- NaN/Inf = CFrame inválido = disconnect na hora. Barato checar.
	if targetPos.X ~= targetPos.X or math.abs(targetPos.X) > 1e5
		or targetPos.Y ~= targetPos.Y or math.abs(targetPos.Y) > 1e5
		or targetPos.Z ~= targetPos.Z or math.abs(targetPos.Z) > 1e5 then
		return false
	end

	self._flightId += 1
	local myFlight = self._flightId
	if self._currentTween then
		pcall(function() self._currentTween:Cancel() end)
		self._currentTween = nil
	end

	-- Tween sentado (barco/cadeira) = weld fight = disconnect. Levanta antes.
	local hum = self:_getHumanoid()
	if hum and hum.Seated then
		pcall(function() hum.Sit = false end)
		task.wait(0.3)
	end

	local root = aliveChar(self)
	if not root then return false end
	if myFlight ~= self._flightId then return false end

	self._flying = true
	self:_startNoclip()

	local speed = self.SpeedBase + randBetween(self.JitterMin, self.JitterMax)
	speed       = math.max(speed, 10)

	local startPos    = root.Position
	local targetSafeY = self:_safeY(targetPos)
	local cruiseY     = math.max(startPos.Y, targetSafeY, self.SeaLevel + self.SeaFloor)
	local alive = function()
		return myFlight == self._flightId and aliveChar(self) ~= nil
	end

	-- Fase 1: eleva até cruzeiro
	if startPos.Y < (cruiseY - 5) then
		if not alive() then self:_cleanup(); return false end
		self:_tweenTo(CFrame.new(Vector3.new(startPos.X, cruiseY, startPos.Z)), speed * 1.2)
	end

	-- Fase 2: cruzeiro chunkado (tween gigante = flag teleport + disconnect)
	if alive() then
		local flatDir = Vector3.new(targetPos.X - startPos.X, 0, targetPos.Z - startPos.Z)
		local hDist = flatDir.Magnitude
		local steps = math.max(1, math.ceil(hDist / SEG_LEN))
		for i = 1, steps do
			if not alive() then self:_cleanup(); return false end
			local t = i / steps
			local wp = Vector3.new(
				startPos.X + (targetPos.X - startPos.X) * t,
				cruiseY,
				startPos.Z + (targetPos.Z - startPos.Z) * t
			)
			self:_requestStream(wp)
			self:_tweenTo(lookCFrame(wp, flatDir), speed)
		end
	end

	-- Fase 3: descida suave
	if alive() then
		local finalY = math.max(targetPos.Y, self.SeaLevel + 5)
		self:_tweenTo(CFrame.new(Vector3.new(targetPos.X, finalY, targetPos.Z)), speed * 1.1)
	end

	self:_cleanup()
	return alive()
end

-- ─── Voa até um alvo com margem de parada ───────────────────
function SmartFlight:FlyToTarget(targetPart, stopRadius)
	stopRadius = stopRadius or 10
	if not aliveChar(self) then return false end

	self._flightId += 1
	local myFlight = self._flightId
	self._flying = true
	self:_startNoclip()

	local t0 = os.clock()
	local lastTween = 0
	while myFlight == self._flightId do
		local root = aliveChar(self)
		if not root or not targetPart or not targetPart.Parent then break end
		if (targetPart.Position - root.Position).Magnitude <= stopRadius then break end
		if os.clock() - t0 > 120 then break end -- alvo fugindo; sem loop infinito
		if os.clock() - lastTween >= 1.0 then -- tween spam = flag teleport
			lastTween = os.clock()
			self:_tweenTo(lookCFrame(targetPart.Position, targetPart.Position - root.Position), self.SpeedBase)
		end
		task.wait(0.2)
	end

	self:_cleanup()
	return true
end

-- ─── Hover estático em uma posição ──────────────────────────
function SmartFlight:HoverAt(position, durationSecs)
	local root = aliveChar(self)
	if not root then return end

	local safeY  = self:_safeY(position)
	local hoverPos = Vector3.new(position.X, safeY, position.Z)

	self:FlyTo(hoverPos) -- sem CFrame direto: teleport = disconnect
	task.wait(durationSecs or 0)
end

-- ─── Limpeza e encerramento do voo ───────────────────────────
function SmartFlight:_cleanup()
	self._flying = false
	self:_stopNoclip()
	if self._currentTween then
		pcall(function() self._currentTween:Cancel() end)
		self._currentTween = nil
	end
end

-- ─── Para qualquer movimento em curso ───────────────────────
function SmartFlight:Stop()
	self._flightId += 1 -- cancela loop de voo em andamento
	self:_cleanup()
end

-- ─── Atualiza referência ao character (respawn) ─────────────
function SmartFlight:SetCharacter(character)
	self:Stop()
	self.Character = character
end

return SmartFlight
