-- ============================================================
--  Elite Automation Framework :: Systems.ESP
--  ESP visual para NPCs, Bosses, Frutas e Players.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local ESP = {}
ESP.__index = ESP

-- ─── Cores por categoria ──────────────────────────────────────
local COLORS = {
	Boss = Color3.fromRGB(255, 50, 50),
	NPC = Color3.fromRGB(255, 200, 0),
	Fruit = Color3.fromRGB(200, 50, 255),
	Player = Color3.fromRGB(50, 150, 255),
	Chest = Color3.fromRGB(255, 215, 0),
}

function ESP.new()
	local self = setmetatable({}, ESP)

	self.Enabled = {
		Boss = false,
		NPC = false,
		Fruit = false,
		Player = false,
		Chest = false,
	}

	self._highlights = {}  -- [model] = Highlight instance
	self._billboards = {}  -- [model] = BillboardGui
	self._updateThread = nil

	return self
end

-- ─── Cria Highlight em modelo ─────────────────────────────────

function ESP:_createHighlight(model, color, category)
	if not model or not model.Parent then return end
	if self._highlights[model] then return end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model

	self._highlights[model] = { Instance = highlight, Category = category }
end

-- ─── Cria Billboard com texto ─────────────────────────────────
function ESP:_createBillboard(model, text, color, category)
	if not model or not model.Parent then return end
	if self._billboards[model] then return end

	local root = model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Head")
		or model:FindFirstChildOfClass("BasePart")

	if not root then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = root
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard

	self._billboards[model] = {
		Instance = billboard,
		Label = label,
		Root = root,
		Text = text,
		Category = category,
	}
end

-- ─── Remove ESP de modelo ─────────────────────────────────────
function ESP:_removeESP(model)
	if self._highlights[model] then
		self._highlights[model].Instance:Destroy()
		self._highlights[model] = nil
	end

	if self._billboards[model] then
		self._billboards[model].Instance:Destroy()
		self._billboards[model] = nil
	end
end

function ESP:_updateDistances()
	local localPlayer = Players.LocalPlayer
	local char = localPlayer and localPlayer.Character
	local playerRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not playerRoot then return end

	for model, data in pairs(self._billboards) do
		if not model.Parent or not data.Instance.Parent or not data.Root.Parent then
			self:_removeESP(model)
		else
			local dist = (data.Root.Position - playerRoot.Position).Magnitude
			data.Label.Text = string.format("%s [%.0fm]", data.Text, dist)
		end
	end

	for model, data in pairs(self._highlights) do
		if not model.Parent or not data.Instance.Parent then
			self:_removeESP(model)
		end
	end
end

-- ─── Atualiza ESP de Bosses ───────────────────────────────────
function ESP:_updateBosses()
	if not self.Enabled.Boss then return end

	-- Lista de nomes de boss conhecidos
	local bossNames = {
		"Kraken", "Sea Beast", "Ghost Ship", "Megalodon",
		"Law", "Moria", "Enel", "Gravito", "Neptune",
		"Ryuma", "Borj", "Pica", "Donmingo", "Lucy",
		"Doflamingo", "Luci",
	}

	for _, name in ipairs(bossNames) do
		local boss = workspace:FindFirstChild(name, true)
		if boss and boss:IsA("Model") then
			local hum = boss:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				self:_createHighlight(boss, COLORS.Boss, "Boss")
				self:_createBillboard(boss, "👑 " .. name, COLORS.Boss, "Boss")
			end
		end
	end
end

-- ─── Atualiza ESP de NPCs ────────────────────────────────────
function ESP:_updateNPCs()
	if not self.Enabled.NPC then return end

	local playerCharacters = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then playerCharacters[player.Character] = true end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and not playerCharacters[obj]
			and obj:FindFirstChildOfClass("Humanoid") then
			self:_createHighlight(obj, COLORS.NPC, "NPC")
			self:_createBillboard(obj, "NPC: " .. obj.Name, COLORS.NPC, "NPC")
		end
	end
end

-- ─── Atualiza ESP de Frutas ───────────────────────────────────
function ESP:_updateFruits()
	if not self.Enabled.Fruit then return end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "Fruit" or obj.Name:find("Fruit", 1, true) then
			if obj:IsA("Model") or obj:IsA("Tool") then
				self:_createHighlight(obj, COLORS.Fruit, "Fruit")
				self:_createBillboard(obj, "🍎 Devil Fruit", COLORS.Fruit, "Fruit")
			end
		end
	end
end

-- ─── Atualiza ESP de Players ──────────────────────────────────
function ESP:_updatePlayers()
	if not self.Enabled.Player then return end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= Players.LocalPlayer then
			local char = player.Character
			if char then
				self:_createHighlight(char, COLORS.Player, "Player")
				self:_createBillboard(char, player.Name, COLORS.Player, "Player")
			end
		end
	end
end

-- ─── Atualiza ESP de Chests ───────────────────────────────────
function ESP:_updateChests()
	if not self.Enabled.Chest then return end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name:find("Chest", 1, true) and obj:IsA("Model") then
			self:_createHighlight(obj, COLORS.Chest, "Chest")
			self:_createBillboard(obj, "📦 Chest", COLORS.Chest, "Chest")
		end
	end
end

-- ─── Loop de atualização ──────────────────────────────────────
function ESP:_updateLoop()
	while self._updateThread do
		local ok, err = pcall(function()
			self:_updateBosses()
			self:_updateNPCs()
			self:_updateFruits()
			self:_updatePlayers()
			self:_updateChests()
			self:_updateDistances()
		end)
		if not ok then Logger.Error("ESP loop error:", err) end

		task.wait(1)  -- Atualiza a cada 1s
	end
end

-- ─── API Pública ──────────────────────────────────────────────
function ESP:Toggle(category, enabled)
	if self.Enabled[category] ~= nil then
		self.Enabled[category] = enabled

		-- Remove ESP existente se desativado
		if not enabled then
			for model, data in pairs(self._highlights) do
				if data.Category == category then self:_removeESP(model) end
			end
			for model, data in pairs(self._billboards) do
				if data.Category == category then self:_removeESP(model) end
			end
		end

		Logger.Info("ESP", category, enabled and "ativado" or "desativado")
	end
end

function ESP:Start()
	if self._updateThread then return end
	self._updateThread = task.spawn(function()
		self:_updateLoop()
	end)
	Logger.Info("ESP iniciado")
end

function ESP:Stop()
	if self._updateThread then
		task.cancel(self._updateThread)
		self._updateThread = nil
	end

	-- Remove todos os ESP
	for model in pairs(self._highlights) do
		self:_removeESP(model)
	end
	for category in pairs(self.Enabled) do
		self.Enabled[category] = false
	end

	Logger.Info("ESP parado")
end

return ESP
