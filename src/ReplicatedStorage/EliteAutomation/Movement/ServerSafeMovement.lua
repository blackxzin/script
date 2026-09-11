-- ============================================================
--  Elite Automation Framework :: Movement.ServerSafeMovement
--  Movimento com validação server-side em mente.
--  Baseado em análise do anti-cheat GPO.
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)
local HumanMovement = require(Root.Movement.HumanMovement)

local ServerSafeMovement = {}
ServerSafeMovement.__index = ServerSafeMovement

-- ─── Limites de velocidade seguros (GPO observado) ────────────
local SAFE_LIMITS = {
	-- Velocidades máximas observadas como seguras
	WalkSpeed = 20,        -- Velocidade padrão do humanoid
	MaxTweenSpeed = 48,    -- Velocidade máxima de tween segura
	DashSpeed = 35,        -- Dash/Geppo típico
	FruitSpeed = 60,       -- Algumas frutas (Pika, etc) são mais rápidas

	-- Distâncias
	MaxTeleportDist = 100, -- Distância máxima segura para "teleporte"

	-- Tempos
	MinTweenTime = 0.8,    -- Tempo mínimo de tween (evita instantâneo)

	-- Altitude
	MaxAltitude = 500,     -- Altura máxima segura
	SeaLevel = 0,
	SafeSeaOffset = 35,
}

function ServerSafeMovement.new(character, settings)
	local self = setmetatable({}, ServerSafeMovement)

	self.Character = character
	self.Settings = settings or {}

	-- Modo extremamente conservador (padrão)
	self.SafetyLevel = self.Settings.SafetyLevel or "Extreme"  -- Extreme, High, Medium

	self._lastPosition = nil
	self._lastMoveTime = 0
	self._movementHistory = {}  -- Últimos 10 movimentos
	self._suspicionScore = 0    -- Score de suspeita (0-100)

	return self
end

-- ─── Calcula velocidade segura baseada em contexto ────────────
function ServerSafeMovement:_getSafeSpeed(distance)
	local baseSpeed = SAFE_LIMITS.MaxTweenSpeed

	-- Ajusta por nível de segurança
	if self.SafetyLevel == "Extreme" then
		baseSpeed = baseSpeed * 0.75  -- 36 studs/s
	elseif self.SafetyLevel == "High" then
		baseSpeed = baseSpeed * 0.85  -- 40.8 studs/s
	end

	-- Adiciona variação Perlin
	local speed = HumanMovement.PerlinVelocity(baseSpeed, os.clock(), 123)

	-- Limita ao máximo absoluto
	return math.clamp(speed, 20, SAFE_LIMITS.MaxTweenSpeed)
end

-- ─── Valida se movimento é server-safe ────────────────────────
function ServerSafeMovement:_validateMovement(startPos, endPos, duration)
	local distance = (endPos - startPos).Magnitude
	local speed = distance / duration

	-- Check 1: Velocidade impossível
	if speed > SAFE_LIMITS.FruitSpeed then
		Logger.Warn("Movimento rejeitado: velocidade muito alta", speed)
		return false, "speed_too_high"
	end

	-- Check 2: Teleporte suspeito
	if distance > SAFE_LIMITS.MaxTeleportDist and duration < SAFE_LIMITS.MinTweenTime then
		Logger.Warn("Movimento rejeitado: teleporte detectado", distance, duration)
		return false, "teleport_detected"
	end

	-- Check 3: Altitude impossível
	if endPos.Y > SAFE_LIMITS.MaxAltitude then
		Logger.Warn("Movimento rejeitado: altitude muito alta", endPos.Y)
		return false, "altitude_too_high"
	end

	-- Check 4: Frequência de movimento (anti-spam)
	local now = os.clock()
	if (now - self._lastMoveTime) < 0.3 then
		Logger.Warn("Movimento rejeitado: frequência muito alta")
		return false, "move_spam"
	end

	return true, "ok"
end

-- ─── Registra movimento no histórico (para análise) ───────────
function ServerSafeMovement:_recordMovement(startPos, endPos, duration, speed)
	table.insert(self._movementHistory, {
		Start = startPos,
		End = endPos,
		Duration = duration,
		Speed = speed,
		Time = os.clock(),
	})

	-- Mantém apenas últimos 10
	if #self._movementHistory > 10 then
		table.remove(self._movementHistory, 1)
	end

	-- Calcula score de suspeita
	self:_updateSuspicionScore()
end

