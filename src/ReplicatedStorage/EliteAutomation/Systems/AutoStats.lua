-- ============================================================
--  Elite Automation Framework :: Systems.AutoStats
--  Distribuição automática de stats com builds pré-configurados.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local AutoStats = {}
AutoStats.__index = AutoStats

-- ─── Builds pré-configurados para GPO ─────────────────────────
local BUILDS = {
	-- Sword Main (Full Melee)
	SwordMain = {
		Name = "Sword Main",
		Priority = {"Strength", "Defense", "Stamina", "Fruit"},
		Distribution = {Strength = 0.50, Defense = 0.25, Stamina = 0.20, Fruit = 0.05},
	},

	-- Devil Fruit Main
	DevilFruitMain = {
		Name = "Devil Fruit Main",
		Priority = {"Fruit", "Stamina", "Defense", "Strength"},
		Distribution = {Fruit = 0.55, Stamina = 0.20, Defense = 0.15, Strength = 0.10},
	},

	-- Balanced Hybrid
	Hybrid = {
		Name = "Hybrid",
		Priority = {"Strength", "Fruit", "Defense", "Stamina"},
		Distribution = {Strength = 0.35, Fruit = 0.35, Defense = 0.20, Stamina = 0.10},
	},

	-- Tank (PvP Survival)
	Tank = {
		Name = "Tank",
		Priority = {"Defense", "Stamina", "Strength", "Fruit"},
		Distribution = {Defense = 0.45, Stamina = 0.30, Strength = 0.20, Fruit = 0.05},
	},

	-- Glass Cannon (Max Damage)
	GlassCannon = {
		Name = "Glass Cannon",
		Priority = {"Strength", "Fruit", "Stamina", "Defense"},
		Distribution = {Strength = 0.45, Fruit = 0.40, Stamina = 0.10, Defense = 0.05},
	},
}

function AutoStats.new(buildName, notifications)
	local self = setmetatable({}, AutoStats)

	self.Build = BUILDS[buildName] or BUILDS.Hybrid
	self.Notifications = notifications
	self.Enabled = false
	self._lastCheck = 0

	return self
end

-- ─── Detecta stats points disponíveis ─────────────────────────
function AutoStats:_getAvailablePoints()
	local lp = Players.LocalPlayer
	if not lp then return 0 end

	-- GPO armazena stat points em leaderstats ou PlayerData
	local leaderstats = lp:FindFirstChild("leaderstats")
	if leaderstats then
		local points = leaderstats:FindFirstChild("StatPoints")
			or leaderstats:FindFirstChild("Points")
		if points and points.Value then
			return tonumber(points.Value) or 0
		end
	end

	-- Fallback: Character attribute
	local char = lp.Character
	if char then
		local pts = char:GetAttribute("StatPoints")
		if pts then return pts end
	end

	return 0
end

-- ─── Distribui stats automaticamente ──────────────────────────
function AutoStats:_distributeStats()
	local points = self:_getAvailablePoints()
	if points <= 0 then return end

	Logger.Info("Distribuindo", points, "stat points com build:", self.Build.Name)

	local dist = self.Build.Distribution

	-- Calcula quantos pontos para cada stat
	local allocation = {
		Strength = math.floor(points * dist.Strength),
		Defense = math.floor(points * dist.Defense),
		Stamina = math.floor(points * dist.Stamina),
		Fruit = math.floor(points * dist.Fruit),
	}

	-- Distribui pontos restantes pelo prioridade
	local remainder = points - (allocation.Strength + allocation.Defense + allocation.Stamina + allocation.Fruit)
	for _, stat in ipairs(self.Build.Priority) do
		if remainder > 0 then
			allocation[stat] = allocation[stat] + 1
			remainder = remainder - 1
		end
	end

	-- Executa distribuição
	for stat, amount in pairs(allocation) do
		if amount > 0 then
			self:_addStat(stat, amount)
		end
	end

	-- Notifica UI
	if self.Notifications then
		local lp = Players.LocalPlayer
		if lp and lp.PlayerGui then
			self.Notifications.Create(
				lp.PlayerGui,
				"📊 STATS DISTRIBUÍDOS",
				string.format("%d pontos alocados (%s)", points, self.Build.Name),
				4,
				Color3.fromRGB(100, 200, 255)
			)
		end
	end
end

-- ─── Adiciona pontos em um stat específico ────────────────────
function AutoStats:_addStat(statName, amount)
	Logger.Debug("Adicionando", amount, "pontos em", statName)

	-- GPO usa RemoteEvent para adicionar stats
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if remotes then
		local addStat = remotes:FindFirstChild("AddStat")
			or remotes:FindFirstChild("Stats")
			or remotes:FindFirstChild("StatUpgrade")

		if addStat and addStat:IsA("RemoteEvent") then
			for i = 1, amount do
				addStat:FireServer(statName)
				task.wait(0.05)  -- Pequeno delay para evitar spam
			end
		end
	end
end

-- ─── Loop de verificação ──────────────────────────────────────
function AutoStats:Check()
	if not self.Enabled then return end

	local now = os.clock()
	if (now - self._lastCheck) < 5 then return end  -- Verifica a cada 5s
	self._lastCheck = now

	local points = self:_getAvailablePoints()
	if points > 0 then
		self:_distributeStats()
	end
end

-- ─── Muda build em tempo real ─────────────────────────────────
function AutoStats:SetBuild(buildName)
	if BUILDS[buildName] then
		self.Build = BUILDS[buildName]
		Logger.Info("Build de stats alterada para:", self.Build.Name)
		return true
	end
	return false
end

function AutoStats:Enable()
	self.Enabled = true
	Logger.Info("AutoStats ativado:", self.Build.Name)
end

function AutoStats:Disable()
	self.Enabled = false
	Logger.Info("AutoStats desativado")
end

function AutoStats:GetBuildList()
	local list = {}
	for name, build in pairs(BUILDS) do
		table.insert(list, {Name = name, Display = build.Name})
	end
	return list
end

return AutoStats
