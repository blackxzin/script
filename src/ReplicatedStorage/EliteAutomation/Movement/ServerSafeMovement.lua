-- ============================================================
--  Elite Automation Framework :: Movement.ServerSafeMovement
--  Arquitetura de Movimento com Validação de Padrão e Anti-Detection
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

-- ─── [1] CONSTANTES DE SEGURANÇA (Hard Limits) ──────────────
local SAFE_LIMITS = {
	MaxTweenSpeed    = 48,    -- Limite para evitar detecção de velocidade
	MaxTeleportDist  = 85,    -- Distância máxima por segmento (Chunking)
	MinTweenTime     = 0.8,   -- Tempo mínimo para evitar "snapping"
	MaxAltitude      = 500,   -- Limite de altura para evitar detecção de voo
	MaxSuspicion     = 100,   -- Score máximo de suspeita
}

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────
function ServerSafeMovement.new(character, settings)
	local self = setmetatable({}, ServerSafeMovement)

	self.Character = character
	self.Settings = settings or {}

	-- Níveis de Segurança: Extreme (Mais lento/seguro) -> Medium (Mais rápido)
	self.SafetyLevel = self.Settings.SafetyLevel or "Extreme" 

	self._lastMoveTime = 0
	self._movementHistory = {}  -- Armazena os últimos 10 movimentos para análise de padrão
	self._suspicionScore = 0    -- Score de suspeita baseado em comportamento
	self._isMoving = false

	return self
end

-- ─── [3] MOTOR DE VELOCIDADE (Gaussian Velocity) ─────────────
function ServerSafeMovement:_getSafeSpeed(distance)
	local baseSpeed = SAFE_LIMITS.MaxTweenSpeed

	-- Ajuste por nível de segurança
	if self.SafetyLevel == "Extreme" then
		baseSpeed = baseSpeed * 0.70 -- ~33 studs/s
	elseif self.SafetyLevel == "High" then
		baseSpeed = baseSpeed * 0.85 -- ~40 studs/s
	end

	-- Aplica variação orgânica (Perlin Noise) para não ser constante
	return HumanMovement.PerlinVelocity(baseSpeed, os.clock(), 123)
end

-- ─── [4] VALIDAÇÃO DE PADRÃO (Anti-Pattern Detection) ────────
function ServerSafeMovement:_validateMovement(startPos, endPos, duration)
	local distance = (endPos - startPos).Magnitude
	local speed = distance / duration

	-- Check 1: Velocidade (Speed Hack Detection)
	if speed > SAFE_LIMITS.MaxTweenSpeed + 5 then
		Logger.Warn("Segurança: Velocidade excessiva detectada!")
		return false, "speed_limit_exceeded"
	end

	-- Check 2: Teleporte (Snap Detection)
	if distance > SAFE_LIMITS.MaxTeleportDist and duration < SAFE_LIMITS.MinTweenTime then
		return false, "teleport_snap"
	end

	-- Check 3: Altitude (Sky Hack Detection)
	if endPos.Y > SAFE_LIMITS.MaxAltitude then
		return false, "altitude_too_high"
	end

	-- Check 4: Anti-Spam (Movement Frequency)
	local now = os.clock()
	if (now - self._lastMoveTime) < 0.25 then
		return false, "movement_spam"
	end

	return true, "ok"
end

-- ─── [5] ANÁLISE DE COMPORTAMENTO (Suspicion Score) ──────────
function ServerSafeMovement:_updateSuspicionScore(newMove)
	table.insert(self._movementHistory, newMove)
	if #self._movementHistory > 10 then table.remove(self._movementHistory, 1) end

	local score = 0
	if #self._movementHistory < 5 then return end

	-- Check: Linha Reta Perfeita (Bot Detection)
	local straightLines = 0
	for i = 2, #self._movementHistory do
		local m1 = self._movementHistory[i-1]
		local m2 = self._movementHistory[i]
		
		local dir1 = (m1.End - m1.Start).Unit
		local dir2 = (m2.End - m2.Start).Unit
		
		if dir1:Dot(dir2) > 0.995 then -- Quase paralelo
			straightLines += 1
		end
	end

	if straightLines >= 3 then score += 30 end

	-- Check: Velocidade Constante (Inconsistência Humana)
	local avgSpeed = 0
	for _, m in ipairs(self._movementHistory) do avgSpeed += m.speed end
	avgSpeed /= #self._movementHistory
	
	local variance = 0
	for _, m in ipairs(self._movementHistory) do variance += math.abs(m.speed - avgSpeed) end
	variance /= #self._movementHistory

	if variance < 1.5 then score += 25 end -- Velocidade muito estável é suspeita

	self._suspicionScore = math.clamp(score, 0, SAFE_LIMITS.MaxSuspicion)
