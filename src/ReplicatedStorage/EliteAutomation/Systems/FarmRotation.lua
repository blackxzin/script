-- ============================================================
--  Elite Automation Framework :: Systems.FarmRotation
--  Sistema de rotação inteligente de bosses baseado em:
--  XP/hora, drops, respawn time, distância.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local FarmRotation = {}
FarmRotation.__index = FarmRotation

-- ─── Database de bosses com dados reais do GPO ─────────────────
local BOSS_DATABASE = {
	-- First Sea (ordenado por eficiência)
	{
		Name = "Bandit Boss",
		Location = Vector3.new(1050, 18, 1220),
		Level = 5,
		HP = 800,
		RespawnTime = 300,  -- 5 min
		ExpReward = 250,
		PeliReward = 2000,
		Drops = {"Bandit Cape"},
		DropRate = 0.05,
		KillTime = 60,  -- Estimado para build média
		Priority = 3,
	},
	{
		Name = "Lucid",
		Location = Vector3.new(-1150, 18, 1420),
		Level = 15,
		HP = 2000,
		RespawnTime = 600,  -- 10 min
		ExpReward = 800,
		PeliReward = 5000,
		Drops = {"Lucid's Cloak"},
		DropRate = 0.05,
		KillTime = 90,
		Priority = 4,
	},
	{
		Name = "Axe Hand Logan",
		Location = Vector3.new(-3800, 20, -4200),
		Level = 25,
		HP = 3000,
		RespawnTime = 900,  -- 15 min
		ExpReward = 1200,
		PeliReward = 8000,
		Drops = {"Logan's Outfit", "Logan's Axe"},
		DropRate = 0.05,
		KillTime = 120,
		Priority = 5,
	},
	{
		Name = "Gravito",
		Location = Vector3.new(2800, 80, -3200),
		Level = 100,
		HP = 3600,
		RespawnTime = 720,  -- 12 min
		ExpReward = 3500,
		PeliReward = 15000,
		Drops = {"Gravity Blade", "Hoverboard", "Gravito's Cape"},
		DropRate = 0.02,
		KillTime = 180,
		Priority = 8,
	},
	{
		Name = "Enel",
		Location = Vector3.new(-1200, 450, 6000),
		Level = 150,
		HP = 5000,
		RespawnTime = 2700,  -- 45 min
		ExpReward = 8000,
		PeliReward = 45000,
		Drops = {"Golden Staff"},
		DropRate = 0.05,
		KillTime = 240,
		Priority = 9,
	},
	{
		Name = "Neptune",
		Location = Vector3.new(7200, -300, 1100),
		Level = 180,
		HP = 6000,
		RespawnTime = 2400,  -- 40 min
		ExpReward = 9000,
		PeliReward = 38000,
		Drops = {"Neptune's Trident", "Neptune's Crown"},
		DropRate = 0.15,
		KillTime = 300,
		Priority = 8,
	},

	-- Second Sea
	{
		Name = "Ryuma",
		Location = Vector3.new(-5400, 120, -7800),
		Level = 350,
		HP = 8000,
		RespawnTime = 1800,  -- 30 min
		ExpReward = 15000,
		PeliReward = 35000,
		Drops = {"Shusui"},
		DropRate = 0.01,
		KillTime = 360,
		Priority = 10,
	},
	{
		Name = "Law",
		Location = Vector3.new(-4716, 28, 1263),
		Level = 400,
		HP = 10000,
		RespawnTime = 3600,  -- 60 min
		ExpReward = 25000,
		PeliReward = 70000,
		Drops = {"Kikoku"},
		DropRate = 0.005,
		KillTime = 450,
		Priority = 10,
	},
}

function FarmRotation.new(combat, movement, notifications)
	local self = setmetatable({}, FarmRotation)

	self.Combat = combat
	self.Movement = movement
	self.Notifications = notifications

	self.Enabled = false
	self._thread = nil
	self._bossTimers = {}  -- [bossName] = lastKillTime
	self._currentRoute = {}

	return self
end

-- ─── Calcula eficiência de farm (XP/minuto) ───────────────────
function FarmRotation:_calculateEfficiency(boss)
	-- Eficiência = (XP + valor dos drops) / (kill time + respawn wait)
	local totalTime = boss.KillTime + boss.RespawnTime
	local expPerMin = (boss.ExpReward / totalTime) * 60

	-- Considera valor dos drops
	local dropValue = boss.PeliReward * boss.DropRate
	local peliPerMin = (dropValue / totalTime) * 60

	-- Score combinado (XP pesa mais)
	return (expPerMin * 0.7) + (peliPerMin * 0.0003)
end

