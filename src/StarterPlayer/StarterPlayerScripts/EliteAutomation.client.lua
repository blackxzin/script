-- ============================================================
--  Elite Automation Framework v2.1 - MAIN INTEGRATOR
--  O Maestro: Gerencia o ciclo de vida e a conexão UI <-> Sistemas
-- ============================================================

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")

local localPlayer        = Players.LocalPlayer
local character          = localPlayer.Character or localPlayer.CharacterAdded:Wait()

-- 1. BUSCA DO ROOT (Proteção contra carregamento incompleto)
local Root = ReplicatedStorage:WaitForChild("EliteAutomation", 20)
if not Root then
    warn("[EliteAutomation] Erro: Root não encontrado no ReplicatedStorage!")
    return
end

-- 2. IMPORTAÇÃO DOS MÓDULOS (Ordem de Dependência)
-- Core primeiro
local Logger         = require(Root.Core.Logger)
local TaskManager    = require(Root.Core.TaskManager)
local StateMachine   = require(Root.Core.StateMachine)
local PriorityManager = require(Root.Core.PriorityManager)
local Settings       = require(Root.Config.Settings)

-- Sistemas de Movimento e Combate (Base para outros sistemas)
local SmartFlight    = require(Root.Movement.SmartFlight)
local CombatController = require(Root.Combat.CombatController)
local TargetSelector   = require(Root.Combat.TargetSelector)

-- Sistemas de Mundo (Dependem de Combate e Movimento)
local FruitDatabase   = require(Root.Systems.FruitDatabase)
local FruitTracker    = require(Root.Systems.FruitTracker)
local BossManager     = require(Root.Systems.BossManager)
local ItemFarm        = require(Root.Systems.ItemFarm)
local MerchantTracker = require(Root.Systems.MerchantTracker)
local LawFactoryFarm  = require(Root.Systems.LawFactoryFarm)
local AntiAFK         = require(Root.Systems.AntiAFK)
local FarmRotation    = require(Root.Systems.FarmRotation)
local QuestManager    = require(Root.Systems.QuestManager)
local AutoHeal        = require(Root.Systems.AutoHeal)
local AutoStats       = require(Root.Systems.AutoStats)
local ESP             = require(Root.Systems.ESP)
local TeleportManager = require(Root.Systems.TeleportManager)
local AdaptiveBrain   = require(Root.Systems.AdaptiveBrain)
local KickTelemetry   = require(Root.Systems.KickTelemetry)

-- Interface (UI)
local MainUI       = require(Root.UI.MainUI)
local TabManager   = require(Root.UI.TabManager)
local Components   = require(Root.UI.Components)
local Notifications = require(Root.UI.Notifications)

-- ============================================================
-- INICIALIZAÇÃO DO MOTOR (ENGINE SETUP)
-- ============================================================

Logger.Info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Logger.Info("  Elite Automation Framework v2.1")
Logger.Info("  Iniciando Engine de Automação...")
Logger.Info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Gerenciador de tarefas (O coração do controle)
local manager = TaskManager.new()
local taskToggles = {}
local FARM_TASKS = {"BossFarm", "FarmRotation", "QuestFarm", "FruitTracker", "ItemFarm", "FactoryFarm", "LawFarm"}

local function stopConflictingFarms(activeName)
    local raidTask = activeName == "FactoryFarm" or activeName == "LawFarm"
    for _, name in ipairs(FARM_TASKS) do
        local sameRaidEngine = raidTask and (name == "FactoryFarm" or name == "LawFarm")
        if name ~= activeName and not sameRaidEngine and manager:IsEnabled(name) then
            manager:SetEnabled(name, false)
            local toggle = taskToggles[name]
            if toggle then toggle.SetEnabled(false) end
            Logger.Warn("Farm interrompido para evitar conflito: " .. name)
        end
    end
end

-- Inicialização do Personagem e Movimento
local smartFlight = SmartFlight.new(character, Settings.Movement)
local characterConnection = localPlayer.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    smartFlight:SetCharacter(newCharacter)
    Logger.Info("Personagem atualizado após respawn.")
end)

-- Inicialização do Combate
local combatController = CombatController.new(Settings.Combat)
combatController:SetFlight(smartFlight)

