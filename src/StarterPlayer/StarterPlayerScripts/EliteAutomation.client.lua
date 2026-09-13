-- ============================================================
--  Elite Automation Framework :: EliteAutomation.client.lua
--  INTEGRADOR PRINCIPAL — Ponto de entrada do framework.
--
--  Responsabilidades:
--    1. Carrega todos os módulos
--    2. Inicializa componentes na ordem correta
--    3. Liga a UI aos sistemas via TaskManager
--    4. Monta a interface completa com abas e toggles
--    5. Gerencia respawn do personagem
-- ============================================================

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")

local localPlayer        = Players.LocalPlayer
local character          = localPlayer.Character or localPlayer.CharacterAdded:Wait()

-- ─── Root do framework ────────────────────────────────────────
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")

-- ─── Core ─────────────────────────────────────────────────────
local Logger         = require(Root.Core.Logger)
local TaskManager    = require(Root.Core.TaskManager)
local StateMachine   = require(Root.Core.StateMachine)
local PriorityManager = require(Root.Core.PriorityManager)

-- ─── Config ───────────────────────────────────────────────────
local Settings = require(Root.Config.Settings)

-- Configura nível de log
if Settings.General.DebugLogs then
	Logger.SetMinLevel("DEBUG")
else
	Logger.SetMinLevel("INFO")
end

-- ─── UI ───────────────────────────────────────────────────────
local MainUI       = require(Root.UI.MainUI)
local TabManager   = require(Root.UI.TabManager)
local Components   = require(Root.UI.Components)
local Notifications = require(Root.UI.Notifications)

-- ─── Sistemas ─────────────────────────────────────────────────
local FruitDatabase   = require(Root.Systems.FruitDatabase)
local FruitTracker    = require(Root.Systems.FruitTracker)
local BossManager     = require(Root.Systems.BossManager)
local ItemFarm        = require(Root.Systems.ItemFarm)
local MerchantTracker = require(Root.Systems.MerchantTracker)
local LawFactoryFarm  = require(Root.Systems.LawFactoryFarm)
local AdaptiveBrain   = require(Root.Systems.AdaptiveBrain)
local KickTelemetry   = require(Root.Systems.KickTelemetry)

-- ─── Combate ──────────────────────────────────────────────────
local CombatController = require(Root.Combat.CombatController)
local TargetSelector   = require(Root.Combat.TargetSelector)

-- ─── Movimento ────────────────────────────────────────────────
local SmartFlight = require(Root.Movement.SmartFlight)

-- ══════════════════════════════════════════════════════════════
--   INICIALIZAÇÃO DOS MÓDULOS
-- ══════════════════════════════════════════════════════════════

Logger.Info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Logger.Info("  Elite Automation Framework v2.1")
Logger.Info("  Grand Piece Online (GPO) | Iniciando...")
Logger.Info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ─ Gerenciador de tarefas ─
local manager = TaskManager.new()

-- ─ Movimento ─
local smartFlight = SmartFlight.new(character, Settings.Movement)

-- ─ Combate ─
local combatController = CombatController.new(Settings.Combat)
combatController:SetFlight(smartFlight) -- kite ranged usa voo

-- ─ Sistemas ─
local fruitTracker = FruitTracker.new(
	FruitDatabase,
	Notifications,
	Settings.FruitTracker
)
fruitTracker:SetFlight(smartFlight)  -- injeta o voo
fruitTracker:SetAutoCollect(false) -- toggles mandam; sem isso Start() coletava com toggle off

local bossManager = BossManager.new(
	combatController,
	smartFlight,
	Notifications,
	Settings.BossManager
)

local itemFarm = ItemFarm.new(
	smartFlight,
	Notifications,
	Settings.ItemFarm
)

local merchantTracker = MerchantTracker.new(
	Notifications,
	Settings.MerchantTracker
)
merchantTracker:SetFlight(smartFlight)

local lawFactoryFarm = LawFactoryFarm.new(
	combatController,
	smartFlight,
	Notifications,
	Settings.LawFactoryFarm
)

-- Brain: observa boss + HP e ajusta voo/combate sozinho
local adaptiveBrain = AdaptiveBrain.new(
	combatController,
	smartFlight,
	bossManager,
	lawFactoryFarm
)
adaptiveBrain:Start() -- sempre on; sem boss restaura defaults

-- Telemetry: inject + kick dump (descobre a causa do kick)
local kickLog = KickTelemetry.new(Notifications)
kickLog:BindManager(manager)
kickLog:Start()

