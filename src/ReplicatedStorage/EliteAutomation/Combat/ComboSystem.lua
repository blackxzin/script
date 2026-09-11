-- ============================================================
--  Elite Automation Framework :: Combat.ComboSystem
--  Sistema de combos inteligente para GPO com skill rotation.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)
local HumanMovement = require(Root.Movement.HumanMovement)

local ComboSystem = {}
ComboSystem.__index = ComboSystem

-- ─── Combos pré-configurados por tipo de build ────────────────
local COMBOS = {
	-- Sword Main (Espada)
	Sword = {
		{Key = Enum.KeyCode.Z, Name = "Skill 1 (Z)", Cooldown = 8, Priority = 1},
		{Key = Enum.KeyCode.X, Name = "Skill 2 (X)", Cooldown = 10, Priority = 2},
		{Key = Enum.KeyCode.C, Name = "Skill 3 (C)", Cooldown = 15, Priority = 3},
	},

	-- Devil Fruit (Akuma no Mi)
	DevilFruit = {
		{Key = Enum.KeyCode.Z, Name = "DF Move 1", Cooldown = 6, Priority = 1},
		{Key = Enum.KeyCode.X, Name = "DF Move 2", Cooldown = 9, Priority = 2},
		{Key = Enum.KeyCode.C, Name = "DF Move 3", Cooldown = 12, Priority = 3},
		{Key = Enum.KeyCode.V, Name = "DF Move 4", Cooldown = 18, Priority = 4},
	},

	-- Fighting Style (Estilo de Luta)
	FightingStyle = {
		{Key = Enum.KeyCode.Z, Name = "Combat Art 1", Cooldown = 7, Priority = 1},
		{Key = Enum.KeyCode.X, Name = "Combat Art 2", Cooldown = 10, Priority = 2},
		{Key = Enum.KeyCode.C, Name = "Combat Art 3", Cooldown = 14, Priority = 3},
	},

	-- Hybrid (Mix de tudo)
	Hybrid = {
		{Key = Enum.KeyCode.Z, Name = "Sword Z", Cooldown = 8, Priority = 1},
		{Key = Enum.KeyCode.X, Name = "DF X", Cooldown = 9, Priority = 2},
		{Key = Enum.KeyCode.C, Name = "Sword C", Cooldown = 15, Priority = 3},
		{Key = Enum.KeyCode.V, Name = "DF V", Cooldown = 18, Priority = 4},
	},
}

function ComboSystem.new(buildType)
	local self = setmetatable({}, ComboSystem)

	self.BuildType = buildType or "Hybrid"
	self.Combo = COMBOS[self.BuildType] or COMBOS.Hybrid
	self.Cooldowns = {}  -- [skillName] = lastUseTime
	self.Enabled = false

	for _, skill in ipairs(self.Combo) do
		self.Cooldowns[skill.Name] = 0
	end

	return self
end

-- ─── Verifica se skill está em cooldown ───────────────────────
function ComboSystem:_isOnCooldown(skill)
	local lastUse = self.Cooldowns[skill.Name] or 0
	local elapsed = os.clock() - lastUse
	return elapsed < skill.Cooldown
end

-- ─── Usa uma skill específica ─────────────────────────────────
function ComboSystem:_useSkill(skill)
	Logger.Debug("Usando skill:", skill.Name)

	local vim = game:GetService("VirtualInputManager")
	if not vim then return false end

	-- Input humanizado
	local delay = HumanMovement.InputDelay()

	vim:SendKeyEvent(true, skill.Key, false, game)
	task.wait(delay)
	vim:SendKeyEvent(false, skill.Key, false, game)

	self.Cooldowns[skill.Name] = os.clock()
	return true
end

-- ─── Executa combo completo ────────────────────────────────────
function ComboSystem:ExecuteCombo(target)
	if not self.Enabled then return end
	if not target or not target.Parent then return end

	-- Ordena skills por prioridade
	local available = {}
	for _, skill in ipairs(self.Combo) do
		if not self:_isOnCooldown(skill) then
			table.insert(available, skill)
		end
	end

	table.sort(available, function(a, b)
		return a.Priority < b.Priority
	end)

	-- Executa skills disponíveis em sequência
	for _, skill in ipairs(available) do
		if not target or not target.Parent then break end

		local hum = target:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then break end

		self:_useSkill(skill)

		-- Aguarda entre skills (timing humanizado)
		task.wait(HumanMovement.HumanDelay(0.4, 0.15))
	end
end

-- ─── Usa melhor skill disponível (single) ─────────────────────
function ComboSystem:UseBestSkill()
	if not self.Enabled then return false end

	for _, skill in ipairs(self.Combo) do
		if not self:_isOnCooldown(skill) then
			self:_useSkill(skill)
			return true
		end
	end

	return false
end

-- ─── Muda build type em tempo real ────────────────────────────
function ComboSystem:SetBuildType(buildType)
	if COMBOS[buildType] then
		self.BuildType = buildType
		self.Combo = COMBOS[buildType]
		Logger.Info("Build type alterado para:", buildType)
	end
end

function ComboSystem:Enable()
	self.Enabled = true
	Logger.Info("ComboSystem ativado:", self.BuildType)
end

function ComboSystem:Disable()
	self.Enabled = false
	Logger.Info("ComboSystem desativado")
end

return ComboSystem