-- ─── Seleciona melhor boss disponível ─────────────────────────
function FarmRotation:_selectBestBoss()
	local playerLevel = self:_getPlayerLevel()
	local now = os.clock()

	local available = {}

	for _, boss in ipairs(BOSS_DATABASE) do
		-- Ignora bosses muito acima do nível
		if boss.Level <= (playerLevel + 50) then
			-- Verifica se respawn passou
			local lastKill = self._bossTimers[boss.Name] or 0
			local elapsed = now - lastKill

			if elapsed >= boss.RespawnTime then
				local efficiency = self:_calculateEfficiency(boss)
				table.insert(available, {
					Boss = boss,
					Efficiency = efficiency,
				})
			end
		end
	end

	if #available == 0 then return nil end

	-- Ordena por eficiência
	table.sort(available, function(a, b)
		return a.Efficiency > b.Efficiency
	end)

	return available[1].Boss
end

-- ─── Cria rota otimizada (TSP simplificado) ───────────────────
function FarmRotation:_buildRoute()
	local playerLevel = self:_getPlayerLevel()
	local now = os.clock()

	local eligible = {}

	for _, boss in ipairs(BOSS_DATABASE) do
		if boss.Level <= (playerLevel + 50) then
			local lastKill = self._bossTimers[boss.Name] or 0
			local elapsed = now - lastKill

			if elapsed >= boss.RespawnTime then
				table.insert(eligible, boss)
			end
		end
	end

	if #eligible == 0 then return {} end

	-- Ordena por prioridade + eficiência
	table.sort(eligible, function(a, b)
		local effA = self:_calculateEfficiency(a)
		local effB = self:_calculateEfficiency(b)
		return (a.Priority * 10 + effA) > (b.Priority * 10 + effB)
	end)

	-- Pega top 5 para rotação
	local route = {}
	for i = 1, math.min(5, #eligible) do
		table.insert(route, eligible[i])
	end

	return route
end

-- ─── Obtém nível do player ────────────────────────────────────
function FarmRotation:_getPlayerLevel()
	local lp = Players.LocalPlayer
	if not lp then return 1 end

	local leaderstats = lp:FindFirstChild("leaderstats")
	if leaderstats then
		local lvl = leaderstats:FindFirstChild("Level")
		if lvl then return lvl.Value or 1 end
	end

	return 1
end

-- ─── Farm um boss específico ──────────────────────────────────
function FarmRotation:_farmBoss(boss)
	Logger.Info("Farmando boss:", boss.Name, "| Eficiência:", string.format("%.1f", self:_calculateEfficiency(boss)))

	-- Notifica
	if self.Notifications then
		local lp = Players.LocalPlayer
		if lp and lp.PlayerGui then
			self.Notifications.Create(
				lp.PlayerGui,
				"🎯 ROTAÇÃO DE FARM",
				boss.Name .. " selecionado - " .. boss.ExpReward .. " XP",
				4,
				Color3.fromRGB(255, 200, 0)
			)
		end
	end

	-- Voa até boss
	if self.Movement then
		self.Movement:FlyTo(boss.Location)
	end

	task.wait(1)

	-- Procura modelo do boss
	local bossModel = workspace:FindFirstChild(boss.Name, true)
	if not bossModel then
		Logger.Warn("Boss não encontrado:", boss.Name)
		return false
	end

	-- Engaja combate
	if self.Combat then
		self.Combat:SetTarget(bossModel)
	end

	-- Aguarda morte
	local timeout = os.clock() + boss.KillTime + 60
	while os.clock() < timeout do
		if not bossModel.Parent then break end

		local hum = bossModel:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then break end

		task.wait(0.5)
	end

	-- Registra kill
	self._bossTimers[boss.Name] = os.clock()

	Logger.Success("Boss eliminado:", boss.Name)
	return true
end

-- ─── Loop de rotação ──────────────────────────────────────────
function FarmRotation:_loop()
	while self.Enabled do
		-- Reconstrói rota a cada ciclo
		self._currentRoute = self:_buildRoute()

		if #self._currentRoute == 0 then
			Logger.Debug("Nenhum boss disponível, aguardando...")
			task.wait(30)
		else
			Logger.Info("Rota de farm:", #self._currentRoute, "bosses")

			for _, boss in ipairs(self._currentRoute) do
				if not self.Enabled then break end
				self:_farmBoss(boss)
				task.wait(2)
			end
		end

		task.wait(5)
	end
end

function FarmRotation:Start()
	if self.Enabled then return end
	self.Enabled = true
	self._thread = task.spawn(function() self:_loop() end)
	Logger.Info("FarmRotation iniciado")
end

function FarmRotation:Stop()
	self.Enabled = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	Logger.Info("FarmRotation parado")
end

function FarmRotation:GetCurrentRoute()
	return self._currentRoute
end

return FarmRotation