-- ─ Telemetry nos toggles: mostra no dump o que estava ligado ─
do
	local baseSet = manager.SetEnabled
	function manager:SetEnabled(name, enabled)
		if kickLog then kickLog:Event("toggle", name .. "=" .. tostring(enabled)) end
		return baseSet(self, name, enabled)
	end
end

-- ─ CombatController: callbacks ─
combatController.OnTargetFound = function(model)
	if kickLog then kickLog:Event("target", model.Name) end
	Logger.Info("Alvo em combate:", model.Name)
end
combatController.OnFlee = function()
	Logger.Warn("HP crítico! Fugindo...")
	Notifications.Create(
		localPlayer.PlayerGui,
		"⚠ HP CRÍTICO",
		"Saindo do combate para recuperar vida!",
		4,
		Color3.fromRGB(255, 80, 100)
	)
end

-- ══════════════════════════════════════════════════════════════
--   REGISTRO DE TAREFAS NO TASK MANAGER
-- ══════════════════════════════════════════════════════════════

-- ─ Fruit Tracker ─
manager:Register(
	"FruitTracker",
	function()
		fruitTracker:Start()
		Notifications.Create(localPlayer.PlayerGui,
			"✅ ATIVADO", "Fruit Tracker ligado", 3, Color3.fromRGB(80, 220, 130))
	end,
	function()
		fruitTracker:Stop()
		Notifications.Create(localPlayer.PlayerGui,
			"⛔ DESATIVADO", "Fruit Tracker desligado", 3)
	end
)

-- ─ Auto-Collection (toggle separado) ─
manager:Register(
	"AutoCollect",
	function()
		fruitTracker:SetAutoCollect(true)
		Notifications.Create(localPlayer.PlayerGui,
			"✅ ATIVADO", "Auto-Collection ligado", 3, Color3.fromRGB(80, 220, 130))
	end,
	function()
		fruitTracker:SetAutoCollect(false)
		Notifications.Create(localPlayer.PlayerGui,
			"⛔ DESATIVADO", "Auto-Collection desligado", 3)
	end
)

-- ─ Boss Farm ─
manager:Register(
	"BossFarm",
	function()
		combatController:Start()
		bossManager:Start()
		Notifications.Create(localPlayer.PlayerGui,
			"✅ ATIVADO", "Boss Farm ligado", 3, Color3.fromRGB(80, 220, 130))
	end,
	function()
		bossManager:Stop()
		combatController:Stop()
		Notifications.Create(localPlayer.PlayerGui,
			"⛔ DESATIVADO", "Boss Farm desligado", 3)
	end
)

-- ─ Item Farm ─
manager:Register(
	"ItemFarm",
	function()
		itemFarm:Start()
		Notifications.Create(localPlayer.PlayerGui,
			"✅ ATIVADO", "Item Farm ligado", 3, Color3.fromRGB(80, 220, 130))
	end,
	function()
		itemFarm:Stop()
		Notifications.Create(localPlayer.PlayerGui,
			"⛔ DESATIVADO", "Item Farm desligado", 3)
	end
)

-- ─ Anti-Detection Mode (manual: pausa o brain p/ nao brigar) ─
manager:Register(
	"AntiDetection",
	function()
		Settings.General.AntiDetectionMode = true
		adaptiveBrain:Stop() -- brain ajusta a cada 1s; sem stop ele sobrescreve
		smartFlight.SpeedBase   = 45   -- velocidade mais lenta = menos suspeito
		combatController.AttackMin = 0.60
		combatController.AttackMax = 1.10
		Logger.Info("Anti-Detection Mode: ATIVADO")
		Notifications.Create(localPlayer.PlayerGui,
			"🛡 ANTI-DETECÇÃO", "Modo furtivo ativado", 4, Color3.fromRGB(255, 200, 0))
	end,
	function()
		Settings.General.AntiDetectionMode = false
		adaptiveBrain:Start()
		smartFlight.SpeedBase   = Settings.Movement.DefaultSpeed
		combatController.AttackMin = Settings.Combat.AttackIntervalMin
		combatController.AttackMax = Settings.Combat.AttackIntervalMax
		Logger.Info("Anti-Detection Mode: DESATIVADO")
	end
)

