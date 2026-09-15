-- ============================================================
--  Elite Automation Framework :: Systems.FruitTracker
--  Arquitetura de Rastreamento e Coleta Inteligente (GPO)
-- ============================================================

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root           = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger         = require(Root.Core.Logger)

local FruitTracker = {}
FruitTracker.__index = FruitTracker

-- ─── [1] CONFIGURAÇÕES E CONSTANTES ──────────────────────────

local FRUIT_SUFFIXES = { "_Fruit", "-Fruit", " Fruit", "Fruit", "" }
local SCAN_RETRY_DELAY = 1.5 -- Delay entre scans para evitar sobrecarga

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function FruitTracker.new(fruitDB, notificationModule, settings)
    local self = setmetatable({}, FruitTracker)

    self.DB              = fruitDB
    self.Notifications   = notificationModule
    self.ScanInterval    = (settings and settings.ScanInterval)   or SCAN_RETRY_DELAY
    self.AutoCollect     = (settings and settings.AutoCollect)     ~= false
    self.MinRarity       = (settings and settings.MinRarity)       or "Common"
    self.CollectRadius   = (settings and settings.CollectRadius)   or 5
    self.NotifyOnDetect  = (settings and settings.NotifyOnDetect)  ~= false

    self._running        = false
    self._thread         = nil
    self._knownFruits    = {}  -- Cache de modelos detectados
    self._smartFlight    = nil  -- Injetado para movimentação segura
    self._lastScanTime   = 0

    return self
end

-- ─── [3] MÉTODOS DE SUPORTE (Helpers) ────────────────────────

function FruitTracker:SetFlight(smartFlight)
    self._smartFlight = smartFlight
end