-- Inicialização dos Sistemas de Farm
local fruitTracker = FruitTracker.new(FruitDatabase, Notifications, Settings.FruitTracker)
fruitTracker:SetFlight(smartFlight)
fruitTracker:SetAutoCollect(false) -- Controlado via UI

local bossManager = BossManager.new(combatController, smartFlight, Notifications, Settings.BossManager)
local itemFarm = ItemFarm.new(smartFlight, Notifications, Settings.ItemFarm)
local merchantTracker = MerchantTracker.new(Notifications, Settings.MerchantTracker)
merchantTracker:SetFlight(smartFlight)
local lawFactoryFarm = LawFactoryFarm.new(combatController, smartFlight, Notifications, Settings.LawFactoryFarm)
local antiAFK = AntiAFK.new()
antiAFK:SetMovementGuard(function()
    for _, name in ipairs(FARM_TASKS) do
        if manager:IsEnabled(name) then return true end
    end
    return false
end)
local farmRotation = FarmRotation.new(combatController, smartFlight, Notifications)
local questManager = QuestManager.new(combatController, smartFlight, Notifications, Settings)
local autoHeal = AutoHeal.new()
local autoStats = AutoStats.new("Hybrid", Notifications)
local esp = ESP.new()
local teleportManager = TeleportManager.new(smartFlight, Notifications)

-- Inicialização da Inteligência e Segurança
local adaptiveBrain = AdaptiveBrain.new(combatController, smartFlight, bossManager, lawFactoryFarm)
adaptiveBrain:Start()

local kickLog = KickTelemetry.new(Notifications)
kickLog:BindManager(manager)
kickLog:Start()

-- 3. CONFIGURAÇÃO DE CALLBACKS (Onde a mágica acontece)
-- Conectando o combate aos eventos de telemetria
combatController.OnTargetFound = function(model)
    kickLog:Event("target", model.Name)
    Logger.Info("Alvo detectado: " .. model.Name)
end

combatController.OnFlee = function()
    Logger.Warn("HP Crítico! Iniciando protocolo de fuga.")
    Notifications.Create(localPlayer.PlayerGui, "⚠ HP CRÍTICO", "Recuando para segurança...", 4, Color3.fromRGB(255, 80, 100))
end

-- ============================================================
-- REGISTRO DE TAREFAS (Conexão UI <-> TaskManager)
-- ============================================================

-- Este bloco registra o que cada botão da UI vai disparar no motor interno

-- [FARM DE BOSSES]
manager:Register("BossFarm", function()
    stopConflictingFarms("BossFarm")
    if not manager:IsEnabled("AntiDetection") then adaptiveBrain:Start() end
    combatController:Start()
    bossManager:Start()
    Logger.Info("SISTEMA: Farm de Bosses Ativado.")
end, function()
    bossManager:Stop()
    combatController:Stop()
    Logger.Info("SISTEMA: Farm de Bosses Desativado.")
end)

-- [FRUTAS]
manager:Register("FruitTracker", function()
    stopConflictingFarms("FruitTracker")
    fruitTracker:Start()
    Logger.Info("SISTEMA: Rastreador de Frutas Ativado.")
end, function()
    fruitTracker:Stop()
    Logger.Info("SISTEMA: Rastreador de Frutas Desativado.")
end)

manager:Register("AutoCollect", function()
    fruitTracker:SetAutoCollect(true)
    Logger.Info("SISTEMA: Coleta Automática ON.")
end, function()
    fruitTracker:SetAutoCollect(false)
    Logger.Info("SISTEMA: Coleta Automática OFF.")
end)

-- [ITENS]
manager:Register("ItemFarm", function()
    stopConflictingFarms("ItemFarm")
    itemFarm:Start()
    Logger.Info("SISTEMA: Farm de itens ativado.")
end, function()
    itemFarm:Stop()
    Logger.Info("SISTEMA: Farm de itens desativado.")
end)

-- [ANTI-AFK]
manager:Register("AntiAFK", function()
    antiAFK:Start()
end, function()
    antiAFK:Stop()
end)

-- [ROTAÇÃO DE BOSSES]
manager:Register("FarmRotation", function()
    stopConflictingFarms("FarmRotation")
    if not manager:IsEnabled("AntiDetection") then adaptiveBrain:Start() end
    combatController:Start()
    farmRotation:Start()
end, function()
    farmRotation:Stop()
    combatController:Stop()
end)

