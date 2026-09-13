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
	self.Order     = {}       -- insercao ordenada; pairs() ordem aleatoria
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
	if not self.Tabs[name] then
		table.insert(self.Order, name)
	end
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

	-- Desativa a aba atual (ordem de insercao; pairs() ordem aleatoria)
	for _, tabName in ipairs(self.Order) do
		local tab = self.Tabs[tabName]
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

		-- Mostra/oculta conteúdo (cada aba é um ScrollingFrame próprio)
		if isTarget then
			tab.Content.Visible = true
			pcall(function()
				tab.Content.CanvasPosition = Vector2.new(0, 0)
			end)
		else
			tab.Content.Visible = false
		end
	end

	self.ActiveTab = name
end

-- Ativa a primeira aba registrada (ordem de insercao)
function TabManager:ShowFirst()
	if #self.Order > 0 then
		self:Switch(self.Order[1])
	end
end

function TabManager:GetActive()
	return self.ActiveTab
end

return TabManager
