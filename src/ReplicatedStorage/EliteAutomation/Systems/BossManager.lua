-- ============================================================
--  Elite Automation Framework :: Systems.BossManager
--  Gerenciador de Bosses e Sea Events do Grand Piece Online (GPO):
--  1. Sea Events / Location Bosses (Kraken, Sea Beast, Ghost Ship, Megalodon)
--  2. Timed / World Bosses (Ryuma, Borj, Gravito, Enel, Neptune)
--  3. Raid Bosses (Moria, Ba'al, Impel Down Warden)
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root       = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger     = require(Root.Core.Logger)

local BossManager = {}
BossManager.__index = BossManager

-- ─── Utilitário: encontra modelo no workspace por nome ou aliases ─
local function findBossModel(config)
	if not config then return nil end

	-- Lista de nomes a testar
	local names = { config.Name }
	if config.Aliases then
		for _, alias in ipairs(config.Aliases) do
			table.insert(names, alias)
		end
	end

	for _, name in ipairs(names) do
		local m = workspace:FindFirstChild(name, true) or workspace:FindFirstChild(name)
		if m and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildOfClass("Humanoid")) then
			return m
		end
	end

	-- Busca parcial/case-insensitive em descendants se for Kraken ou Sea Beast
	local lowerName = config.Name:lower()
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") then
			local objLower = obj.Name:lower()
			if objLower:find(lowerName, 1, true) then
				if obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("Humanoid") then
					return obj
				end
			end
		end
	end

	return nil
end

-- ─── Utilitário: jitter simples ──────────────────────────────
local function jitter(min, max)
	return min + math.random() * (max - min)
end

-- ─── Construtor ──────────────────────────────────────────────
function BossManager.new(combat, smartFlight, notifications, settings)
	local self = setmetatable({}, BossManager)

	self.Combat        = combat        -- CombatController
	self.SmartFlight   = smartFlight   -- SmartFlight
	self.Notifications = notifications
	self.Settings      = settings or {}
	self.ScanInterval  = self.Settings.ScanInterval or 2.0
	self.AttackRadius  = self.Settings.AttackRadius or 90

	-- Timestamps de último spawn visto para bosses de tempo
	self._timedTimestamps = {}     -- [bossName] = os.time() do último spawn
	self._running         = false
	self._thread          = nil
	self._currentBoss     = nil    -- boss atualmente sendo farmado

	return self
end

-- ─════════════════════════════════════════════════════════════
--   CATEGORIA 1 — RAID / DUNGEON BOSSES (Moria, Ba'al, Impel Down)
-- ══════════════════════════════════════════════════════════════

function BossManager:_handleRaidBoss(config)
	Logger.Info("BossManager → Verificando Raid Boss:", config.Name)

	local bossModel = findBossModel(config)
	if not bossModel then
		-- Se houver localização definida e não estiver engajado, vai até lá
		if config.Location and self.SmartFlight and not self._currentBoss then
			Logger.Info("Raid Boss não avistado. Posicionando em:", tostring(config.Location))
			self.SmartFlight:FlyTo(config.Location)
		end
		return
	end

	Logger.Success("Raid Boss detectado:", config.Name, "| Fases:", config.PhaseCount or 1)

	-- Notifica UI
	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"⚔ GPO RAID BOSS",
				config.Name .. " detectado! Engajando...",
				5,
				Color3.fromRGB(255, 75, 75)
			)
		end
	end

	self._currentBoss = bossModel

	-- Loop de combate
	for phase = 1, (config.PhaseCount or 1) do
		Logger.Info(string.format("  Fase %d/%d", phase, config.PhaseCount or 1))

		local bossRoot = bossModel:FindFirstChild("HumanoidRootPart")
		if bossRoot and self.SmartFlight then
			self.SmartFlight:FlyTo(bossRoot.Position)
		end

		if self.Combat then
			self.Combat:SetTarget(bossModel)
		end

		local timeout = os.clock() + 300
		while os.clock() < timeout do
			local hum = bossModel:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 or not bossModel.Parent then
				Logger.Info("Boss eliminado na fase", phase)
				break
			end
			task.wait(1)
		end

		if phase < (config.PhaseCount or 1) then
			task.wait(jitter(2, 4))
		end
	end

	self._currentBoss = nil
	if self.Combat then
		self.Combat:Stop()
	end

	Logger.Success("Raid Boss", config.Name, "finalizado!")
end

-- ─════════════════════════════════════════════════════════════
--   CATEGORIA 2 — BOSSES DE TEMPO E ILHAS (Ryuma, Borj, Gravito, Enel, Neptune)
-- ══════════════════════════════════════════════════════════════