-- ─── Atualiza score de suspeita baseado em padrões ────────────
function ServerSafeMovement:_updateSuspicionScore()
	local score = 0

	-- Analisa últimos 5 movimentos
	local recent = {}
	for i = math.max(1, #self._movementHistory - 4), #self._movementHistory do
		table.insert(recent, self._movementHistory[i])
	end

	if #recent >= 3 then
		-- Check: Velocidade muito consistente (não humano)
		local speeds = {}
		for _, move in ipairs(recent) do
			table.insert(speeds, move.Speed)
		end

		local avgSpeed = 0
		for _, s in ipairs(speeds) do
			avgSpeed = avgSpeed + s
		end
		avgSpeed = avgSpeed / #speeds

		local variance = 0
		for _, s in ipairs(speeds) do
			variance = variance + math.abs(s - avgSpeed)
		end
		variance = variance / #speeds

		-- Velocidade muito consistente = suspeito
		if variance < 2 then
			score = score + 15
		end

		-- Check: Mudanças de direção perfeitas (linhas retas)
		local straightLines = 0
		for i = 2, #recent do
			local prev = recent[i - 1]
			local curr = recent[i]

			local dir1 = (prev.End - prev.Start).Unit
			local dir2 = (curr.End - curr.Start).Unit

			local dot = dir1:Dot(dir2)
			if dot > 0.99 then  -- Quase paralelo
				straightLines = straightLines + 1
			end
		end

		if straightLines == #recent - 1 then
			score = score + 20  -- Todos movimentos em linha reta
		end
	end

	self._suspicionScore = math.clamp(score, 0, 100)

	if self._suspicionScore > 50 then
		Logger.Warn("⚠ SCORE DE SUSPEITA ALTO:", self._suspicionScore, "- Aumentando aleatoriedade")
	end
end

-- ─── Movimento seguro com validação completa ───────────────────
function ServerSafeMovement:SafeMoveTo(targetPos)
	local root = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local startPos = root.Position
	local distance = (targetPos - startPos).Magnitude

	-- Calcula duração baseada em velocidade segura
	local speed = self:_getSafeSpeed(distance)
	local duration = distance / speed

	-- Adiciona tempo mínimo
	duration = math.max(duration, SAFE_LIMITS.MinTweenTime)

	-- Valida movimento
	local valid, reason = self:_validateMovement(startPos, targetPos, duration)
	if not valid then
		Logger.Error("Movimento cancelado:", reason)
		return false
	end

	-- Adiciona micro-desvios se score alto
	local finalPos = targetPos
	if self._suspicionScore > 30 then
		finalPos = HumanMovement.AddJitter(targetPos, 1.5)
	end

	-- Executa tween
	local tween = TweenService:Create(
		root,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{CFrame = CFrame.new(finalPos)}
	)

	tween:Play()
	tween.Completed:Wait()

	-- Registra movimento
	self:_recordMovement(startPos, finalPos, duration, speed)
	self._lastPosition = finalPos
	self._lastMoveTime = os.clock()

	Logger.Debug("Movimento seguro concluído:", distance, "studs em", string.format("%.2fs", duration))
	return true
end

-- ─── Movimento em segmentos (para distâncias longas) ──────────
function ServerSafeMovement:SafeLongDistance(targetPos)
	local root = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local startPos = root.Position
	local totalDist = (targetPos - startPos).Magnitude

	-- Se distância > 100, divide em segmentos
	if totalDist > SAFE_LIMITS.MaxTeleportDist then
		local segments = math.ceil(totalDist / 80)  -- Segmentos de ~80 studs
		local path = HumanMovement.OrganicPath(startPos, targetPos, segments)

		for i, waypoint in ipairs(path) do
			local success = self:SafeMoveTo(waypoint)
			if not success then
				Logger.Error("Falha no segmento", i, "de", #path)
				return false
			end

			-- Pausa natural entre segmentos
			if i < #path then
				task.wait(HumanMovement.HumanDelay(0.2, 0.1))
			end
		end

		return true
	else
		return self:SafeMoveTo(targetPos)
	end
end

-- ─── Reseta score de suspeita (quando ficar idle) ─────────────
function ServerSafeMovement:ResetSuspicion()
	self._suspicionScore = math.max(0, self._suspicionScore - 5)
	self._movementHistory = {}
end

function ServerSafeMovement:GetSuspicionScore()
	return self._suspicionScore
end

function ServerSafeMovement:SetSafetyLevel(level)
	if level == "Extreme" or level == "High" or level == "Medium" then
		self.SafetyLevel = level
		Logger.Info("Safety level alterado para:", level)
	end
end

return ServerSafeMovement
