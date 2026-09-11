-- ============================================================
--  Elite Automation Framework :: Systems.ItemFarm
--  Scanneia o workspace por itens (baús, caixas, drops) e
--  coleta automaticamente via SmartFlight.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root       = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger     = require(Root.Core.Logger)

local ItemFarm = {}
ItemFarm.__index = ItemFarm

-- ─── Construtor ──────────────────────────────────────────────
function ItemFarm.new(smartFlight, notifications, settings)
	local self = setmetatable({}, ItemFarm)

	self.SmartFlight   = smartFlight
	self.Notifications = notifications
	self.Settings      = settings or {}

	self.ScanInterval  = self.Settings.ScanInterval or 2
	self.ItemTags      = self.Settings.ItemTags or { "Chest", "Baú", "Crate", "Drop" }
	self.CollectRadius = 5

	self._running      = false
	self._thread       = nil
	self._collected    = {}   -- [model] = true, cache anti-duplicata

	return self
end

-- ─── Verifica se modelo é um item coletável ──────────────────
function ItemFarm:_isCollectible(model)
	for _, tag in ipairs(self.ItemTags) do
		-- Nome exato
		if model.Name == tag then return true end
		-- Nome contém a tag
		if model.Name:find(tag, 1, true) then return true end
	end
	return false
end

-- ─── Obtém posição central do item ───────────────────────────
local function getItemPosition(model)
	if model:IsA("Model") then
		local primary = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
		return primary and primary.Position
	elseif model:IsA("BasePart") then
		return model.Position
	end
	return nil
end

-- ─── Coleta um item ──────────────────────────────────────────
function ItemFarm:_collectItem(model)
	if self._collected[model] then return end
	self._collected[model] = true

	local pos = getItemPosition(model)
	if not pos then return end

	Logger.Info("ItemFarm → Coletando:", model.Name, "em", tostring(pos))

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"📦 ITEM DETECTADO",
				model.Name .. " encontrado! Coletando...",
				3
			)
		end
	end

	-- Voa até o item
	if self.SmartFlight then
		self.SmartFlight:FlyTo(pos)
	end

	-- Tenta "tocar" o item para coletar
	local localChar = Players.LocalPlayer.Character
	local root      = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
		task.wait(0.2)
	end

	-- Remove do cache se o modelo sumiu (confirmação de coleta)
	task.delay(3, function()
		if not model or not model.Parent then
			self._collected[model] = nil
			Logger.Success("Item coletado:", model and model.Name or "?")
		else
			-- Item ainda existe → remove do cache para tentar de novo
			self._collected[model] = nil
		end
	end)
end

-- ─── Scan do workspace ───────────────────────────────────────
function ItemFarm:_scan()
	local results = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if (obj:IsA("Model") or obj:IsA("BasePart")) and self:_isCollectible(obj) then
			if not self._collected[obj] then
				table.insert(results, obj)
			end
		end
	end
	return results
end

-- ─── Loop principal ──────────────────────────────────────────
function ItemFarm:_loop()
	self._collected = {}

	while self._running do
		local ok, err = pcall(function()
			local items = self:_scan()

			-- Prioriza por distância
			local localChar = Players.LocalPlayer.Character
			local root      = localChar and localChar:FindFirstChild("HumanoidRootPart")

			if root and #items > 0 then
				table.sort(items, function(a, b)
					local pa = getItemPosition(a) or Vector3.zero
					local pb = getItemPosition(b) or Vector3.zero
					return (pa - root.Position).Magnitude < (pb - root.Position).Magnitude
				end)

				-- Coleta o mais próximo
				task.spawn(function()
					self:_collectItem(items[1])
				end)
			end

			-- Limpa cache de modelos destruídos
			for model in pairs(self._collected) do
				if not model or not model.Parent then
					self._collected[model] = nil
				end
			end
		end)

		if not ok then
			Logger.Error("ItemFarm loop error:", err)
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function ItemFarm:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
	Logger.Info("ItemFarm iniciado. Tags:", table.concat(self.ItemTags, ", "))
end

function ItemFarm:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	self._collected = {}
	Logger.Info("ItemFarm parado.")
end

function ItemFarm:AddTag(tag)
	table.insert(self.ItemTags, tag)
end

function ItemFarm:RemoveTag(tag)
	for i, t in ipairs(self.ItemTags) do
		if t == tag then
			table.remove(self.ItemTags, i)
			return
		end
	end
end

return ItemFarm
