-- ============================================================
--  Elite Automation Framework :: Systems.MerchantTracker
--  Arquitetura de Monitoramento de Ciclo e Spawn de Eventos
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root       = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger     = require(Root.Core.Logger)

local MerchantTracker = {}
MerchantTracker.__index = MerchantTracker

-- ─── [1] CONFIGURAÇÕES E CONSTANTES ──────────────────────────

local MERCHANT_NAMES = {
    "Traveling Merchant",
    "TravelingMerchant",
    "Wandering Merchant",
    "Merchant",
}

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function MerchantTracker.new(notifications, settings)
    local self = setmetatable({}, MerchantTracker)

    self.Notifications = notifications
    self.Settings      = settings or {}
    self.ScanInterval  = self.Settings.ScanInterval or 2.0
    
    -- Mapeamento de Ilhas (Coordenadas de Referência)
    self.KnownIslands  = {
        ["Town of Beginnings"] = Vector3.new(1100, 15, 1200),
        ["Sandora"]            = Vector3.new(-1100, 15, 1400),
        ["Shells Town"]        = Vector3.new(-3800, 15, -4200),
        ["Orange Town"]        = Vector3.new(-800, 15, 800),
        ["Baratie"]            = Vector3.new(-3100, 10, 4800),
        ["Sphinx Island"]      = Vector3.new(-6500, 30, -2100),
        ["Shark Park"]         = Vector3.new(1200, 15, -3400),
        ["Kori Island"]        = Vector3.new(2200, 15, 1800),
        ["Land of the Sky"]    = Vector3.new(-1200, 450, 6000),
        ["Gravito's Fort"]     = Vector3.new(2800, 80, -3200),
        ["Fishman Island"]     = Vector3.new(7200, -300, 1100),
        ["Desert Kingdom"]     = Vector3.new(-1200, 20, -3000),
        ["Sashi Island"]       = Vector3.new(4100, 25, -1500),
        ["Rovo Island"]        = Vector3.new(-2500, 20, 3800),
        ["Spirit Island"]      = Vector3.new(3200, 30, 4500),
        ["Foro Island"]        = Vector3.new(-4800, 20, 1100),
        ["Umi Island"]         = Vector3.new(5200, 20, -4200),
        ["Colosseum of Arc"]   = Vector3.new(-600, 25, 5200),
        ["Thriller Bark"]      = Vector3.new(-5400, 80, -7800),
        ["Rose Kingdom"]       = Vector3.new(450, 120, -180),
    }
    for islandName, islandPosition in pairs(self.Settings.KnownIslands or {}) do
        if typeof(islandPosition) == "Vector3" then
            self.KnownIslands[islandName] = islandPosition
        end
    end

    self._running        = false
    self._thread         = nil
    self._currentMerchant = nil  -- { model, position, island, spawnTime }
    self._smartFlight    = nil
    self._lastState      = false
    self._lastFly        = 0
    self.FirstSpawnDelay = self.Settings.FirstSpawnDelay or 600
    self.ActiveDuration  = self.Settings.ActiveDuration or 600
    self.CycleDuration   = self.Settings.CycleDuration or 1800

    return self
end

-- ─── [3] MÉTODOS DE BUSCA E CÁLCULO ─────────────────────────

-- Identifica a ilha mais próxima baseada na distância euclidiana
function MerchantTracker:_identifyIsland(pos)
    local bestIsland, bestDist = "Desconhecida", math.huge
    for islandName, islandPos in pairs(self.KnownIslands) do
        local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(islandPos.X, 0, islandPos.Z)).Magnitude
        if d < bestDist then
            bestDist   = d
            bestIsland = islandName
        end
    end
    return bestIsland, bestDist
end

-- Busca o modelo do mercador no workspace (Otimizada)
function MerchantTracker:_findMerchant()
    for _, name in ipairs(MERCHANT_NAMES) do
        local model = workspace:FindFirstChild(name, true)
        if model and model:IsA("Model") then
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildOfClass("BasePart")
            if root then return model, root.Position end
        end
    end

    -- Fallback: Busca por string parcial para variações de nome
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("merchant", 1, true) then
            local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("BasePart")
            if root then return obj, root.Position end
        end
    end

    return nil, nil
end

-- ─── [4] LÓGICA DE CICLO E TEMPO ────────────────────────────