-- ─ Merchant Tracker (Mercador Viajante) ─
manager:Register(
	"MerchantTracker",
	function()
		merchantTracker:Start()
		Notifications.Create(localPlayer.PlayerGui,
			"🛒 ATIVADO", "Rastreador de Mercador ligado", 3, Color3.fromRGB(255, 215, 0))
	end,
	function()
		merchantTracker:Stop()
		Notifications.Create(localPlayer.PlayerGui,
			"⛔ DESATIVADO", "Rastreador de Mercador desligado", 3)
	end
)

-- ─ Factory Farm (Core) ─
manager:Register(
	"FactoryFarm",
	function()
		lawFactoryFarm:SetFactoryEnabled(true)
		Notifications.Create(localPlayer.PlayerGui,
			"🏭 ATIVADO", "Farm da Factory (Core) ligado", 3, Color3.fromRGB(255, 80, 80))
	end,
	function()
		lawFactoryFarm:SetFactoryEnabled(false)
		Notifications.Create(localPlayer.PlayerGui,
			"⛔ DESATIVADO", "Farm da Factory desligado", 3)
	end
)

-- ─ Law Raid Farm ─
manager:Register(
	"LawFarm",
	function()
		lawFactoryFarm:SetLawEnabled(true)
		Notifications.Create(localPlayer.PlayerGui,
			"⚡ ATIVADO", "Farm do Law (Order) ligado", 3, Color3.fromRGB(241, 196, 15))
	end,
	function()
		lawFactoryFarm:SetLawEnabled(false)
		Notifications.Create(localPlayer.PlayerGui,
			"⛔ DESATIVADO", "Farm do Law desligado", 3)
	end
)

-- ─ Auto-Haki Armamento (Buso) ─
manager:Register(
	"AutoBuso",
	function()
		combatController.AutoBusoHaki = true
		Notifications.Create(localPlayer.PlayerGui,
			"⚔ BUSO HAKI", "Haki do Armamento ativado ('J')", 3, Color3.fromRGB(120, 80, 255))
	end,
	function()
		combatController.AutoBusoHaki = false
	end
)

-- ─ Auto-Haki Observação (Ken) ─
manager:Register(
	"AutoKen",
	function()
		combatController.AutoKenHaki = true
		Notifications.Create(localPlayer.PlayerGui,
			"👁 KEN HAKI", "Haki da Observação ativado ('K')", 3, Color3.fromRGB(80, 180, 255))
	end,
	function()
		combatController.AutoKenHaki = false
	end
)

-- ─ Farm de arma (ranged kite 32-60m) ─
manager:Register(
	"RangedFarm",
	function()
		combatController:SetRangedMode(true)
		Notifications.Create(localPlayer.PlayerGui,
			"🔫 RANGED", "Farm de arma ligado (32-60m)", 3, Color3.fromRGB(80, 200, 255))
	end,
	function()
		combatController:SetRangedMode(false)
	end
)

-- ─ Auto-Grip ('B') ─
manager:Register(
	"AutoGrip",
	function()
		combatController.AutoGrip = true
		Notifications.Create(localPlayer.PlayerGui,
			"💀 AUTO-GRIP", "Finalização automática ativada ('B')", 3, Color3.fromRGB(230, 80, 80))
	end,
	function()
		combatController.AutoGrip = false
	end
)

-- ══════════════════════════════════════════════════════════════
--   CONSTRUÇÃO DA UI
-- ══════════════════════════════════════════════════════════════

local ui   = MainUI.new()
local tabs = TabManager.new()

-- ─ Cria abas ─
local btnMain      = ui:CreateTabButton("Main")
local btnCombat    = ui:CreateTabButton("Combat")
local btnFruits    = ui:CreateTabButton("Frutas")
local btnSettings  = ui:CreateTabButton("Config")

local frameMain     = ui:CreateTabFrame()
local frameCombat   = ui:CreateTabFrame()
local frameFruits   = ui:CreateTabFrame()
local frameSettings = ui:CreateTabFrame()

tabs:AddTab("Main",     btnMain,     frameMain)
tabs:AddTab("Combat",   btnCombat,   frameCombat)
tabs:AddTab("Frutas",   btnFruits,   frameFruits)
tabs:AddTab("Config",   btnSettings, frameSettings)

-- ──────────────────────────────────────────────
--   ABA: MAIN — status + farms principais
-- ──────────────────────────────────────────────

