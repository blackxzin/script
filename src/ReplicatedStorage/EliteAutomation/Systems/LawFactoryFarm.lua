-- ============================================================
--  Elite Automation Framework :: Systems.LawFactoryFarm
--  Arquitetura de Raid Especializada (Law & Factory)
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root       = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger     = require(Root.Core.Logger)

local LawFactoryFarm = {}
LawFactoryFarm.__index = LawFactoryFarm

-- ─── [1] CONFIGURAÇÕES E CONSTANTES ──────────────────────────

local CYBORG_KEYS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
local CYBORG_CD   = { [Enum.KeyCode.Z] = 6, [Enum.KeyCode.X] = 9, [Enum.KeyCode.C] = 12, [Enum.KeyCode.V] = 18 }

local LAW_NAMES = { "Law", "Trafalgar Law", "Order", "Boss Order" }
local CORE_NAMES = { "Slime Core", "SlimeCore", "Core", "Factory Core", "FactoryCore" }
local RAID_POD_NAMES = { "Raid Pod", "Start Raid", "RaidButton", "LaboratoryPod", "FactoryDoor" }

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function LawFactoryFarm.new(combat, smartFlight, notifications, settings)
    local self = setmetatable({}, LawFactoryFarm)

    self.Combat        = combat
    self.SmartFlight   = smartFlight
    self.Notifications = notifications
    self.Settings      = settings or {}

    -- Configurações Factory
    local fCfg = (self.Settings.Factory or {})
    self.FactoryLocation   = fCfg.Location or Vector3.new(450, 120, -180)
    self.CoreHoverHeight   = fCfg.CoreHoverHeight or 14
    self.MinLavaAltitude   = fCfg.MinLavaAltitude or 135

    -- Configurações Law
    local lCfg = (self.Settings.Law or {})
    self.LawLocation       = lCfg.Location or Vector3.new(450, 145, -180)
    self.LawCombatHeight   = lCfg.CombatHeight or 14
    self.ShamblesThreshold = lCfg.ShamblesThreshold or 25
    self.AutoStartRaid     = lCfg.AutoStartRaid ~= false
    self.UseCyborgSkills   = lCfg.UseCyborgSkills ~= false

    -- Estado Interno
    self._lastSkill      = 0
    self._skillIdx       = 1
    self._skillTimes     = {}
    self._lastNavigation = { Factory = 0, Law = 0 }
    self._running        = false
    self._thread         = nil
    self._activeThreads  = {} -- Para gerenciar loops de segurança

    -- Status para UI
    self.FactoryEnabled  = false
    self.LawEnabled      = false
    self.FactoryStatus   = "Desativado"
    self.LawStatus       = "Desativado"
    self.CurrentStage    = "Aguardando"

    return self
end

-- ─── [3] MÉTODOS DE SUPORTE (Helpers) ───────────────────────

function LawFactoryFarm:_findModel(namesList, requireHumanoid)
    requireHumanoid = requireHumanoid ~= false
    for _, name in ipairs(namesList) do
        local model = workspace:FindFirstChild(name, true)
        if model and (model:IsA("Model") or model:IsA("BasePart")) then
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildOfClass("BasePart")
            local hum = model:FindFirstChildOfClass("Humanoid")
            if model:IsA("BasePart") then root = model end
            if root and (not requireHumanoid or (hum and hum.Health > 0)) then
                return model, root, hum
            end
        end
    end
    return nil
end

function LawFactoryFarm:_detectLava()
    local lava = workspace:FindFirstChild("Lava", true) or workspace:FindFirstChild("RisingLava", true)
    if lava and lava:IsA("BasePart") then
        return lava.Position.Y
    end
    return -math.huge
end

function LawFactoryFarm:_shouldNavigate(key)
    local now = os.clock()
    if now - (self._lastNavigation[key] or 0) < 8 then return false end
    self._lastNavigation[key] = now
    return true
end