local function extractFruitName(modelName)
    for _, suffix in ipairs(FRUIT_SUFFIXES) do
        if suffix ~= "" and modelName:sub(-#suffix) == suffix then
            return modelName:sub(1, -(#suffix + 1))
        end
    end
    return modelName
end

local function getFruitPosition(fruitObj)
    if fruitObj:IsA("Model") then
        local primary = fruitObj.PrimaryPart or fruitObj:FindFirstChildOfClass("BasePart")
        return primary and primary.Position
    elseif fruitObj:IsA("BasePart") then
        return fruitObj.Position
    end
    return nil
end

-- ─── [4] LÓGICA DE DETECÇÃO E COLETA ─────────────────────────

-- Escaneia o ambiente de forma otimizada
function FruitTracker:_scan()
    local found = {}
    
    -- Em vez de GetDescendants em tudo, tentamos focar em objetos relevantes
    -- Se o jogo for muito grande, o ideal é filtrar por pastas conhecidas
    for _, obj in ipairs(workspace:GetChildren()) do -- Scan inicial em nível superior
        -- Se o objeto for muito complexo, podemos usar GetDescendants apenas em certos casos
        local descendants = obj:IsA("Model") and obj:GetDescendants() or {obj}
        
        for _, item in ipairs(descendants) do
            if item:IsA("Model") or item:IsA("BasePart") then
                local rawName   = item.Name
                local cleanName = extractFruitName(rawName)
                
                -- Validação de integridade do objeto
                local data = self.DB:Get(cleanName) or self.DB:Get(rawName)

                if data then
                    -- Verifica se a raridade atende ao filtro do usuário
                    if self.DB:MeetsMinRarity(cleanName, self.MinRarity) then
                        table.insert(found, {
                            model    = item,
                            name     = data.name or cleanName,
                            data     = data,
                        })
                    end
                end
            end
        end
    end

    return found
end

-- Coleta a fruta usando o SmartFlight para evitar detecção de teleporte
function FruitTracker:_collect(fruitEntry)
    if not self._smartFlight then
        Logger.Warn("FruitTracker: SmartFlight não injetado. Coleta abortada.")
        return
    end

    local pos = getFruitPosition(fruitEntry.model)
    if not pos then return end

    Logger.Info(string.format("Coletando [%s] %s...", fruitEntry.data.rarity, fruitEntry.name))

    -- 1. Voa até a fruta usando o sistema de voo seguro
    self._smartFlight:FlyTo(pos)

    -- 2. Aguarda proximidade e tenta a interação
    local localChar = Players.LocalPlayer.Character
    local root      = localChar and localChar:FindFirstChild("HumanoidRootPart")

    if root then
        local timeout = os.clock() + 12 -- Timeout de segurança
        while os.clock() < timeout do
            if not fruitEntry.model.Parent then break end -- Fruta sumiu (coletada)

            local currentPos = getFruitPosition(fruitEntry.model)
            if not currentPos then break end

            local dist = (currentPos - root.Position).Magnitude
            if dist <= self.CollectRadius then
                -- Tenta acionar ProximityPrompt (padrão GPO para itens)
                local prompt = fruitEntry.model:FindFirstChildOfClass("ProximityPrompt", true)
                if prompt and fireproximityprompt then
                    fireproximityprompt(prompt)
                end

                task.wait(0.2) -- Delay para garantir a interação
                break
            end
            task.wait(0.1)
        end
    end

    -- Limpa o cache para permitir nova detecção se o item respawnar
    self._knownFruits[fruitEntry.model] = nil
end

-- Processa a detecção de uma nova fruta
function FruitTracker:_onFruitDetected(entry)
    -- Evita processar a mesma instância múltiplas vezes
    if self._knownFruits[entry.model] then return end
    self._knownFruits[entry.model] = true

    -- 1. Notificação Visual (UI)
    if self.NotifyOnDetect and self.Notifications then
        local localPlayer = Players.LocalPlayer
        if localPlayer and localPlayer.PlayerGui then
            self.Notifications.Create(
                localPlayer.PlayerGui,
                "🍎 FRUTA DETECTADA",
                string.format("%s (%s)\nValor: %s Peli", 
                    entry.name, entry.data.rarity, tostring(entry.data.value)),
                5,
                entry.data.color
            )
        end
    end

    -- 2. Log de Sistema
    Logger.Success(string.format("Detectada: %s [%s]", entry.name, entry.data.rarity))

    -- 3. Auto-Collection (Se habilitado)
    if self.AutoCollect then
        task.spawn(function()
            self:_collect(entry)
        end)
    end
end

-- ─── [5] LOOP PRINCIPAL (Thread de Execução) ──────────────────

function FruitTracker:_loop()
    while self._running do
        local ok, fruits = pcall(function()
            return self:_scan()
        end)

        if ok and fruits then
            for _, entry in ipairs(fruits) do
                if not self._running then break end
                self:_onFruitDetected(entry)
            end
        else
            if not ok then
                Logger.Error("FruitTracker Scan Error: " .. tostring(fruits))
            end
        end

        task.wait(self.ScanInterval)
    end
end

-- ─── [6] API PÚBLICA ──────────────────────────────────────────

function FruitTracker:Start()
    if self._running then return end
    self._running = true
    self._thread = task.spawn(function() self:_loop() end)
    Logger.Info("FruitTracker (GPO) iniciado.")
end

function FruitTracker:Stop()
    self._running = false
    if self._thread then
        task.cancel(self._thread)
        self._thread = nil
    end
    Logger.Info("FruitTracker parado.")
end

function FruitTracker:SetAutoCollect(enabled)
    self.AutoCollect = enabled
    Logger.Info("AutoCollect: " .. (enabled and "ON" or "OFF"))
end

function FruitTracker:SetMinRarity(rarity)
    self.MinRarity = rarity
    Logger.Info("MinRarity alterada para: " .. rarity)
end

function FruitTracker:GetKnownCount()
    local count = 0
    for _ in pairs(self._knownFruits) do count = count + 1 end
    return count
end

return FruitTracker