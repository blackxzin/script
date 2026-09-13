-- ============================================================
--  Elite Automation Framework :: UI.MainUI
--  Painel principal da interface de usuário.
--  Design escuro com glassmorphism, drag-to-move e abas.
-- ============================================================

local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players        = game:GetService("Players")

local MainUI = {}
MainUI.__index = MainUI

-- ─── Paleta ───────────────────────────────────────────────────
local C = {
	BG       = Color3.fromRGB(10, 10, 20),
	Header   = Color3.fromRGB(15, 15, 30),
	Surface  = Color3.fromRGB(20, 20, 38),
	Border   = Color3.fromRGB(50, 50, 90),
	Accent   = Color3.fromRGB(100, 130, 255),
	AccentGlow = Color3.fromRGB(80, 110, 230),
	Text     = Color3.fromRGB(230, 230, 255),
	TextSub  = Color3.fromRGB(130, 130, 180),
	TabInactive = Color3.fromRGB(35, 35, 62),
	TabActive   = Color3.fromRGB(100, 130, 255),
}

local PANEL_W = 340
local PANEL_H = 440
local TAB_H   = 32
local HEADER_H = 50

-- ─── Cria UICorner ────────────────────────────────────────────
local function corner(r, p)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

-- ─── Cria UIStroke ────────────────────────────────────────────
local function stroke(color, thick, p)
	local s = Instance.new("UIStroke")
	s.Color     = color
	s.Thickness = thick
	s.Parent    = p
end

-- ─── Implementa drag-to-move ─────────────────────────────────
local function makeDraggable(frame, handle)
	local dragging   = false
	local dragStart  = nil
	local startPos   = nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = input.Position
			startPos  = frame.Position
		end
	end)

	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- ─── Construtor ──────────────────────────────────────────────
function MainUI.new()
	local self = setmetatable({}, MainUI)

	local localPlayer = Players.LocalPlayer
	local playerGui   = localPlayer:WaitForChild("PlayerGui")

	-- ─ Re-execução limpa: remove UI velha (loops duplicados = kick) ─
	pcall(function()
		local old = playerGui:FindFirstChild("EliteAutomationUI")
		if old then old:Destroy() end
		local notifs = playerGui:FindFirstChild("EliteNotifs")
		if notifs then notifs:Destroy() end
	end)

	-- ─ ScreenGui ─
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "EliteAutomationUI"
	screenGui.ResetOnSpawn   = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder   = 100
	screenGui.Parent         = playerGui
	self.ScreenGui = screenGui

	-- ─ Painel principal ─
	local panel = Instance.new("Frame")
	panel.Name             = "Panel"
	panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
	panel.Position         = UDim2.new(0, 20, 0.5, -PANEL_H / 2)
	panel.BackgroundColor3 = C.BG
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel  = 0
	panel.Visible          = false
	corner(12, panel)
	stroke(C.Border, 1.5, panel)
	panel.Parent = screenGui
	self.Panel = panel

	-- ─ Header ─
	local header = Instance.new("Frame")
	header.Name             = "Header"
	header.Size             = UDim2.new(1, 0, 0, HEADER_H)
	header.BackgroundColor3 = C.Header
	header.BorderSizePixel  = 0
	corner(12, header)
	header.Parent = panel

	-- Mascara canto inferior do header para ficar quadrado embaixo
	local headerMask = Instance.new("Frame")
	headerMask.Size             = UDim2.new(1, 0, 0, 12)
	headerMask.Position         = UDim2.new(0, 0, 1, -12)
	headerMask.BackgroundColor3 = C.Header
	headerMask.BorderSizePixel  = 0
	headerMask.Parent = header

	-- ─ Logo / Título ─
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size           = UDim2.new(1, -100, 1, 0)
	titleLabel.Position       = UDim2.new(0, 15, 0, 0)
	titleLabel.Text           = "⚡ ELITE AUTOMATION"
	titleLabel.TextColor3     = C.Accent
	titleLabel.TextSize       = 16
	titleLabel.Font           = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header

	-- ─ Subtítulo/versão ─
	local subLabel = Instance.new("TextLabel")
	subLabel.Size           = UDim2.new(1, -100, 0, 14)
	subLabel.Position       = UDim2.new(0, 15, 0, 30)
	subLabel.Text           = "Grand Piece Online (GPO) v2.1"
	subLabel.TextColor3     = C.TextSub
	subLabel.TextSize       = 10
	subLabel.Font           = Enum.Font.Gotham
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.BackgroundTransparency = 1
	subLabel.Parent = header

	-- ─ Botão minimizar (–) ─
	local minimizeBtn = Instance.new("TextButton")
	minimizeBtn.Name             = "Minimize"
	minimizeBtn.Size             = UDim2.new(0, 26, 0, 26)
	minimizeBtn.Position         = UDim2.new(1, -60, 0.5, -13)
	minimizeBtn.Text             = "–"
	minimizeBtn.TextColor3       = C.TextSub
	minimizeBtn.TextSize         = 18
	minimizeBtn.Font             = Enum.Font.GothamBold
	minimizeBtn.BackgroundColor3 = C.Surface
	minimizeBtn.BorderSizePixel  = 0
	corner(6, minimizeBtn)
	minimizeBtn.Parent = header

	-- ─ Botão fechar (×) ─
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name             = "Close"
	closeBtn.Size             = UDim2.new(0, 26, 0, 26)
	closeBtn.Position         = UDim2.new(1, -30, 0.5, -13)
	closeBtn.Text             = "×"
	closeBtn.TextColor3       = Color3.fromRGB(255, 80, 100)
	closeBtn.TextSize         = 18
	closeBtn.Font             = Enum.Font.GothamBold
	closeBtn.BackgroundColor3 = C.Surface
	closeBtn.BorderSizePixel  = 0
	corner(6, closeBtn)
	closeBtn.Parent = header

	-- ─ Funcionalidade dos botões ─
	local minimized = false
	local contentArea

	minimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if contentArea then
			contentArea.Visible = not minimized
		end
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Sine),
			{ Size = minimized
				and UDim2.new(0, PANEL_W, 0, HEADER_H)
				or  UDim2.new(0, PANEL_W, 0, PANEL_H)
			}
		):Play()
		minimizeBtn.Text = minimized and "+" or "–"
	end)

	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	-- ─ Drag ─
	makeDraggable(panel, header)

	-- ─ Tab Bar ─
	local tabBar = Instance.new("Frame")
	tabBar.Name             = "TabBar"
	tabBar.Size             = UDim2.new(1, 0, 0, TAB_H)
	tabBar.Position         = UDim2.new(0, 0, 0, HEADER_H)
	tabBar.BackgroundColor3 = C.Header
	tabBar.BorderSizePixel  = 0
	tabBar.Parent = panel
	self.TabBar = tabBar

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder     = Enum.SortOrder.LayoutOrder
	tabLayout.Parent        = tabBar

	-- ─ Content Area (Frame fixo; cada aba tem scroll próprio) ─
	local content = Instance.new("Frame")
	content.Name                 = "ContentArea"
	content.Size                 = UDim2.new(1, 0, 1, -(HEADER_H + TAB_H + 8))
	content.Position             = UDim2.new(0, 0, 0, HEADER_H + TAB_H)
	content.BackgroundTransparency = 1
	content.BorderSizePixel      = 0
	content.ClipsDescendants     = true
	content.Parent = panel
	self.ContentArea = content
	contentArea = content

	self._tabButtons = {}
	self._tabFrames  = {}
	self._tabCount   = 0

	return self