Components.CreateSection(frameMain, "📊 Status")
local statusLabel    = Components.CreateStatusLabel(frameMain, "Estado Geral", "Idle")
local bossLabel      = Components.CreateStatusLabel(frameMain, "Boss Ativo", "—")
local merchantLabel  = Components.CreateStatusLabel(frameMain, "Mercador GPO", "Calculando ciclo...")
local fruitLabel     = Components.CreateStatusLabel(frameMain, "Frutas Coletadas", "0")
local brainLabel     = Components.CreateStatusLabel(frameMain, "🧠 Brain", "Idle")

adaptiveBrain.OnAdjust = function(text)
	brainLabel.SetValue(text)
end

merchantTracker.OnMerchantSpawned = function(data)
	merchantLabel.SetValue("Ativo: " .. data.island)
end
merchantTracker.OnMerchantDespawned = function()
	local sched = merchantTracker:GetSchedule()
	merchantLabel.SetValue(sched and sched.DisplayText or "Aguardando spawn")
end

-- ─ Farms principais ─
Components.CreateSection(frameMain, "⚔️ Farms")
local toggleBossFarm = Components.CreateToggle(frameMain, "Auto-Farm Bosses", function(enabled)
	manager:SetEnabled("BossFarm", enabled)
end)

local toggleFruitTracker = Components.CreateToggle(frameMain, "Fruit Tracker", function(enabled)
	manager:SetEnabled("FruitTracker", enabled)
end)

local toggleAutoCollect = Components.CreateToggle(frameMain, "Auto-Collection", function(enabled)
	manager:SetEnabled("AutoCollect", enabled)
end)

local toggleMerchant = Components.CreateToggle(frameMain, "Rastrear Mercador", function(enabled)
	manager:SetEnabled("MerchantTracker", enabled)
end, false)

local toggleItemFarm = Components.CreateToggle(frameMain, "Item Farm (Baús)", function(enabled)
	manager:SetEnabled("ItemFarm", enabled)
end)

local toggleAntiDetect = Components.CreateToggle(frameMain, "Anti-Detection Mode", function(enabled)
	manager:SetEnabled("AntiDetection", enabled)
end)

-- ─ Viagem rápida ─
Components.CreateSection(frameMain, "✈️ Viagem")
Components.CreateButton(frameMain, "🛒 Voar até o Mercador", function()
	if merchantTracker:IsActive() then
		merchantTracker:FlyToMerchant()
		Notifications.Create(localPlayer.PlayerGui,
			"🛒 VOO MERCADOR", "Voando com segurança até o Mercador...", 4, Color3.fromRGB(255, 215, 0))
	else
		Notifications.Create(localPlayer.PlayerGui,
			"❌ MERCADOR INATIVO", "O Mercador Viajante não está spawnado no servidor", 3)
	end
end)

-- ──────────────────────────────────────────────
--   ABA: COMBAT — farms, estilo de luta, voos
-- ──────────────────────────────────────────────

Components.CreateSection(frameCombat, "📊 Status")
local combatStatusLabel  = Components.CreateStatusLabel(frameCombat, "Estado Combate", "Idle")
local factoryStageLabel  = Components.CreateStatusLabel(frameCombat, "Factory Stage", "Aguardando")
local factoryStatusLabel = Components.CreateStatusLabel(frameCombat, "Factory Core", "Desativado")
local lawStatusLabel     = Components.CreateStatusLabel(frameCombat, "Boss Law (Order)", "Desativado")

-- ─ Raids ─
Components.CreateSection(frameCombat, "🏭 Raids")
local toggleFactoryFarm = Components.CreateToggle(frameCombat, "Auto-Farm Factory (Core)", function(enabled)
	manager:SetEnabled("FactoryFarm", enabled)
end)

local toggleLawFarm = Components.CreateToggle(frameCombat, "Auto-Farm Law (Order)", function(enabled)
	manager:SetEnabled("LawFarm", enabled)
end)

-- ─ Estilo de luta: melee perto vs arma longe ─
Components.CreateSection(frameCombat, "🔫 Estilo de luta")
Components.CreateToggle(frameCombat, "🔫 Farm de Arma (32-60m)", function(enabled)
	manager:SetEnabled("RangedFarm", enabled)
end, false)

-- ─ Buffs e skills ─
Components.CreateSection(frameCombat, "✨ Buffs")
Components.CreateToggle(frameCombat, "Auto-Buso Haki ('J')", function(enabled)
	manager:SetEnabled("AutoBuso", enabled)
end, false)

Components.CreateToggle(frameCombat, "Auto-Ken Haki ('K')", function(enabled)
	manager:SetEnabled("AutoKen", enabled)
end, false)

