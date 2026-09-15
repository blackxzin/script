-- ============================================================
--  Elite Automation Framework v2.1 - MAIN INTEGRATION
--  O Maestro: Gerenciador de Ciclo de Vida e Conexão UI
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

-- 1. IMPORTAÇÃO DE MÓDULOS (CORE)
local Logger = customRequire("EliteAutomation.Core.Logger")
local TaskManager = customRequire("EliteAutomation.Core.TaskManager")
local Settings = customRequire("EliteAutomation.Config.Settings")

-- 2. IMPORTAÇÃO DE SISTEMAS (ENGINE)
local SmartFlight = customRequire("EliteAutomation.Movement.SmartFlight")
local CombatController = customRequire("EliteAutomation.Combat.CombatController")
local TargetSelector = customRequire("EliteAutomation.Combat.TargetSelector")

-- 3. IMPORTAÇÃO DE UI (INTERFACE)
local MainUI = customRequire("EliteAutomation.UI.MainUI")
local TabManager = customRequire("EliteAutomation.UI.TabManager")
local Components = customRequire("EliteAutomation.UI.Components")
local Notifications = customRequire("EliteAutomation.UI.Notifications")

-- 4. IMPORTAÇÃO DE SISTEMAS DE APOIO
local BossManager = customRequire("EliteAutomation.Systems.BossManager")
local FruitTracker = customRequire("EliteAutomation.Systems.FruitTracker")
local FruitDatabase = customrequire("EliteAutomation.Systems.FruitDatabase")
local ItemFarm = customrequire("EliteAutomation.Systems.ItemFarm")
local MerchantTracker = customrequire("EliteAutomation.Systems.MerchantTracker")
local LawFactoryFarm = customrequire("EliteAutomation.Systems.LawFactoryFarm")
local AdaptiveBrain = customrequire("EliteAutomation.Systems.AdaptiveBrain")
local KickTelemetry = customrequire("EliteAutomation.Systems.KickTelemetry")

-- ============================================================
-- INICIALIZAÇÃO DO MOTOR (ENGINE SETUP)
-- ============================================================

Logger.Info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Logger.Info("  Elite Automation Framework - Booting...")
Logger.Info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Inicializa o Gerenciador de Tarefas (O coração do controle)
local taskManager = TaskManager.new()

-- Inicializa o Sistema de Movimento
local smartFlight = SmartFlight.new(character, Settings.Movement)

-- Inicializa o Sistema de Combate
local combatController = CombatController.new(Settings.Combat)
combatController:SetFlight(smartFlight) -- Conecta o voo ao combate

-- Inicializa os Sistemas de Farm
local fruitTracker = FruitTracker.new(FruitDatabase, Notifications, Settings.FruitTracker)
fruitTracker:SetFlight(smartFlight)

local bossManager = BossManager.new(combatController, smartFlight, Notifications, Settings.BossManager)
local itemFarm = ItemFarm.new(smartFlight, Notifications, Settings.ItemFarm)
local merchantTracker = MerchantTracker.new(Notifications, Settings.MerchantTracker)
merchantTracker:SetFlight(smartFlight)
local lawFactoryFarm = LawFactoryFarm.new(combatController, smartFlight, Notifications, Settings.LawFactoryFarm)

-- Inicializa o Cérebro (AI/Adaptive)
local adaptiveBrain = AdaptiveBrain.new(combatController, smartFlight, bossManager, lawFactoryFarm)
adaptiveBrain:Start()

-- Inicializa Telemetria (Segurança)
local kickLog = KickTelemetry.new(Notifications)
kickLog:BindManager(taskManager)
kickLog:Start()

-- ============================================================
-- CONEXÃO DA UI (A PONTE ENTRE BOTÕES E LÓGICA)
-- ============================================================

-- 1. Setup da Interface Principal
local ui = MainUI.new()
local tabs = TabManager.new()

-- 2. Criação de Abas
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
-- ABA: MAIN (Status e Atalhos Rápidos)
-- ────────────────────────────────────────────────────────────
Components.CreateSection(frameMain, "📊 Status do Sistema")
local statusLabel = Components.CreateStatusLabel(frameMain, "Estado", "Idle")
local bossLabel = Components.CreateStatusLabel(frameMain, "Boss Ativo", "—")
local brainLabel = Components.CreateStatusLabel(frameMain, "AI Brain", "Idle")

adaptiveBrain.OnAdjust = function(text) brainLabel.SetValue(text) end

Components.CreateSection(frameMain, "🚀 Atalhos Rápidos")
Components.CreateButton(frameMain, "Ativar Farm de Bosses", function()
    taskManager:SetEnabled("BossFarm", true)
end)

Components.CreateButton(frameMain, "Ativar Coleta de Frutas", function()
    taskManager:SetEnabled("FruitTracker", true)
end)

Components.CreateButton(frameMain, "Parar Tudo (Panic)", function()
    taskManager:StopAll()
    combatController:Stop()
    smartFlight:Stop()
    Logger.Warn("SISTEMA: Parada de Emergência!")
end)

