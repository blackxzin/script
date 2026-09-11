-- ============================================================
--  Elite Automation Framework :: UI.Notifications
--  Sistema de notificações visuais no canto da tela.
--  Suporta cor customizada por raridade e fila limitada.
-- ============================================================

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local Notifications = {}
Notifications.__index = Notifications

-- ─── Configurações visuais ────────────────────────────────────
local NOTIF_WIDTH    = 280
local NOTIF_HEIGHT   = 70
local NOTIF_PADDING  = 8
local NOTIF_X_OFFSET = 15   -- distância da borda direita
local NOTIF_Y_START  = 80   -- distância do topo
local MAX_VISIBLE    = 4

local DEFAULT_BG     = Color3.fromRGB(15, 15, 25)
local DEFAULT_ACCENT = Color3.fromRGB(100, 200, 255)
local TEXT_COLOR     = Color3.fromRGB(240, 240, 255)
local ICON_SIZE      = 20

-- ─── Fila de notificações ativas ─────────────────────────────
local activeNotifs = {}   -- lista de frames na tela

-- ─── Repositiona todas as notificações ativas ────────────────
local function repositionAll(playerGui)
	for i, frame in ipairs(activeNotifs) do
		local targetY = NOTIF_Y_START + (i - 1) * (NOTIF_HEIGHT + NOTIF_PADDING)
		TweenService:Create(
			frame,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1, -(NOTIF_WIDTH + NOTIF_X_OFFSET), 0, targetY) }
		):Play()
	end
end

-- ─── Remove uma notificação da lista ─────────────────────────
local function removeNotif(frame)
	for i, f in ipairs(activeNotifs) do
		if f == frame then
			table.remove(activeNotifs, i)
			return
		end
	end
end

-- ─════════════════════════════════════════════════════════════
--   API PRINCIPAL: Notifications.Create
-- ═════════════════════════════════════════════════════════════

--[[
	playerGui  : PlayerGui do jogador local
	title      : string do título (ex: "🍎 FRUTA DETECTADA")
	message    : string da mensagem
	duration   : segundos visível (padrão: 5)
	accentColor: Color3 opcional (padrão: azul)
]]
function Notifications.Create(playerGui, title, message, duration, accentColor)
	if not playerGui then return end

	duration    = duration    or 5
	accentColor = accentColor or DEFAULT_ACCENT

	-- Garante que o ScreenGui existe
	local screenGui = playerGui:FindFirstChild("EliteNotifs")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name            = "EliteNotifs"
		screenGui.ResetOnSpawn    = false
		screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
		screenGui.DisplayOrder    = 999
		screenGui.Parent          = playerGui
	end

	-- Limita a MAX_VISIBLE notificações
	if #activeNotifs >= MAX_VISIBLE then
		local oldest = table.remove(activeNotifs, 1)
		oldest:Destroy()
	end

	-- ─── Frame principal ─────────────────────────────────────
	local frame = Instance.new("Frame")
	frame.Name             = "Notification"
	frame.Size             = UDim2.new(0, NOTIF_WIDTH, 0, NOTIF_HEIGHT)
	-- Começa fora da tela (à direita)
	frame.Position         = UDim2.new(1, 50, 0, NOTIF_Y_START)
	frame.BackgroundColor3 = DEFAULT_BG
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel  = 0
	frame.ClipsDescendants = true
	frame.ZIndex           = 10

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- ─── Barra de acento lateral ─────────────────────────────
	local accentBar = Instance.new("Frame")
	accentBar.Name             = "AccentBar"
	accentBar.Size             = UDim2.new(0, 4, 1, 0)
	accentBar.Position         = UDim2.new(0, 0, 0, 0)
	accentBar.BackgroundColor3 = accentColor
	accentBar.BorderSizePixel  = 0
	accentBar.ZIndex           = 11
	accentBar.Parent           = frame

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 4)
	accentCorner.Parent = accentBar

	-- ─── Título ──────────────────────────────────────────────
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name             = "Title"
	titleLabel.Size             = UDim2.new(1, -18, 0, 22)
	titleLabel.Position         = UDim2.new(0, 14, 0, 8)
	titleLabel.Text             = title
	titleLabel.TextColor3       = accentColor
	titleLabel.TextSize         = 13
	titleLabel.Font             = Enum.Font.GothamBold
	titleLabel.TextXAlignment   = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.ZIndex           = 12
	titleLabel.Parent           = frame

	-- ─── Mensagem ────────────────────────────────────────────
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name               = "Message"
	msgLabel.Size               = UDim2.new(1, -18, 0, 35)
	msgLabel.Position           = UDim2.new(0, 14, 0, 28)
	msgLabel.Text               = message
	msgLabel.TextColor3         = TEXT_COLOR
	msgLabel.TextSize           = 11
	msgLabel.Font               = Enum.Font.Gotham
	msgLabel.TextXAlignment     = Enum.TextXAlignment.Left
	msgLabel.TextWrapped        = true
	msgLabel.BackgroundTransparency = 1
	msgLabel.ZIndex             = 12
	msgLabel.Parent             = frame

	-- ─── Barra de progresso (timer) ─────────────────────────
	local progressBg = Instance.new("Frame")
	progressBg.Name             = "ProgressBg"
	progressBg.Size             = UDim2.new(1, 0, 0, 2)
	progressBg.Position         = UDim2.new(0, 0, 1, -2)
	progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	progressBg.BorderSizePixel  = 0
	progressBg.ZIndex           = 11
	progressBg.Parent           = frame

	local progressBar = Instance.new("Frame")
	progressBar.Name             = "Progress"
	progressBar.Size             = UDim2.new(1, 0, 1, 0)
	progressBar.BackgroundColor3 = accentColor
	progressBar.BorderSizePixel  = 0
	progressBar.ZIndex           = 12
	progressBar.Parent           = progressBg

	frame.Parent = screenGui
	table.insert(activeNotifs, frame)

	-- ─── Slide In ────────────────────────────────────────────
	local targetPos = UDim2.new(1, -(NOTIF_WIDTH + NOTIF_X_OFFSET), 0,
		NOTIF_Y_START + (#activeNotifs - 1) * (NOTIF_HEIGHT + NOTIF_PADDING))

	TweenService:Create(
		frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = targetPos }
	):Play()

	-- ─── Animação de progresso ────────────────────────────────
	TweenService:Create(
		progressBar,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(0, 0, 1, 0) }
	):Play()

	-- ─── Slide Out e destruição ──────────────────────────────
	task.delay(duration, function()
		if not frame or not frame.Parent then return end

		TweenService:Create(
			frame,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 50, 0, frame.Position.Y.Offset) }
		):Play()

		task.wait(0.3)
		removeNotif(frame)
		frame:Destroy()
		repositionAll(playerGui)
	end)
end

return Notifications