-- [QUESTS]
manager:Register("QuestFarm", function()
    stopConflictingFarms("QuestFarm")
    if not manager:IsEnabled("AntiDetection") then adaptiveBrain:Start() end
    combatController:Start()
    questManager:Start()
end, function()
    questManager:Stop()
    combatController:Stop()
end)

-- [UTILIDADES]
manager:Register("AutoHeal", function()
    autoHeal:Start()
end, function()
    autoHeal:Stop()
end)

manager:Register("AutoStats", function()
    autoStats:Start()
end, function()
    autoStats:Stop()
end)

manager:Register("ESP", function()
    esp:Start()
    for _, category in ipairs({"Boss", "NPC", "Fruit", "Player", "Chest"}) do
        esp:Toggle(category, true)
    end
end, function()
    esp:Stop()
end)

-- [SEGURANÇA E ANTI-DETECÇÃO]
manager:Register("AntiDetection", function()
    Settings.General.AntiDetectionMode = true
    adaptiveBrain:Stop() 
    smartFlight.SpeedBase = 45 -- Velocidade segura
    combatController.AttackMin = 0.60
    combatController.AttackMax = 1.10
    Logger.Warn("SEGURANÇA: Modo Anti-Detecção ATIVADO.")
end, function()
    Settings.General.AntiDetectionMode = false
    adaptiveBrain:Start()
    smartFlight.SpeedBase = Settings.Movement.DefaultSpeed
    combatController.AttackMin = Settings.Combat.AttackIntervalMin
    combatController.AttackMax = Settings.Combat.AttackIntervalMax
    Logger.Info("SEGURANÇA: Modo Anti-Detecção DESATIVADO.")
end)

-- [COMBATE AVANÇADO]
manager:Register("AutoBuso", function() combatController.AutoBusoHaki = true end, function() combatController.AutoBusoHaki = false end)
manager:Register("AutoKen", function() combatController.AutoKenHaki = true end, function() combatController.AutoKenHaki = false end)
manager:Register("AutoGrip", function() combatController.AutoGrip = true end, function() combatController.AutoGrip = false end)

-- [COMBATE À DISTÂNCIA]
manager:Register("RangedFarm", function()
    combatController:SetRangedMode(true)
end, function()
    combatController:SetRangedMode(false)
end)

-- [MERCADOR]
manager:Register("MerchantTracker", function()
    merchantTracker:Start()
end, function()
    merchantTracker:Stop()
end)

-- [RAIDS]
manager:Register("FactoryFarm", function()
    stopConflictingFarms("FactoryFarm")
    if not manager:IsEnabled("AntiDetection") then adaptiveBrain:Start() end
    combatController:Start()
    lawFactoryFarm:SetFactoryEnabled(true)
end, function()
    lawFactoryFarm:SetFactoryEnabled(false)
    if not manager:IsEnabled("LawFarm") then combatController:Stop() end
end)
manager:Register("LawFarm", function()
    stopConflictingFarms("LawFarm")
    if not manager:IsEnabled("AntiDetection") then adaptiveBrain:Start() end
    combatController:Start()
    lawFactoryFarm:SetLawEnabled(true)
end, function()
    lawFactoryFarm:SetLawEnabled(false)
    if not manager:IsEnabled("FactoryFarm") then combatController:Stop() end
end)

-- ============================================================
-- CONSTRUÇÃO DA INTERFACE (UI)
-- ============================================================

local ui = MainUI.new()
local tabs = TabManager.new()

-- Criação das abas de navegação
local btnMain = ui:CreateTabButton("Main")
local btnCombat = ui:CreateTabButton("Combat")
local btnFruits = ui:CreateTabButton("Frutas")
local btnConfig = ui:CreateTabButton("Config")

local frameMain = ui:CreateTabFrame()
local frameCombat = ui:CreateTabFrame()
local frameFruits = ui:CreateTabFrame()
local frameConfig = ui:CreateTabFrame()

tabs:AddTab("Main", btnMain, frameMain)
tabs:AddTab("Combat", btnCombat, frameCombat)
tabs:AddTab("Frutas", btnFruits, frameFruits)
tabs:AddTab("Config", btnConfig, frameConfig)