end

-- ─── Cria botão de aba (largura redividida; /4 fixo quebrava com N abas) ───
function MainUI:CreateTabButton(name)
	self._tabCount = self._tabCount + 1

	local tabW = math.floor(PANEL_W / self._tabCount)
	for _, b in ipairs(self._tabButtons) do
		b.Size = UDim2.new(0, tabW, 1, 0)
	end

	local btn = Instance.new("TextButton")
	btn.Name             = "Tab_" .. name
	btn.Size             = UDim2.new(0, tabW, 1, 0)
	btn.BackgroundColor3 = C.TabInactive
	btn.Text             = name
	btn.TextColor3       = C.TextSub
	btn.TextSize         = 11
	btn.Font             = Enum.Font.GothamMedium
	btn.BorderSizePixel  = 0
	btn.LayoutOrder      = self._tabCount
	btn.Parent           = self.TabBar
	corner(6, btn)

	table.insert(self._tabButtons, btn)
	return btn
end

-- ─── Cria frame de conteúdo de aba (scroll próprio por aba) ────
function MainUI:CreateTabFrame()
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name                   = "TabContent_" .. tostring(#self._tabFrames + 1)
	scroll.Size                   = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel        = 0
	scroll.Visible                = false
	scroll.Active                 = true
	scroll.ClipsDescendants       = true
	scroll.ScrollingDirection     = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness     = 6
	scroll.ScrollBarImageColor3   = C.Accent
	scroll.ElasticBehaviour       = Enum.ElasticBehavior.WhenScrollable
	scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	scroll.Parent                 = self.ContentArea

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding   = UDim.new(0, 6)
	layout.Parent    = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft   = UDim.new(0, 8)
	pad.PaddingRight  = UDim.new(0, 8)
	pad.PaddingTop    = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent        = scroll

	table.insert(self._tabFrames, scroll)
	return scroll
end

-- ─── Abre o painel com animação ──────────────────────────────
function MainUI:Open()
	self.Panel.Visible = true
	self.Panel.BackgroundTransparency = 1
	TweenService:Create(
		self.Panel,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.05 }
	):Play()
end

function MainUI:Close()
	TweenService:Create(
		self.Panel,
		TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	):Play()
	task.delay(0.22, function()
		self.Panel.Visible = false
	end)
end

return MainUI
