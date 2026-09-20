-- ============================================================
--  Elite Automation Framework :: Systems.FarmRotation
--  Arquitetura de Otimização de Lucro (XP/Min) e Eficiência
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local FarmRotation = {}
FarmRotation.__index = FarmRotation

-- ─── [1] DATABASE DE BOSSES (Otimizada) ─────────────────────
-- Nota: A ordem aqui é baseada em prioridade de eficiência inicial
local BOSS_DATABASE = {
    -- First Sea
    { Name = "Bandit Boss", Location = Vector3.new(1050, 18, 1220), Level = 5, HP = 800, RespawnTime = 300, ExpReward = 250, PeliReward = 2000, DropRate = 0.05, KillTime = 60, Priority = 3 },
    { Name = "Lucid", Location = Vector3.new(-1150, 18, 1420), Level = 15, HP = 2000, RespawnTime = 600, ExpReward = 800, PeliReward = 5000, DropRate = 0.05, KillTime = 90, Priority = 4 },
    { Name = "Axe Hand Logan", Location = Vector3.new(-3800, 20, -4200), Level = 25, HP = 3000, RespawnTime = 900, ExpReward = 1200, PeliReward = 8000, DropRate = 0.05, KillTime = 120, Priority = 5 },
    { Name = "Gravito", Location = Vector3.new(2800, 80, -3200), Level = 100, HP = 3600, RespawnTime = 720, ExpReward = 3500, PeliReward = 15000, DropRate = 0.02, KillTime = 180, Priority = 8 },
    { Name = "Enel", Location = Vector3.new(-1200, 450, 6000), Level = 150, HP = 5000, RespawnTime = 2700, ExpReward = 8000, PeliReward = 45000, DropRate = 0.05, KillTime = 240, Priority = 9 },
    { Name = "Neptune", Location = Vector3.new(7200, -300, 1100), Level = 180, HP = 6000, RespawnTime = 2400, ExpReward = 9000, PeliReward = 38000, DropRate = 0.15, KillTime = 300, Priority = 8 },

    -- Second Sea
    { Name = "Ryuma", Location = Vector3.new(-5400, 120, -7800), Level = 350, HP = 8000, RespawnTime = 1800, ExpReward = 15000, PeliReward = 35000, DropRate = 0.01, KillTime = 360, Priority = 10 },
    { Name = "Law", Location = Vector3.new(-4716, 28, 1263), Level = 400, HP = 10000, RespawnTime = 3600, ExpReward = 25000, PeliReward = 70000, DropRate = 0.005, KillTime = 450, Priority = 10 },
}

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function FarmRotation.new(combat, movement, notifications)
    local self = setmetatable({}, FarmRotation)

    self.Combat = combat
    self.Movement = movement
    self.Notifications = notifications

    self.Enabled = false
    self._thread = nil
    self._bossTimers = {}  -- [bossName] = timestamp de morte
    self._currentRoute = {}
    self._playerLevel = 1

    return self
end

-- ─── [3] LÓGICA DE CÁLCULO (Eficiência e Prioridade) ──────────

-- Calcula o Score de Eficiência (XP + Peli por Minuto)
function FarmRotation:_calculateEfficiency(boss)
    local totalCycleTime = boss.KillTime + boss.RespawnTime
    
    -- Peso: XP (70%) + Peli (30%)
    local expScore = (boss.ExpReward / totalCycleTime) * 60
    local peliScore = (boss.PeliReward * boss.DropRate / totalCycleTime) * 60
    
    return (expScore * 0.7) + (peliScore * 0.3)
end

-- Verifica o nível do jogador para evitar bosses muito difíceis
function FarmRotation:_updatePlayerLevel()
    local lp = Players.LocalPlayer
    if lp then
        local ls = lp:FindFirstChild("leaderstats")
        if ls then
            local lvl = ls:FindFirstChild("Level")
            if lvl then self._playerLevel = lvl.Value end
        end
    end
end