-- ────────────────────────────────────────────────────────────
-- ABA: MAIN (Status e Controle Geral)
-- ────────────────────────────────────────────────────────────
Components.CreateSection(frameMain, "📊 Monitoramento")
local statusLabel = Components.CreateStatusLabel(frameMain, "Estado Geral", "Idle")
local bossLabel = Components.CreateStatusLabel(frameMain, "Boss Ativo", "—")
local brainLabel = Components.CreateStatusLabel(frameMain, "IA Brain", "Idle")

adaptiveBrain.OnAdjust = function(text) brainLabel.SetValue(text) end

Components.CreateSection(frameMain, "⚔️ Automação Principal")
taskToggles.BossFarm = Components.CreateToggle(frameMain, "Auto-Farm Bosses", function(en) manager:SetEnabled("BossFarm", en) end)
taskToggles.FruitTracker = Components.CreateToggle(frameMain, "Rastreador de Frutas", function(en) manager:SetEnabled("FruitTracker", en) end)
taskToggles.AutoCollect = Components.CreateToggle(frameMain, "Coleta Automática", function(en) manager:SetEnabled("AutoCollect", en) end)
taskToggles.AntiDetection = Components.CreateToggle(frameMain, "Modo Anti-Detecção", function(en) manager:SetEnabled("AntiDetection", en) end)
taskToggles.MerchantTracker = Components.CreateToggle(frameMain, "Rastreador de Mercador", function(en) manager:SetEnabled("MerchantTracker", en) end)
taskToggles.AntiAFK = Components.CreateToggle(frameMain, "Anti-AFK", function(en) manager:SetEnabled("AntiAFK", en) end)
taskToggles.AutoHeal = Components.CreateToggle(frameMain, "Auto-Heal", function(en) manager:SetEnabled("AutoHeal", en) end)
taskToggles.ESP = Components.CreateToggle(frameMain, "ESP Completo", function(en) manager:SetEnabled("ESP", en) end)

Components.CreateSection(frameMain, "🚀 Atalhos")
Components.CreateButton(frameMain, "Voar até Mercador", function()
    stopConflictingFarms("Merchant")
    if merchantTracker:IsActive() then
        merchantTracker:FlyToMerchant()
    else
        Notifications.Create(localPlayer.PlayerGui, "❌ ERRO", "Mercador não detectado!", 3)
    end
end)

-- ────────────────────────────────────────────────────────────
-- ABA: COMBAT (Configurações de Luta)
-- ────────────────────────────────────────────────────────────
Components.CreateSection(frameCombat, "🏭 Raids & Bosses")
taskToggles.FactoryFarm = Components.CreateToggle(frameCombat, "Auto-Farm Factory (Core)", function(en) manager:SetEnabled("FactoryFarm", en) end)
taskToggles.LawFarm = Components.CreateToggle(frameCombat, "Auto-Farm Law (Order)", function(en) manager:SetEnabled("LawFarm", en) end)
taskToggles.FarmRotation = Components.CreateToggle(frameCombat, "Rotação de Bosses", function(en) manager:SetEnabled("FarmRotation", en) end)
taskToggles.QuestFarm = Components.CreateToggle(frameCombat, "Farm de Quests", function(en) manager:SetEnabled("QuestFarm", en) end)

Components.CreateSection(frameCombat, "✨ Haki & Skills")
taskToggles.AutoBuso = Components.CreateToggle(frameCombat, "Auto-Buso Haki", function(en) manager:SetEnabled("AutoBuso", en) end)
taskToggles.AutoKen = Components.CreateToggle(frameCombat, "Auto-Ken Haki", function(en) manager:SetEnabled("AutoKen", en) end)
taskToggles.AutoGrip = Components.CreateToggle(frameCombat, "Auto-Grip (Executar)", function(en) manager:SetEnabled("AutoGrip", en) end)

Components.CreateSection(frameCombat, "🛡️ Combate Avançado")
taskToggles.RangedFarm = Components.CreateToggle(frameCombat, "Modo Ranged (Armas)", function(en) manager:SetEnabled("RangedFarm", en) end)

-- ────────────────────────────────────────────────────────────
-- ABA: FRUTAS (Configuração de Coleta)
-- ────────────────────────────────────────────────────────────
Components.CreateSection(frameFruits, "🍎 Filtros de Coleta")
taskToggles.ItemFarm = Components.CreateToggle(frameFruits, "Farm de Itens", function(en) manager:SetEnabled("ItemFarm", en) end)