function BossManager:_handleTimedBoss(config)
	local name     = config.Name
	local cooldown = config.CooldownSecs or 1800
	local lastSeen = self._timedTimestamps[name] or 0
	local now      = os.time()
	local elapsed  = now - lastSeen
	local remaining = cooldown - elapsed

	if remaining > 0 then
		Logger.Debug(string.format(
			"Timed Boss '%s' em cooldown. Próximo em: %d min %d s",
			name,
			math.floor(remaining / 60),
			remaining % 60
		))
		return
	end

	Logger.Info("BossManager → Verificando World Boss:", name)
	local bossModel = findBossModel(config)

	if not bossModel then
		return
	end

	Logger.Success("World Boss VIVO:", name)
	self._timedTimestamps[name] = now

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"⏱ GPO WORLD BOSS",
				name .. " spawnado em " .. (config.Island or "ilha") .. "!",
				6,
				Color3.fromRGB(255, 200, 0)
			)
		end
	end

	if self.SmartFlight and config.Location then
		if config.FlyToSky then
			local skyPos = Vector3.new(
				config.Location.X,
				math.max(config.Location.Y, 200),
				config.Location.Z
			)
			self.SmartFlight:FlyTo(skyPos)
		else
			self.SmartFlight:FlyTo(config.Location)
		end
	end

	self._currentBoss = bossModel
	if self.Combat then
		self.Combat:SetTarget(bossModel)
	end

	local timeout = os.clock() + 600
	while os.clock() < timeout do
		local hum = bossModel:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or not bossModel.Parent then
			break
		end
		task.wait(1)
	end

	self._currentBoss = nil
	Logger.Success("World Boss", name, "eliminado!")
end

-- ─════════════════════════════════════════════════════════════
--   CATEGORIA 3 — SEA EVENTS & BOSSES DE MAR (Kraken, Sea Beast, Ghost Ship, Megalodon)
-- ══════════════════════════════════════════════════════════════

function BossManager:_handleLocationBoss(config)
	local bossModel = findBossModel(config)
	if not bossModel then return end

	local bossRoot = bossModel:FindFirstChild("HumanoidRootPart")
		or bossModel:FindFirstChildOfClass("BasePart")
	if not bossRoot then return end

	local bossPos = bossRoot.Position

	-- Região de validade
	local region = config.Region
	if region then
		local dist = (Vector3.new(bossPos.X, 0, bossPos.Z)
			- Vector3.new(region.center.X, 0, region.center.Z)).Magnitude
		if dist > region.radius then
			return
		end
	end

	Logger.Success("🌊 SEA EVENT DETECTADO:", bossModel.Name, "em", tostring(bossPos))

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"🌊 GPO SEA EVENT",
				bossModel.Name .. " surgiu no mar!\nAltitude de segurança ativada.",
				6,
				Color3.fromRGB(0, 180, 255)
			)
		end
	end

	self._currentBoss = bossModel

	-- "Voo de Segurança Anti-Mar" — mantém altitude acima da água
	if self.SmartFlight and config.SafeAltitude then
		local oldHover = self.SmartFlight.HoverOffset
		self.SmartFlight.HoverOffset = config.SafeAltitude

		-- Garante proteção estrita contra contato com água
		local antiDrownThread = task.spawn(function()
			while self._currentBoss and self._currentBoss.Parent do
				if config.DiveProtection then
					local localChar = Players.LocalPlayer.Character
					local root      = localChar and localChar:FindFirstChild("HumanoidRootPart")
					if root then
						local seaLevel = config.SeaLevel or 0
						if root.Position.Y < (seaLevel + config.SafeAltitude) then
							root.CFrame = CFrame.new(
								root.Position.X,
								seaLevel + config.SafeAltitude + 5,
								root.Position.Z
							)
							Logger.Warn("Anti-afogamento GPO ativado! Mantendo sobre o mar.")
						end
					end
				end
				task.wait(0.15)
			end
		end)

		-- Voa até o boss no plano horizontal mantendo safe altitude
		local safePos = Vector3.new(bossPos.X, (config.SeaLevel or 0) + config.SafeAltitude, bossPos.Z)
		self.SmartFlight:FlyTo(safePos)

		-- Engaja combate
		if self.Combat then
			self.Combat:SetTarget(bossModel)
		end

		-- Aguarda desfecho
		local timeout = os.clock() + 600
		while os.clock() < timeout do
			local hum = bossModel:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 or not bossModel.Parent then
				break
			end
			task.wait(1)
		end

		pcall(function() task.cancel(antiDrownThread) end)
		self.SmartFlight.HoverOffset = oldHover
	end

	self._currentBoss = nil
	Logger.Success("Sea Event", bossModel.Name, "concluído!")
end

-- ─════════════════════════════════════════════════════════════
--   LOOP PRINCIPAL
-- ══════════════════════════════════════════════════════════════

function BossManager:_loop()
	local cfg = self.Settings

	while self._running do
		local ok, err = pcall(function()

			-- ── 1. Sea Events / Location Bosses (Prioridade máxima em GPO)
			if cfg.LocationBosses then
				for _, bossCfg in pairs(cfg.LocationBosses) do
					if not self._running then break end
					self:_handleLocationBoss(bossCfg)
				end
			end

			-- ── 2. Bosses de Tempo e Ilhas
			if cfg.TimedBosses then
				for _, bossCfg in pairs(cfg.TimedBosses) do
					if not self._running then break end
					self:_handleTimedBoss(bossCfg)
				end
			end

			-- ── 3. Raids e Dungeons
			if cfg.RaidBosses then
				for _, bossCfg in pairs(cfg.RaidBosses) do
					if not self._running then break end
					self:_handleRaidBoss(bossCfg)
				end
			end

		end)

		if not ok then
			Logger.Error("BossManager loop error:", err)
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function BossManager:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
	Logger.Info("BossManager (GPO) iniciado.")
end

function BossManager:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	self._currentBoss = nil
	Logger.Info("BossManager parado.")
end

function BossManager:GetCurrentBoss()
	return self._currentBoss
end

return BossManager
