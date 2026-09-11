-- ============================================================
--  Elite Automation Framework :: Systems.QuestManager
--  Auto-Quest system para GPO com priorização inteligente.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local QuestManager = {}
QuestManager.__index = QuestManager

-- ─── Quest database GPO ───────────────────────────────────────
local QUESTS = {
	-- First Sea
	{
		Name = "Bandit Quest",
		NPC = "Quest Giver",
		Location = Vector3.new(1100, 18, 1230),
		Island = "Town of Beginnings",
		Level = 1,
		ExpReward = 150,
		PeliReward = 500,
		Enemies = {"Bandit", "Thug"},
		Count = 5,
	},
	{
		Name = "Desert Bandits",
		NPC = "Desert Quest Giver",
		Location = Vector3.new(-1100, 18, 1400),
		Island = "Sandora",
		Level = 10,
		ExpReward = 400,
		PeliReward = 1200,
		Enemies = {"Desert Bandit", "Sandora Thug"},
		Count = 8,
	},
	{
		Name = "Marine Quest",
		NPC = "Marine Officer",
		Location = Vector3.new(-3800, 20, -4200),
		Island = "Shell's Town",
		Level = 20,
		ExpReward = 800,
		PeliReward = 2500,
		Enemies = {"Marine", "Marine Private"},
		Count = 10,
	},
	-- Second Sea
	{
		Name = "Desert Kingdom Quest",
		NPC = "Desert Kingdom Guard",
		Location = Vector3.new(-1200, 25, -3000),
		Island = "Desert Kingdom",
		Level = 60,
		ExpReward = 5000,
		PeliReward = 8000,
		Enemies = {"Desert Warrior", "Kingdom Guard"},
		Count = 12,
	},
}

function QuestManager.new(combat, smartFlight, notifications, settings)
	local self = setmetatable({}, QuestManager)

	self.Combat = combat
	self.SmartFlight = smartFlight
	self.Notifications = notifications
	self.Settings = settings or {}

	self._running = false
	self._thread = nil
	self._currentQuest = nil
	self._questProgress = 0

	return self
end

-- ─── Detecta nível do player ──────────────────────────────────
function QuestManager:_getPlayerLevel()
	local lp = Players.LocalPlayer
	if not lp then return 1 end

	-- GPO armazena level em leaderstats ou PlayerData
	local leaderstats = lp:FindFirstChild("leaderstats")
	if leaderstats then
		local lvl = leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("level")
		if lvl and lvl.Value then
			return tonumber(lvl.Value) or 1
		end
	end

	-- Fallback: Character Attribute
	local char = lp.Character
	if char then
		local level = char:GetAttribute("Level")
		if level then return level end
	end

	return 1
end

-- ─── Seleciona melhor quest baseado em nível ─────────────────
function QuestManager:_selectBestQuest()
	local playerLevel = self:_getPlayerLevel()
	local best = nil
	local bestScore = -math.huge

	for _, quest in ipairs(QUESTS) do
		-- Ignora quests muito acima do nível
		if quest.Level <= (playerLevel + 10) then
			-- Score = ExpReward / Dificuldade
			local difficulty = math.max(1, quest.Level - playerLevel + quest.Count * 0.5)
			local score = quest.ExpReward / difficulty

			if score > bestScore then
				bestScore = score
				best = quest
			end
		end
	end

	return best
end

-- ─── Aceita quest no NPC ──────────────────────────────────────
function QuestManager:_acceptQuest(quest)
	Logger.Info("Aceitando quest:", quest.Name)

	-- Voa até o NPC
	if self.SmartFlight and quest.Location then
		self.SmartFlight:FlyTo(quest.Location)
	end

	task.wait(0.5)

	-- Procura NPC no workspace
	local npc = workspace:FindFirstChild(quest.NPC, true)
	if not npc then
		Logger.Warn("NPC não encontrado:", quest.NPC)
		return false
	end

	-- Tenta clicar no NPC (ProximityPrompt ou ClickDetector)
	local prompt = npc:FindFirstChildOfClass("ProximityPrompt", true)
	if prompt and fireproximityprompt then
		fireproximityprompt(prompt)
		task.wait(0.3)
	end

	local detector = npc:FindFirstChildOfClass("ClickDetector", true)
	if detector and fireclickdetector then
		fireclickdetector(detector)
		task.wait(0.3)
	end

	Logger.Success("Quest aceita:", quest.Name)
	return true
