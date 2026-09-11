-- ============================================================
--  Elite Automation Framework :: Systems.ESP
--  ESP visual para NPCs, Bosses, Frutas e Players.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
	self._connections = {}
	self._updateThread = nil

	return self
end

-- ─── Cria Highlight em modelo ─────────────────────────────────
function ESP:_createHighlight(model, color)
	if self._highlights[model] then return end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model

	self._highlights[model] = highlight
end

-- ─── Cria Billboard com texto ─────────────────────────────────
function ESP:_createBillboard(model, text, color)
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

	-- Adiciona distância
	local char = Players.LocalPlayer.Character
	if char then
		local playerRoot = char:FindFirstChild("HumanoidRootPart")
		if playerRoot then
			RunService.Heartbeat:Connect(function()
				if not billboard.Parent then return end
				local dist = (root.Position - playerRoot.Position).Magnitude
				label.Text = string.format("%s [%.0fm]", text, dist)
			end)
		end
	end

	self._billboards[model] = billboard
end

-- ─── Remove ESP de modelo ─────────────────────────────────────
function ESP:_removeESP(model)
	if self._highlights[model] then
		self._highlights[model]:Destroy()
		self._highlights[model] = nil
	end

	if self._billboards[model] then
		self._billboards[model]:Destroy()
		self._billboards[model] = nil
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
	}

	for _, name in ipairs(bossNames) do
		local boss = workspace:FindFirstChild(name, true)
		if boss and boss:IsA("Model") then
			local hum = boss:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				self:_createHighlight(boss, COLORS.Boss)
				self:_createBillboard(boss, "👑 " .. name, COLORS.Boss)
			end
		end
	end
end

-- ─── Atualiza ESP de Frutas ───────────────────────────────────
function ESP:_updateFruits()
	if not self.Enabled.Fruit then return end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "Fruit" or obj.Name:find("Fruit", 1, true) then
			if obj:IsA("Model") or obj:IsA("Tool") then
				self:_createHighlight(obj, COLORS.Fruit)
				self:_createBillboard(obj, "🍎 Devil Fruit", COLORS.Fruit)
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
				self:_createHighlight(char, COLORS.Player)
				self:_createBillboard(char, player.Name, COLORS.Player)
			end
		end
	end
end

-- ─── Atualiza ESP de Chests ───────────────────────────────────
function ESP:_updateChests()
	if not self.Enabled.Chest then return end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name:find("Chest", 1, true) and obj:IsA("Model") then
			self:_createHighlight(obj, COLORS.Chest)
			self:_createBillboard(obj, "📦 Chest", COLORS.Chest)
		end
	end
end

-- ─── Loop de atualização ──────────────────────────────────────
function ESP:_updateLoop()
	while self._updateThread do
		self:_updateBosses()
		self:_updateFruits()
		self:_updatePlayers()
		self:_updateChests()

		task.wait(1)  -- Atualiza a cada 1s
	end
end

-- ─── API Pública ──────────────────────────────────────────────
function ESP:Toggle(category, enabled)
	if self.Enabled[category] ~= nil then
		self.Enabled[category] = enabled

		-- Remove ESP existente se desativado
		if not enabled then
			for model in pairs(self._highlights) do
				self:_removeESP(model)
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

	Logger.Info("ESP parado")
end

return ESP
