-- ============================================================
--  Elite Automation Framework :: UI.TabManager
--  Gerencia múltiplas abas (tabs) de conteúdo no painel.
--  Ao clicar em uma aba, oculta as demais com animação.
-- ============================================================

local TweenService = game:GetService("TweenService")

local TabManager = {}
TabManager.__index = TabManager

-- ─── Cores ───────────────────────────────────────────────────
local C_ACTIVE   = Color3.fromRGB(100, 130, 255)
local C_INACTIVE = Color3.fromRGB(45, 45, 75)
local C_TEXT_ON  = Color3.fromRGB(255, 255, 255)
local C_TEXT_OFF = Color3.fromRGB(140, 140, 190)

function TabManager.new()
	local self = setmetatable({}, TabManager)
	self.Tabs      = {}       -- [name] = { button, content }
	self.ActiveTab = nil
	return self
end

--[[
	Registra uma aba.
	name    : string identificador
	button  : TextButton da aba (no header)
	content : Frame com o conteúdo a exibir
]]
function TabManager:AddTab(name, button, content)
	self.Tabs[name] = {
		Button  = button,
		Content = content,
	}

	-- Esconde o conteúdo por padrão
	content.Visible = false

	-- Conecta o clique
	button.MouseButton1Click:Connect(function()
		self:Switch(name)
	end)
end

function TabManager:Switch(name)
	local target = self.Tabs[name]
	if not target then return end

	-- Desativa a aba atual
	for tabName, tab in pairs(self.Tabs) do
		local isTarget = (tabName == name)

		-- Anima o botão
		TweenService:Create(
			tab.Button,
			TweenInfo.new(0.18, Enum.EasingStyle.Sine),
			{
				BackgroundColor3 = isTarget and C_ACTIVE or C_INACTIVE,
				TextColor3       = isTarget and C_TEXT_ON or C_TEXT_OFF,
			}
		):Play()

		-- Mostra/oculta conteúdo
		if isTarget then
			tab.Content.Visible          = true
			tab.Content.BackgroundTransparency = 1
			TweenService:Create(
				tab.Content,
				TweenInfo.new(0.15, Enum.EasingStyle.Sine),
				{ BackgroundTransparency = 0 }
			):Play()
		else
			tab.Content.Visible = false
		end
	end

	self.ActiveTab = name
end

-- Ativa a primeira aba registrada
function TabManager:ShowFirst()
	local firstName = nil
	for name in pairs(self.Tabs) do
		firstName = name
		break
	end
	if firstName then
		self:Switch(firstName)
	end
end

function TabManager:GetActive()
	return self.ActiveTab
end

return TabManager