end

-- ─── [6] MOVIMENTO SEGURO (Core Method) ───────────────────────
function ServerSafeMovement:SafeMoveTo(targetPos)
	local root = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	if not root or self._isMoving then return false end

	local startPos = root.Position
	local distance = (targetPos - startPos).Magnitude
	
	-- Calcula duração baseada em velocidade dinâmica
	local speed = self:_getSafeSpeed(distance)
	local duration = math.max(distance / speed, SAFE_LIMITS.MinTweenTime)

	-- Validação antes de iniciar
	local valid, reason = self:_validateMovement(startPos, targetPos, duration)
	if not valid then
		Logger.Error("Movimento Bloqueado: " .. reason)
		return false
	end

	self._isMoving = true

	-- Aplica o caminho orgânico (Curvas em vez de linhas retas)
	local pathPoints = HumanMovement.OrganicPath(startPos, targetPos, 4)
	
	for i = 1, #pathPoints - 1 do
		local p1 = pathPoints[i]
		local p2 = pathPoints[i+1]
		local segmentDist = (p2 - p1).Magnitude
		local segmentDuration = math.max(segmentDist / speed, 0.2)

		-- Adiciona Jitter se a suspeita estiver alta
		local finalTarget = p2
		if self._suspicionScore > 40 then
			finalTarget = HumanMovement.AddJitter(p2, 1.2)
		end

		local tween = TweenService:Create(root, 
			TweenInfo.new(segmentDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), 
			{CFrame = CFrame.new(finalTarget)}
		)

		tween:Play()
		tween.Completed:Wait()
		
		-- Pequena pausa entre segmentos para simular hesitação humana
		task.wait(HumanMovement.HumanDelay(0.1, 0.05))
	end

	-- Finalização do movimento
	self._lastMoveTime = os.clock()
	self._isMoving = false
	
	-- Registra para análise de padrão
	self:_updateSuspicionScore({
		speed = speed,
		dist = distance,
		time = os.clock()
	})

	Logger.Debug("Movimento Seguro Finalizado: " .. string.format("%.1f", distance) .. " studs")
	return true
end

-- ─── [7] MOVIMENTO DE LONGA DISTÂNCIA (Chunking) ─────────────
function ServerSafeMovement:SafeLongDistance(targetPos)
	local root = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local startPos = root.Position
	local totalDist = (targetPos - startPos).Magnitude

	-- Se a distância for muito grande, divide em segmentos (chunks)
	-- Isso evita o "Teleporte" que o servidor detecta
	local segments = math.ceil(totalDist / SAFE_LIMITS.MaxTeleportDist)
	
	for i = 1, segments do
		local progress = i / segments
		local nextWaypoint = startPos:Lerp(targetPos, progress)
		
		-- Adiciona um pequeno atraso entre os chunks
		local success = self:SafeMoveTo(nextWaypoint)
		
		if not success then
			Logger.Error("Falha no trajeto longo no segmento: " .. i)
			return false
		end
		
		task.wait(HumanMovement.HumanDelay(0.2, 0.1))
	end

	return true
end

-- ─── [8] UTILITÁRIOS ─────────────────────────────────────────
function ServerSafeMovement:ResetSuspicion()
	self._suspicionScore = 0
	self._movementHistory = {}
	Logger.Info("Score de suspeita resetado.")
end

function ServerSafeMovement:GetSuspicionScore()
    return self._suspicionScore
end

function ServerSafeMovement:SetSafetyLevel(level)
    self.SafetyLevel = level
    Logger.Info("Nível de Segurança: " .. level)
end

return ServerSafeMovement