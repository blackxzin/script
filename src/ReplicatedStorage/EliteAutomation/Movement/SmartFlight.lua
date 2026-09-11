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

-- ─── Utilitário: aguarda tween terminar de forma segura ──────
local function awaitTween(tween)
	if not tween then return end
	local done = false
	local conn
	conn = tween.Completed:Connect(function()
		done = true
	end)
	while not done and tween.PlaybackState == Enum.PlaybackState.Playing do
		task.wait()
	end
	if conn then conn:Disconnect() end
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

	-- Cria BodyVelocity de estabilização de física se não existir.
	-- O BodyVelocity zera a inércia perante a física do Roblox e o anticheat do GPO,
	-- permitindo que o TweenService mova o CFrame sem disparar o detector de queda/teleporte.
	if root and not root:FindFirstChild("FlightStabilizer") then
		local bv = Instance.new("BodyVelocity")
		bv.Name = "FlightStabilizer"
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Velocity = Vector3.zero
		bv.Parent = root
	end

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

		-- Spoof de estado de física para evitar detecção de noclip no GPO
		local h = self:_getHumanoid()
		if h and h.Health > 0 then
			h:ChangeState(Enum.HumanoidStateType.Physics)
		end
	end)
end

function SmartFlight:_stopNoclip()
	if self._noclipConn then
		self._noclipConn:Disconnect()
		self._noclipConn = nil
	end

	-- Remove o estabilizador de física
	local root = self:_getRoot()
	if root then
		local bv = root:FindFirstChild("FlightStabilizer")
		if bv then bv:Destroy() end
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
	local ray = Ray.new(
		Vector3.new(targetPos.X, 5000, targetPos.Z),
		Vector3.new(0, -6000, 0)
	)
	local hit, hitPos = workspace:FindPartOnRayWithIgnoreList(
		ray, { self.Character }
	)
	local groundY = hit and hitPos.Y or self.SeaLevel

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
	local root = self:_getRoot()
	if not root then return false end

	local dist = (targetCFrame.Position - root.Position).Magnitude
	if dist < 0.5 then return true end

	-- Pre-requisita streaming da área de destino
	self:_requestStream(targetCFrame.Position)

	local duration = dist / math.max(speed, 5)

	local info = TweenInfo.new(
		duration,
		self.TweenStyle,
		self.TweenDir
	)

	local tween = TweenService:Create(root, info, { CFrame = targetCFrame })
	self._currentTween = tween
	tween:Play()

	awaitTween(tween)

	-- Limpa referência
	if self._currentTween == tween then
		self._currentTween = nil
	end

	return true
end

-- ─── Voa até uma posição com trajetória otimizada ────────────
--[[
	targetPos : Vector3 do destino
	Usa estratégia de voo em 3 fases:
	  1. Subida até a altitude segura de cruzeiro (evita bater em montanhas/ilhas)
	  2. Cruzeiro horizontal até as coordenadas X, Z
	  3. Descida suave até o alvo final
]]
function SmartFlight:FlyTo(targetPos)
	local root = self:_getRoot()
	if not root then return false end

	-- Cancela qualquer tween anterior
	if self._currentTween then
		self._currentTween:Cancel()
		self._currentTween = nil
	end

	self._flying = true
	self:_startNoclip()

	local speed = self.SpeedBase + randBetween(self.JitterMin, self.JitterMax)
	speed       = math.max(speed, 10)

	local startPos    = root.Position
	local targetSafeY = self:_safeY(targetPos)
	local cruiseY     = math.max(startPos.Y, targetSafeY, self.SeaLevel + self.SeaFloor)

	local horizontalDist = (Vector3.new(targetPos.X, 0, targetPos.Z)
		- Vector3.new(startPos.X, 0, startPos.Z)).Magnitude

	-- Se o percurso for longo (> 80 studs), usa subida -> cruzeiro -> descida
	if horizontalDist > 80 then
		-- Fase 1: Eleva até a altitude de cruzeiro se estiver mais baixo
		if startPos.Y < (cruiseY - 5) then
			local liftCFrame = CFrame.new(Vector3.new(startPos.X, cruiseY, startPos.Z))
			self:_tweenTo(liftCFrame, speed * 1.2)
		end

		if not self._flying then self:_cleanup(); return false end

		-- Fase 2: Cruzeiro horizontal direto até a vertical do destino
		local cruiseCFrame = CFrame.new(
			Vector3.new(targetPos.X, cruiseY, targetPos.Z),
			Vector3.new(targetPos.X, cruiseY, targetPos.Z) + (targetPos - startPos).Unit
		)
		self:_tweenTo(cruiseCFrame, speed)

		if not self._flying then self:_cleanup(); return false end

		-- Fase 3: Descida suave até a posição alvo
		local finalY = math.max(targetPos.Y, self.SeaLevel + 5)
		local finalCFrame = CFrame.new(Vector3.new(targetPos.X, finalY, targetPos.Z))
		self:_tweenTo(finalCFrame, speed * 1.1)

	else
		-- Percurso curto: vai diretamente ao alvo
		local finalY = math.max(targetPos.Y, self.SeaLevel + 5)
		local targetCFrame = CFrame.new(Vector3.new(targetPos.X, finalY, targetPos.Z))
		self:_tweenTo(targetCFrame, speed)
	end

	self:_cleanup()
	return true
end

-- ─── Voa até um alvo com margem de parada ───────────────────
function SmartFlight:FlyToTarget(targetPart, stopRadius)
	stopRadius = stopRadius or 10
	local root = self:_getRoot()
	if not root then return false end

	while targetPart and targetPart.Parent and self._flying do
		local dist = (targetPart.Position - root.Position).Magnitude
		if dist <= stopRadius then
			break
		end
		local result = self:FlyTo(targetPart.Position)
		if not result then break end
		task.wait(0.05)
	end

	self:_cleanup()
	return true
end

-- ─── Hover estático em uma posição ──────────────────────────
function SmartFlight:HoverAt(position, durationSecs)
	local root = self:_getRoot()
	if not root then return end

	local safeY  = self:_safeY(position)
	local hoverPos = Vector3.new(position.X, safeY, position.Z)

	root.CFrame = CFrame.new(hoverPos)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	task.wait(durationSecs or 0)
end

-- ─── Limpeza e encerramento do voo ───────────────────────────
function SmartFlight:_cleanup()
	self._flying = false
	self:_stopNoclip()
	if self._currentTween then
		self._currentTween:Cancel()
		self._currentTween = nil
	end
end

-- ─── Para qualquer movimento em curso ───────────────────────
function SmartFlight:Stop()
	self:_cleanup()
end

-- ─── Atualiza referência ao character (respawn) ─────────────
function SmartFlight:SetCharacter(character)
	self:Stop()
	self.Character = character
end

return SmartFlight
