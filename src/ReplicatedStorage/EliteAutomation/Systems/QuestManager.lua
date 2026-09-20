-- ============================================================
--  Elite Automation Framework :: Systems.QuestManager
--  Arquitetura de Progressão e Automação de Missões
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root       = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger     = require(Root.Core.Logger)

local QuestManager = {}
QuestManager.__index = QuestManager

-- ─── [1] DATABASE DE QUESTS (Otimizada) ──────────────────────

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

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function QuestManager.new(combat, smartFlight, notifications, settings)
	local self = setmetatable({}, QuestManager)

	self.Combat        = combat
	self.SmartFlight   = smartFlight
	self.Notifications = notifications
	self.Settings      = settings or {}

	self._running        = false
	self._thread         = nil
	self._currentQuest   = nil
	self._questProgress  = 0
	self._lastQuestTime  = 0

	return self
end

-- ─── [3] LÓGICA DE DECISÃO (Inteligência de Nível) ──────────

-- Verifica o nível atual do jogador (com fallback de segurança)
function QuestManager:_getPlayerLevel()
	local lp = Players.LocalPlayer
	if not lp then return 1 end

	local leaderstats = lp:FindFirstChild("leaderstats")
	if leaderstats then
		local lvl = leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("level")
		if lvl and lvl.Value then
			return tonumber(lvl.Value) or 1
		end
	end

	local char = lp.Character
	if char then
		local level = char:GetAttribute("Level")
		if level then return level end
	end

	return 1
end

-- Seleciona a melhor quest baseada em Score de Eficiência (Exp/Dificuldade)
function QuestManager:_selectBestQuest()
	local playerLevel = self:_getPlayerLevel()
	local best = nil
	local bestScore = -math.huge

	for _, quest in ipairs(QUESTS) do
		-- Filtro de Nível: Evita quests muito difíceis para o nível atual
		if quest.Level <= (playerLevel + 10) then
			-- Score = Recompensa de XP / (Nível da Quest + Contagem de Inimigos)
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

-- ─── [4] EXECUÇÃO DE AÇÕES (Interação e Combate) ────────────

-- Gerencia a aceitação da quest no NPC
function QuestManager:_acceptQuest(quest)
	Logger.Info("Aceitando Quest: " .. quest.Name)

	-- 1. Deslocamento para o NPC
	if self.SmartFlight then
		if not self.SmartFlight:FlyTo(quest.Location) then
			Logger.Warn("Deslocamento para a quest interrompido: " .. quest.Name)
			return false
		end
		task.wait(1.5) -- Delay de estabilização de voo
	end

	-- 2. Busca do NPC no Workspace
	local npc = workspace:FindFirstChild(quest.NPC, true)
	if not npc then
		Logger.Warn("NPC não encontrado: " .. quest.NPC)
		return false
	end

	-- 3. Interação (ProximityPrompt ou ClickDetector)
	local prompt = npc:FindFirstChildOfClass("ProximityPrompt", true)
	if prompt and fireproximityprompt then
		pcall(function() fireproximityprompt(prompt) end)
		task.wait(0.5)
	end

	local detector = npc:FindFirstChildOfClass("ClickDetector", true)
	if detector and fireclickdetector then
		pcall(function() fireclickdetector(detector) end)
		task.wait(0.5)
	end

	Logger.Success("Quest aceita: " .. quest.Name)
	return true
end

-- Gerencia o combate contra os inimigos da quest
function QuestManager:_farmEnemies(quest)
	Logger.Info("Iniciando Farm: " .. quest.Name)
	local killed = 0
	local timeout = os.clock() + 300 -- Timeout de 5 minutos por quest

	while self._running and killed < quest.Count and os.clock() < timeout do
		local target = nil
		
		-- Busca o inimigo mais próximo da lista de inimigos da quest
		for _, enemyName in ipairs(quest.Enemies) do
			local enemy = workspace:FindFirstChild(enemyName, true)
			if enemy and enemy:IsA("Model") then
				local hum = enemy:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					target = enemy
					break
				end
			end
		end

		if target then
			-- 1. Posicionamento e Combate
			if self.SmartFlight then
				self.SmartFlight:FlyTo(target.PrimaryPart and target.PrimaryPart.Position or target:GetPivot().Position)
			end

			if self.Combat then
				self.Combat:SetTarget(target)
			end

			-- 2. Monitoramento de Morte
			local hum = target:FindFirstChildOfClass("Humanoid")
			while hum and hum.Health > 0 and target.Parent and self._running do
				task.wait(0.5)
			end

			killed += 1
			self._questProgress = killed / quest.Count
			Logger.Info(string.format("Progresso de %s: %d/%d", quest.Name, killed, quest.Count))
		else
			-- Aguarda respawn do inimigo
			task.wait(2)
		end
	end

	return killed >= quest.Count
end

-- ─── [5] LOOP PRINCIPAL (Thread de Execução) ─────────────────

function QuestManager:_loop()
	while self._running do
		local ok, err = pcall(function()
			-- 1. Seleção da Próxima Quest
			local quest = self:_selectBestQuest()
			if not quest then
				Logger.Warn("Nenhuma quest viável para o nível atual.")
				task.wait(10)
				return
			end

			self._currentQuest = quest
			self._questProgress = 0

			-- 2. Processo de Aceitação
			local accepted = self:_acceptQuest(quest)
			if not accepted then
				task.wait(5)
				return
			end

			-- 3. Notificação de Início
			if self.Notifications then
				self.Notifications.Create(Players.LocalPlayer.PlayerGui, "📜 QUEST INICIADA", 
					quest.Name .. " [" .. quest.Island .. "]", 4, Color3.fromRGB(100, 200, 255))
			end

			-- 4. Fase de Farm
			local completed = self:_farmEnemies(quest)

			-- 5. Finalização e Recompensa
			if completed then
				Logger.Success(string.format("Quest Completa: %s! (+%d EXP)", quest.Name, quest.ExpReward))
				if self.Notifications then
					self.Notifications.Create(Players.LocalPlayer.PlayerGui, "✅ QUEST COMPLETA", 
						quest.Name .. " finalizada!", 5, Color3.fromRGB(80, 220, 130))
				end
			end

			self._currentQuest = nil
			task.wait(2)
		end)

		if not ok then
			Logger.Error("QuestManager Loop Error: " .. tostring(err))
		end

		task.wait(1)
	end
end

-- ─── [6] API PÚBLICA ──────────────────────────────────────────

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