Components.CreateSeparator(frameFruits)
Components.CreateSection(frameFruits, "Raridade Mínima")
local rarities = {"Common", "Rare", "Legendary", "Mythical"}
for _, r in ipairs(rarities) do
    Components.CreateToggle(frameFruits, r, function(en)
        fruitTracker:SetMinRarity(r)
    end)
end

-- ────────────────────────────────────────────────────────────
-- ABA: CONFIG (Sistema e Debug)
-- ────────────────────────────────────────────────────────────
Components.CreateSection(frameConfig, "🛠️ Sistema")
taskToggles.AutoStats = Components.CreateToggle(frameConfig, "Auto-Stats (Hybrid)", function(en) manager:SetEnabled("AutoStats", en) end)

Components.CreateSection(frameConfig, "🌍 Viagem")
Components.CreateButton(frameConfig, "Ir para Town of Beginnings", function()
    stopConflictingFarms("Teleport")
    teleportManager:TeleportTo("Town of Beginnings")
end)
Components.CreateButton(frameConfig, "Ir para Sandora", function()
    stopConflictingFarms("Teleport")
    teleportManager:TeleportTo("Sandora")
end)
Components.CreateButton(frameConfig, "Ir para Desert Kingdom", function()
    stopConflictingFarms("Teleport")
    teleportManager:TeleportTo("Desert Kingdom")
end)

Components.CreateButton(frameConfig, "Parar Tudo (Panic)", function()
    manager:StopAll()
    adaptiveBrain:Stop()
    combatController:Stop()
    smartFlight:Stop()
    for _, toggle in pairs(taskToggles) do
        toggle.SetEnabled(false)
    end
    Logger.Warn("SISTEMA: Parada de Emergência!")
end)

Components.CreateButton(frameConfig, "Copiar Kick Log", function()
    local logs = ""
    for _, e in ipairs(kickLog:GetEvents()) do
        logs = logs .. string.format("[%s] %s %s\n", e.t, e.action, e.detail)
    end
    if setclipboard then
        setclipboard(logs)
        Notifications.Create(localPlayer.PlayerGui, "📋 COPIADO", "Logs enviados para o clipboard!", 3)
    end
end)

-- ============================================================
-- LOOP DE ATUALIZAÇÃO DA UI (STATUS EM TEMPO REAL)
-- ============================================================

task.spawn(function()
    while true do
        -- Atualiza o status visual na UI
        local state = manager:IsEnabled("FactoryFarm") and "Factory (Core)"
            or manager:IsEnabled("LawFarm") and "Law (Order) Raid"
            or manager:IsEnabled("BossFarm") and "Boss Farm"
            or manager:IsEnabled("FarmRotation") and "Rotação de Bosses"
            or manager:IsEnabled("QuestFarm") and "Quest Farm"
            or manager:IsEnabled("FruitTracker") and "Fruit Tracker"
            or manager:IsEnabled("ItemFarm") and "Item Farm"
            or manager:IsEnabled("MerchantTracker") and "Rastreador"
            or manager:IsEnabled("AntiAFK") and "Anti-AFK"
            or manager:IsEnabled("AutoHeal") and "Auto-Heal"
            or manager:IsEnabled("ESP") and "ESP"
            or "Idle"
        
        statusLabel.SetValue(state)

        local currentBoss = bossManager:GetCurrentBoss()
        bossLabel.SetValue(currentBoss and currentBoss.Name or "—")

        task.wait(1)
    end
end)

-- ============================================================
-- FINALIZAÇÃO & HOTKEYS
-- ============================================================

-- Atalho para abrir/fechar a UI
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Home then
        ui.Panel.Visible = not ui.Panel.Visible
    end
end)

-- Boot Completo
ui:Open()
tabs:Switch("Main")

Logger.Success("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Logger.Success("  FRAMEWORK CARREGADO COM SUCESSO!")
Logger.Success("  Pressione HOME para abrir o painel")
Logger.Success("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

Notifications.Create(
    localPlayer.PlayerGui,
    "⚡ ELITE AUTOMATION",
    "Framework v2.1 pronto para uso!\nIniciando Engine...",
    6,
    Color3.fromRGB(100, 130, 255)
)
