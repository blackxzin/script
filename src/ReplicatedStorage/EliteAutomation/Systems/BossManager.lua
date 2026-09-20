-- ============================================================
--  Elite Automation Framework :: BossManager v2.1
--  Gerenciador de Inteligência de Combate e Eventos de Mundo
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root       = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger     = require(Root.Core.Logger)

local BossManager = {}
BossManager.__index = BossManager

-- ─── [1] CONSTANTES E UTILITÁRIOS ───────────────────────────

local function getValidRoot(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildOfClass("BasePart")
end

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function BossManager.new(combat, smartFlight, notifications, settings)
    local self = setmetatable({}, BossManager)

    self.Combat        = combat        -- CombatController
    self.SmartFlight   = smartFlight   -- SmartFlight
    self.Notifications = notifications
    self.Settings      = settings or {}
    self.ScanInterval  = self.Settings.ScanInterval or 2.0
    self.AttackRadius  = self.Settings.AttackRadius or 90

    self._timedTimestamps = {}     -- [bossName] = os.time()
    self._running         = false
    self._thread          = nil
    self._currentBoss     = nil    -- Boss alvo atual
    self._activeTasks     = {}     -- Gerenciamento de threads de combate

    return self
end

-- ─── [3] MOTOR DE BUSCA (Otimizado) ─────────────────────────

function BossManager:_findBoss(config)
    if not config or type(config.Name) ~= "string" or config.Name == "" then return nil end

    local names = {config.Name}
    if config.Aliases then
        for _, v in ipairs(config.Aliases) do table.insert(names, v) end
    end

    for _, name in ipairs(names) do
        -- Busca rápida no Workspace (Busca por nome com prefixo/sufixo)
        local model = workspace:FindFirstChild(name, true) 
        if model and model:IsA("Model") then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                return model
            end
        end
    end
    return nil
end

-- ─── [4] LÓGICA DE COMBATE E EVENTOS ────────────────────────

-- Gerencia o combate contra Bosses de Raid/Dungeon
function BossManager:_handleRaidBoss(config)
    if not config or type(config.Name) ~= "string" or config.Name == "" then
        Logger.Warn("Raid Boss ignorado: configuração sem Name.")
        return
    end

    Logger.Info("Raid Boss: Analisando " .. config.Name)
    
    local bossModel = self:_findBoss(config)
    if not bossModel then return end

    self._currentBoss = bossModel
    
    -- Notificação de Engajamento
    if self.Notifications then
        self.Notifications.Create(Players.LocalPlayer.PlayerGui, "⚔ RAID DETECTADA", 
            "Engajando: " .. config.Name, 5, Color3.fromRGB(255, 75, 75))
    end

    -- Loop de Combate da Raid
    while self._running and self._currentBoss == bossModel do
        local hum = bossModel:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or not bossModel.Parent then break end

        -- 1. Posicionamento Seguro (FlyTo)
        local bossRoot = getValidRoot(bossModel)
        if bossRoot and self.SmartFlight then
            self.SmartFlight:FlyTo(bossRoot.Position)
        end

        -- 2. Ativação do CombatController
        if self.Combat then
            self.Combat:SetTarget(bossModel)
        end

        task.wait(1)
    end

    if self.Combat then self.Combat:ClearTarget() end
    self._currentBoss = nil
    Logger.Success("Raid Boss " .. config.Name .. " derrotado ou sumiu.")
end

-- Gerencia Bosses de Mundo e Eventos de Mar
function BossManager:_handleWorldBoss(config)
    if not config or type(config.Name) ~= "string" or config.Name == "" then
        Logger.Warn("World Boss ignorado: configuração sem Name.")
        return
    end

    local name = config.Name
    local lastSeen = self._timedTimestamps[name] or 0
    
    -- Verifica Cooldown
    local cooldown = config.CooldownSecs or config.Cooldown or 1800
    if os.clock() - lastSeen < cooldown then return end

    local bossModel = self:_findBoss(config)
    if not bossModel then return end

    -- Validação de Região (Para Sea Events)
    if config.Region then
        local bossRoot = getValidRoot(bossModel)
        if bossRoot then
            local dist = (bossRoot.Position - config.Region.center).Magnitude
            if dist > config.Region.radius then return end
        end
    end

    self._currentBoss = bossModel

    Logger.Success("🌍 EVENTO DETECTADO: " .. name)

    -- Notificação de Spawn
    if self.Notifications then
        self.Notifications.Create(Players.LocalPlayer.PlayerGui, "🌊 EVENTO DE MUNDO", 
            "Boss: " .. name .. " detectado!", 6, Color3.fromRGB(0, 180, 255))
    end

    -- Loop de Combate do World Boss
    while self._running and self._currentBoss == bossModel do
        local hum = bossModel:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or not bossModel.Parent then break end

        -- Mantém altitude de segurança (Anti-Mar)
        local targetPos = bossModel.PrimaryPart and bossModel.PrimaryPart.Position or bossModel:GetPivot().Position
        if config.SafeAltitude then
            targetPos = Vector3.new(targetPos.X, config.SafeAltitude, targetPos.Z)
        end

        -- Movimentação e Combate
        if self.SmartFlight then
            self.SmartFlight:FlyTo(targetPos)
        end

        if self.Combat then
            self.Combat:SetTarget(bossModel)
        end

        task.wait(1)
    end

    if self.Combat then self.Combat:ClearTarget() end
    self._timedTimestamps[name] = os.clock()
    self._currentBoss = nil
end

-- ─── [5] LOOP PRINCIPAL ─────────────────────────────────────

function BossManager:_loop()
    while self._running do
        local ok, err = pcall(function()
            -- 1. Prioridade Máxima: Sea Events (Kraken, Sea Beast, etc)
            if self.Settings.LocationBosses then
                for _, bossCfg in pairs(self.Settings.LocationBosses) do
                    if not self._running then break end
                    self:_handleWorldBoss(bossCfg)
                end
            end

            -- 2. Prioridade Média: Timed Bosses (Mundo/Ilhas)
            if self.Settings.TimedBosses then
                for _, bossCfg in pairs(self.Settings.TimedBosses) do
                    if not self._running then break end
                    self:_handleWorldBoss(bossCfg)
                end
            end

            -- 3. Prioridade de Raid (Dungeons)
            if self.Settings.RaidBosses then
                for _, raidCfg in pairs(self.Settings.RaidBosses) do
                    if not self._running then break end
                    self:_handleRaidBoss(raidCfg)
                end
            end
        end)

        if not ok then
            Logger.Error("BossManager Loop Error: " .. tostring(err))
        end

        task.wait(self.ScanInterval)
    end
end

-- ─── [6] API PÚBLICA ─────────────────────────────────────────

function BossManager:Start()
    if self._running then return end
    self._running = true
    self._thread = task.spawn(function() self:_loop() end)
    Logger.Info("BossManager iniciado com sucesso.")
end

function BossManager:Stop()
    self._running = false
    if self._thread then
        task.cancel(self._thread)
        self._thread = nil
    end
    if self.Combat then self.Combat:ClearTarget() end
    self._currentBoss = nil
    Logger.Info("BossManager parado.")
end

function BossManager:GetCurrentBoss()
    return self._currentBoss
end

return BossManager