Components.CreateToggle(frameCombat, "Auto-Grip / Executar ('B')", function(enabled)
	manager:SetEnabled("AutoGrip", enabled)
end, false)

Components.CreateToggle(frameCombat, "Cyborg Skills no Law (Z/X/C/V)", function(enabled)
	lawFactoryFarm.UseCyborgSkills = enabled
end, true)

-- ─ Boss Farm Geral ─
Components.CreateSection(frameCombat, "🌊 Mundo / Mar")
Components.CreateToggle(frameCombat, "Boss Farm Geral (Mundo/Mar)", function(enabled)
	manager:SetEnabled("BossFarm", enabled)
	toggleBossFarm.SetEnabled(enabled)
end)

-- ─ FlyTo com telemetry: dump mostra último voo antes do kick ─
local function loggedFly(pos)
	if kickLog then kickLog:Event("flyto", tostring(pos)) end
	smartFlight:FlyTo(pos)
end

-- ─ Voos de combate ─
Components.CreateSection(frameCombat, "✈️ Voos")
Components.CreateButton(frameCombat, "🏭 Voar para a Factory", function()
	local loc = Settings.LawFactoryFarm.Factory.Location
	loggedFly(loc)
	Notifications.Create(localPlayer.PlayerGui,
		"🏭 VOO FACTORY", "Voando até a Factory...", 3, Color3.fromRGB(255, 80, 80))
end)

Components.CreateButton(frameCombat, "⚡ Voar para o Law (Order)", function()
	local loc = Settings.LawFactoryFarm.Law.Location
	loggedFly(loc)
	Notifications.Create(localPlayer.PlayerGui,
		"⚡ VOO LAW", "Voando até o laboratório do Law...", 3, Color3.fromRGB(241, 196, 15))
end)

-- Botão para forçar teleport ao boss mais próximo
Components.CreateButton(frameCombat, "Ir ao Boss mais próximo", function()
	local char  = localPlayer.Character
	local root  = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local nearest, bestDist = nil, math.huge
	local function checkBossGroup(group)
		if not group then return end
		for _, cfg in pairs(group) do
			local names = { cfg.Name }
			if cfg.Aliases then
				for _, a in ipairs(cfg.Aliases) do table.insert(names, a) end
			end
			for _, name in ipairs(names) do
				local model = workspace:FindFirstChild(name, true)
				if model then
					local r = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildOfClass("BasePart")
					if r then
						local d = (r.Position - root.Position).Magnitude
						if d < bestDist then
							bestDist = d
							nearest  = r.Position
						end
					end
				end
			end
		end
	end

	checkBossGroup(Settings.BossManager.LocationBosses)
	checkBossGroup(Settings.BossManager.TimedBosses)
	checkBossGroup(Settings.BossManager.RaidBosses)

	if nearest then
		task.spawn(function()
			loggedFly(nearest)
		end)
		Notifications.Create(localPlayer.PlayerGui,
			"✈ VOO", "Voando até o boss...", 3, Color3.fromRGB(100, 130, 255))
	else
		Notifications.Create(localPlayer.PlayerGui,
			"❌ NENHUM BOSS", "Nenhum boss de GPO ativo no momento", 3)
	end
end)

-- ──────────────────────────────────────────────
--   ABA: FRUTAS
-- ──────────────────────────────────────────────

Components.CreateStatusLabel(frameFruits, "Raridade Mínima", Settings.FruitTracker.MinRarity)
Components.CreateSeparator(frameFruits)

-- Toggle por raridade (GPO canônico)
local RARITIES = { "Common", "Rare", "Legendary", "Mythical" }
for _, rarity in ipairs(RARITIES) do
	Components.CreateToggle(frameFruits, "Coletar " .. rarity,
		function(enabled)
			if enabled then
				fruitTracker:SetMinRarity(rarity)
				Notifications.Create(localPlayer.PlayerGui,
					"🍎 RARIDADE", "Mínimo: " .. rarity, 2)
			end
		end,
		rarity == Settings.FruitTracker.MinRarity
	)
end

-- ──────────────────────────────────────────────
--   ABA: CONFIGURAÇÕES
-- ──────────────────────────────────────────────

Components.CreateStatusLabel(frameSettings, "Velocidade de Voo", tostring(Settings.Movement.DefaultSpeed))
Components.CreateStatusLabel(frameSettings, "Raio de Ataque", tostring(Settings.Combat.AttackRange) .. " studs")
Components.CreateStatusLabel(frameSettings, "Hover Offset", tostring(Settings.Movement.HoverOffset) .. " studs")
Components.CreateSeparator(frameSettings)

