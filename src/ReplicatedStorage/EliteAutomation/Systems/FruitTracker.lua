-- ============================================================
--  Elite Automation Framework :: Systems.FruitTracker
--  Rastreia frutas (Akuma no Mi) e baús de fruta no Grand Piece Online (GPO),
--  notifica a UI com raridade/valor em Peli e executa Auto-Collection via SmartFlight.
-- ============================================================

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root           = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger         = require(Root.Core.Logger)

local FruitTracker = {}
FruitTracker.__index = FruitTracker

-- ─── Nomes de modelos de fruta no workspace ──────────────────
-- GPO usa convenções como "Mera-Mera Fruit", "Pika Fruit", "Fruit", etc.
local FRUIT_SUFFIXES = { "_Fruit", "-Fruit", " Fruit", "Fruit", "" }

local function extractFruitName(modelName)
	for _, suffix in ipairs(FRUIT_SUFFIXES) do
		if suffix ~= "" and modelName:sub(-#suffix) == suffix then
			return modelName:sub(1, -(#suffix + 1))
		end
	end
	return modelName
end

-- ─── Construtor ──────────────────────────────────────────────
function FruitTracker.new(fruitDB, notificationModule, settings)
	local self = setmetatable({}, FruitTracker)

	self.DB              = fruitDB
	self.Notifications   = notificationModule
	self.ScanInterval    = (settings and settings.ScanInterval)   or 1.5
	self.AutoCollect     = (settings and settings.AutoCollect)     ~= false
	self.MinRarity       = (settings and settings.MinRarity)       or "Common"
	self.CollectRadius   = (settings and settings.CollectRadius)   or 5
	self.NotifyOnDetect  = (settings and settings.NotifyOnDetect)  ~= false

	self._running        = false
	self._thread         = nil
	self._knownFruits    = {}  -- [model] = true, para evitar duplicatas
	self._smartFlight    = nil  -- injetado externamente

	return self
end

-- Injeta o módulo de voo
function FruitTracker:SetFlight(smartFlight)
	self._smartFlight = smartFlight
end

-- ─── Scanneia workspace por frutas ───────────────────────────
function FruitTracker:_scan()
	local found = {}

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("Part") then
			local rawName   = obj.Name
			local cleanName = extractFruitName(rawName)
			-- Testa nome limpo ou nome bruto no FruitDatabase
			local data      = self.DB:Get(cleanName) or self.DB:Get(rawName)

			if data then
				local displayName = data.name or cleanName
				if self.DB:MeetsMinRarity(displayName, self.MinRarity) then
					table.insert(found, {
						model    = obj,
						name     = displayName,
						data     = data,
					})
				end
			end
		end
	end

	return found
end

-- ─── Obtém a posição de uma fruta ────────────────────────────
local function getFruitPosition(fruitObj)
	if fruitObj:IsA("Model") then
		local primary = fruitObj.PrimaryPart or fruitObj:FindFirstChildOfClass("BasePart")
		return primary and primary.Position
	elseif fruitObj:IsA("BasePart") then
		return fruitObj.Position
	end
	return nil
end

-- ─── Coleta uma fruta voando até ela ────────────────────────
function FruitTracker:_collect(fruitEntry)
	if not self._smartFlight then
		Logger.Warn("FruitTracker: SmartFlight não injetado. Coleta manual desativada.")
		return
	end

	local pos = getFruitPosition(fruitEntry.model)
	if not pos then return end

	Logger.Info(
		string.format("FruitTracker → Coletando [%s] %s em (%.0f, %.0f, %.0f)",
			fruitEntry.data.rarity, fruitEntry.name, pos.X, pos.Y, pos.Z)
	)

	-- Voa até a fruta
	self._smartFlight:FlyTo(pos)

	local localChar = Players.LocalPlayer.Character
	local root      = localChar and localChar:FindFirstChild("HumanoidRootPart")

	if root then
		local timeout = os.clock() + 15
		while os.clock() < timeout do
			local currentPos = getFruitPosition(fruitEntry.model)
			if not currentPos or not fruitEntry.model.Parent then
				break  -- Fruta coletada ou despawnada
			end
			local dist = (currentPos - root.Position).Magnitude
			if dist <= self.CollectRadius then
				root.CFrame = CFrame.new(currentPos)

				-- Tenta acionar ProximityPrompt caso exista
				local prompt = fruitEntry.model:FindFirstChildOfClass("ProximityPrompt", true)
				if prompt and fireproximityprompt then
					fireproximityprompt(prompt)
				end

				task.wait(0.15)
				break
			end
			task.wait(0.1)
		end
	end

	self._knownFruits[fruitEntry.model] = nil
end

-- ─── Processa fruta recém detectada ──────────────────────────
function FruitTracker:_onFruitDetected(entry)
	if self._knownFruits[entry.model] then return end
	self._knownFruits[entry.model] = true

	local pos = getFruitPosition(entry.model)

	Logger.Success(string.format(
		"🍎 GPO Fruta Detectada: [%s] %s | Valor: %s Peli",
		entry.data.rarity,
		entry.name,
		tostring(entry.data.value)
	))

	-- Notifica a UI
	if self.NotifyOnDetect and self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			local msg = string.format(
				"%s • %s\nValor: %s Peli",
				entry.data.rarity,
				entry.name,
				tostring(entry.data.value)
			)
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"🍎 FRUTA DETECTADA",
				msg,
				5,
				entry.data.color
			)
		end
	end

	-- Auto-Collection
	if self.AutoCollect then
		task.spawn(function()
			self:_collect(entry)
		end)
	end
end

-- ─── Loop principal ──────────────────────────────────────────
function FruitTracker:_loop()
	while self._running do
		local ok, fruits = pcall(function()
			return self:_scan()
		end)

		if ok and fruits then
			for _, entry in ipairs(fruits) do
				if not self._running then break end
				self:_onFruitDetected(entry)
			end
		else
			Logger.Error("FruitTracker loop error:", fruits)
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function FruitTracker:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
	Logger.Info("FruitTracker (GPO) iniciado.")
end

function FruitTracker:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	Logger.Info("FruitTracker parado.")
end

function FruitTracker:SetAutoCollect(enabled)
	self.AutoCollect = enabled
	Logger.Info("AutoCollect:", enabled and "Ativado" or "Desativado")
end

function FruitTracker:SetMinRarity(rarity)
	self.MinRarity = rarity
	Logger.Info("MinRarity alterada para:", rarity)
end

function FruitTracker:GetKnownCount()
	local count = 0
	for _ in pairs(self._knownFruits) do count = count + 1 end
	return count
end

return FruitTracker
