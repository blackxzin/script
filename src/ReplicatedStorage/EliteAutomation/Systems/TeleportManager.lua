-- ============================================================
--  Elite Automation Framework :: Systems.TeleportManager
--  Sistema de teleporte seguro entre ilhas com anti-detecção.
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local TeleportManager = {}
TeleportManager.__index = TeleportManager

-- ─── Mapa de ilhas GPO (First & Second Sea) ──────────────────
local ISLANDS = {
	-- First Sea
	["Town of Beginnings"] = Vector3.new(1100, 18, 1230),
	["Sandora"] = Vector3.new(-1150, 18, 1420),
	["Shell's Town"] = Vector3.new(-3800, 20, -4200),
	["Orange Town"] = Vector3.new(-820, 18, 830),
	["Baratie"] = Vector3.new(-3100, 12, 4800),
	["Kori Island"] = Vector3.new(2200, 18, 1850),
	["Sphinx Island"] = Vector3.new(-6500, 35, -2100),
	["Shark Park"] = Vector3.new(1250, 18, -3420),
	["Land of the Sky"] = Vector3.new(-1200, 450, 6000),
	["Golden City"] = Vector3.new(-1200, 450, 6000),
	["Gravito's Fort"] = Vector3.new(2800, 80, -3200),
	["Fishman Island"] = Vector3.new(7200, -300, 1100),
	["Underwater"] = Vector3.new(7200, -300, 1100),

	-- Second Sea
	["Desert Kingdom"] = Vector3.new(-1200, 25, -3000),
	["Sashi Island"] = Vector3.new(4100, 30, -1500),
	["Rovo Island"] = Vector3.new(-2500, 22, 3800),
	["Spirit Island"] = Vector3.new(3200, 32, 4500),
	["Foro Island"] = Vector3.new(-4800, 22, 1100),
	["Umi Island"] = Vector3.new(5200, 22, -4200),
	["Thriller Bark"] = Vector3.new(-5400, 80, -7800),
	["Rose Kingdom"] = Vector3.new(450, 120, -180),
	["Colosseum"] = Vector3.new(-600, 30, 5200),
	["Colosseum of Arc"] = Vector3.new(-600, 30, 5200),
}

-- ─── Aliases populares ────────────────────────────────────────
local ALIASES = {
	["start"] = "Town of Beginnings",
	["starter"] = "Town of Beginnings",
	["beginning"] = "Town of Beginnings",
	["desert"] = "Sandora",
	["marine"] = "Shell's Town",
	["shells"] = "Shell's Town",
	["baratie"] = "Baratie",
	["restaurant"] = "Baratie",
	["sky"] = "Land of the Sky",
	["skypiea"] = "Land of the Sky",
	["golden"] = "Golden City",
	["fishman"] = "Fishman Island",
	["underwater"] = "Fishman Island",
	["thriller"] = "Thriller Bark",
	["rose"] = "Rose Kingdom",
	["factory"] = "Rose Kingdom",
}

function TeleportManager.new(smartFlight, notifications)
	local self = setmetatable({}, TeleportManager)

	self.SmartFlight = smartFlight
	self.Notifications = notifications
	self.TeleportHistory = {}  -- últimos 5 teleportes

	return self
end

-- ─── Resolve nome de ilha (com aliases) ──────────────────────
function TeleportManager:_resolveIsland(name)
	name = name:lower()

	-- Tenta alias primeiro
	if ALIASES[name] then
		return ALIASES[name], ISLANDS[ALIASES[name]]
	end

	-- Tenta match parcial
	for islandName, pos in pairs(ISLANDS) do
		if islandName:lower():find(name, 1, true) then
			return islandName, pos
		end
	end

	return nil, nil
end

-- ─── Teleporte seguro com bypass ──────────────────────────────
function TeleportManager:TeleportTo(islandName)
	local fullName, position = self:_resolveIsland(islandName)

	if not fullName or not position then
		Logger.Warn("Ilha não encontrada:", islandName)
		return false
	end

	Logger.Info("Teleportando para:", fullName)

	local char = Players.LocalPlayer.Character
	if not char then return false end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	-- Notifica UI
	if self.Notifications then
		local lp = Players.LocalPlayer
		if lp and lp.PlayerGui then
			self.Notifications.Create(
				lp.PlayerGui,
				"🌍 TELEPORTE",
				"Viajando para " .. fullName .. "...",
				3,
				Color3.fromRGB(100, 200, 255)
			)
		end
	end

	-- Usa SmartFlight para teleporte seguro (bypass integrado)
	if self.SmartFlight then
		self.SmartFlight:FlyTo(position)
	else
		-- Fallback: teleporte direto (menos seguro)
		root.CFrame = CFrame.new(position)
	end

	-- Registra no histórico
	table.insert(self.TeleportHistory, 1, {
		Island = fullName,
		Time = os.time(),
	})
	if #self.TeleportHistory > 5 then
		table.remove(self.TeleportHistory)
	end

	Logger.Success("Chegou em:", fullName)
	return true
end

-- ─── Lista ilhas disponíveis ──────────────────────────────────
function TeleportManager:ListIslands()
	local list = {}
	for name in pairs(ISLANDS) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

-- ─── Teleporte para ilha mais próxima ────────────────────────
function TeleportManager:TeleportToNearest()
	local char = Players.LocalPlayer.Character
	if not char then return false end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local nearest, nearestDist = nil, math.huge
	local currentPos = root.Position

	for name, pos in pairs(ISLANDS) do
		local dist = (pos - currentPos).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearest = name
		end
	end

	if nearest then
		return self:TeleportTo(nearest)
	end

	return false
end

-- ─── Histórico de teleportes ──────────────────────────────────
function TeleportManager:GetHistory()
	return self.TeleportHistory
end

return TeleportManager
