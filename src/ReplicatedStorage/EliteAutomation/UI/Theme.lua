-- ============================================================
--  Elite Automation Framework :: UI.Theme
--  Sistema de temas com glassmorphism, gradientes e animações.
-- ============================================================

local Theme = {}

-- ─── Temas disponíveis ────────────────────────────────────────
Theme.Presets = {
	Dark = {
		Name = "Dark Elite",
		BG = Color3.fromRGB(10, 10, 20),
		BGGradient = {Color3.fromRGB(15, 15, 30), Color3.fromRGB(8, 8, 18)},
		Header = Color3.fromRGB(15, 15, 30),
		Surface = Color3.fromRGB(20, 20, 38),
		Border = Color3.fromRGB(50, 50, 90),
		Accent = Color3.fromRGB(100, 130, 255),
		AccentGlow = Color3.fromRGB(80, 110, 230),
		AccentOff = Color3.fromRGB(55, 55, 90),
		Text = Color3.fromRGB(230, 230, 255),
		TextSub = Color3.fromRGB(130, 130, 180),
		Success = Color3.fromRGB(80, 220, 130),
		Danger = Color3.fromRGB(255, 80, 100),
		Warning = Color3.fromRGB(255, 200, 80),
		TabInactive = Color3.fromRGB(35, 35, 62),
		TabActive = Color3.fromRGB(100, 130, 255),
		Blur = true,
		BlurSize = 12,
	},
	Neon = {
		Name = "Neon Cyber",
		BG = Color3.fromRGB(8, 8, 18),
		BGGradient = {Color3.fromRGB(15, 5, 25), Color3.fromRGB(5, 15, 35)},
		Header = Color3.fromRGB(12, 8, 25),
		Surface = Color3.fromRGB(18, 12, 32),
		Border = Color3.fromRGB(120, 60, 200),
		Accent = Color3.fromRGB(200, 60, 255),
		AccentGlow = Color3.fromRGB(180, 40, 240),
		AccentOff = Color3.fromRGB(60, 30, 80),
		Text = Color3.fromRGB(240, 240, 255),
		TextSub = Color3.fromRGB(160, 120, 200),
		Success = Color3.fromRGB(100, 255, 150),
		Danger = Color3.fromRGB(255, 60, 120),
		Warning = Color3.fromRGB(255, 180, 60),
		TabInactive = Color3.fromRGB(40, 20, 60),
		TabActive = Color3.fromRGB(200, 60, 255),
		Blur = true,
		BlurSize = 16,
	},
	Minimal = {
		Name = "Minimal",
		BG = Color3.fromRGB(18, 18, 18),
		BGGradient = {Color3.fromRGB(20, 20, 20), Color3.fromRGB(15, 15, 15)},
		Header = Color3.fromRGB(22, 22, 22),
		Surface = Color3.fromRGB(25, 25, 25),
		Border = Color3.fromRGB(60, 60, 60),
		Accent = Color3.fromRGB(120, 120, 255),
		AccentGlow = Color3.fromRGB(100, 100, 235),
		AccentOff = Color3.fromRGB(60, 60, 80),
		Text = Color3.fromRGB(240, 240, 240),
		TextSub = Color3.fromRGB(140, 140, 140),
		Success = Color3.fromRGB(100, 200, 120),
		Danger = Color3.fromRGB(240, 80, 80),
		Warning = Color3.fromRGB(240, 180, 60),
		TabInactive = Color3.fromRGB(40, 40, 40),
		TabActive = Color3.fromRGB(120, 120, 255),
		Blur = false,
		BlurSize = 0,
	},
}

Theme.Current = Theme.Presets.Dark

-- ─── Aplica gradiente em frame ────────────────────────────────
function Theme.ApplyGradient(frame, color1, color2, rotation)
	rotation = rotation or 90

	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = frame
	end

	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color1),
		ColorSequenceKeypoint.new(1, color2),
	})
	gradient.Rotation = rotation

	return gradient
end

-- ─── Adiciona blur backdrop (glassmorphism) ───────────────────
function Theme.ApplyBlur(frame, size)
	size = size or Theme.Current.BlurSize
	if not Theme.Current.Blur then return end

	-- Usa BackgroundTransparency + Stroke para simular glass
	frame.BackgroundTransparency = 0.15

	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = frame
	end
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.85

	-- Efeito de brilho interno
	local glow = frame:FindFirstChild("GlowEffect")
	if not glow then
		glow = Instance.new("ImageLabel")
		glow.Name = "GlowEffect"
		glow.Size = UDim2.new(1, 0, 1, 0)
		glow.BackgroundTransparency = 1
		glow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		glow.ImageTransparency = 0.92
		glow.ImageColor3 = Theme.Current.Accent
		glow.ZIndex = frame.ZIndex - 1
		glow.Parent = frame
	end
end

-- ─── Corner helper ───────────────────────────────────────────
function Theme.Corner(radius, parent)
	local c = parent:FindFirstChildOfClass("UICorner")
	if not c then
		c = Instance.new("UICorner")
		c.Parent = parent
	end
	c.CornerRadius = UDim.new(0, radius)
	return c
end

-- ─── Stroke helper ───────────────────────────────────────────
function Theme.Stroke(color, thick, parent, transparency)
	local s = parent:FindFirstChildOfClass("UIStroke")
	if not s then
		s = Instance.new("UIStroke")
		s.Parent = parent
	end
	s.Color = color
	s.Thickness = thick
	s.Transparency = transparency or 0
	return s
end

-- ─── Muda tema globalmente ───────────────────────────────────
function Theme.SetTheme(presetName)
	local preset = Theme.Presets[presetName]
	if preset then
		Theme.Current = preset
		return true
	end
	return false
end

return Theme
