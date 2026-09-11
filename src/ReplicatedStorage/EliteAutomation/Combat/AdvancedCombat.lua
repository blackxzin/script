-- ============================================================
--  Elite Automation Framework :: Combat.AdvancedCombat
--  Sistema de combate avançado baseado em dados reais do GPO.
--  Implementa: Perfect Block, Block Break, Combo chains, iframes.
-- ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)
local HumanMovement = require(Root.Movement.HumanMovement)

local AdvancedCombat = {}
AdvancedCombat.__index = AdvancedCombat

-- ─── Timing de Perfect Block (baseado em observações GPO) ────
local PERFECT_BLOCK_WINDOW = 0.15  -- 150ms antes do hit

-- ─── Combos conhecidos por build ──────────────────────────────
local COMBO_CHAINS = {
	-- Sword Main (3SS)
	ThreeSwordStyle = {
		{M1 = 3, Skill = "Z", M1 = 2, Skill = "X", M1 = 1, Skill = "C"},
	},

	-- Black Leg → Demon Step
	BlackLegCombo = {
		{Skill = "Z", M1 = 2, Skill = "X", M1 = 3, Skill = "C"},
	},

	-- Electro (M1 enhanced)
	ElectroCombo = {
		{Skill = "Z", M1 = 4, Skill = "X", M1 = 3},  -- Electro Fist amplia M1
	},

	-- Dragon Claw
	DragonClawCombo = {
		{Skill = "Z", M1 = 2, Skill = "X", Skill = "C", M1 = 2},
	},

	-- Fishman Karate
	FishmanCombo = {
		{M1 = 2, Skill = "Z", Skill = "X", M1 = 3, Skill = "C"},
	},
}

function AdvancedCombat.new(buildType)
	local self = setmetatable({}, AdvancedCombat)

	self.BuildType = buildType or "ThreeSwordStyle"
	self.Enabled = false
	self.AutoBlock = false
	self.AutoPerfectBlock = false
	self.AutoBlockBreak = true

	self._lastBlock = 0
	self._blockCooldown = 0.5
	self._comboActive = false

	return self
end

-- ─── Detecta ataque iminente (previsão) ───────────────────────
function AdvancedCombat:_predictIncomingAttack(enemy)
	if not enemy or not enemy.Parent then return false end

	local hum = enemy:FindFirstChildOfClass("Humanoid")
	if not hum then return false end

	-- Verifica se animação de ataque está rodando
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		local tracks = animator:GetPlayingAnimationTracks()
		for _, track in ipairs(tracks) do
			local name = track.Name:lower()
			if name:find("punch", 1, true)
				or name:find("kick", 1, true)
				or name:find("slash", 1, true)
				or name:find("attack", 1, true) then
				return true
			end
		end
	end

	-- Verifica distância + estado do humanoid
	local root = enemy:FindFirstChild("HumanoidRootPart")
	local playerRoot = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

	if root and playerRoot then
		local dist = (root.Position - playerRoot.Position).Magnitude
		if dist < 8 then  -- Range de M1 típico
			return true
		end
	end

	return false
end

-- ─── Perfect Block (timing preciso) ───────────────────────────
function AdvancedCombat:_attemptPerfectBlock()
	if not self.AutoPerfectBlock then return end

	local now = os.clock()
	if (now - self._lastBlock) < self._blockCooldown then return end

	-- Timing humanizado
	task.wait(HumanMovement.HumanDelay(0.02, 0.01))

	-- Pressiona F (block no GPO)
	local vim = game:GetService("VirtualInputManager")
	if vim then
		vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
		task.wait(PERFECT_BLOCK_WINDOW)
		vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
	end

	self._lastBlock = now
	Logger.Debug("Perfect Block attempt")
end

-- ─── Block Break (quebra defesa do inimigo) ───────────────────
function AdvancedCombat:_useBlockBreak()
	-- Skills que quebram Block no GPO:
	-- - Muitas habilidades "C" e "V"
	-- - Dragon Claw Z
	-- - Fishman Karate C
	-- - etc.

	-- Usa skill C (comum ter Block Break)
	local vim = game:GetService("VirtualInputManager")
	if vim then
		vim:SendKeyEvent(true, Enum.KeyCode.C, false, game)
		task.wait(0.05)
		vim:SendKeyEvent(false, Enum.KeyCode.C, false, game)
	end

	Logger.Debug("Block Break usado")
end

-- ─── Executa combo chain ──────────────────────────────────────
function AdvancedCombat:ExecuteCombo(target)
	if not self.Enabled or self._comboActive then return end
	if not target or not target.Parent then return end

	self._comboActive = true

	local combo = COMBO_CHAINS[self.BuildType]
	if not combo or #combo == 0 then
		self._comboActive = false
		return
	end

	local chain = combo[1]
	local vim = game:GetService("VirtualInputManager")

	for _, action in ipairs(chain) do
		if not target or not target.Parent then break end

		if action.M1 then
			-- M1 combo
			for i = 1, action.M1 do
				HumanMovement.HumanClick(function(pressed)
					vim:SendMouseButtonEvent(0, 0, 0, pressed, game, 1)
				end)
				task.wait(HumanMovement.HumanDelay(0.35, 0.08))
			end

		elseif action.Skill then
			-- Skill
			local key = Enum.KeyCode[action.Skill]
			vim:SendKeyEvent(true, key, false, game)
			task.wait(0.05)
			vim:SendKeyEvent(false, key, false, game)
			task.wait(HumanMovement.HumanDelay(0.6, 0.15))
		end
	end

	self._comboActive = false
	Logger.Info("Combo completo executado")
end

-- ─── Loop de defesa automática ────────────────────────────────
function AdvancedCombat:DefenseLoop(enemies)
	if not self.AutoBlock and not self.AutoPerfectBlock then return end

	for _, enemy in ipairs(enemies) do
		if self:_predictIncomingAttack(enemy) then
			if self.AutoPerfectBlock then
				self:_attemptPerfectBlock()
			elseif self.AutoBlock then
				-- Block normal (segura F)
				local vim = game:GetService("VirtualInputManager")
				if vim then
					vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
					task.wait(0.3)
					vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
				end
			end
			break
		end
	end
end

function AdvancedCombat:Enable()
	self.Enabled = true
	Logger.Info("AdvancedCombat ativado:", self.BuildType)
end

function AdvancedCombat:Disable()
	self.Enabled = false
	Logger.Info("AdvancedCombat desativado")
end

return AdvancedCombat