-- ─── [4] GESTÃO DE ROTA (Otimização de Caminho) ───────────────

function FarmRotation:_buildRoute()
    self:_updatePlayerLevel()
    local availableBosses = {}

    for _, boss in ipairs(BOSS_DATABASE) do
        -- Filtro de Nível e Cooldown
        local isLevelOk = boss.Level <= (self._playerLevel + 40)
        local lastKill = self._bossTimers[boss.Name] or 0
        local isCooldownDone = (os.clock() - lastKill) >= boss.RespawnTime

        if isLevelOk and isCooldownDone then
            local efficiency = self:_calculateEfficiency(boss)
            table.insert(availableBosses, {
                Data = boss,
                Score = efficiency,
                Priority = boss.Priority
            })
        end
    end

    -- Ordenação: Prioridade (Peso Alto) + Eficiência (Score)
    table.sort(availableBosses, function(a, b)
        return (a.Priority * 10 + a.Score) > (b.Priority * 10 + b.Score)
    end)

    return availableBosses
end

-- ─── [5] EXECUÇÃO DO FARM (Loop de Combate) ──────────────────

function FarmRotation:_farmBoss(bossData)
    local boss = bossData.Data
    
    -- 1. Notificação de Início
    if self.Notifications then
        -- (Simulação de chamada de notificação)
        Logger.Info("Iniciando Farm: " .. boss.Name)
    end

    -- 2. Deslocamento Seguro
    if self.Movement then
        self.Movement:FlyTo(boss.Location)
    end
    
    task.wait(2) -- Delay de estabilização de voo

    -- 3. Busca do Modelo no Mundo
    local bossModel = workspace:FindFirstChild(boss.Name, true)
    if not bossModel then
        Logger.Warn("Boss " .. boss.Name .. " não encontrado no spawn!")
        return false
    end

    -- 4. Engajamento de Combate
    if self.Combat then
        self.Combat:SetTarget(bossModel)
    end

    -- 5. Monitoramento de Morte/Timeout
    local timeout = os.clock() + boss.KillTime + 60
    local killed = false

    while os.clock() < timeout and self.Enabled do
        local hum = bossModel:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or not bossModel.Parent then
            killed = true
            break
        end
        task.wait(1)
    end

    -- 6. Registro de Resultado
    if killed then
        self._bossTimers[boss.Name] = os.clock()
        Logger.Success("Boss Eliminado: " .. boss.Name)
    else
        Logger.Warn("Timeout ou Boss Despawnado: " .. boss.Name)
    end

    -- Limpeza de Estado
    if self.Combat then self.Combat:ClearTarget() end
    return killed
end

-- ─── [6] LOOP PRINCIPAL (Thread de Execução) ──────────────────

function FarmRotation:_loop()
    while self.Enabled do
        local route = self:_buildRoute()
        self._currentRoute = route

        if #route == 0 then
            Logger.Debug("Nenhum boss disponível na rota atual. Aguardando...")
            task.wait(10)
        else
            -- Itera pela rota otimizada
            for _, target in ipairs(route) do
                if not self.Enabled then break end

                local bossData = target.Data
                Logger.Info("Próximo alvo da rota: " .. bossData.Name)

                -- Executa o ciclo de farm
                self:_farmBoss(target)

                -- Delay entre bosses para evitar spam de requests
                task.wait(3)
            end

            task.wait(5)
        end
    end
end

-- ─── [7] API PÚBLICA ──────────────────────────────────────────

function FarmRotation:Start()
    if self.Enabled then return end
    self.Enabled = true
    self._thread = task.spawn(function() self:_loop() end)
    Logger.Info("FarmRotation: Sistema Ativado.")
end

function FarmRotation:Stop()
    self.Enabled = false
    if self._thread then
        task.cancel(self._thread)
        self._thread = nil
    end
    self._currentRoute = {}
    Logger.Info("FarmRotation: Sistema Desativado.")
end

function FarmRotation:GetCurrentRoute()
    return self._currentRoute
end

return FarmRotation