end

-- ─── Farm inimigos da quest ───────────────────────────────────
function QuestManager:_farmEnemies(quest)
	Logger.Info("Farmando inimigos:", table.concat(quest.Enemies, ", "))

	local killed = 0
	local timeout = os.clock() + 300  -- 5 min max

	while self._running and killed < quest.Count and os.clock() < timeout do
		local target = nil

		-- Procura inimigo da quest
		for _, enemyName in ipairs(quest.Enemies) do
			local enemy = workspace:FindFirstChild(enemyName, true)
			if enemy then
				local hum = enemy:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					target = enemy
					break
				end
			end
		end

		if target then
			-- Engaja combate
			local root = target:FindFirstChild("HumanoidRootPart")
			if root and self.SmartFlight then
				self.SmartFlight:FlyTo(root.Position)
			end

			if self.Combat then
				self.Combat:SetTarget(target)
			end

			-- Aguarda morte
			local hum = target:FindFirstChildOfClass("Humanoid")
			while hum and hum.Health > 0 and target.Parent do
				task.wait(0.2)
			end

			killed = killed + 1
			self._questProgress = killed / quest.Count
			Logger.Info(string.format("Progresso: %d/%d", killed, quest.Count))
		else
			-- Nenhum inimigo encontrado, aguarda respawn
			task.wait(2)
		end
	end

	return killed >= quest.Count
end

-- ─── Loop principal ───────────────────────────────────────────
function QuestManager:_loop()
	while self._running do
		local ok, err = pcall(function()
			-- Seleciona melhor quest
			local quest = self:_selectBestQuest()
			if not quest then
				Logger.Warn("Nenhuma quest disponível para o nível atual")
				task.wait(10)
				return
			end

			self._currentQuest = quest
			self._questProgress = 0

			-- Aceita quest
			local accepted = self:_acceptQuest(quest)
			if not accepted then
				task.wait(5)
				return
			end

			-- Notifica UI
			if self.Notifications then
				local lp = Players.LocalPlayer
				if lp and lp.PlayerGui then
					self.Notifications.Create(
						lp.PlayerGui,
						"📜 QUEST INICIADA",
						quest.Name .. " - " .. quest.Island,
						4,
						Color3.fromRGB(100, 200, 255)
					)
				end
			end

			-- Farm inimigos
			local completed = self:_farmEnemies(quest)

			if completed then
				Logger.Success("Quest completada:", quest.Name, "| +", quest.ExpReward, "EXP")

				if self.Notifications then
					local lp = Players.LocalPlayer
					if lp and lp.PlayerGui then
						self.Notifications.Create(
							lp.PlayerGui,
							"✅ QUEST COMPLETA",
							string.format("+%d EXP | +%d Peli", quest.ExpReward, quest.PeliReward),
							5,
							Color3.fromRGB(80, 220, 130)
						)
					end
				end
			end

			self._currentQuest = nil
			task.wait(2)
		end)

		if not ok then
			Logger.Error("QuestManager loop error:", err)
		end

		task.wait(1)
	end
end

-- ─── API Pública ──────────────────────────────────────────────
function QuestManager:Start()
	if self._running then return end
	self._running = true
	self._thread = task.spawn(function() self:_loop() end)
	Logger.Info("QuestManager iniciado.")
end

function QuestManager:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	self._currentQuest = nil
	Logger.Info("QuestManager parado.")
end

function QuestManager:GetCurrentQuest()
	return self._currentQuest
end

function QuestManager:GetProgress()
	return self._questProgress
end

return QuestManager
