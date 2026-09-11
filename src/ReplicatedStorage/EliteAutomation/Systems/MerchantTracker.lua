-- ============================================================
--  Elite Automation Framework :: Systems.MerchantTracker
--  Rastreador do Mercador Viajante (Traveling Merchant) de GPO.
--  Detecta spawns em ilhas, notifica a UI e oferece voo automático.
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root       = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger     = require(Root.Core.Logger)

local MerchantTracker = {}
MerchantTracker.__index = MerchantTracker

-- Nomes e variações conhecidas do modelo do mercador no GPO
local MERCHANT_NAMES = {
	"Traveling Merchant",
	"TravelingMerchant",
	"Wandering Merchant",
	"Merchant",
}

-- ─── Construtor ──────────────────────────────────────────────
function MerchantTracker.new(notifications, settings)
	local self = setmetatable({}, MerchantTracker)

	self.Notifications = notifications
	self.Settings      = settings or {}
	self.ScanInterval  = self.Settings.ScanInterval or 1.5
	self.KnownIslands  = self.Settings.KnownIslands or {
		-- ─ First Sea ─
		["Town of Beginnings"] = Vector3.new(1100, 15, 1200),
		["Sandora"]            = Vector3.new(-1100, 15, 1400),
		["Shells Town"]        = Vector3.new(-3800, 15, -4200),
		["Orange Town"]        = Vector3.new(-800, 15, 800),
		["Baratie"]            = Vector3.new(-3100, 10, 4800),
		["Sphinx Island"]      = Vector3.new(-6500, 30, -2100),
		["Shark Park"]         = Vector3.new(1200, 15, -3400),
		["Kori Island"]        = Vector3.new(2200, 15, 1800),
		["Land of the Sky"]    = Vector3.new(-1200, 450, 6000),
		["Gravito's Fort"]     = Vector3.new(2800, 80, -3200),
		["Fishman Island"]     = Vector3.new(7200, -300, 1100),
		-- ─ Second Sea ─
		["Desert Kingdom"]     = Vector3.new(-1200, 20, -3000),
		["Sashi Island"]       = Vector3.new(4100, 25, -1500),
		["Rovo Island"]        = Vector3.new(-2500, 20, 3800),
		["Spirit Island"]      = Vector3.new(3200, 30, 4500),
		["Foro Island"]        = Vector3.new(-4800, 20, 1100),
		["Umi Island"]         = Vector3.new(5200, 20, -4200),
		["Colosseum of Arc"]   = Vector3.new(-600, 25, 5200),
		["Thriller Bark"]      = Vector3.new(-5400, 80, -7800),
		["Rose Kingdom"]       = Vector3.new(450, 120, -180),
	}

	self._running        = false
	self._thread         = nil
	self._currentMerchant = nil  -- { model = ..., position = ..., island = ..., spawnTime = ... }
	self._smartFlight    = nil  -- injetado externamente
	self._lastState      = false

	-- Callbacks
	self.OnMerchantSpawned   = nil -- function(merchantData)
	self.OnMerchantDespawned = nil -- function()

	return self
end

function MerchantTracker:SetFlight(smartFlight)
	self._smartFlight = smartFlight
end

-- ─── Cálculo do Ciclo do Mercador via Uptime de Servidor ──────
-- No GPO, o Traveling Merchant surge aos 10 minutos (600s) de servidor,
-- permanece por 10 minutos (600s) e reaparece a cada 30 minutos (1800s).
function MerchantTracker:GetSchedule()
	local uptime = workspace.DistributedGameTime or 0

	if uptime < 600 then
		local timeToFirst = math.ceil(600 - uptime)
		return {
			Status        = "WAITING",
			SecondsLeft   = timeToFirst,
			MinutesLeft   = math.floor(timeToFirst / 60),
			SecondsRem    = timeToFirst % 60,
			DisplayText   = string.format("1º Spawn em: %02d:%02d", math.floor(timeToFirst / 60), timeToFirst % 60),
			IsActive      = false,
		}
	end

	local cycleElapsed = (uptime - 600) % 1800

	if cycleElapsed < 600 then
		-- Mercador está atualmente ATIVO no servidor!
		local despawnIn = math.ceil(600 - cycleElapsed)
		return {
			Status        = "ACTIVE",
			SecondsLeft   = despawnIn,
			MinutesLeft   = math.floor(despawnIn / 60),
			SecondsRem    = despawnIn % 60,
			DisplayText   = string.format("MERCADOR ATIVO! Despawn em: %02d:%02d", math.floor(despawnIn / 60), despawnIn % 60),
			IsActive      = true,
		}
	else
		-- Mercador está DESPAWNADO, aguardando próximo ciclo
		local nextIn = math.ceil(1800 - cycleElapsed)
		return {
			Status        = "WAITING",
			SecondsLeft   = nextIn,
			MinutesLeft   = math.floor(nextIn / 60),
			SecondsRem    = nextIn % 60,
			DisplayText   = string.format("Próximo spawn em: %02d:%02d", math.floor(nextIn / 60), nextIn % 60),
			IsActive      = false,
		}
	end
end