-- Calcula o ciclo de vida baseado no uptime do servidor
function MerchantTracker:GetSchedule()
    local uptime = workspace.DistributedGameTime or 0

    -- Ciclo: Spawn em 10m, Ativo por 10m, Cooldown de 30m
    if uptime < self.FirstSpawnDelay then
        local timeToFirst = math.ceil(self.FirstSpawnDelay - uptime)
        return {
            Status = "WAITING",
            SecondsLeft = timeToFirst,
            DisplayText = string.format("1º Spawn em: %02d:%02d", math.floor(timeToFirst / 60), timeToFirst % 60),
            IsActive = false
        }
    end

    local cycleElapsed = (uptime - self.FirstSpawnDelay) % self.CycleDuration
    if cycleElapsed < self.ActiveDuration then
        local despawnIn = math.ceil(self.ActiveDuration - cycleElapsed)
        return {
            Status = "ACTIVE",
            SecondsLeft = despawnIn,
            DisplayText = string.format("MERCADOR ATIVO! Despawn em: %02d:%02d", math.floor(despawnIn / 60), despawnIn % 60),
            IsActive = true
        }
    else
        local nextIn = math.ceil(self.CycleDuration - cycleElapsed)
        return {
            Status = "WAITING",
            SecondsLeft = nextIn,
            DisplayText = string.format("Próximo spawn em: %02d:%02d", math.floor(nextIn / 60), nextIn % 60),
            IsActive = false
        }
    end
end

-- ─── [5] LOOP PRINCIPAL E EXECUÇÃO ──────────────────────────

function MerchantTracker:_loop()
    while self._running do
        local ok, err = pcall(function()
            local model, pos = self:_findMerchant()

            if model and pos then
                if not self._lastState then
                    -- Novo Spawn Detectado
                    self._lastState = true
                    local islandName, _ = self:_identifyIsland(pos)

                    self._currentMerchant = {
                        model = model,
                        position = pos,
                        island = islandName,
                        spawnTime = os.clock()
                    }

                    if self.Settings.NotifyOnSpawn ~= false and self.Notifications then
                        local lp = Players.LocalPlayer
                        if lp and lp.PlayerGui then
                            self.Notifications.Create(lp.PlayerGui, "🛒 MERCADOR DETECTADO", 
                                "O Mercador spawnou em " .. islandName .. "!", 8, Color3.fromRGB(255, 215, 0))
                        end
                    end

                    if self.OnMerchantSpawned then self.OnMerchantSpawned(self._currentMerchant) end
                else
                    -- Atualiza posição se o modelo se moveu
                    self._currentMerchant.position = pos
                end
            else
                if self._lastState then
                    -- Despawn Detectado
                    self._lastState = false
                    self._currentMerchant = nil
                    if self.OnMerchantDespawned then self.OnMerchantDespawned() end
                    Logger.Warn("🛒 Mercador Viajante despawnou.")
                end
            end
        end)

        if not ok then Logger.Error("MerchantTracker Loop Error: " .. tostring(err)) end
        task.wait(self.ScanInterval)
    end
end

-- ─── [6] API PÚBLICA ─────────────────────────────────────────

function MerchantTracker:SetFlight(smartFlight)
    self._smartFlight = smartFlight
end

function MerchantTracker:FlyToMerchant()
    -- Atualiza o cache antes do voo para não seguir uma posição antiga.
    local model, position = self:_findMerchant()
    if model and position then
        local islandName = self:_identifyIsland(position)
        self._currentMerchant = self._currentMerchant or { spawnTime = os.clock() }
        self._currentMerchant.model = model
        self._currentMerchant.position = position
        self._currentMerchant.island = islandName
    end

    local now = os.clock()
    if not self._currentMerchant or not self._currentMerchant.position
        or not self._currentMerchant.model or not self._currentMerchant.model.Parent then
        Logger.Warn("MerchantTracker: Mercador não está ativo.")
        return false
    end

    -- Anti-Spam de Clique
    if (now - self._lastFly) < 5 then return false end
    self._lastFly = now

    local targetPos = self._currentMerchant.position + Vector3.new(0, 4, 0)
    
    -- Validação de Coordenadas (Anti-NaN)
    if targetPos.X ~= targetPos.X or targetPos.Y ~= targetPos.Y or targetPos.Z ~= targetPos.Z
        or math.abs(targetPos.X) > 1e5 or math.abs(targetPos.Y) > 1e5 or math.abs(targetPos.Z) > 1e5 then
        return false
    end

    if not self._smartFlight then
        Logger.Warn("MerchantTracker: SmartFlight não configurado.")
        return false
    end

    Logger.Info("Voando para o Mercador em: " .. self._currentMerchant.island)
    if not self._smartFlight:FlyTo(targetPos) then
        Logger.Warn("MerchantTracker: voo até o Mercador foi interrompido.")
        return false
    end
    return true
end

function MerchantTracker:Start()
    if self._running then return end
    self._running = true
    self._thread = task.spawn(function() self:_loop() end)
    Logger.Info("MerchantTracker iniciado.")
end

function MerchantTracker:Stop()
    self._running = false
    if self._thread then
        task.cancel(self._thread)
        self._thread = nil
    end
    self._currentMerchant = nil
    self._lastState = false
    Logger.Info("MerchantTracker parado.")
end

function MerchantTracker:IsActive()
    return self._currentMerchant ~= nil
end

function MerchantTracker:GetMerchant()
    return self._currentMerchant
end

return MerchantTracker
