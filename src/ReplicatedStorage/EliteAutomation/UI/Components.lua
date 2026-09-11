-- ============================================================
--  Elite Automation Framework :: UI.Components
--  Componentes reutilizáveis de UI: Toggle, Slider, Label.
-- ============================================================

local TweenService = game:GetService("TweenService")

local Components = {}

-- ─── Paleta de cores ─────────────────────────────────────────
local C = {
	BG       = Color3.fromRGB(18, 18, 30),
	Surface  = Color3.fromRGB(25, 25, 42),
	Border   = Color3.fromRGB(45, 45, 75),
	Accent   = Color3.fromRGB(100, 130, 255),
	AccentOff = Color3.fromRGB(55, 55, 90),
	TextMain = Color3.fromRGB(230, 230, 255),
	TextSub  = Color3.fromRGB(130, 130, 180),
	Success  = Color3.fromRGB(80, 220, 130),
	Danger   = Color3.fromRGB(255, 80, 100),
}

-- ─── Utilitário: cria UICorner ────────────────────────────────
local function corner(radius, parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- ─════════════════════════════════════════════════════════════
--   Toggle Button
-- ═════════════════════════════════════════════════════════════

--[[
	Cria um toggle (on/off) dentro de um frame pai.

	parent   : Frame container
	label    : texto descritivo
	callback : function(enabled: bool) chamada ao mudar estado
	default  : bool (estado inicial, padrão false)

	Retorna { SetEnabled = function(bool) }
]]
function Components.CreateToggle(parent, label, callback, default)
	local enabled = default or false

	-- ─ Row container ─
	local row = Instance.new("Frame")
	row.Name                  = "Toggle_" .. label
	row.Size                  = UDim2.new(1, -10, 0, 38)
	row.BackgroundColor3      = C.Surface
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel       = 0
	row.LayoutOrder           = 1
	corner(8, row)
	row.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color     = C.Border
	stroke.Thickness = 1
	stroke.Parent    = row

	-- ─ Label ─
	local lbl = Instance.new("TextLabel")
	lbl.Name              = "Label"
	lbl.Size              = UDim2.new(1, -60, 1, 0)
	lbl.Position          = UDim2.new(0, 12, 0, 0)
	lbl.Text              = label
	lbl.TextColor3        = C.TextMain
	lbl.TextSize          = 13
	lbl.Font              = Enum.Font.GothamMedium
	lbl.TextXAlignment    = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1
	lbl.Parent = row

	-- ─ Track (fundo do toggle) ─
	local track = Instance.new("Frame")
	track.Name             = "Track"
	track.Size             = UDim2.new(0, 42, 0, 22)
	track.Position         = UDim2.new(1, -54, 0.5, -11)
	track.BackgroundColor3 = enabled and C.Accent or C.AccentOff
	track.BorderSizePixel  = 0
	corner(11, track)
	track.Parent = row

	-- ─ Thumb (bolinha) ─
	local thumb = Instance.new("Frame")
	thumb.Name             = "Thumb"
	thumb.Size             = UDim2.new(0, 16, 0, 16)
	thumb.Position         = enabled
		and UDim2.new(0, 23, 0.5, -8)
		or  UDim2.new(0, 3, 0.5, -8)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel  = 0
	corner(8, thumb)
	thumb.Parent = track

	-- ─ Animação do toggle ─
	local function animate(state)
		TweenService:Create(track, TweenInfo.new(0.18, Enum.EasingStyle.Sine),
			{ BackgroundColor3 = state and C.Accent or C.AccentOff }
		):Play()
		TweenService:Create(thumb, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = state
				and UDim2.new(0, 23, 0.5, -8)
				or  UDim2.new(0, 3, 0.5, -8)
			}
		):Play()
	end

	-- ─ Clique ─
	local button = Instance.new("TextButton")
	button.Size               = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text               = ""
	button.Parent             = row

	button.MouseButton1Click:Connect(function()
		enabled = not enabled
		animate(enabled)
		if callback then
			task.spawn(callback, enabled)
		end
	end)

	-- ─ Hover effect ─
	button.MouseEnter:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.1),
			{ BackgroundTransparency = 0.1 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.1),
			{ BackgroundTransparency = 0.3 }):Play()
	end)

	-- ─ API pública ─
	return {
		SetEnabled = function(state)
			enabled = state
			animate(state)
		end,
		IsEnabled = function()
			return enabled
		end,
		Frame = row,
	}
end

-- ─════════════════════════════════════════════════════════════
--   Label de Status
-- ═════════════════════════════════════════════════════════════

function Components.CreateStatusLabel(parent, labelText, valueText)
	local row = Instance.new("Frame")
	row.Name             = "Status_" .. labelText
	row.Size             = UDim2.new(1, -10, 0, 28)
	row.BackgroundTransparency = 1
	row.BorderSizePixel  = 0
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size             = UDim2.new(0.5, 0, 1, 0)
	lbl.Text             = labelText
	lbl.TextColor3       = C.TextSub
	lbl.TextSize         = 12
	lbl.Font             = Enum.Font.Gotham
	lbl.TextXAlignment   = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1
	lbl.Parent = row

	local val = Instance.new("TextLabel")
	val.Name             = "Value"
	val.Size             = UDim2.new(0.5, 0, 1, 0)
	val.Position         = UDim2.new(0.5, 0, 0, 0)
	val.Text             = valueText or "—"
	val.TextColor3       = C.TextMain
	val.TextSize         = 12
	val.Font             = Enum.Font.GothamBold
	val.TextXAlignment   = Enum.TextXAlignment.Right
	val.BackgroundTransparency = 1
	val.Parent = row

	return {
		SetValue = function(text)
			val.Text = tostring(text)
		end,
		Frame = row,
	}
end

-- ─════════════════════════════════════════════════════════════
--   Separador visual
-- ═════════════════════════════════════════════════════════════

function Components.CreateSeparator(parent)
	local sep = Instance.new("Frame")
	sep.Size             = UDim2.new(1, -10, 0, 1)
	sep.BackgroundColor3 = C.Border
	sep.BorderSizePixel  = 0
	sep.Parent = parent
	return sep
end

-- ─════════════════════════════════════════════════════════════
--   Botão de ação simples
-- ═════════════════════════════════════════════════════════════

function Components.CreateButton(parent, label, callback)
	local btn = Instance.new("TextButton")
	btn.Name             = "Btn_" .. label
	btn.Size             = UDim2.new(1, -10, 0, 34)
	btn.BackgroundColor3 = C.Accent
	btn.Text             = label
	btn.TextColor3       = Color3.fromRGB(255, 255, 255)
	btn.TextSize         = 13
	btn.Font             = Enum.Font.GothamBold
	btn.BorderSizePixel  = 0
	corner(8, btn)
	btn.Parent = parent

	btn.MouseButton1Click:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.08),
			{ BackgroundColor3 = Color3.fromRGB(70, 100, 220) }):Play()
		task.wait(0.1)
		TweenService:Create(btn, TweenInfo.new(0.15),
			{ BackgroundColor3 = C.Accent }):Play()
		if callback then task.spawn(callback) end
	end)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12),
			{ BackgroundColor3 = Color3.fromRGB(120, 150, 255) }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12),
			{ BackgroundColor3 = C.Accent }):Play()
	end)

	return btn
end

return Components