-- ─ Kick log: copia últimas ações p/ clipboard, abre arquivo ─
Components.CreateSection(frameSettings, "🧾 Kick Log")
Components.CreateButton(frameSettings, "📋 Copiar Kick Log", function()
	local lines = {}
	for _, e in ipairs(kickLog:GetEvents()) do
		table.insert(lines, string.format("[%s] %s %s @%s", e.t, e.action, e.detail, e.pos))
	end
	if setclipboard then
		setclipboard(table.concat(lines, "\n"))
		Notifications.Create(localPlayer.PlayerGui, "📋 COPIADO", "Kick log no clipboard!", 3)
	else
		Notifications.Create(localPlayer.PlayerGui, "❌ SEM CLIPBOARD", "Executor sem setclipboard", 3)
	end
end)

Components.CreateButton(frameSettings, "Parar Tudo", function()
	manager:StopAll()
	Notifications.Create(localPlayer.PlayerGui,
		"⛔ PARADO", "Todas as tarefas foram paradas", 4)
end)

-- ══════════════════════════════════════════════════════════════
--   ATIVA UI E MOSTRA ABA INICIAL
-- ══════════════════════════════════════════════════════════════

ui:Open()
tabs:Switch("Main")

-- ══════════════════════════════════════════════════════════════
--   LOOP DE STATUS (atualiza labels em tempo real)
-- ══════════════════════════════════════════════════════════════

local fruitsCollected = 0

task.spawn(function()
	while true do
		-- Estado geral
		local state = manager:IsEnabled("FactoryFarm")     and "Factory (Core)"
			or manager:IsEnabled("LawFarm")         and "Law (Order) Raid"
			or manager:IsEnabled("BossFarm")        and "Boss Farm"
			or manager:IsEnabled("FruitTracker")    and "Fruit Tracker"
			or manager:IsEnabled("MerchantTracker") and "Rastreando Mercador"
			or manager:IsEnabled("ItemFarm")        and "Item Farm"
			or "Idle"
		statusLabel.SetValue(state)

		-- Boss ativo
		local currentBoss = bossManager:GetCurrentBoss()
		bossLabel.SetValue(currentBoss and currentBoss.Name or "—")

		-- Status Mercador (Ao vivo via Uptime de Servidor do GPO)
		local merch = merchantTracker:GetMerchant()
		if merch then
			merchantLabel.SetValue("Ativo: " .. merch.island)
		else
			local sched = merchantTracker:GetSchedule()
			merchantLabel.SetValue(sched and sched.DisplayText or "Não detectado")
		end

		-- Status Factory & Law
		factoryStageLabel.SetValue(lawFactoryFarm.CurrentStage or "Aguardando")
		factoryStatusLabel.SetValue(lawFactoryFarm.FactoryStatus)
		lawStatusLabel.SetValue(lawFactoryFarm.LawStatus)
		combatStatusLabel.SetValue(combatController.FSM:Get())

		task.wait(1)
	end
end)

-- ══════════════════════════════════════════════════════════════
--   GERENCIAMENTO DE RESPAWN
-- ══════════════════════════════════════════════════════════════

localPlayer.CharacterAdded:Connect(function(newChar)
	character = newChar
	smartFlight:SetCharacter(newChar)
	Logger.Info("Personagem respawnado. Referências atualizadas.")
	Notifications.Create(localPlayer.PlayerGui,
		"🔄 RESPAWN", "Personagem atualizado no framework", 3)
end)

-- ══════════════════════════════════════════════════════════════
--   ATALHO DE TECLADO: HOME = toggle do painel
-- ══════════════════════════════════════════════════════════════

local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Home then
		local panel = ui.Panel
		panel.Visible = not panel.Visible
	end
end)

-- ══════════════════════════════════════════════════════════════
--   BOOT COMPLETO
-- ══════════════════════════════════════════════════════════════

Logger.Success("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Logger.Success("  Framework carregado com sucesso!")
Logger.Success("  Pressione HOME para abrir/fechar o painel")
Logger.Success("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

Notifications.Create(
	localPlayer.PlayerGui,
	"⚡ ELITE AUTOMATION",
	"Framework v2.1 carregado!\nPressione HOME para abrir.",
	6,
	Color3.fromRGB(100, 130, 255)
)
