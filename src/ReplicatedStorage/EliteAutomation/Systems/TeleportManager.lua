-- ============================================================
--  Elite Automation Framework :: Systems.TeleportManager
--  Arquitetura de Navegação Segura e Inteligente
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local TeleportManager = {}
TeleportManager.__index = TeleportManager

-- ─── [1] DATABASE DE ILHAS (Otimizada) ───────────────────────

local ISLANDS = {
	-- First Sea
	["Town of Beginnings"] = Vector3.new(1100, 18, 1230),
	["Sandora"]            = Vector3.new(-1150, 18, 1420),
	["Shell's Town"]       = Vector3.new(-3800, 20, -4200),
	["Orange Town"]        = Vector3.new(-820, 18, 830),
	["Baratie"]            = Vector3.new(-3100, 12, 4800),
	["Kori Island"]        = Vector3.new(2200, 18, 1850),
	["Sphinx Island"]      = Vector3.new(-6500, 35, -2100),
	["Shark Park"]         = Vector3.new(1250, 18, -3420),
	["Land of the Sky"]    = Vector3.new(-1200, 450, 6000),
	["Golden City"]        = Vector3.new(-1200, 450, 6000),
	["Gravito's Fort"]     = Vector3.new(2800, 80, -3200),
	["Fishman Island"]     = Vector3.new(7200, -300, 1100),
	["Underwater"]         = Vector3.new(7200, -300, 1100),

	-- Second Sea
	["Desert Kingdom"]     = Vector3.new(-1200, 25, -3000),
	["Sashi Island"]       = Vector3.new(4100, 30, -1500),
	["Rovo Island"]        = Vector3.new(-2500, 22, 3800),
	["Spirit Island"]      = Vector3.new(3200, 32, 4500),
	["Foro Island"]        = Vector3.new(-4800, 22, 1100),
	["Umi Island"]         = Vector3.new(5200, 22, -4200),
	["Thriller Bark"]      = Vector3.new(-5400, 80, -7800),
	["Rose Kingdom"]       = Vector3.new(450, 120, -180),
	["Colosseum"]          = Vector3.new(-600, 30, 5200),
	["Colosseum of Arc"]   = Vector3.new(-600, 30, 5200),
}

-- Aliases para busca rápida
local ALIASES = {
	["start"] = "Town of Beginnings",
	["beginning"] = "Town of Beginnings",
	["desert"] = "Sandora",
	["marine"] = "Shell's Town",
	["shells"] = "Shell's Town",
	["baratie"] = "Baratie",
	["sky"] = "Land of the Sky",
	["golden"] = "Golden City",
	["fishman"] = "Fishman Island",
	["underwater"] = "Fishman Island",
	["thriller"] = "Thriller Bark",
	["rose"] = "Rose Kingdom",
	["factory"] = "Rose Kingdom",
}

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function TeleportManager.new(smartFlight, notifications)
	local self = setmetatable({}, TeleportManager)

	self.SmartFlight   = smartFlight
	self.Notifications = notifications

	self.TeleportHistory = {}  -- Histórico de viagens para debug
	self._maxHistory     = 5

	return self
end

-- ─── [3] LÓGICA DE BUSCA (Engine) ────────────────────────────

-- Resolve o nome da ilha usando Alias ou Match Parcial
function TeleportManager:_resolveIsland(name)
	name = name:lower():gsub("%s+", "") -- Limpa espaços

	-- 1. Match por Alias
	local aliasMatch = nil
	for alias, fullName in pairs(ALIASES) do
		if name:find(alias, 1, true) then
			aliasMatch = fullName
			break
		end
	end

	if aliasMatch then return aliasMatch, ISLANDS[aliasMatch] end

	-- 2. Match por Nome Completo ou Parcial
	for islandName, pos in pairs(ISLANDS) do
		local lowerIsland = islandName:lower()
		if lowerIsland:find(name, 1, true) or name:find(lowerIsland, 1, true) then
			return islandName, pos
		end
	end

	return nil, nil
end

-- ─── [4] EXECUÇÃO DE VIAGEM (Core Method) ────────────────────

function TeleportManager:TeleportTo(islandName)
	local fullName, position = self:_resolveIsland(islandName)

	if not fullName or not position then
		Logger.Warn("TeleportManager: Ilha não encontrada: " .. tostring(islandName))
		return false
	end

	-- Validação de Integridade da Posição (Anti-NaN/Infinity)
	if position.X ~= position.X or math.abs(position.X) > 1e5 then
		Logger.Error("TeleportManager: Posição inválida detectada!")
		return false
	end

	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	-- Notificação de Início
	if self.Notifications then
		self.Notifications.Create(Players.LocalPlayer.PlayerGui, "🌍 VIAGEM INICIADA", 
			"Indo para: " .. fullName, 3, Color3.fromRGB(100, 200, 255))
	end

	-- O uso do SmartFlight é OBRIGATÓRIO para evitar detecção de teleporte
	if self.SmartFlight then
		-- O SmartFlight cuidará do Tweening e da trajetória orgânica
		self.SmartFlight:FlyTo(position)
	else
		Logger.Error("TeleportManager: SmartFlight não configurado! Viagem abortada.")
		return false
	end

	-- Registro de Histórico
	table.insert(self.TeleportHistory, 1, {
		Island = fullName,
		Time = os.time()
	})
	if #self.TeleportHistory > self._maxHistory then
		table.remove(self.TeleportHistory)
	end

	Logger.Success("Chegou em: " .. fullName)
	return true
end

-- ─── [5] UTILITÁRIOS E API PÚBLICA ───────────────────────────

-- Teleporte para a ilha mais próxima do jogador
function TeleportManager:TeleportToNearest()
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
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

-- Lista todas as ilhas catalogadas
function TeleportManager:ListIslands()
	local list = {}
	for name in pairs(ISLANDS) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

-- Retorna o histórico de viagens
function TeleportManager:GetHistory()
	return self.TeleportHistory
end

return TeleportManager