function LawFactoryFarm:_goToConfiguredLocation(key, position)
    if not self.SmartFlight or not position or not self:_shouldNavigate(key) then return false end
    return self.SmartFlight:FlyTo(position)
end

-- ─── [4] LÓGICA DE COMBATE AVANÇADO ─────────────────────────

function LawFactoryFarm:_cyborgTick()
    if not self.UseCyborgSkills then return end
    local now = os.clock()
    if (now - self._lastSkill) < 4 then return end

    local key = CYBORG_KEYS[self._skillIdx]
    local cd = CYBORG_CD[key] or 8

    if (now - (self._skillTimes[key] or 0)) < cd then return end

    self._skillTimes[key] = now
    self._lastSkill = now
    self._skillIdx = (self._skillIdx % #CYBORG_KEYS) + 1

    local ok, vim = pcall(function()
        return game:GetService("VirtualInputManager")
    end)
    if ok and vim then
        pcall(function()
            vim:SendKeyEvent(true, key, false, game)
            task.wait(0.05)
            vim:SendKeyEvent(false, key, false, game)
        end)
    end
end

-- ─── [5] ROTINAS DE FARM (Factory & Law) ────────────────────

-- Rotina de Farm da Factory (Core)
function LawFactoryFarm:_handleFactory()
    local coreModel, corePart = self:_findModel(CORE_NAMES, false)
    if not coreModel then
        self.FactoryStatus = "Indo para Factory / aguardando Core..."
        self:_goToConfiguredLocation("Factory", self.FactoryLocation)
        if self.AutoStartRaid then self:_startRaid() end
        return
    end

    -- Verifica se o Law ainda está presente (Impedindo o Core de ser atacado antes da hora)
    local lawModel, _, lawHum = self:_findModel(LAW_NAMES)
    if lawModel and lawHum and lawHum.Health > 0 then
        self.CurrentStage = "Estágio 4: Boss Law"
        self.FactoryStatus = "Eliminando Law primeiro..."
        self:_handleLaw()
        return
    end

    self.FactoryStatus = "Destruindo Core!"
    local lavaY = self:_detectLava()
    local safeY = math.max(corePart.Position.Y + self.CoreHoverHeight, lavaY + 20, self.MinLavaAltitude)
    local targetPos = Vector3.new(corePart.Position.X, safeY, corePart.Position.Z)

    -- Movimentação e Combate
    if self.SmartFlight then self.SmartFlight:FlyTo(targetPos) end
    if self.Combat then self.Combat:SetTarget(coreModel) end

    -- Loop de Dano no Core
    local timeout = os.clock() + 300
    while self.FactoryEnabled and os.clock() < timeout do
        local hum = coreModel:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or not coreModel.Parent then break end

        -- Re-ajuste de altura para evitar lava
        local currentLava = self:_detectLava()
        if currentLava > (targetPos.Y - 10) then
            -- Re-calcula posição segura
            local newSafeY = math.max(currentLava + 20, self.MinLavaAltitude)
            self.SmartFlight:FlyTo(Vector3.new(targetPos.X, newSafeY, targetPos.Z))
        end

        task.wait(0.5)
    end

    self.FactoryStatus = "Concluído"
    self.Combat:ClearTarget()
end

-- Rotina de Combate contra o Boss Law
function LawFactoryFarm:_handleLaw()
    local lawModel, lawRoot, lawHum = self:_findModel(LAW_NAMES)
    if not lawModel or not lawRoot then
        -- Tenta iniciar a Raid se configurado
        self.LawStatus = "Indo para Law / aguardando spawn..."
        self:_goToConfiguredLocation("Law", self.LawLocation)
        if self.AutoStartRaid then
            self:_startRaid()
        end
        return
    end

    self.LawStatus = "Combatendo Law"
    
    -- Loop de Combate Aéreo
    local timeout = os.clock() + 450
    while self.LawEnabled and os.clock() < timeout do
        local currentLawRoot = lawModel:FindFirstChild("HumanoidRootPart")
            or lawModel:FindFirstChildOfClass("BasePart")
        if not currentLawRoot or not lawHum or lawHum.Health <= 0 then break end

        local playerChar = Players.LocalPlayer.Character
        local playerRoot = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
        
        if playerRoot then
            local dist = (playerRoot.Position - currentLawRoot.Position).Magnitude
            local idealPos = currentLawRoot.Position + Vector3.new(0, self.LawCombatHeight, 0)

            -- Anti-Shambles: Se o Law teleportar o player, volta imediatamente para cima dele
            if dist > self.ShamblesThreshold then
                self.SmartFlight:FlyTo(idealPos)
            elseif (playerRoot.Position - idealPos).Magnitude > 15 then
                self.SmartFlight:FlyTo(idealPos)
            end
        end

        if self.Combat then self.Combat:SetTarget(lawModel) end
        
        self._cyborgTick()
        task.wait(0.3)
    end

    self.LawStatus = "Desativado"
end

-- ─── [6] MÉTODOS DE SUPORTE E API ───────────────────────────

function LawFactoryFarm:_startRaid()
    local terminal
    for _, name in ipairs(RAID_POD_NAMES) do
        terminal = workspace:FindFirstChild(name, true)
        if terminal then break end
    end

    if not terminal then
        Logger.Debug("Terminal de raid ainda não encontrado.")
        return false
    end

    local part = terminal:IsA("BasePart") and terminal or terminal:FindFirstChild("HumanoidRootPart")
        or terminal:FindFirstChildOfClass("BasePart")
    if part and self.SmartFlight then
        self.SmartFlight:FlyTo(part.Position + Vector3.new(0, 3, 0))
    end

    local prompt = terminal:FindFirstChildOfClass("ProximityPrompt", true)
    if prompt and fireproximityprompt then
        local ok = pcall(function() fireproximityprompt(prompt) end)
        if ok then
            Logger.Info("Terminal de raid acionado por ProximityPrompt.")
            return true
        end
    end

    local detector = terminal:FindFirstChildOfClass("ClickDetector", true)
    if detector and fireclickdetector then
        local ok = pcall(function() fireclickdetector(detector) end)
        if ok then
            Logger.Info("Terminal de raid acionado por ClickDetector.")
            return true
        end
    end

    Logger.Debug("Terminal encontrado, mas sem interação compatível.")
    return false
end

function LawFactoryFarm:_loop()
    while self._running do
        local ok, err = pcall(function()
            if self.FactoryEnabled then self:_handleFactory() end
            if self.LawEnabled then self:_handleLaw() end
        end)

        if not ok then Logger.Error("LawFarm Loop Error: " .. tostring(err)) end
        task.wait(2)
    end
end

-- API Pública
function LawFactoryFarm:Start()
    if self._running then return end
    self._running = true
    self._thread = task.spawn(function() self:_loop() end)
    Logger.Info("LawFarm Engine Ativa.")
end

function LawFactoryFarm:Stop()
    self._running = false
    if self._thread then
        task.cancel(self._thread)
        self._thread = nil
    end
    self.FactoryEnabled = false
    self.LawEnabled = false
    self.LawStatus = "Desativado"
    self.FactoryStatus = "Desativado"
    Logger.Info("LawFarm Engine Parada.")
end

function LawFactoryFarm:SetFactoryEnabled(enabled)
    self.FactoryEnabled = enabled
    if enabled then
        self:Start()
    elseif not self.LawEnabled then
        self:Stop()
    end
    Logger.Info("Factory Farm: " .. (enabled and "ON" or "OFF"))
end

function LawFactoryFarm:SetLawEnabled(enabled)
    self.LawEnabled = enabled
    if enabled then
        self:Start()
    elseif not self.FactoryEnabled then
        self:Stop()
    end
    Logger.Info("Law Farm: " .. (enabled and "ON" or "OFF"))
end

function LawFactoryFarm:SetCyborgSkills(enabled)
    self.UseCyborgSkills = enabled
    Logger.Info("Cyborg Skills: " .. (enabled and "ON" or "OFF"))
end

return LawFactoryFarm