-- ────────────────────────────────────────────────────────────
-- ABA: COMBAT (Configurações de Luta)
-- ────────────────────────────────────────────────────────────
Components.CreateSection(frameCombat, "⚔️ Modo de Combate")

Components.CreateToggle(frameCombat, "Auto-Farm Bosses", function(enabled)
    taskManager:SetEnabled("BossFarm", enabled)
end)

Components.CreateToggle(frameCombat, "Auto-Farm Law/Factory", function(enabled)
    lawFactoryFarm:SetLawEnabled(enabled)
    lawFactoryFarm:SetFactoryEnabled(enabled)
end)

Components.CreateSeparator(frameCombat)

Components.CreateSection(frameCombat, "✨ Buffs & Haki")
Components.CreateToggle(frameCombat, "Auto-Buso Haki ('J')", function(enabled)
    combatController.AutoBusoHaki = enabled
end)

Components.CreateToggle(frameCombat, "Auto-Ken Haki ('K')", function(enabled)
    combatController.AutoKenHaki = enabled
end)

Components.CreateToggle(frameCombat, "Auto-Grip ('B')", function(enabled)
    combatController.AutoGrip = enabled
end)

Components.CreateSeparator(frameCombat)

Components.CreateSection(frameCombat, "🛡️ Segurança")
Components.CreateToggle(frameCombat, "Modo Anti-Detecção", function(enabled)
    -- Ajusta parâmetros para voo e combate mais "humanos"
    if enabled then
        smartFlight.SpeedBase = 40
        combatController.AttackMin = 0.6
        combatController.AttackMax = 1.1
        Logger.Info("Segurança: Modo Furtivo ON")
    else
        smartFlight.SpeedBase = 52
        combatController.AttackMin = 0.4
        combatController.AttackMax = 0.75
        Logger.Info("Segurança: Modo Furtivo OFF")
    end
end)

-- ────────────────────────────────────────────────────────────
-- ABA: FRUTAS (Configuração de Coleta)
-- ────────────────────────────────────────────────────────────
Components.CreateSection(frameFruits, "🍎 Coleta de Frutas")

Components.CreateToggle(frameFruits, "Rastreador Ativo", function(enabled)
    taskManager:SetEnabled("FruitTracker", enabled)
end)

Components.CreateToggle(frameFruits, "Auto-Coleta (Voo)", function(enabled)
    fruitTracker:SetAutoCollect(enabled)
end)

Components.CreateSeparator(frameFruits)

Components.CreateSection(frameFruits, "💎 Raridade Mínima")
Components.CreateToggle(frameFruits, "Common", function(enabled)
    fruitTracker:SetMinRarity("Common")
end)
Components.CreateToggle(frameFruits, "Rare", function(enabled)
    fruitTracker:SetMinRarity("Rare")
end)
Components.CreateToggle(frameFruits, "Legendary", function(enabled)
    fruitTracker:SetMinRarity("Legendary")
end)
Components.CreateToggle(frameFruits, "Mythical", function(enabled)
    fruitTracker:SetMinRarity("Mythical")
end)

-- ────────────────────────────────────────────────────────────
-- ABA: CONFIG (Sistema e Debug)
-- ────────────────────────────────────────────────────────────
Components.CreateSection(frameConfig, "🛠️ Sistema")

Components.CreateButton(frameConfig, "Limpar Cache", function()
    taskManager:StopAll()
    Logger.Info("Sistema: Cache Limpo.")
end)

Components.CreateButton(frameConfig, "Copiar Kick Log", function()
    local logs = ""
    for _, e in ipairs(kickLog:GetEvents()) do
        logs = logs .. string.format("[%s] %s %s\n", e.t, e.action, e.detail)
    end
    if setclipboard then
        setclipboard(logs)
        Notifications.Create(localPlayer.PlayerGui, "📋 LOG COPIADO", "Logs enviados para o clipboard.", 3)
    end
end)

-- ============================================================
-- LOOP DE ATUALIZAÇÃO DE UI (STATUS EM TEMPO REAL)
-- ============================================================

task.spawn(function()
    while true do
        -- Atualiza Status de Combate
        local state = combatController.FSM:Get()
        statusLabel.SetValue(state)
        
        -- Atualiza Boss Ativo
        local currentBoss = bossManager:GetCurrentBoss()
        bossLabel.SetValue(currentBoss and currentBoss.Name or "—")
        
        task.wait(1)
    end
end)

-- ============================================================
-- BOOT FINAL
-- ============================================================

ui:Open()
tabs:Switch("Main")

Logger.Success("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Logger.Success("  FRAMEWORK PRONTO PARA USO!")
Logger.Success("  Pressione HOME para abrir/fechar o painel")
Logger.Success("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

Notifications.Create(
    localPlayer.PlayerGui,
    "⚡ ELITE AUTOMATION",
    "Sistema Carregado com Sucesso!\nPronto para o Farm.",
    6,
    Color3.fromRGB(100, 130, 255)
)

-- Atalho de Teclado para abrir/fechar a UI
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Home then
        ui.Panel.Visible = not ui.Panel.Visible
    end
end)