-- ─── Identifica a ilha mais próxima de uma posição ───────────
function MerchantTracker:_identifyIsland(pos)
	local bestIsland, bestDist = "Desconhecida", math.huge
	for islandName, islandPos in pairs(self.KnownIslands) do
		local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(islandPos.X, 0, islandPos.Z)).Magnitude
		if d < bestDist then
			bestDist   = d
			bestIsland = islandName
		end
	end
	return bestIsland, bestDist
end

-- ─── Scanner de Bússola e Compass no PlayerGui (GPO) ──────────
function MerchantTracker:_scanCompassGui()
	local lp = Players.LocalPlayer
	if not lp then return nil end
	local pg = lp:FindFirstChild("PlayerGui")
	if not pg then return nil end

	-- Procura indicador de bússola com ícone ou texto do Traveling Merchant
	for _, gui in ipairs(pg:GetChildren()) do
		if gui:IsA("ScreenGui") then
			local compass = gui:FindFirstChild("Compass", true) or gui:FindFirstChild("CompassGui", true)
			if compass then
				local marker = compass:FindFirstChild("MerchantMarker", true)
					or compass:FindFirstChild("Merchant", true)
					or compass:FindFirstChild("TravelingMerchant", true)
				if marker then
					return marker
				end
			end
		end
	end
	return nil
end

-- ─── Busca o modelo do mercador no workspace ─────────────────
function MerchantTracker:_findMerchant()
	for _, name in ipairs(MERCHANT_NAMES) do
		local model = workspace:FindFirstChild(name, true)
		if model then
			local root = model:FindFirstChild("HumanoidRootPart")
				or model:FindFirstChildOfClass("BasePart")
			if root then
				return model, root.Position
			end
		end
	end

	-- Busca em NPCs / Spawns caso o nome contenha 'Merchant'
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj.Name:lower():find("merchant", 1, true) then
			local root = obj:FindFirstChild("HumanoidRootPart")
				or obj:FindFirstChildOfClass("BasePart")
			if root then
				return obj, root.Position
			end
		end
	end

	return nil, nil
end

-- ─── Loop de rastreamento ────────────────────────────────────
function MerchantTracker:_loop()
	while self._running do
		local ok, err = pcall(function()
			local model, pos = self:_findMerchant()

			if model and pos then
				if not self._lastState then
					-- Mercador acabou de surgir!
					self._lastState = true
					local islandName, dist = self:_identifyIsland(pos)

					self._currentMerchant = {
						model     = model,
						position  = pos,
						island    = islandName,
						spawnTime = os.time(),
					}

					Logger.Success(string.format(
						"🛒 MERCADOR DETECTADO! Ilha: %s em (%.0f, %.0f, %.0f)",
						islandName, pos.X, pos.Y, pos.Z
					))

					if self.Notifications then
						local localPlayer = Players.LocalPlayer
						if localPlayer and localPlayer.PlayerGui then
							self.Notifications.Create(
								localPlayer.PlayerGui,
								"🛒 MERCADOR VIAJANTE",
								string.format("O Mercador spawnou em %s!\nClique para voar até ele.", islandName),
								8,
								Color3.fromRGB(255, 215, 0)
							)
						end
					end

					if self.OnMerchantSpawned then
						self.OnMerchantSpawned(self._currentMerchant)
					end
				else
					-- Atualiza posição caso o modelo tenha se movido
					if self._currentMerchant then
						self._currentMerchant.model    = model
						self._currentMerchant.position = pos
					end
				end
			else
				if self._lastState then
					-- Mercador despawnou
					self._lastState = false
					Logger.Warn("🛒 Mercador Viajante despawnou ou deixou a ilha.")

					if self.Notifications then
						local localPlayer = Players.LocalPlayer
						if localPlayer and localPlayer.PlayerGui then
							self.Notifications.Create(
								localPlayer.PlayerGui,
								"🛒 MERCADOR DESPAWNOU",
								"O Mercador Viajante não está mais ativo.",
								4,
								Color3.fromRGB(200, 100, 100)
							)
						end
					end

					if self.OnMerchantDespawned then
						self.OnMerchantDespawned()
					end

					self._currentMerchant = nil
				end
			end
		end)

		if not ok then
			Logger.Error("MerchantTracker loop error:", err)
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── Voa até o mercador ──────────────────────────────────────
function MerchantTracker:FlyToMerchant()
	if not self._currentMerchant or not self._currentMerchant.position then
		Logger.Warn("MerchantTracker: Mercador não está ativo no momento.")
		return false
	end

	if not self._smartFlight then
		Logger.Warn("MerchantTracker: SmartFlight não configurado.")
		return false
	end

	local targetPos = self._currentMerchant.position + Vector3.new(0, 4, 0)
	Logger.Info("Voando até o Mercador em:", self._currentMerchant.island)
	self._smartFlight:FlyTo(targetPos)
	return true
end

-- ─── API Pública ─────────────────────────────────────────────
function MerchantTracker:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
	Logger.Info("MerchantTracker iniciado.")
end

function MerchantTracker:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	self._currentMerchant = nil
	self._lastState       = false
	Logger.Info("MerchantTracker parado.")
end

function MerchantTracker:GetMerchant()
	return self._currentMerchant
end

function MerchantTracker:IsActive()
	return self._currentMerchant ~= nil
end

return MerchantTracker
