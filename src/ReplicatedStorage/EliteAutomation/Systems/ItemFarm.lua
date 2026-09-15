-- ============================================================
--  Elite Automation Framework :: Systems.ItemFarm
--  Arquitetura de Coleta de Recursos e Otimização de Loot
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local ItemFarm = {}
ItemFarm.__index = ItemFarm

-- ─── [1] CONFIGURAÇÕES E CONSTANTES ──────────────────────────

local SCAN_LIMIT_DISTANCE = 300 -- Distância máxima para considerar um item para coleta
local MIN_DISTANCE_TO_COLLECT = 8 -- Distância mínima para acionar a coleta

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function ItemFarm.new(smartFlight, notifications, settings)
	local self = setmetatable({}, ItemFarm)

	self.SmartFlight   = smartFlight
	self.Notifications = notifications
	self.Settings      = settings or {}

	self.ScanInterval  = self.Settings.ScanInterval or 2
	self.ItemTags      = self.Settings.ItemTags or { "Chest", "Baú", "Crate", "Drop", "Peli", "Pouch" }
	self.CollectRadius = self.Settings.CollectRadius or 5

	self._running      = false
	self._thread       = nil
	self._collected    = {}  -- Cache de itens em processo de coleta
	self._lastScanTime = 0

	return self
end

-- ─── [3] MÉTODOS DE VALIDAÇÃO E BUSCA ───────────────────────

-- Verifica se o objeto é um item válido baseado nas tags
function ItemFarm:_isCollectible(model)
	if not model:IsA("Model") and not model:IsA("BasePart") then return false end
	
	for _, tag in ipairs(self.ItemTags) do
		if model.Name:find(tag, 1, true) then
			return true
		end
	end
	return false
end

-- Obtém a posição central do item com fallback para PrimaryPart
local function getItemPosition(model)
	if model:IsA("Model") then
		local primary = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
		return primary and primary.Position
	elseif model:IsA("BasePart") then
		return model.Position
	end
	return nil
end

-- ─── [4] LÓGICA DE COLETA (Core Logic) ───────────────────────

-- Coleta um item específico com segurança
function ItemFarm:_collectItem(model, name)
	if self._collected[model] then return end
	self._collected[model] = true

	local pos = getItemPosition(model)
	if not pos then 
		self._collected[model] = nil
		return 
	end

	Logger.Info(string.format("ItemFarm → Coletando: %s em (%.0f, %.0f, %.0f)", name, pos.X, pos.Y, pos.Z))

	-- 1. Notificação Visual
	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"📦 ITEM DETECTADO",
				name .. " encontrado! Iniciando coleta...",
				3
			)
		end
	end

	-- 2. Deslocamento Seguro via SmartFlight
	if self.SmartFlight then
		-- Voa para uma posição ligeiramente acima do item para evitar colisões
		self.SmartFlight:FlyTo(pos + Vector3.new(0, 4, 0))
	end

	-- 3. Verificação de Proximidade e Interação
	local localChar = Players.LocalPlayer.Character
	local root = localChar and localChar:FindFirstChild("HumanoidRootPart")

	if root then
		local timeout = os.clock() + 15 -- Timeout de segurança para o processo de coleta
		while os.clock() < timeout do
			if not model.Parent then break end -- Item sumiu (coletado ou deletado)

			local currentPos = getItemPosition(model)
			if not currentPos then break end

			local dist = (currentPos - root.Position).Magnitude
			if dist <= self.CollectRadius then
				-- Tenta interagir via ProximityPrompt ou método de clique
				local prompt = model:FindFirstChildOfClass("ProximityPrompt", true)
				if prompt and fireproximityprompt then
					fireproximityprompt(prompt)
				end
				
				task.wait(0.3) -- Delay para a animação de coleta
				break
			end
			task.wait(0.1)
		end
	end

	-- 4. Limpeza do Cache
	task.delay(5, function()
		self._collected[model] = nil
		Logger.Debug("ItemFarm: Cache limpo para " .. name)
	end)
end

-- ─── [5] LOOP DE VARREDURA (Scan Engine) ─────────────────────

-- Escaneia o ambiente de forma otimizada
function ItemFarm:_scan()
	local results = {}
	local localChar = Players.LocalPlayer.Character
	local root = localChar and localChar:FindFirstChild("HumanoidRootPart")
	
	if not root then return results end
	local myPos = root.Position

	-- Scan otimizado: foca em objetos que fazem sentido
	for _, obj in ipairs(workspace:GetChildren()) do
		-- Se o objeto for muito grande, escaneia os descendentes (como baús dentro de modelos)
		local targets = obj:IsA("Model") and obj:GetDescendants() or {obj}
		
		for _, item in ipairs(targets) do
			if item:IsA("Model") or item:IsA("BasePart") then
				if self:_isCollectible(item) then
					local pos = getItemPosition(item)
					if pos then
						local dist = (pos - myPos).Magnitude
						-- Filtro de distância para evitar scan de itens muito longe
						if dist <= SCAN_LIMIT_DISTANCE then
							table.insert(results, {
								model = item,
								name = item.Name,
								pos = pos,
								dist = dist
							})
						end
					end
				end
			end
		end
	end

	-- Ordena por proximidade para priorizar o item mais próximo
	table.sort(results, function(a, b)
		return a.dist < b.dist
	end)

	return results
end

-- ─── [6] MODO DE EXECUÇÃO (Main Loop) ────────────────────────

function ItemFarm:_loop()
	while self._running do
		local ok, items = pcall(function()
			return self:_scan()
		end)

		if ok and #items > 0 then
			-- Processa o item mais próximo da lista
			local target = items[1]
			
			if target and not self._collected[target.model] then
				self:_collectItem(target.model, target.name)
			end
		elseif not ok then
			Logger.Error("ItemFarm Loop Error: " .. tostring(items))
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── [7] API PÚBLICA ──────────────────────────────────────────

function ItemFarm:Start()
	if self._running then return end
	self._running = true
	self._thread = task.spawn(function() self:_loop() end)
	Logger.Info("ItemFarm iniciado. Modo: Otimizado.")
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