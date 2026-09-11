-- ============================================================
--  Elite Automation Framework :: Systems.AutoHeal
--  Sistema de cura automática com priorização inteligente.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local AutoHeal = {}
AutoHeal.__index = AutoHeal

-- ─── Items de cura conhecidos no GPO ──────────────────────────
local HEAL_ITEMS = {
	-- Comidas (ordenadas por eficiência)
	{Name = "Pineapple", HealAmount = 500, Priority = 1},
	{Name = "Apple", HealAmount = 300, Priority = 2},
	{Name = "Banana", HealAmount = 250, Priority = 3},
	{Name = "Orange", HealAmount = 200, Priority = 4},
	{Name = "Meat", HealAmount = 400, Priority = 1},
	{Name = "Cooked Meat", HealAmount = 600, Priority = 1},

	-- Poções
	{Name = "Health Potion", HealAmount = 1000, Priority = 1},
	{Name = "Small Health Potion", HealAmount = 500, Priority = 2},
}

function AutoHeal.new(settings)
	local self = setmetatable({}, AutoHeal)

	self.Settings = settings or {}
	self.HealThreshold = self.Settings.HealThreshold or 0.50  -- Cura abaixo de 50% HP
	self.EmergencyThreshold = self.Settings.EmergencyThreshold or 0.25  -- Emergência <25%
	self.Enabled = false
	self._lastHeal = 0
	self._lastCheck = 0

	return self
end

-- ─── Obtém HP atual do jogador ────────────────────────────────
function AutoHeal:_getHealthPct()
	local char = Players.LocalPlayer.Character
	if not char then return 1.0 end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return 1.0 end

	return hum.Health / math.max(hum.MaxHealth, 1)
end

-- ─── Verifica se tem item no inventário ───────────────────────
function AutoHeal:_hasItem(itemName)
	local lp = Players.LocalPlayer
	if not lp then return false end

	-- Procura no inventário/backpack
	local backpack = lp:FindFirstChild("Backpack")
	if backpack and backpack:FindFirstChild(itemName) then
		return true
	end

	-- Procura no personagem (equipado)
	local char = lp.Character
	if char and char:FindFirstChild(itemName) then
		return true
	end

	return false
end

-- ─── Usa item de cura ─────────────────────────────────────────
function AutoHeal:_useItem(itemName)
	Logger.Info("Usando item de cura:", itemName)

	local lp = Players.LocalPlayer
	if not lp then return false end

	-- Tenta equipar do backpack
	local backpack = lp:FindFirstChild("Backpack")
	local item = backpack and backpack:FindFirstChild(itemName)

	if item and item:IsA("Tool") then
		-- Equipa ferramenta
		local char = lp.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:EquipTool(item)
				task.wait(0.2)

				-- Ativa ferramenta (GPO usa :Activate())
				pcall(function()
					item:Activate()
				end)

				task.wait(0.3)

				-- Desequipa
				pcall(function()
					hum:UnequipTools()
				end)

				self._lastHeal = os.clock()
				return true
			end
		end
	end

	return false
end

-- ─── Seleciona melhor item disponível ─────────────────────────
function AutoHeal:_getBestHealItem(emergency)
	-- Se emergência, pega qualquer item
	-- Senão, pega o mais eficiente disponível

	local available = {}
	for _, item in ipairs(HEAL_ITEMS) do
		if self:_hasItem(item.Name) then
			table.insert(available, item)
		end
	end

	if #available == 0 then return nil end

	-- Ordena por prioridade
	table.sort(available, function(a, b)
		return a.Priority < b.Priority
	end)

	return available[1]
end

-- ─── Verifica e cura se necessário ────────────────────────────
function AutoHeal:Check()
	if not self.Enabled then return end

	local now = os.clock()
	if (now - self._lastCheck) < 0.5 then return end
	self._lastCheck = now

	-- Cooldown de 2s entre curas
	if (now - self._lastHeal) < 2.0 then return end

	local hpPct = self:_getHealthPct()
	local isEmergency = hpPct <= self.EmergencyThreshold

	if hpPct <= self.HealThreshold or isEmergency then
		local item = self:_getBestHealItem(isEmergency)
		if item then
			self:_useItem(item.Name)

			if isEmergency then
				Logger.Warn("HP CRÍTICO! Usando", item.Name)
			else
				Logger.Info("Auto-Heal ativado:", item.Name)
			end
		else
			Logger.Warn("HP baixo mas nenhum item de cura disponível!")
		end
	end
end

function AutoHeal:Enable()
	self.Enabled = true
	Logger.Info("AutoHeal ativado (threshold:", self.HealThreshold * 100, "%)")
end

function AutoHeal:Disable()
	self.Enabled = false
	Logger.Info("AutoHeal desativado")
end

function AutoHeal:SetThreshold(threshold)
	self.HealThreshold = math.clamp(threshold, 0.1, 0.9)
	Logger.Info("Heal threshold alterado para:", self.HealThreshold * 100, "%")
end

return AutoHeal
