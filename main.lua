-- ============================================================
--  Elite Automation Framework v2.0 - Standalone Universal Bundle
--  Optimized for Grand Piece Online (GPO)
--  Compatible with: Xeno, Delta, Codex, Fluxus, Hydrogen, Arceus X
--  GitHub: https://github.com/blackxzin/script
--
--  Execute with:
--  loadstring(game:HttpGet("https://raw.githubusercontent.com/blackxzin/script/main/main.lua"))()
-- ============================================================

-- Previne execucao duplicada
if getgenv and getgenv()._EliteAutomationLoaded then
	warn("[EliteAutomation] Script ja esta em execucao!")
	return
end
if getgenv then getgenv()._EliteAutomationLoaded = true end

local executor = "Unknown"
if identifyexecutor then executor = identifyexecutor()
elseif getexecutorname then executor = getexecutorname()
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  [EliteAutomation v2.0] GPO Hub")
print("  Executor detectado: " .. tostring(executor))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

local __modules = {}
local __cache = {}

local function __register(name, fn)
	__modules[name] = fn
end

-- Require customizado que suporta tanto strings quanto referencias de Instancias
local function customRequire(target)
	local name = nil
	if type(target) == "string" then
		name = target
	elseif typeof and typeof(target) == "Instance" then
		local path = {}
		local cur = target
		while cur and cur ~= game do
			table.insert(path, 1, cur.Name)
			cur = cur.Parent
		end
		name = table.concat(path, ".")
		local eaIdx = string.find(name, "EliteAutomation")
		if eaIdx then
			name = string.sub(name, eaIdx)
		end
	end

	if name and __modules[name] then
		if __cache[name] == nil then
			__cache[name] = __modules[name](customRequire)
		end
		return __cache[name]
	end

	return getfenv(0).require(target)
end

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Core.Logger
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Core.Logger", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Core.Logger
--  Logging centralizado com níveis, cores e timestamps.
-- ============================================================

local Logger = {}

local LOG_LEVELS = {
	DEBUG   = { priority = 0, tag = "[DEBUG]",   color = "\27[36m" },   -- Ciano
	INFO    = { priority = 1, tag = "[INFO] ",   color = "\27[32m" },   -- Verde
	WARN    = { priority = 2, tag = "[WARN] ",   color = "\27[33m" },   -- Amarelo
	ERROR   = { priority = 3, tag = "[ERROR]",   color = "\27[31m" },   -- Vermelho
	SUCCESS = { priority = 4, tag = "[OK]   ",   color = "\27[35m" },   -- Magenta
}

local RESET = "\27[0m"
local MIN_LEVEL = LOG_LEVELS.DEBUG.priority

local function timestamp()
	return os.date("%H:%M:%S")
end

local function log(level, ...)
	if level.priority < MIN_LEVEL then return end
	local parts = {...}
	local msg = table.concat(parts, " ")
	print(string.format(
		"%s%s %s [%s] %s%s",
		level.color,
		level.tag,
		timestamp(),
		"EliteAuto",
		msg,
		RESET
	))
end

function Logger.Debug(...)   log(LOG_LEVELS.DEBUG,   ...) end
function Logger.Info(...)    log(LOG_LEVELS.INFO,    ...) end
function Logger.Warn(...)    log(LOG_LEVELS.WARN,    ...) end
function Logger.Error(...)   log(LOG_LEVELS.ERROR,   ...) end
function Logger.Success(...) log(LOG_LEVELS.SUCCESS, ...) end

function Logger.SetMinLevel(levelName)
	local lvl = LOG_LEVELS[levelName]
	if lvl then
		MIN_LEVEL = lvl.priority
	end
end

return Logger

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Core.PriorityManager
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Core.PriorityManager", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Core.PriorityManager
--  Gerencia prioridade de tarefas concorrentes.
--  Mais alto = mais prioritário. Apenas 1 tarefa ativa por vez.
-- ============================================================

local PriorityManager = {}
PriorityManager.__index = PriorityManager

function PriorityManager.new()
	local self = setmetatable({}, PriorityManager)

	self.ActiveTask    = nil   -- nome da tarefa atualmente ativa
	self.Tasks         = {}    -- [name] = { priority, onActivate, onDeactivate }

	return self
end

--[[
	Registra uma tarefa com prioridade.
	priority     : número (maior = mais importante)
	onActivate   : função chamada quando esta tarefa se torna ativa
	onDeactivate : função chamada quando perde o controle
]]
function PriorityManager:Register(name, priority, onActivate, onDeactivate)
	self.Tasks[name] = {
		Priority     = priority,
		OnActivate   = onActivate,
		OnDeactivate = onDeactivate,
		Active       = false,
	}
end

-- Pede para ativar uma tarefa; só ativa se tiver prioridade suficiente.
function PriorityManager:Request(name)
	local requestedTask = self.Tasks[name]
	if not requestedTask then return false end

	-- Sem tarefa ativa → ativa imediatamente
	if not self.ActiveTask then
		self.ActiveTask         = name
		requestedTask.Active    = true
		requestedTask.OnActivate()
		return true
	end

	-- Compara com tarefa atual
	local currentTask = self.Tasks[self.ActiveTask]
	if requestedTask.Priority > currentTask.Priority then
		-- Preempta a tarefa atual
		currentTask.Active = false
		currentTask.OnDeactivate()

		self.ActiveTask         = name
		requestedTask.Active    = true
		requestedTask.OnActivate()
		return true
	end

	return false -- sem prioridade suficiente
end

-- Libera a tarefa; deixa o sistema escolher a próxima mais prioritária ativa.
function PriorityManager:Release(name)
	local task = self.Tasks[name]
	if not task or not task.Active then return end

	task.Active = false
	task.OnDeactivate()

	if self.ActiveTask == name then
		self.ActiveTask = nil
	end
end

function PriorityManager:GetActive()
	return self.ActiveTask
end

function PriorityManager:IsActive(name)
	local task = self.Tasks[name]
	return task ~= nil and task.Active
end

return PriorityManager

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Core.StateMachine
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Core.StateMachine", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Core.StateMachine
--  Máquina de estados finitos com listeners e histórico.
-- ============================================================

local StateMachine = {}
StateMachine.__index = StateMachine

--[[
	Estados válidos do agente:
	  "Idle"     - Aguardando próxima ação
	  "Combat"   - Em combate ativo
	  "Moving"   - Deslocando até alvo
	  "Farming"  - Coletando item/fruta
	  "Fleeing"  - Fugindo de perigo
	  "Waiting"  - Aguardando cooldown (boss de tempo)
]]

function StateMachine.new(initialState)
	local self = setmetatable({}, StateMachine)

	self.State       = initialState
	self.PrevState   = nil
	self.Transitions = {}
	self.Listeners   = { OnEnter = {}, OnLeave = {} }
	self.History     = {}

	return self
end

function StateMachine:AddTransition(fromState, toState, condition)
	self.Transitions[fromState] = self.Transitions[fromState] or {}
	table.insert(self.Transitions[fromState], {
		To        = toState,
		Condition = condition,
	})
end

-- Registra callback ao ENTRAR em um estado
function StateMachine:OnEnter(state, callback)
	self.Listeners.OnEnter[state] = callback
end

-- Registra callback ao SAIR de um estado
function StateMachine:OnLeave(state, callback)
	self.Listeners.OnLeave[state] = callback
end

-- Força transição direta sem checar condições (uso interno controlado)
function StateMachine:ForceTransition(toState, ...)
	local prevState = self.State

	if self.Listeners.OnLeave[prevState] then
		self.Listeners.OnLeave[prevState](...)
	end

	table.insert(self.History, prevState)
	if #self.History > 10 then table.remove(self.History, 1) end

	self.PrevState = prevState
	self.State     = toState

	if self.Listeners.OnEnter[toState] then
		self.Listeners.OnEnter[toState](...)
	end
end

-- Avalia as condições registradas e faz transição automaticamente
function StateMachine:Update(...)
	local rules = self.Transitions[self.State]
	if not rules then return end

	for _, rule in ipairs(rules) do
		if rule.Condition(...) then
			self:ForceTransition(rule.To, ...)
			return
		end
	end
end

function StateMachine:Get()
	return self.State
end

function StateMachine:Is(state)
	return self.State == state
end

function StateMachine:WasIn(state)
	return self.PrevState == state
end

return StateMachine

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Core.TaskManager
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Core.TaskManager", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Core.TaskManager
--  Gerencia o ciclo de vida de tarefas (start/stop/toggle).
--  Cada tarefa pode ter um thread interno de loop.
-- ============================================================

local TaskManager = {}
TaskManager.__index = TaskManager

function TaskManager.new()
	local self = setmetatable({}, TaskManager)
	self.Tasks = {}   -- [name] = { Enabled, Start, Stop, Thread }
	return self
end

--[[
	Registra uma tarefa.
	name  : identificador único
	start : função a chamar ao habilitar
	stop  : função a chamar ao desabilitar
]]
function TaskManager:Register(name, startFn, stopFn)
	self.Tasks[name] = {
		Enabled = false,
		Start   = startFn,
		Stop    = stopFn,
		Thread  = nil,
	}
end

function TaskManager:SetEnabled(name, enabled)
	local t = self.Tasks[name]
	if not t then
		warn("[TaskManager] Tarefa não registrada:", name)
		return
	end

	if enabled and not t.Enabled then
		t.Enabled = true
		-- Executa em thread separada para não bloquear
		t.Thread = task.spawn(function()
			local ok, err = pcall(t.Start)
			if not ok then
				warn("[TaskManager] Erro ao iniciar '" .. name .. "':", err)
			end
		end)

	elseif not enabled and t.Enabled then
		t.Enabled = false
		local ok, err = pcall(t.Stop)
		if not ok then
			warn("[TaskManager] Erro ao parar '" .. name .. "':", err)
		end
		-- Cancela thread se ainda estiver rodando
		if t.Thread then
			task.cancel(t.Thread)
			t.Thread = nil
		end
	end
end

function TaskManager:Toggle(name)
	local t = self.Tasks[name]
	if t then
		self:SetEnabled(name, not t.Enabled)
	end
end

function TaskManager:IsEnabled(name)
	local t = self.Tasks[name]
	return t ~= nil and t.Enabled
end

-- Para todas as tarefas registradas
function TaskManager:StopAll()
	for name, t in pairs(self.Tasks) do
		if t.Enabled then
			self:SetEnabled(name, false)
		end
	end
end

return TaskManager

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Config.Settings
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Config.Settings", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Config.Settings
--  Configurações especializadas para Grand Piece Online (GPO).
-- ============================================================

return {

	-- ─── Gerais ───────────────────────────────────────────
	General = {
		GameName          = "Grand Piece Online",
		AntiDetectionMode = true,    -- Ativa jitters e movimentos humanizados
		AutoReconnect     = true,    -- Reconecta ao jogo em caso de kick
		DebugLogs         = false,   -- Imprime logs de debug no console
	},

	-- ─── Movimentação (SmartFlight & Anti-Mar) ─────────────
	Movement = {
		DefaultSpeed    = 52,        -- Studs/s base de voo (adequado para vastidão do mar de GPO)
		SpeedJitterMin  = -6,        -- Variação mínima de velocidade
		SpeedJitterMax  =  6,        -- Variação máxima de velocidade
		HoverOffset     = 25,        -- Altitude mínima acima do solo
		SeaFloorOffset  = 35,        -- Altitude segura acima do mar (anti-afogamento DF)
		SeaLevel        = 0,         -- Coordenada Y da superfície do mar em GPO
		TweenStyle      = Enum.EasingStyle.Sine,
		TweenDirection  = Enum.EasingDirection.InOut,
		DefaultDuration = 2.5,
		SafetyCheckRate = 0.1,       -- Checagem rápida de altitude para evitar contato com a água
	},

	-- ─── Combate (CombatController) ───────────────────────
	Combat = {
		UpdateInterval    = 0.1,     -- Hz do loop de combate
		AttackRange       = 18,      -- Distância máxima para ataque corpo-a-corpo / armas
		AttackIntervalMin = 0.40,    -- M1 swing interval mínimo
		AttackIntervalMax = 0.75,    -- M1 swing interval máximo com jitter humano
		MaxRetries        = 5,
		FleeHealthPct     = 0.20,    -- Foge se HP cair abaixo de 20%
		StaminaThreshold  = 0.15,    -- Preserva stamina para Geppo / esquiva em GPO
	},

	-- ─── Seleção de Alvo (TargetSelector) ─────────────────
	TargetSelector = {
		PreferLowHealth = true,      -- Foca alvos com menos HP
		BlacklistNPCs   = {          -- NPCs neutros e civis em GPO
			"Dummy",
			"Trainer",
			"Shopkeeper",
			"Shipwright",
			"Sailor",
			"Civilian",
			"Quest Giver",
		},
	},

	-- ─── Sistema de Bosses & Sea Events (GPO) ─────────────
	BossManager = {
		ScanInterval    = 2.0,       -- Segundos entre scans de boss no workspace
		AttackRadius    = 90,        -- Raio para engajar o boss

		-- Sea Events / Bosses de Mar (Prioridade em GPO)
		LocationBosses = {
			Kraken = {
				Name           = "Kraken",
				Aliases        = { "Red Kraken", "Blue Kraken", "Green Kraken", "Gold Kraken", "Purple Kraken" },
				Region         = { center = Vector3.new(0, 0, 0), radius = 10000 },
				SeaLevel       = 0,
				SafeAltitude   = 40,       -- Permanece suspenso a 40 studs do mar para evitar afogamento
				DiveProtection = true,     -- Anti-afundamento estrito
				RewardPeli     = 25000,
			},
			SeaBeast = {
				Name           = "Sea Beast",
				Aliases        = { "Sea Serpent", "Beast" },
				Region         = { center = Vector3.new(0, 0, 0), radius = 10000 },
				SeaLevel       = 0,
				SafeAltitude   = 38,
				DiveProtection = true,
				RewardPeli     = 20000,
			},
			GhostShip = {
				Name           = "Ghost Ship",
				Aliases        = { "Ghost Galleon", "Ghost Galeon" },
				Region         = { center = Vector3.new(0, 0, 0), radius = 10000 },
				SeaLevel       = 0,
				SafeAltitude   = 35,
				DiveProtection = true,
				RewardPeli     = 18000,
			},
			Megalodon = {
				Name           = "Megalodon",
				Region         = { center = Vector3.new(0, 0, 0), radius = 10000 },
				SeaLevel       = 0,
				SafeAltitude   = 35,
				DiveProtection = true,
				RewardPeli     = 15000,
			},
			MarineGalleon = {
				Name           = "Marine Galleon",
				Aliases        = { "Galleon", "Marine Ship", "Warship" },
				Region         = { center = Vector3.new(0, 0, 0), radius = 10000 },
				SeaLevel       = 0,
				SafeAltitude   = 32,
				DiveProtection = true,
				RewardPeli     = 12000,
			},
		},

		-- Bosses de Ilha e Mundiais do GPO (First Sea & Second Sea)
		TimedBosses = {
			-- ─ First Sea Bosses ─
			BanditBoss = {
				Name         = "Bandit Boss",
				Location     = Vector3.new(1050, 18, 1220),
				Island       = "Town of Beginnings",
				CooldownSecs = 300,
				RewardPeli   = 2000,
			},
			Lucid = {
				Name         = "Lucid",
				Location     = Vector3.new(-1150, 18, 1420),
				Island       = "Sandora",
				CooldownSecs = 600,
				RewardPeli   = 5000,
			},
			AxeHandLogan = {
				Name         = "Axe Hand Logan",
				Aliases      = { "Logan" },
				Location     = Vector3.new(-3800, 20, -4200),
				Island       = "Shell's Town",
				CooldownSecs = 900,
				RewardPeli   = 8000,
			},
			StarClown = {
				Name         = "Star Clown",
				Aliases      = { "Buggy" },
				Location     = Vector3.new(-820, 18, 830),
				Island       = "Orange Town",
				CooldownSecs = 900,
				RewardPeli   = 10000,
			},
			GorillaKing = {
				Name         = "Gorilla King",
				Location     = Vector3.new(-6500, 35, -2100),
				Island       = "Sphinx Island",
				CooldownSecs = 1200,
				RewardPeli   = 15000,
			},
			SawShark = {
				Name         = "Saw Shark",
				Aliases      = { "Arlong" },
				Location     = Vector3.new(1250, 18, -3420),
				Island       = "Shark Park",
				CooldownSecs = 1500,
				RewardPeli   = 20000,
			},
			HeadGuardian = {
				Name         = "Head Guardian",
				Location     = Vector3.new(-1200, 480, 5950),
				Island       = "Sky Castle",
				CooldownSecs = 1800,
				RewardPeli   = 25000,
			},
			Enel = {
				Name         = "Enel",
				Aliases      = { "Thunder God" },
				Location     = Vector3.new(-1200, 450, 6000),
				Island       = "Golden City (Skypiea)",
				CooldownSecs = 2700,  -- 45 min
				FlyToSky     = true,
				RewardPeli   = 45000,
			},
			Gravito = {
				Name         = "Gravito",
				Location     = Vector3.new(2800, 80, -3200),
				Island       = "Gravito's Fort",
				CooldownSecs = 2400,  -- 40 min
				RewardPeli   = 40000,
			},
			Neptune = {
				Name         = "Neptune",
				Location     = Vector3.new(7200, -300, 1100),
				Island       = "Fishman Island",
				CooldownSecs = 2400,
				RewardPeli   = 38000,
			},
			Ryu = {
				Name         = "Ryu",
				Location     = Vector3.new(7150, -290, 1180),
				Island       = "Fishman Island",
				CooldownSecs = 1800,
				RewardPeli   = 32000,
			},

			-- ─ Second Sea Bosses ─
			CrabKingCho = {
				Name         = "Crab King Cho",
				Aliases      = { "Cho" },
				Location     = Vector3.new(-1250, 25, -3150),
				Island       = "Desert Kingdom",
				CooldownSecs = 1200,
				RewardPeli   = 22000,
			},
			PharaohAkshan = {
				Name         = "Pharaoh Akshan",
				Aliases      = { "Akshan" },
				Location     = Vector3.new(-1400, 40, -3300),
				Island       = "Desert Kingdom",
				CooldownSecs = 2100,
				RewardPeli   = 38000,
			},
			Musashi = {
				Name         = "Musashi",
				Location     = Vector3.new(4100, 30, -1500),
				Island       = "Sashi Island",
				CooldownSecs = 2400,
				RewardPeli   = 42000,
			},
			GhostPrincess = {
				Name         = "Ghost Princess",
				Aliases      = { "Perona" },
				Location     = Vector3.new(-5300, 60, -7700),
				Island       = "Thriller Bark",
				CooldownSecs = 1500,
				RewardPeli   = 28000,
			},
			Ryuma = {
				Name         = "Ryuma",
				Location     = Vector3.new(-5400, 120, -7800),
				Island       = "Thriller Bark",
				CooldownSecs = 1800,  -- 30 min
				RewardPeli   = 35000,
			},
			Borj = {
				Name         = "Borj",
				Location     = Vector3.new(-5100, 45, -7500),
				Island       = "Thriller Bark",
				CooldownSecs = 1800,
				RewardPeli   = 30000,
			},
			SoulKing = {
				Name         = "Soul King",
				Aliases      = { "Brook" },
				Location     = Vector3.new(-5200, 50, -7600),
				Island       = "Thriller Bark",
				CooldownSecs = 2400,
				RewardPeli   = 40000,
			},
			Pica = {
				Name         = "Pica",
				Location     = Vector3.new(380, 160, -220),
				Island       = "Rose Kingdom",
				CooldownSecs = 2700,
				RewardPeli   = 55000,
			},
			Donmingo = {
				Name         = "Donmingo",
				Aliases      = { "Doflamingo" },
				Location     = Vector3.new(500, 210, -120),
				Island       = "Rose Kingdom (Mansion)",
				CooldownSecs = 3600,
				RewardPeli   = 70000,
			},
			Lucy = {
				Name         = "Lucy",
				Aliases      = { "Colosseum Champion" },
				Location     = Vector3.new(-600, 30, 5200),
				Island       = "Colosseum of Arc",
				CooldownSecs = 1800,
				RewardPeli   = 35000,
			},
		},

		-- Raid / Dungeon Bosses de GPO (ondas / eventos especiais)
		RaidBosses = {
			Moria = {
				Name        = "Moria",
				Aliases     = { "Moria, The Shadow King" },
				Location    = Vector3.new(-5500, 160, -8200),
				Island      = "Thriller Bark Castle",
				PhaseCount  = 2,
				WaveCount   = 5,
				RewardPeli  = 75000,
			},
			Baal = {
				Name        = "Ba'al",
				Location    = Vector3.new(0, 50, 0),
				PhaseCount  = 3,
				WaveCount   = 10,
				RewardPeli  = 100000,
			},
			ImpelDownWarden = {
				Name        = "Warden",
				Location    = Vector3.new(1500, -100, -5000),
				PhaseCount  = 4,
				WaveCount   = 25,
				RewardPeli  = 90000,
			},
		},
	},

	-- ─── Fruit Tracker (Spawns sob árvores / Notifier) ────
	FruitTracker = {
		ScanInterval    = 1.5,       -- Segundos entre scans de fruta no workspace
		AutoCollect     = true,      -- Voa até a fruta e coleta automaticamente
		MinRarity       = "Common",  -- Common, Rare, Legendary, Mythical
		NotifyOnDetect  = true,
		CollectRadius   = 5,
	},

	-- ─── Item Farm (Baús de GPO) ──────────────────────────
	ItemFarm = {
		ScanInterval = 1.8,
		ItemTags     = {
			"Chest",
			"Wooden Chest",
			"Bronze Chest",
			"Silver Chest",
			"Gold Chest",
			"Rare Chest",
			"Legendary Chest",
			"Mythical Chest",
			"Peli Pouch",
			"Peli",
			"Drop",
		},
	},

	-- ─── Merchant Tracker (Mercador Viajante) ────────────
	MerchantTracker = {
		ScanInterval   = 2.0,        -- Segundos entre scans do mercador no workspace
		NotifyOnSpawn  = true,       -- Notificação popup ao spawnar
		KnownIslands   = {
			["Desert Kingdom"]   = Vector3.new(-1200, 20, -3000),
			["Shells Town"]      = Vector3.new(-3800, 15, -4200),
			["Sphinx Island"]    = Vector3.new(-6500, 30, -2100),
			["Koki Island"]      = Vector3.new(1500, 15, 1200),
			["Marine Base G-1"]  = Vector3.new(2800, 80, -3200),
			["Orange Town"]      = Vector3.new(-800, 15, 800),
			["Baratie"]          = Vector3.new(-3100, 10, 4800),
			["Fishman Island"]   = Vector3.new(7200, -300, 1100),
			["Thriller Bark"]    = Vector3.new(-5400, 80, -7800),
		},
	},

	-- ─── Law & Factory Farm ──────────────────────────────
	LawFactoryFarm = {
		Factory = {
			Location        = Vector3.new(450, 120, -180),
			CoreHoverHeight = 14,       -- studs acima do Core (imune a ácido e chão tóxico)
			WaitHeight      = 200,      -- altitude de espera fora da fábrica
		},
		Law = {
			Location          = Vector3.new(-4716, 28, 1263),
			CombatHeight      = 12,     -- studs acima do Law (evita Tact e cortes de espada)
			ShamblesThreshold = 25,     -- distância de teleporte do Shambles para reposicionar
			AutoStartRaid     = true,
		},
	},

	-- ─── Notificações ─────────────────────────────────────
	Notifications = {
		Duration     = 5,
		MaxVisible   = 4,
		SlideInTime  = 0.3,
		SlideOutTime = 0.25,
	},

}

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.UI.Notifications
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.UI.Notifications", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: UI.Notifications
--  Sistema de notificações visuais no canto da tela.
--  Suporta cor customizada por raridade e fila limitada.
-- ============================================================

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local Notifications = {}
Notifications.__index = Notifications

-- ─── Configurações visuais ────────────────────────────────────
local NOTIF_WIDTH    = 280
local NOTIF_HEIGHT   = 70
local NOTIF_PADDING  = 8
local NOTIF_X_OFFSET = 15   -- distância da borda direita
local NOTIF_Y_START  = 80   -- distância do topo
local MAX_VISIBLE    = 4

local DEFAULT_BG     = Color3.fromRGB(15, 15, 25)
local DEFAULT_ACCENT = Color3.fromRGB(100, 200, 255)
local TEXT_COLOR     = Color3.fromRGB(240, 240, 255)
local ICON_SIZE      = 20

-- ─── Fila de notificações ativas ─────────────────────────────
local activeNotifs = {}   -- lista de frames na tela

-- ─── Repositiona todas as notificações ativas ────────────────
local function repositionAll(playerGui)
	for i, frame in ipairs(activeNotifs) do
		local targetY = NOTIF_Y_START + (i - 1) * (NOTIF_HEIGHT + NOTIF_PADDING)
		TweenService:Create(
			frame,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1, -(NOTIF_WIDTH + NOTIF_X_OFFSET), 0, targetY) }
		):Play()
	end
end

-- ─── Remove uma notificação da lista ─────────────────────────
local function removeNotif(frame)
	for i, f in ipairs(activeNotifs) do
		if f == frame then
			table.remove(activeNotifs, i)
			return
		end
	end
end

-- ─════════════════════════════════════════════════════════════
--   API PRINCIPAL: Notifications.Create
-- ═════════════════════════════════════════════════════════════

--[[
	playerGui  : PlayerGui do jogador local
	title      : string do título (ex: "🍎 FRUTA DETECTADA")
	message    : string da mensagem
	duration   : segundos visível (padrão: 5)
	accentColor: Color3 opcional (padrão: azul)
]]
function Notifications.Create(playerGui, title, message, duration, accentColor)
	if not playerGui then return end

	duration    = duration    or 5
	accentColor = accentColor or DEFAULT_ACCENT

	-- Garante que o ScreenGui existe
	local screenGui = playerGui:FindFirstChild("EliteNotifs")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name            = "EliteNotifs"
		screenGui.ResetOnSpawn    = false
		screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
		screenGui.DisplayOrder    = 999
		screenGui.Parent          = playerGui
	end

	-- Limita a MAX_VISIBLE notificações
	if #activeNotifs >= MAX_VISIBLE then
		local oldest = table.remove(activeNotifs, 1)
		oldest:Destroy()
	end

	-- ─── Frame principal ─────────────────────────────────────
	local frame = Instance.new("Frame")
	frame.Name             = "Notification"
	frame.Size             = UDim2.new(0, NOTIF_WIDTH, 0, NOTIF_HEIGHT)
	-- Começa fora da tela (à direita)
	frame.Position         = UDim2.new(1, 50, 0, NOTIF_Y_START)
	frame.BackgroundColor3 = DEFAULT_BG
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel  = 0
	frame.ClipsDescendants = true
	frame.ZIndex           = 10

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- ─── Barra de acento lateral ─────────────────────────────
	local accentBar = Instance.new("Frame")
	accentBar.Name             = "AccentBar"
	accentBar.Size             = UDim2.new(0, 4, 1, 0)
	accentBar.Position         = UDim2.new(0, 0, 0, 0)
	accentBar.BackgroundColor3 = accentColor
	accentBar.BorderSizePixel  = 0
	accentBar.ZIndex           = 11
	accentBar.Parent           = frame

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 4)
	accentCorner.Parent = accentBar

	-- ─── Título ──────────────────────────────────────────────
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name             = "Title"
	titleLabel.Size             = UDim2.new(1, -18, 0, 22)
	titleLabel.Position         = UDim2.new(0, 14, 0, 8)
	titleLabel.Text             = title
	titleLabel.TextColor3       = accentColor
	titleLabel.TextSize         = 13
	titleLabel.Font             = Enum.Font.GothamBold
	titleLabel.TextXAlignment   = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.ZIndex           = 12
	titleLabel.Parent           = frame

	-- ─── Mensagem ────────────────────────────────────────────
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name               = "Message"
	msgLabel.Size               = UDim2.new(1, -18, 0, 35)
	msgLabel.Position           = UDim2.new(0, 14, 0, 28)
	msgLabel.Text               = message
	msgLabel.TextColor3         = TEXT_COLOR
	msgLabel.TextSize           = 11
	msgLabel.Font               = Enum.Font.Gotham
	msgLabel.TextXAlignment     = Enum.TextXAlignment.Left
	msgLabel.TextWrapped        = true
	msgLabel.BackgroundTransparency = 1
	msgLabel.ZIndex             = 12
	msgLabel.Parent             = frame

	-- ─── Barra de progresso (timer) ─────────────────────────
	local progressBg = Instance.new("Frame")
	progressBg.Name             = "ProgressBg"
	progressBg.Size             = UDim2.new(1, 0, 0, 2)
	progressBg.Position         = UDim2.new(0, 0, 1, -2)
	progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	progressBg.BorderSizePixel  = 0
	progressBg.ZIndex           = 11
	progressBg.Parent           = frame

	local progressBar = Instance.new("Frame")
	progressBar.Name             = "Progress"
	progressBar.Size             = UDim2.new(1, 0, 1, 0)
	progressBar.BackgroundColor3 = accentColor
	progressBar.BorderSizePixel  = 0
	progressBar.ZIndex           = 12
	progressBar.Parent           = progressBg

	frame.Parent = screenGui
	table.insert(activeNotifs, frame)

	-- ─── Slide In ────────────────────────────────────────────
	local targetPos = UDim2.new(1, -(NOTIF_WIDTH + NOTIF_X_OFFSET), 0,
		NOTIF_Y_START + (#activeNotifs - 1) * (NOTIF_HEIGHT + NOTIF_PADDING))

	TweenService:Create(
		frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = targetPos }
	):Play()

	-- ─── Animação de progresso ────────────────────────────────
	TweenService:Create(
		progressBar,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(0, 0, 1, 0) }
	):Play()

	-- ─── Slide Out e destruição ──────────────────────────────
	task.delay(duration, function()
		if not frame or not frame.Parent then return end

		TweenService:Create(
			frame,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 50, 0, frame.Position.Y.Offset) }
		):Play()

		task.wait(0.3)
		removeNotif(frame)
		frame:Destroy()
		repositionAll(playerGui)
	end)
end

return Notifications

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.UI.Components
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.UI.Components", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: UI.Components
--  Componentes reutilizáveis de UI: Toggle, Slider, Label.
-- ============================================================

local TweenService = game:GetService("TweenService")

local Components = {}

-- ─── Paleta de cores ─────────────────────────────────────────
local C = {
	BG       = Color3.fromRGB(18, 18, 30),
	Surface  = Color3.fromRGB(25, 25, 42),
	Border   = Color3.fromRGB(45, 45, 75),
	Accent   = Color3.fromRGB(100, 130, 255),
	AccentOff = Color3.fromRGB(55, 55, 90),
	TextMain = Color3.fromRGB(230, 230, 255),
	TextSub  = Color3.fromRGB(130, 130, 180),
	Success  = Color3.fromRGB(80, 220, 130),
	Danger   = Color3.fromRGB(255, 80, 100),
}

-- ─── Utilitário: cria UICorner ────────────────────────────────
local function corner(radius, parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- ─════════════════════════════════════════════════════════════
--   Toggle Button
-- ═════════════════════════════════════════════════════════════

--[[
	Cria um toggle (on/off) dentro de um frame pai.

	parent   : Frame container
	label    : texto descritivo
	callback : function(enabled: bool) chamada ao mudar estado
	default  : bool (estado inicial, padrão false)

	Retorna { SetEnabled = function(bool) }
]]
function Components.CreateToggle(parent, label, callback, default)
	local enabled = default or false

	-- ─ Row container ─
	local row = Instance.new("Frame")
	row.Name                  = "Toggle_" .. label
	row.Size                  = UDim2.new(1, -10, 0, 38)
	row.BackgroundColor3      = C.Surface
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel       = 0
	row.LayoutOrder           = 1
	corner(8, row)
	row.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color     = C.Border
	stroke.Thickness = 1
	stroke.Parent    = row

	-- ─ Label ─
	local lbl = Instance.new("TextLabel")
	lbl.Name              = "Label"
	lbl.Size              = UDim2.new(1, -60, 1, 0)
	lbl.Position          = UDim2.new(0, 12, 0, 0)
	lbl.Text              = label
	lbl.TextColor3        = C.TextMain
	lbl.TextSize          = 13
	lbl.Font              = Enum.Font.GothamMedium
	lbl.TextXAlignment    = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1
	lbl.Parent = row

	-- ─ Track (fundo do toggle) ─
	local track = Instance.new("Frame")
	track.Name             = "Track"
	track.Size             = UDim2.new(0, 42, 0, 22)
	track.Position         = UDim2.new(1, -54, 0.5, -11)
	track.BackgroundColor3 = enabled and C.Accent or C.AccentOff
	track.BorderSizePixel  = 0
	corner(11, track)
	track.Parent = row

	-- ─ Thumb (bolinha) ─
	local thumb = Instance.new("Frame")
	thumb.Name             = "Thumb"
	thumb.Size             = UDim2.new(0, 16, 0, 16)
	thumb.Position         = enabled
		and UDim2.new(0, 23, 0.5, -8)
		or  UDim2.new(0, 3, 0.5, -8)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	thumb.BorderSizePixel  = 0
	corner(8, thumb)
	thumb.Parent = track

	-- ─ Animação do toggle ─
	local function animate(state)
		TweenService:Create(track, TweenInfo.new(0.18, Enum.EasingStyle.Sine),
			{ BackgroundColor3 = state and C.Accent or C.AccentOff }
		):Play()
		TweenService:Create(thumb, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = state
				and UDim2.new(0, 23, 0.5, -8)
				or  UDim2.new(0, 3, 0.5, -8)
			}
		):Play()
	end

	-- ─ Clique ─
	local button = Instance.new("TextButton")
	button.Size               = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text               = ""
	button.Parent             = row

	button.MouseButton1Click:Connect(function()
		enabled = not enabled
		animate(enabled)
		if callback then
			task.spawn(callback, enabled)
		end
	end)

	-- ─ Hover effect ─
	button.MouseEnter:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.1),
			{ BackgroundTransparency = 0.1 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(row, TweenInfo.new(0.1),
			{ BackgroundTransparency = 0.3 }):Play()
	end)

	-- ─ API pública ─
	return {
		SetEnabled = function(state)
			enabled = state
			animate(state)
		end,
		IsEnabled = function()
			return enabled
		end,
		Frame = row,
	}
end

-- ─════════════════════════════════════════════════════════════
--   Label de Status
-- ═════════════════════════════════════════════════════════════

function Components.CreateStatusLabel(parent, labelText, valueText)
	local row = Instance.new("Frame")
	row.Name             = "Status_" .. labelText
	row.Size             = UDim2.new(1, -10, 0, 28)
	row.BackgroundTransparency = 1
	row.BorderSizePixel  = 0
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size             = UDim2.new(0.5, 0, 1, 0)
	lbl.Text             = labelText
	lbl.TextColor3       = C.TextSub
	lbl.TextSize         = 12
	lbl.Font             = Enum.Font.Gotham
	lbl.TextXAlignment   = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1
	lbl.Parent = row

	local val = Instance.new("TextLabel")
	val.Name             = "Value"
	val.Size             = UDim2.new(0.5, 0, 1, 0)
	val.Position         = UDim2.new(0.5, 0, 0, 0)
	val.Text             = valueText or "—"
	val.TextColor3       = C.TextMain
	val.TextSize         = 12
	val.Font             = Enum.Font.GothamBold
	val.TextXAlignment   = Enum.TextXAlignment.Right
	val.BackgroundTransparency = 1
	val.Parent = row

	return {
		SetValue = function(text)
			val.Text = tostring(text)
		end,
		Frame = row,
	}
end

-- ─════════════════════════════════════════════════════════════
--   Separador visual
-- ═════════════════════════════════════════════════════════════

function Components.CreateSeparator(parent)
	local sep = Instance.new("Frame")
	sep.Size             = UDim2.new(1, -10, 0, 1)
	sep.BackgroundColor3 = C.Border
	sep.BorderSizePixel  = 0
	sep.Parent = parent
	return sep
end

-- ─════════════════════════════════════════════════════════════
--   Botão de ação simples
-- ═════════════════════════════════════════════════════════════

function Components.CreateButton(parent, label, callback)
	local btn = Instance.new("TextButton")
	btn.Name             = "Btn_" .. label
	btn.Size             = UDim2.new(1, -10, 0, 34)
	btn.BackgroundColor3 = C.Accent
	btn.Text             = label
	btn.TextColor3       = Color3.fromRGB(255, 255, 255)
	btn.TextSize         = 13
	btn.Font             = Enum.Font.GothamBold
	btn.BorderSizePixel  = 0
	corner(8, btn)
	btn.Parent = parent

	btn.MouseButton1Click:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.08),
			{ BackgroundColor3 = Color3.fromRGB(70, 100, 220) }):Play()
		task.wait(0.1)
		TweenService:Create(btn, TweenInfo.new(0.15),
			{ BackgroundColor3 = C.Accent }):Play()
		if callback then task.spawn(callback) end
	end)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12),
			{ BackgroundColor3 = Color3.fromRGB(120, 150, 255) }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12),
			{ BackgroundColor3 = C.Accent }):Play()
	end)

	return btn
end

return Components

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.UI.TabManager
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.UI.TabManager", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: UI.TabManager
--  Gerencia múltiplas abas (tabs) de conteúdo no painel.
--  Ao clicar em uma aba, oculta as demais com animação.
-- ============================================================

local TweenService = game:GetService("TweenService")

local TabManager = {}
TabManager.__index = TabManager

-- ─── Cores ───────────────────────────────────────────────────
local C_ACTIVE   = Color3.fromRGB(100, 130, 255)
local C_INACTIVE = Color3.fromRGB(45, 45, 75)
local C_TEXT_ON  = Color3.fromRGB(255, 255, 255)
local C_TEXT_OFF = Color3.fromRGB(140, 140, 190)

function TabManager.new()
	local self = setmetatable({}, TabManager)
	self.Tabs      = {}       -- [name] = { button, content }
	self.ActiveTab = nil
	return self
end

--[[
	Registra uma aba.
	name    : string identificador
	button  : TextButton da aba (no header)
	content : Frame com o conteúdo a exibir
]]
function TabManager:AddTab(name, button, content)
	self.Tabs[name] = {
		Button  = button,
		Content = content,
	}

	-- Esconde o conteúdo por padrão
	content.Visible = false

	-- Conecta o clique
	button.MouseButton1Click:Connect(function()
		self:Switch(name)
	end)
end

function TabManager:Switch(name)
	local target = self.Tabs[name]
	if not target then return end

	-- Desativa a aba atual
	for tabName, tab in pairs(self.Tabs) do
		local isTarget = (tabName == name)

		-- Anima o botão
		TweenService:Create(
			tab.Button,
			TweenInfo.new(0.18, Enum.EasingStyle.Sine),
			{
				BackgroundColor3 = isTarget and C_ACTIVE or C_INACTIVE,
				TextColor3       = isTarget and C_TEXT_ON or C_TEXT_OFF,
			}
		):Play()

		-- Mostra/oculta conteúdo
		if isTarget then
			tab.Content.Visible          = true
			tab.Content.BackgroundTransparency = 1
			TweenService:Create(
				tab.Content,
				TweenInfo.new(0.15, Enum.EasingStyle.Sine),
				{ BackgroundTransparency = 0 }
			):Play()
		else
			tab.Content.Visible = false
		end
	end

	self.ActiveTab = name
end

-- Ativa a primeira aba registrada
function TabManager:ShowFirst()
	local firstName = nil
	for name in pairs(self.Tabs) do
		firstName = name
		break
	end
	if firstName then
		self:Switch(firstName)
	end
end

function TabManager:GetActive()
	return self.ActiveTab
end

return TabManager

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.UI.MainUI
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.UI.MainUI", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: UI.MainUI
--  Painel principal da interface de usuário.
--  Design escuro com glassmorphism, drag-to-move e abas.
-- ============================================================

local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players        = game:GetService("Players")

local MainUI = {}
MainUI.__index = MainUI

-- ─── Paleta ───────────────────────────────────────────────────
local C = {
	BG       = Color3.fromRGB(10, 10, 20),
	Header   = Color3.fromRGB(15, 15, 30),
	Surface  = Color3.fromRGB(20, 20, 38),
	Border   = Color3.fromRGB(50, 50, 90),
	Accent   = Color3.fromRGB(100, 130, 255),
	AccentGlow = Color3.fromRGB(80, 110, 230),
	Text     = Color3.fromRGB(230, 230, 255),
	TextSub  = Color3.fromRGB(130, 130, 180),
	TabInactive = Color3.fromRGB(35, 35, 62),
	TabActive   = Color3.fromRGB(100, 130, 255),
}

local PANEL_W = 340
local PANEL_H = 440
local TAB_H   = 32
local HEADER_H = 50

-- ─── Cria UICorner ────────────────────────────────────────────
local function corner(r, p)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

-- ─── Cria UIStroke ────────────────────────────────────────────
local function stroke(color, thick, p)
	local s = Instance.new("UIStroke")
	s.Color     = color
	s.Thickness = thick
	s.Parent    = p
end

-- ─── Implementa drag-to-move ─────────────────────────────────
local function makeDraggable(frame, handle)
	local dragging   = false
	local dragStart  = nil
	local startPos   = nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = input.Position
			startPos  = frame.Position
		end
	end)

	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- ─── Construtor ──────────────────────────────────────────────
function MainUI.new()
	local self = setmetatable({}, MainUI)

	local localPlayer = Players.LocalPlayer
	local playerGui   = localPlayer:WaitForChild("PlayerGui")

	-- ─ ScreenGui ─
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "EliteAutomationUI"
	screenGui.ResetOnSpawn   = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder   = 100
	screenGui.Parent         = playerGui
	self.ScreenGui = screenGui

	-- ─ Painel principal ─
	local panel = Instance.new("Frame")
	panel.Name             = "Panel"
	panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
	panel.Position         = UDim2.new(0, 20, 0.5, -PANEL_H / 2)
	panel.BackgroundColor3 = C.BG
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel  = 0
	panel.Visible          = false
	corner(12, panel)
	stroke(C.Border, 1.5, panel)
	panel.Parent = screenGui
	self.Panel = panel

	-- ─ Header ─
	local header = Instance.new("Frame")
	header.Name             = "Header"
	header.Size             = UDim2.new(1, 0, 0, HEADER_H)
	header.BackgroundColor3 = C.Header
	header.BorderSizePixel  = 0
	corner(12, header)
	header.Parent = panel

	-- Mascara canto inferior do header para ficar quadrado embaixo
	local headerMask = Instance.new("Frame")
	headerMask.Size             = UDim2.new(1, 0, 0, 12)
	headerMask.Position         = UDim2.new(0, 0, 1, -12)
	headerMask.BackgroundColor3 = C.Header
	headerMask.BorderSizePixel  = 0
	headerMask.Parent = header

	-- ─ Logo / Título ─
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size           = UDim2.new(1, -100, 1, 0)
	titleLabel.Position       = UDim2.new(0, 15, 0, 0)
	titleLabel.Text           = "⚡ ELITE AUTOMATION"
	titleLabel.TextColor3     = C.Accent
	titleLabel.TextSize       = 16
	titleLabel.Font           = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.BackgroundTransparency = 1
	titleLabel.Parent = header

	-- ─ Subtítulo/versão ─
	local subLabel = Instance.new("TextLabel")
	subLabel.Size           = UDim2.new(1, -100, 0, 14)
	subLabel.Position       = UDim2.new(0, 15, 0, 30)
	subLabel.Text           = "Grand Piece Online (GPO) v2.0"
	subLabel.TextColor3     = C.TextSub
	subLabel.TextSize       = 10
	subLabel.Font           = Enum.Font.Gotham
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.BackgroundTransparency = 1
	subLabel.Parent = header

	-- ─ Botão minimizar (–) ─
	local minimizeBtn = Instance.new("TextButton")
	minimizeBtn.Name             = "Minimize"
	minimizeBtn.Size             = UDim2.new(0, 26, 0, 26)
	minimizeBtn.Position         = UDim2.new(1, -60, 0.5, -13)
	minimizeBtn.Text             = "–"
	minimizeBtn.TextColor3       = C.TextSub
	minimizeBtn.TextSize         = 18
	minimizeBtn.Font             = Enum.Font.GothamBold
	minimizeBtn.BackgroundColor3 = C.Surface
	minimizeBtn.BorderSizePixel  = 0
	corner(6, minimizeBtn)
	minimizeBtn.Parent = header

	-- ─ Botão fechar (×) ─
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name             = "Close"
	closeBtn.Size             = UDim2.new(0, 26, 0, 26)
	closeBtn.Position         = UDim2.new(1, -30, 0.5, -13)
	closeBtn.Text             = "×"
	closeBtn.TextColor3       = Color3.fromRGB(255, 80, 100)
	closeBtn.TextSize         = 18
	closeBtn.Font             = Enum.Font.GothamBold
	closeBtn.BackgroundColor3 = C.Surface
	closeBtn.BorderSizePixel  = 0
	corner(6, closeBtn)
	closeBtn.Parent = header

	-- ─ Funcionalidade dos botões ─
	local minimized = false
	local contentArea

	minimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if contentArea then
			contentArea.Visible = not minimized
		end
		TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Sine),
			{ Size = minimized
				and UDim2.new(0, PANEL_W, 0, HEADER_H)
				or  UDim2.new(0, PANEL_W, 0, PANEL_H)
			}
		):Play()
		minimizeBtn.Text = minimized and "+" or "–"
	end)

	closeBtn.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	-- ─ Drag ─
	makeDraggable(panel, header)

	-- ─ Tab Bar ─
	local tabBar = Instance.new("Frame")
	tabBar.Name             = "TabBar"
	tabBar.Size             = UDim2.new(1, 0, 0, TAB_H)
	tabBar.Position         = UDim2.new(0, 0, 0, HEADER_H)
	tabBar.BackgroundColor3 = C.Header
	tabBar.BorderSizePixel  = 0
	tabBar.Parent = panel
	self.TabBar = tabBar

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder     = Enum.SortOrder.LayoutOrder
	tabLayout.Parent        = tabBar

	-- ─ Content Area ─
	local content = Instance.new("ScrollingFrame")
	content.Name                 = "ContentArea"
	content.Size                 = UDim2.new(1, 0, 1, -(HEADER_H + TAB_H + 8))
	content.Position             = UDim2.new(0, 0, 0, HEADER_H + TAB_H)
	content.BackgroundTransparency = 1
	content.BorderSizePixel      = 0
	content.ScrollBarThickness   = 3
	content.ScrollBarImageColor3 = C.Accent
	content.CanvasSize           = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize  = Enum.AutomaticSize.Y
	content.Parent = panel
	self.ContentArea = content
	contentArea = content

	-- ─ Layout do content ─
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder   = Enum.SortOrder.LayoutOrder
	contentLayout.Padding     = UDim.new(0, 6)
	contentLayout.Parent      = content

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingLeft   = UDim.new(0, 8)
	contentPadding.PaddingRight  = UDim.new(0, 8)
	contentPadding.PaddingTop    = UDim.new(0, 8)
	contentPadding.PaddingBottom = UDim.new(0, 8)
	contentPadding.Parent        = content

	self._tabButtons = {}
	self._tabFrames  = {}
	self._tabCount   = 0

	return self
end

-- ─── Cria botão de aba ────────────────────────────────────────
function MainUI:CreateTabButton(name)
	self._tabCount = self._tabCount + 1

	local tabW = math.floor(PANEL_W / 4)  -- 4 abas por padrão

	local btn = Instance.new("TextButton")
	btn.Name             = "Tab_" .. name
	btn.Size             = UDim2.new(0, tabW, 1, 0)
	btn.BackgroundColor3 = C.TabInactive
	btn.Text             = name
	btn.TextColor3       = C.TextSub
	btn.TextSize         = 11
	btn.Font             = Enum.Font.GothamMedium
	btn.BorderSizePixel  = 0
	btn.LayoutOrder      = self._tabCount
	btn.Parent           = self.TabBar

	table.insert(self._tabButtons, btn)
	return btn
end

-- ─── Cria frame de conteúdo de aba ───────────────────────────
function MainUI:CreateTabFrame()
	local frame = Instance.new("Frame")
	frame.Name                   = "TabContent_" .. tostring(#self._tabFrames + 1)
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel        = 0
	frame.Visible                = false
	frame.Parent                 = self.ContentArea

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding   = UDim.new(0, 6)
	layout.Parent    = frame

	table.insert(self._tabFrames, frame)
	return frame
end

-- ─── Abre o painel com animação ──────────────────────────────
function MainUI:Open()
	self.Panel.Visible = true
	self.Panel.BackgroundTransparency = 1
	TweenService:Create(
		self.Panel,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.05 }
	):Play()
end

function MainUI:Close()
	TweenService:Create(
		self.Panel,
		TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	):Play()
	task.delay(0.22, function()
		self.Panel.Visible = false
	end)
end

return MainUI

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Combat.TargetSelector
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Combat.TargetSelector", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Combat.TargetSelector
--  Seleciona o melhor alvo dentro de um raio, com filtros e
--  sistema de blacklist para NPCs amigáveis.
-- ============================================================

local Players = game:GetService("Players")

local TargetSelector = {}
TargetSelector.__index = TargetSelector

function TargetSelector.new(settings)
	local self = setmetatable({}, TargetSelector)

	self.AttackRange     = (settings and settings.AttackRange)    or 18
	self.PreferLowHealth = (settings and settings.PreferLowHealth) or true
	self.Blacklist       = {}

	-- Popula blacklist a partir da config
	if settings and settings.BlacklistNPCs then
		for _, name in ipairs(settings.BlacklistNPCs) do
			self.Blacklist[name] = true
		end
	end

	return self
end

-- Verifica se um modelo é um NPC/humanoid válido para atacar
function TargetSelector:_isValidEnemy(model, playerChar)
	if not model or not model.Parent then return false end
	if model == playerChar then return false end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	if humanoid.Health <= 0 then return false end

	-- Não atacar outros players
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character == model then return false end
	end

	-- Checa blacklist por nome do modelo
	if self.Blacklist[model.Name] then return false end

	return true
end

-- Retorna o HumanoidRootPart do modelo ou nil
local function getRoot(model)
	return model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildOfClass("BasePart")
end

--[[
	Scanneia workspace:GetDescendants() (ou um folder específico)
	e retorna o melhor alvo (mais próximo ou menor HP).

	originPos : Vector3 do personagem local
	filter    : função opcional(model) -> bool para filtros extras
]]
function TargetSelector:Select(originPos, filter)
	local playerChar = Players.LocalPlayer.Character

	local bestModel  = nil
	local bestScore  = math.huge  -- menor score = melhor

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and self:_isValidEnemy(obj, playerChar) then
			if (not filter) or filter(obj) then
				local root = getRoot(obj)
				if root then
					local dist = (root.Position - originPos).Magnitude
					if dist <= self.AttackRange then
						local hum    = obj:FindFirstChildOfClass("Humanoid")
						local hpRatio = hum and (hum.Health / math.max(hum.MaxHealth, 1)) or 1

						-- Score: distância ponderada com HP (prefere feridos)
						local score = self.PreferLowHealth
							and (dist * 0.6 + hpRatio * 100 * 0.4)
							or  dist

						if score < bestScore then
							bestScore = score
							bestModel = obj
						end
					end
				end
			end
		end
	end

	return bestModel
end

-- Retorna a humanoid do melhor alvo, se existir
function TargetSelector:SelectHumanoid(originPos, filter)
	local model = self:Select(originPos, filter)
	if model then
		return model:FindFirstChildOfClass("Humanoid"), model
	end
	return nil, nil
end

function TargetSelector:SetAttackRange(range)
	self.AttackRange = range
end

function TargetSelector:AddToBlacklist(name)
	self.Blacklist[name] = true
end

function TargetSelector:RemoveFromBlacklist(name)
	self.Blacklist[name] = nil
end

return TargetSelector

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Combat.CombatController
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Combat.CombatController", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Combat.CombatController
--  Motor de combate com AttackInterval jitterizado,
--  StateMachine de estados e proteção de fuga (flee).
-- ============================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")

-- Módulos internos
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle Mode] Root redirecionado
local StateMachine  = customRequire("EliteAutomation.Core.StateMachine")
local TargetSelector = customRequire("EliteAutomation.Combat.TargetSelector")
local Logger        = customRequire("EliteAutomation.Core.Logger")

local CombatController = {}
CombatController.__index = CombatController

-- ─── Jitter helper ───────────────────────────────────────────
local function jitter(min, max)
	return min + math.random() * (max - min)
end

function CombatController.new(settings)
	local self = setmetatable({}, CombatController)

	self.Settings       = settings or {}
	self.UpdateInterval = self.Settings.UpdateInterval    or 0.1
	self.AttackMin      = self.Settings.AttackIntervalMin or 0.40
	self.AttackMax      = self.Settings.AttackIntervalMax or 0.75
	self.AttackRange    = self.Settings.AttackRange       or 18
	self.FleeHealth     = self.Settings.FleeHealthPct     or 0.15
	self.StaminaThreshold = self.Settings.StaminaThreshold or 0.15
	self.MaxRetries     = self.Settings.MaxRetries        or 5

	-- Recursos Especializados de GPO (Haki, Stamina e Grip)
	self.AutoBusoHaki   = self.Settings.AutoBusoHaki ~= false    -- Ativa Busoshoku Haki ('J')
	self.AutoKenHaki    = self.Settings.AutoKenHaki or false     -- Ativa Kenbunshoku Haki ('K')
	self.AutoGrip       = self.Settings.AutoGrip ~= false        -- Executa alvos nocauteados ('B')
	self._lastHakiCheck = 0
	self._lastGripCheck = 0

	self.Selector       = TargetSelector.new(settings)
	self.FSM            = StateMachine.new("Idle")
	self.Target         = nil
	self.RetryCount     = 0
	self._running       = false
	self._thread        = nil
	self._lastAttack    = 0
	self._nextInterval  = jitter(self.AttackMin, self.AttackMax)

	-- Callbacks externos (podem ser sobrescritos)
	self.OnTargetFound  = nil   -- function(model)
	self.OnTargetLost   = nil   -- function()
	self.OnFlee         = nil   -- function()

	self:_setupFSM()

	return self
end

-- ─── Configura transições da máquina de estados ───────────────
function CombatController:_setupFSM()
	local fsm = self.FSM

	-- Idle → Combat : existe alvo no range
	fsm:AddTransition("Idle", "Combat", function()
		return self.Target ~= nil
	end)

	-- Combat → Idle : alvo morto / sumiu
	fsm:AddTransition("Combat", "Idle", function()
		return self.Target == nil
			or not self.Target.Parent
			or self:_isTargetDead()
	end)

	-- Combat → Fleeing : HP do player muito baixo
	fsm:AddTransition("Combat", "Fleeing", function()
		return self:_shouldFlee()
	end)

	-- Fleeing → Idle : HP recuperado
	fsm:AddTransition("Fleeing", "Idle", function()
		return not self:_shouldFlee()
	end)

	fsm:OnEnter("Combat", function()
		Logger.Info("CombatController → Combat | Alvo:", self.Target and self.Target.Name)
		if self.OnTargetFound and self.Target then
			self.OnTargetFound(self.Target)
		end
	end)

	fsm:OnEnter("Idle", function()
		Logger.Info("CombatController → Idle")
		self.Target = nil
		if self.OnTargetLost then self.OnTargetLost() end
	end)

	fsm:OnEnter("Fleeing", function()
		Logger.Warn("CombatController → Fleeing! HP crítico.")
		if self.OnFlee then self.OnFlee() end
	end)
end

-- ─── Helpers de estado ────────────────────────────────────────
function CombatController:_getLocalChar()
	return Players.LocalPlayer and Players.LocalPlayer.Character
end

function CombatController:_getLocalRoot()
	local char = self:_getLocalChar()
	return char and char:FindFirstChild("HumanoidRootPart")
end

function CombatController:_getLocalHumanoid()
	local char = self:_getLocalChar()
	return char and char:FindFirstChildOfClass("Humanoid")
end

function CombatController:_isTargetDead()
	if not self.Target or not self.Target.Parent then return true end
	local hum = self.Target:FindFirstChildOfClass("Humanoid")
	return hum == nil or hum.Health <= 0
end

function CombatController:_shouldFlee()
	local hum = self:_getLocalHumanoid()
	if not hum then return false end
	return (hum.Health / math.max(hum.MaxHealth, 1)) <= self.FleeHealth
end

function CombatController:_distToTarget()
	local root   = self:_getLocalRoot()
	local tRoot  = self.Target and self.Target:FindFirstChild("HumanoidRootPart")
	if not root or not tRoot then return math.huge end
	return (tRoot.Position - root.Position).Magnitude
end

function CombatController:_triggerKey(keyCode)
	local vim = game:GetService("VirtualInputManager")
	if vim then
		pcall(function()
			vim:SendKeyEvent(true, keyCode, false, game)
			task.wait(0.04)
			vim:SendKeyEvent(false, keyCode, false, game)
		end)
	end
end

-- ─── Auto-Haki (Busoshoku 'J' & Kenbunshoku 'K') no GPO ────────
function CombatController:_checkHaki()
	local now = os.clock()
	if (now - self._lastHakiCheck) < 3.0 then return end
	self._lastHakiCheck = now

	if self.AutoBusoHaki then
		-- Ativa Haki do Armamento para causar dano em Logias e amplificar DPS
		self:_triggerKey(Enum.KeyCode.J)
	end

	if self.AutoKenHaki then
		-- Ativa Haki da Observação para esquiva automática
		self:_triggerKey(Enum.KeyCode.K)
	end
end

-- ─── Auto-Grip ('B' key no GPO para executar alvos) ───────────
function CombatController:_checkGrip()
	if not self.AutoGrip or not self.Target then return end
	local now = os.clock()
	if (now - self._lastGripCheck) < 0.5 then return end

	local hum = self.Target:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then
		self._lastGripCheck = now
		self:_triggerKey(Enum.KeyCode.B)
	end
end

-- ─── Obtém Stamina atual do personagem no GPO ─────────────────
function CombatController:_getStaminaPct()
	local char = self:_getLocalChar()
	if char then
		local stam = char:GetAttribute("Stamina") or char:GetAttribute("MaxStamina")
		local maxStam = char:GetAttribute("MaxStamina") or 100
		if type(stam) == "number" and type(maxStam) == "number" and maxStam > 0 then
			return stam / maxStam
		end
	end
	return 1.0
end

-- ─── Executa um ataque (simula clique na hitbox com regulação) ──
function CombatController:_performAttack()
	local char  = self:_getLocalChar()
	local tRoot = self.Target and self.Target:FindFirstChild("HumanoidRootPart")
	if not char or not tRoot then return end

	-- Regulação de Stamina: Se a stamina estiver crítica (<15%), desacelera ataques para evitar Guard Break
	local stamPct = self:_getStaminaPct()
	if stamPct < self.StaminaThreshold then
		task.wait(0.3)
	end

	-- Vira o personagem para o alvo antes de atacar
	local charRoot = char:FindFirstChild("HumanoidRootPart")
	if charRoot then
		charRoot.CFrame = CFrame.lookAt(charRoot.Position, tRoot.Position)
	end

	-- Garante que Haki esteja ativo antes de atacar
	self:_checkHaki()

	-- Em Grand Piece Online (GPO), ataques corpo-a-corpo e armas usam M1 (Mouse1).
	local vim = game:GetService("VirtualInputManager")
	if vim then
		vim:SendMouseButtonEvent(0, 0, 0, true,  game, 1)
		task.wait(0.04)
		vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
	end

	-- Executa grip se o alvo estiver caído
	self:_checkGrip()

	self._lastAttack   = os.clock()
	self._nextInterval = jitter(self.AttackMin, self.AttackMax)
	Logger.Debug("Attack fired | next in", string.format("%.2fs", self._nextInterval))
end

-- ─── Loop principal de combate ────────────────────────────────
function CombatController:_loop()
	while self._running do
		local root = self:_getLocalRoot()

		-- Atualiza FSM
		self.FSM:Update()

		local state = self.FSM:Get()

		if state == "Idle" then
			-- Procura alvo novo
			if root then
				local model = self.Selector:Select(root.Position)
				if model then
					self.Target     = model
					self.RetryCount = 0
				end
			end

		elseif state == "Combat" then
			if self:_isTargetDead() then
				self.RetryCount = self.RetryCount + 1
				self.Target     = nil
				Logger.Info("Alvo eliminado! Total retries:", self.RetryCount)
			else
				-- Ataca se o intervalo passou e está no range
				local now  = os.clock()
				local dist = self:_distToTarget()

				if dist <= self.AttackRange then
					if (now - self._lastAttack) >= self._nextInterval then
						self:_performAttack()
					end
				else
					-- Alvo fora do range mas existe — tenta de novo
					self.RetryCount = self.RetryCount + 1
					if self.RetryCount > self.MaxRetries then
						Logger.Warn("Alvo inalcançável após", self.MaxRetries, "tentativas. Descartando.")
						self.Target = nil
					end
				end
			end

		elseif state == "Fleeing" then
			-- Em fuga, não ataca; aguarda HP subir
			task.wait(0.5)
		end

		task.wait(self.UpdateInterval)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function CombatController:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
	Logger.Info("CombatController iniciado.")
end

function CombatController:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	self.Target = nil
	self.FSM:ForceTransition("Idle")
	Logger.Info("CombatController parado.")
end

-- Força um alvo específico (usado pelo BossManager)
function CombatController:SetTarget(model)
	self.Target     = model
	self.RetryCount = 0
	if self.FSM:Get() ~= "Combat" then
		self.FSM:ForceTransition("Combat")
	end
end

function CombatController:GetState()
	return self.FSM:Get()
end

return CombatController

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Movement.SmartFlight
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Movement.SmartFlight", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Movement.SmartFlight
--  Sistema de Voo e Tween de Alta Eficácia para GPO:
--  - Noclip contínuo via RunService.Stepped (elimina flings e colisões)
--  - Neutralização de inércia e gravidade (zero AssemblyLinearVelocity)
--  - Trajetória em 3 fases (Subida Segura → Cruzeiro Horizontal → Descida)
--  - Proteção estrita anti-mar (impede afogamento de usuários de fruta)
-- ============================================================

local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local Players       = game:GetService("Players")

local SmartFlight = {}
SmartFlight.__index = SmartFlight

-- ─── Utilitário: número aleatório no intervalo ──────────────
local function randBetween(a, b)
	return a + math.random() * (b - a)
end

-- ─── Utilitário: aguarda tween terminar de forma segura ──────
local function awaitTween(tween)
	if not tween then return end
	local done = false
	local conn
	conn = tween.Completed:Connect(function()
		done = true
	end)
	while not done and tween.PlaybackState == Enum.PlaybackState.Playing do
		task.wait()
	end
	if conn then conn:Disconnect() end
end

function SmartFlight.new(character, settings)
	local self = setmetatable({}, SmartFlight)

	self.Character     = character
	self.Settings      = settings or {}
	self.HoverOffset   = self.Settings.HoverOffset   or 25
	self.SeaFloor      = self.Settings.SeaFloorOffset or 35
	self.SeaLevel      = self.Settings.SeaLevel       or 0
	self.SpeedBase     = self.Settings.DefaultSpeed   or 52
	self.JitterMin     = self.Settings.SpeedJitterMin or -6
	self.JitterMax     = self.Settings.SpeedJitterMax or  6
	self.TweenStyle    = self.Settings.TweenStyle     or Enum.EasingStyle.Sine
	self.TweenDir      = self.Settings.TweenDirection or Enum.EasingDirection.InOut

	self._flying       = false
	self._safeLoop     = nil
	self._noclipConn   = nil
	self._currentTween = nil

	return self
end

function SmartFlight:_getRoot()
	local char = self.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChildOfClass("BasePart")
end

function SmartFlight:_getHumanoid()
	local char = self.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

-- ─── Noclip e Bypass de Física Contínuo (100% eficaz para GPO) ────
function SmartFlight:_startNoclip()
	if self._noclipConn then return end

	local root = self:_getRoot()
	local hum  = self:_getHumanoid()

	-- Cria BodyVelocity de estabilização de física se não existir.
	-- O BodyVelocity zera a inércia perante a física do Roblox e o anticheat do GPO,
	-- permitindo que o TweenService mova o CFrame sem disparar o detector de queda/teleporte.
	if root and not root:FindFirstChild("FlightStabilizer") then
		local bv = Instance.new("BodyVelocity")
		bv.Name = "FlightStabilizer"
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Velocity = Vector3.zero
		bv.Parent = root
	end

	-- Desabilita temporariamente o controle do Humanoid para evitar atrito com o tween
	if hum and hum.Health > 0 then
		hum.PlatformStand = true
	end

	self._noclipConn = RunService.Stepped:Connect(function()
		local char = self.Character
		if not char then return end

		-- Desativa colisões de todas as partes a cada frame de física
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end

		-- Zera velocidades no RootPart para anular gravidade acumulada
		local r = self:_getRoot()
		if r then
			r.AssemblyLinearVelocity = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end

		-- Spoof de estado de física para evitar detecção de noclip no GPO
		local h = self:_getHumanoid()
		if h and h.Health > 0 then
			h:ChangeState(Enum.HumanoidStateType.Physics)
		end
	end)
end

function SmartFlight:_stopNoclip()
	if self._noclipConn then
		self._noclipConn:Disconnect()
		self._noclipConn = nil
	end

	-- Remove o estabilizador de física
	local root = self:_getRoot()
	if root then
		local bv = root:FindFirstChild("FlightStabilizer")
		if bv then bv:Destroy() end
		root.CanCollide = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	-- Restaura estado padrão do Humanoid
	local hum = self:_getHumanoid()
	if hum and hum.Health > 0 then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end
end

-- ─── Calcula altitude segura sobre um ponto do mundo ─────────
function SmartFlight:_safeY(targetPos)
	local ray = Ray.new(
		Vector3.new(targetPos.X, 5000, targetPos.Z),
		Vector3.new(0, -6000, 0)
	)
	local hit, hitPos = workspace:FindPartOnRayWithIgnoreList(
		ray, { self.Character }
	)
	local groundY = hit and hitPos.Y or self.SeaLevel

	-- Proteção rigorosa contra mar no GPO (águas profundas causam dano letal a usuários de fruta)
	-- Se groundY estiver próximo ao nível do mar (<= SeaLevel + 2), força SeaFloorOffset seguro (mínimo 35 studs)
	local safeMin = self.SeaLevel + self.SeaFloor
	if groundY <= (self.SeaLevel + 5) then
		return safeMin
	end

	return math.max(groundY + self.HoverOffset, safeMin)
end

-- ─── Pre-carregamento de chunk para StreamingEnabled de GPO ───
function SmartFlight:_requestStream(pos)
	local lp = Players.LocalPlayer
	if lp and lp.RequestStreamAroundAsync then
		pcall(function()
			lp:RequestStreamAroundAsync(pos, 5)
		end)
	end
end

-- ─── Executa um segmento de Tween de CFrame ───────────────────
function SmartFlight:_tweenTo(targetCFrame, speed)
	local root = self:_getRoot()
	if not root then return false end

	local dist = (targetCFrame.Position - root.Position).Magnitude
	if dist < 0.5 then return true end

	-- Pre-requisita streaming da área de destino
	self:_requestStream(targetCFrame.Position)

	local duration = dist / math.max(speed, 5)

	local info = TweenInfo.new(
		duration,
		self.TweenStyle,
		self.TweenDir
	)

	local tween = TweenService:Create(root, info, { CFrame = targetCFrame })
	self._currentTween = tween
	tween:Play()

	awaitTween(tween)

	-- Limpa referência
	if self._currentTween == tween then
		self._currentTween = nil
	end

	return true
end

-- ─── Voa até uma posição com trajetória otimizada ────────────
--[[
	targetPos : Vector3 do destino
	Usa estratégia de voo em 3 fases:
	  1. Subida até a altitude segura de cruzeiro (evita bater em montanhas/ilhas)
	  2. Cruzeiro horizontal até as coordenadas X, Z
	  3. Descida suave até o alvo final
]]
function SmartFlight:FlyTo(targetPos)
	local root = self:_getRoot()
	if not root then return false end

	-- Cancela qualquer tween anterior
	if self._currentTween then
		self._currentTween:Cancel()
		self._currentTween = nil
	end

	self._flying = true
	self:_startNoclip()

	local speed = self.SpeedBase + randBetween(self.JitterMin, self.JitterMax)
	speed       = math.max(speed, 10)

	local startPos    = root.Position
	local targetSafeY = self:_safeY(targetPos)
	local cruiseY     = math.max(startPos.Y, targetSafeY, self.SeaLevel + self.SeaFloor)

	local horizontalDist = (Vector3.new(targetPos.X, 0, targetPos.Z)
		- Vector3.new(startPos.X, 0, startPos.Z)).Magnitude

	-- Se o percurso for longo (> 80 studs), usa subida -> cruzeiro -> descida
	if horizontalDist > 80 then
		-- Fase 1: Eleva até a altitude de cruzeiro se estiver mais baixo
		if startPos.Y < (cruiseY - 5) then
			local liftCFrame = CFrame.new(Vector3.new(startPos.X, cruiseY, startPos.Z))
			self:_tweenTo(liftCFrame, speed * 1.2)
		end

		if not self._flying then self:_cleanup(); return false end

		-- Fase 2: Cruzeiro horizontal direto até a vertical do destino
		local cruiseCFrame = CFrame.new(
			Vector3.new(targetPos.X, cruiseY, targetPos.Z),
			Vector3.new(targetPos.X, cruiseY, targetPos.Z) + (targetPos - startPos).Unit
		)
		self:_tweenTo(cruiseCFrame, speed)

		if not self._flying then self:_cleanup(); return false end

		-- Fase 3: Descida suave até a posição alvo
		local finalY = math.max(targetPos.Y, self.SeaLevel + 5)
		local finalCFrame = CFrame.new(Vector3.new(targetPos.X, finalY, targetPos.Z))
		self:_tweenTo(finalCFrame, speed * 1.1)

	else
		-- Percurso curto: vai diretamente ao alvo
		local finalY = math.max(targetPos.Y, self.SeaLevel + 5)
		local targetCFrame = CFrame.new(Vector3.new(targetPos.X, finalY, targetPos.Z))
		self:_tweenTo(targetCFrame, speed)
	end

	self:_cleanup()
	return true
end

-- ─── Voa até um alvo com margem de parada ───────────────────
function SmartFlight:FlyToTarget(targetPart, stopRadius)
	stopRadius = stopRadius or 10
	local root = self:_getRoot()
	if not root then return false end

	while targetPart and targetPart.Parent and self._flying do
		local dist = (targetPart.Position - root.Position).Magnitude
		if dist <= stopRadius then
			break
		end
		local result = self:FlyTo(targetPart.Position)
		if not result then break end
		task.wait(0.05)
	end

	self:_cleanup()
	return true
end

-- ─── Hover estático em uma posição ──────────────────────────
function SmartFlight:HoverAt(position, durationSecs)
	local root = self:_getRoot()
	if not root then return end

	local safeY  = self:_safeY(position)
	local hoverPos = Vector3.new(position.X, safeY, position.Z)

	root.CFrame = CFrame.new(hoverPos)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	task.wait(durationSecs or 0)
end

-- ─── Limpeza e encerramento do voo ───────────────────────────
function SmartFlight:_cleanup()
	self._flying = false
	self:_stopNoclip()
	if self._currentTween then
		self._currentTween:Cancel()
		self._currentTween = nil
	end
end

-- ─── Para qualquer movimento em curso ───────────────────────
function SmartFlight:Stop()
	self:_cleanup()
end

-- ─── Atualiza referência ao character (respawn) ─────────────
function SmartFlight:SetCharacter(character)
	self:Stop()
	self.Character = character
end

return SmartFlight

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.FruitDatabase
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.FruitDatabase", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.FruitDatabase
--  Base de dados de Frutas e Baús do Grand Piece Online (GPO)
--  com raridades, valores em Peli, aliases e cores para UI.
-- ============================================================

--[[
	Raridades canônicas de GPO:
	  Common    → Cinza (Suke, Spin, Kilo)
	  Rare      → Azul (Bomu, Bari, Mero, Gomu, Horu)
	  Legendary → Laranja/Dourado (Pika, Magu, Mera, Goro, Hie, Ito, Suna, Zushi, Paw, Kage, Yuki)
	  Mythical  → Vermelho/Magenta (Mochi, Tori, Ope, Venom, Buddha, Dragon)
	  Special   → Baús de Frutas e Raízes (Dark Root, SP Reset)

	Priority: quanto maior, mais urgente para coletar.
]]

local FruitDatabase = {

	-- ─── COMUNS ───────────────────────────────────────────
	Suke       = { name = "Suke Suke no Mi", fullName = "Suke Suke no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 5000   },
	Spin       = { name = "Guru Guru no Mi", fullName = "Guru Guru no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 7500   },
	Guru       = { name = "Guru Guru no Mi", fullName = "Guru Guru no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 7500   },
	Kilo       = { name = "Kilo Kilo no Mi", fullName = "Kilo Kilo no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 10000  },

	-- ─── RARAS ────────────────────────────────────────────
	Bomu       = { name = "Bomu Bomu no Mi", fullName = "Bomu Bomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 150000 },
	Bomb       = { name = "Bomu Bomu no Mi", fullName = "Bomu Bomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 150000 },
	Bari       = { name = "Bari Bari no Mi", fullName = "Bari Bari no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 180000 },
	Barrier    = { name = "Bari Bari no Mi", fullName = "Bari Bari no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 180000 },
	Mero       = { name = "Mero Mero no Mi", fullName = "Mero Mero no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 220000 },
	Love       = { name = "Mero Mero no Mi", fullName = "Mero Mero no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 220000 },
	Gomu       = { name = "Gomu Gomu no Mi", fullName = "Gomu Gomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 250000 },
	Rubber     = { name = "Gomu Gomu no Mi", fullName = "Gomu Gomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 250000 },
	Horu       = { name = "Horu Horu no Mi", fullName = "Horu Horu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 200000 },

	-- ─── LENDÁRIAS (GPO LEGENDARY LOGIAS & PARAMECIAS) ────
	Pika       = { name = "Pika Pika no Mi", fullName = "Pika Pika no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15),  value = 2500000 },
	Light      = { name = "Pika Pika no Mi", fullName = "Pika Pika no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15),  value = 2500000 },
	Magu       = { name = "Magu Magu no Mi", fullName = "Magu Magu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 126, 34),  value = 2400000 },
	Magma      = { name = "Magu Magu no Mi", fullName = "Magu Magu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 126, 34),  value = 2400000 },
	Mera       = { name = "Mera Mera no Mi", fullName = "Mera Mera no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 80, 25),   value = 2200000 },
	Flame      = { name = "Mera Mera no Mi", fullName = "Mera Mera no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 80, 25),   value = 2200000 },
	Goro       = { name = "Goro Goro no Mi", fullName = "Goro Goro no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 215, 0),   value = 2100000 },
	Rumble     = { name = "Goro Goro no Mi", fullName = "Goro Goro no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 215, 0),   value = 2100000 },
	Hie        = { name = "Hie Hie no Mi",   fullName = "Hie Hie no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(130, 210, 255), value = 1800000 },
	Ice        = { name = "Hie Hie no Mi",   fullName = "Hie Hie no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(130, 210, 255), value = 1800000 },
	Ito        = { name = "Ito Ito no Mi",   fullName = "Ito Ito no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(233, 30, 99),   value = 1600000 },
	String     = { name = "Ito Ito no Mi",   fullName = "Ito Ito no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(233, 30, 99),   value = 1600000 },
	Suna       = { name = "Suna Suna no Mi", fullName = "Suna Suna no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(218, 165, 32),  value = 1500000 },
	Sand       = { name = "Suna Suna no Mi", fullName = "Suna Suna no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(218, 165, 32),  value = 1500000 },
	Zushi      = { name = "Zushi Zushi no Mi", fullName = "Zushi Zushi no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(155, 89, 182), value = 1700000 },
	Gravity    = { name = "Zushi Zushi no Mi", fullName = "Zushi Zushi no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(155, 89, 182), value = 1700000 },
	Paw        = { name = "Nikyu Nikyu no Mi", fullName = "Nikyu Nikyu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 105, 180), value = 1750000 },
	Nikyu      = { name = "Nikyu Nikyu no Mi", fullName = "Nikyu Nikyu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 105, 180), value = 1750000 },
	Kage       = { name = "Kage Kage no Mi", fullName = "Kage Kage no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(75, 0, 130),    value = 1900000 },
	Shadow     = { name = "Kage Kage no Mi", fullName = "Kage Kage no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(75, 0, 130),    value = 1900000 },
	Yuki       = { name = "Yuki Yuki no Mi", fullName = "Yuki Yuki no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(200, 240, 255), value = 1850000 },
	Snow       = { name = "Yuki Yuki no Mi", fullName = "Yuki Yuki no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(200, 240, 255), value = 1850000 },

	-- ─── MÍTICAS (GPO MYTHICALS) ──────────────────────────
	Mochi      = { name = "Mochi Mochi no Mi", fullName = "Mochi Mochi no Mi", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 45, 85),  value = 5000000 },
	Tori       = { name = "Tori Tori no Mi",   fullName = "Tori Tori no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(0, 240, 255),   value = 4500000 },
	Phoenix    = { name = "Tori Tori no Mi",   fullName = "Tori Tori no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(0, 240, 255),   value = 4500000 },
	Ope        = { name = "Ope Ope no Mi",     fullName = "Ope Ope no Mi",     rarity = "Mythical", priority = 5, color = Color3.fromRGB(142, 68, 173),  value = 4800000 },
	Venom      = { name = "Doku Doku no Mi",   fullName = "Doku Doku no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(186, 85, 211),  value = 4200000 },
	Doku       = { name = "Doku Doku no Mi",   fullName = "Doku Doku no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(186, 85, 211),  value = 4200000 },
	Buddha     = { name = "Hito Hito: Daibutsu", fullName = "Hito Hito no Mi, Model: Daibutsu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 215, 0), value = 4000000 },
	Daibutsu   = { name = "Hito Hito: Daibutsu", fullName = "Hito Hito no Mi, Model: Daibutsu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 215, 0), value = 4000000 },
	Dragon     = { name = "Uo Uo: Seiryu",     fullName = "Uo Uo no Mi, Model: Seiryu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(46, 204, 113),  value = 5500000 },

	-- ─── BAÚS DE FRUTA E ITENS ESPECIAIS DE GPO ───────────
	MythicalChest  = { name = "Mythical Chest",  fullName = "Mythical Fruit Chest",  rarity = "Mythical",  priority = 5, color = Color3.fromRGB(255, 45, 85),  value = 3500000 },
	LegendaryChest = { name = "Legendary Chest", fullName = "Legendary Fruit Chest", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15), value = 1500000 },
	RareChest      = { name = "Rare Chest",      fullName = "Rare Fruit Chest",      rarity = "Rare",      priority = 3, color = Color3.fromRGB(52, 152, 219),  value = 500000  },
	DarkRoot       = { name = "Dark Root",       fullName = "Dark Root",             rarity = "Rare",      priority = 3, color = Color3.fromRGB(110, 50, 160),  value = 250000  },
	SPReset        = { name = "SP Reset Root",   fullName = "SP Reset Root",         rarity = "Rare",      priority = 3, color = Color3.fromRGB(46, 204, 113),  value = 150000  },

}

-- ─── Tabela de prioridade mínima por string ─────────────────
FruitDatabase.RarityPriority = {
	Common    = 1,
	Rare      = 2,
	Legendary = 4,
	Mythical  = 5,
}

-- ─── Helpers ─────────────────────────────────────────────────

-- Normaliza strings para matching flexível (remove "no Mi", traços e espaços)
local function normalizeKey(str)
	return str:lower()
		:gsub("%s*no%s*mi", "")
		:gsub("[_%-%s]", "")
end

-- Retorna os dados de uma fruta pelo nome ou variante
function FruitDatabase:Get(name)
	if not name or type(name) ~= "string" then return nil end

	-- Teste direto exato
	if self[name] then return self[name] end

	-- Teste case-insensitive direto
	local lower = name:lower()
	for k, v in pairs(self) do
		if type(k) == "string" and type(v) == "table" and k:lower() == lower then
			return v
		end
	end

	-- Teste normalizado (cobre "Mera-Mera", "Mera Mera no Mi", "Pika_Fruit", etc.)
	local normTarget = normalizeKey(name)
	for k, v in pairs(self) do
		if type(k) == "string" and type(v) == "table" and v.rarity then
			local normK = normalizeKey(k)
			if normTarget:find(normK, 1, true) or normK:find(normTarget, 1, true) then
				return v
			end
			if v.name and normalizeKey(v.name):find(normTarget, 1, true) then
				return v
			end
			if v.fullName and normalizeKey(v.fullName):find(normTarget, 1, true) then
				return v
			end
		end
	end

	return nil
end

-- Verifica se a raridade da fruta atende ao mínimo configurado
function FruitDatabase:MeetsMinRarity(fruitName, minRarity)
	local data    = self:Get(fruitName)
	if not data then return false end
	local minPrio = self.RarityPriority[minRarity] or 1
	return data.priority >= minPrio
end

return FruitDatabase

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.FruitTracker
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.FruitTracker", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.FruitTracker
--  Rastreia frutas (Akuma no Mi) e baús de fruta no Grand Piece Online (GPO),
--  notifica a UI com raridade/valor em Peli e executa Auto-Collection via SmartFlight.
-- ============================================================

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle Mode] Root redirecionado
local Logger         = customRequire("EliteAutomation.Core.Logger")

local FruitTracker = {}
FruitTracker.__index = FruitTracker

-- ─── Nomes de modelos de fruta no workspace ──────────────────
-- GPO usa convenções como "Mera-Mera Fruit", "Pika Fruit", "Fruit", etc.
local FRUIT_SUFFIXES = { "_Fruit", "-Fruit", " Fruit", "Fruit", "" }

local function extractFruitName(modelName)
	for _, suffix in ipairs(FRUIT_SUFFIXES) do
		if suffix ~= "" and modelName:sub(-#suffix) == suffix then
			return modelName:sub(1, -(#suffix + 1))
		end
	end
	return modelName
end

-- ─── Construtor ──────────────────────────────────────────────
function FruitTracker.new(fruitDB, notificationModule, settings)
	local self = setmetatable({}, FruitTracker)

	self.DB              = fruitDB
	self.Notifications   = notificationModule
	self.ScanInterval    = (settings and settings.ScanInterval)   or 1.5
	self.AutoCollect     = (settings and settings.AutoCollect)     ~= false
	self.MinRarity       = (settings and settings.MinRarity)       or "Common"
	self.CollectRadius   = (settings and settings.CollectRadius)   or 5
	self.NotifyOnDetect  = (settings and settings.NotifyOnDetect)  ~= false

	self._running        = false
	self._thread         = nil
	self._knownFruits    = {}  -- [model] = true, para evitar duplicatas
	self._smartFlight    = nil  -- injetado externamente

	return self
end

-- Injeta o módulo de voo
function FruitTracker:SetFlight(smartFlight)
	self._smartFlight = smartFlight
end

-- ─── Scanneia workspace por frutas ───────────────────────────
function FruitTracker:_scan()
	local found = {}

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("Part") then
			local rawName   = obj.Name
			local cleanName = extractFruitName(rawName)
			-- Testa nome limpo ou nome bruto no FruitDatabase
			local data      = self.DB:Get(cleanName) or self.DB:Get(rawName)

			if data then
				local displayName = data.name or cleanName
				if self.DB:MeetsMinRarity(displayName, self.MinRarity) then
					table.insert(found, {
						model    = obj,
						name     = displayName,
						data     = data,
					})
				end
			end
		end
	end

	return found
end

-- ─── Obtém a posição de uma fruta ────────────────────────────
local function getFruitPosition(fruitObj)
	if fruitObj:IsA("Model") then
		local primary = fruitObj.PrimaryPart or fruitObj:FindFirstChildOfClass("BasePart")
		return primary and primary.Position
	elseif fruitObj:IsA("BasePart") then
		return fruitObj.Position
	end
	return nil
end

-- ─── Coleta uma fruta voando até ela ────────────────────────
function FruitTracker:_collect(fruitEntry)
	if not self._smartFlight then
		Logger.Warn("FruitTracker: SmartFlight não injetado. Coleta manual desativada.")
		return
	end

	local pos = getFruitPosition(fruitEntry.model)
	if not pos then return end

	Logger.Info(
		string.format("FruitTracker → Coletando [%s] %s em (%.0f, %.0f, %.0f)",
			fruitEntry.data.rarity, fruitEntry.name, pos.X, pos.Y, pos.Z)
	)

	-- Voa até a fruta
	self._smartFlight:FlyTo(pos)

	local localChar = Players.LocalPlayer.Character
	local root      = localChar and localChar:FindFirstChild("HumanoidRootPart")

	if root then
		local timeout = os.clock() + 15
		while os.clock() < timeout do
			local currentPos = getFruitPosition(fruitEntry.model)
			if not currentPos or not fruitEntry.model.Parent then
				break  -- Fruta coletada ou despawnada
			end
			local dist = (currentPos - root.Position).Magnitude
			if dist <= self.CollectRadius then
				root.CFrame = CFrame.new(currentPos)

				-- Tenta acionar ProximityPrompt caso exista
				local prompt = fruitEntry.model:FindFirstChildOfClass("ProximityPrompt", true)
				if prompt and fireproximityprompt then
					fireproximityprompt(prompt)
				end

				task.wait(0.15)
				break
			end
			task.wait(0.1)
		end
	end

	self._knownFruits[fruitEntry.model] = nil
end

-- ─── Processa fruta recém detectada ──────────────────────────
function FruitTracker:_onFruitDetected(entry)
	if self._knownFruits[entry.model] then return end
	self._knownFruits[entry.model] = true

	local pos = getFruitPosition(entry.model)

	Logger.Success(string.format(
		"🍎 GPO Fruta Detectada: [%s] %s | Valor: %s Peli",
		entry.data.rarity,
		entry.name,
		tostring(entry.data.value)
	))

	-- Notifica a UI
	if self.NotifyOnDetect and self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			local msg = string.format(
				"%s • %s\nValor: %s Peli",
				entry.data.rarity,
				entry.name,
				tostring(entry.data.value)
			)
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"🍎 FRUTA DETECTADA",
				msg,
				5,
				entry.data.color
			)
		end
	end

	-- Auto-Collection
	if self.AutoCollect then
		task.spawn(function()
			self:_collect(entry)
		end)
	end
end

-- ─── Loop principal ──────────────────────────────────────────
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
			Logger.Error("FruitTracker loop error:", fruits)
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function FruitTracker:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
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
	Logger.Info("AutoCollect:", enabled and "Ativado" or "Desativado")
end

function FruitTracker:SetMinRarity(rarity)
	self.MinRarity = rarity
	Logger.Info("MinRarity alterada para:", rarity)
end

function FruitTracker:GetKnownCount()
	local count = 0
	for _ in pairs(self._knownFruits) do count = count + 1 end
	return count
end

return FruitTracker

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.BossManager
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.BossManager", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.BossManager
--  Gerenciador de Bosses e Sea Events do Grand Piece Online (GPO):
--  1. Sea Events / Location Bosses (Kraken, Sea Beast, Ghost Ship, Megalodon)
--  2. Timed / World Bosses (Ryuma, Borj, Gravito, Enel, Neptune)
--  3. Raid Bosses (Moria, Ba'al, Impel Down Warden)
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle Mode] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

local BossManager = {}
BossManager.__index = BossManager

-- ─── Utilitário: encontra modelo no workspace por nome ou aliases ─
local function findBossModel(config)
	if not config then return nil end

	-- Lista de nomes a testar
	local names = { config.Name }
	if config.Aliases then
		for _, alias in ipairs(config.Aliases) do
			table.insert(names, alias)
		end
	end

	for _, name in ipairs(names) do
		local m = workspace:FindFirstChild(name, true) or workspace:FindFirstChild(name)
		if m and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildOfClass("Humanoid")) then
			return m
		end
	end

	-- Busca parcial/case-insensitive em descendants se for Kraken ou Sea Beast
	local lowerName = config.Name:lower()
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") then
			local objLower = obj.Name:lower()
			if objLower:find(lowerName, 1, true) then
				if obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("Humanoid") then
					return obj
				end
			end
		end
	end

	return nil
end

-- ─── Utilitário: jitter simples ──────────────────────────────
local function jitter(min, max)
	return min + math.random() * (max - min)
end

-- ─── Construtor ──────────────────────────────────────────────
function BossManager.new(combat, smartFlight, notifications, settings)
	local self = setmetatable({}, BossManager)

	self.Combat        = combat        -- CombatController
	self.SmartFlight   = smartFlight   -- SmartFlight
	self.Notifications = notifications
	self.Settings      = settings or {}
	self.ScanInterval  = self.Settings.ScanInterval or 2.0
	self.AttackRadius  = self.Settings.AttackRadius or 90

	-- Timestamps de último spawn visto para bosses de tempo
	self._timedTimestamps = {}     -- [bossName] = os.time() do último spawn
	self._running         = false
	self._thread          = nil
	self._currentBoss     = nil    -- boss atualmente sendo farmado

	return self
end

-- ─════════════════════════════════════════════════════════════
--   CATEGORIA 1 — RAID / DUNGEON BOSSES (Moria, Ba'al, Impel Down)
-- ══════════════════════════════════════════════════════════════

function BossManager:_handleRaidBoss(config)
	Logger.Info("BossManager → Verificando Raid Boss:", config.Name)

	local bossModel = findBossModel(config)
	if not bossModel then
		-- Se houver localização definida e não estiver engajado, vai até lá
		if config.Location and self.SmartFlight and not self._currentBoss then
			Logger.Info("Raid Boss não avistado. Posicionando em:", tostring(config.Location))
			self.SmartFlight:FlyTo(config.Location)
		end
		return
	end

	Logger.Success("Raid Boss detectado:", config.Name, "| Fases:", config.PhaseCount or 1)

	-- Notifica UI
	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"⚔ GPO RAID BOSS",
				config.Name .. " detectado! Engajando...",
				5,
				Color3.fromRGB(255, 75, 75)
			)
		end
	end

	self._currentBoss = bossModel

	-- Loop de combate
	for phase = 1, (config.PhaseCount or 1) do
		Logger.Info(string.format("  Fase %d/%d", phase, config.PhaseCount or 1))

		local bossRoot = bossModel:FindFirstChild("HumanoidRootPart")
		if bossRoot and self.SmartFlight then
			self.SmartFlight:FlyTo(bossRoot.Position)
		end

		if self.Combat then
			self.Combat:SetTarget(bossModel)
		end

		local timeout = os.clock() + 300
		while os.clock() < timeout do
			local hum = bossModel:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 or not bossModel.Parent then
				Logger.Info("Boss eliminado na fase", phase)
				break
			end
			task.wait(1)
		end

		if phase < (config.PhaseCount or 1) then
			task.wait(jitter(2, 4))
		end
	end

	self._currentBoss = nil
	if self.Combat then
		self.Combat:Stop()
	end

	Logger.Success("Raid Boss", config.Name, "finalizado!")
end

-- ─════════════════════════════════════════════════════════════
--   CATEGORIA 2 — BOSSES DE TEMPO E ILHAS (Ryuma, Borj, Gravito, Enel, Neptune)
-- ══════════════════════════════════════════════════════════════

function BossManager:_handleTimedBoss(config)
	local name     = config.Name
	local cooldown = config.CooldownSecs or 1800
	local lastSeen = self._timedTimestamps[name] or 0
	local now      = os.time()
	local elapsed  = now - lastSeen
	local remaining = cooldown - elapsed

	if remaining > 0 then
		Logger.Debug(string.format(
			"Timed Boss '%s' em cooldown. Próximo em: %d min %d s",
			name,
			math.floor(remaining / 60),
			remaining % 60
		))
		return
	end

	Logger.Info("BossManager → Verificando World Boss:", name)
	local bossModel = findBossModel(config)

	if not bossModel then
		return
	end

	Logger.Success("World Boss VIVO:", name)
	self._timedTimestamps[name] = now

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"⏱ GPO WORLD BOSS",
				name .. " spawnado em " .. (config.Island or "ilha") .. "!",
				6,
				Color3.fromRGB(255, 200, 0)
			)
		end
	end

	if self.SmartFlight and config.Location then
		if config.FlyToSky then
			local skyPos = Vector3.new(
				config.Location.X,
				math.max(config.Location.Y, 200),
				config.Location.Z
			)
			self.SmartFlight:FlyTo(skyPos)
		else
			self.SmartFlight:FlyTo(config.Location)
		end
	end

	self._currentBoss = bossModel
	if self.Combat then
		self.Combat:SetTarget(bossModel)
	end

	local timeout = os.clock() + 600
	while os.clock() < timeout do
		local hum = bossModel:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or not bossModel.Parent then
			break
		end
		task.wait(1)
	end

	self._currentBoss = nil
	Logger.Success("World Boss", name, "eliminado!")
end

-- ─════════════════════════════════════════════════════════════
--   CATEGORIA 3 — SEA EVENTS & BOSSES DE MAR (Kraken, Sea Beast, Ghost Ship, Megalodon)
-- ══════════════════════════════════════════════════════════════

function BossManager:_handleLocationBoss(config)
	local bossModel = findBossModel(config)
	if not bossModel then return end

	local bossRoot = bossModel:FindFirstChild("HumanoidRootPart")
		or bossModel:FindFirstChildOfClass("BasePart")
	if not bossRoot then return end

	local bossPos = bossRoot.Position

	-- Região de validade
	local region = config.Region
	if region then
		local dist = (Vector3.new(bossPos.X, 0, bossPos.Z)
			- Vector3.new(region.center.X, 0, region.center.Z)).Magnitude
		if dist > region.radius then
			return
		end
	end

	Logger.Success("🌊 SEA EVENT DETECTADO:", bossModel.Name, "em", tostring(bossPos))

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"🌊 GPO SEA EVENT",
				bossModel.Name .. " surgiu no mar!\nAltitude de segurança ativada.",
				6,
				Color3.fromRGB(0, 180, 255)
			)
		end
	end

	self._currentBoss = bossModel

	-- "Voo de Segurança Anti-Mar" — mantém altitude acima da água
	if self.SmartFlight and config.SafeAltitude then
		local oldHover = self.SmartFlight.HoverOffset
		self.SmartFlight.HoverOffset = config.SafeAltitude

		-- Garante proteção estrita contra contato com água
		local antiDrownThread = task.spawn(function()
			while self._currentBoss and self._currentBoss.Parent do
				if config.DiveProtection then
					local localChar = Players.LocalPlayer.Character
					local root      = localChar and localChar:FindFirstChild("HumanoidRootPart")
					if root then
						local seaLevel = config.SeaLevel or 0
						if root.Position.Y < (seaLevel + config.SafeAltitude) then
							root.CFrame = CFrame.new(
								root.Position.X,
								seaLevel + config.SafeAltitude + 5,
								root.Position.Z
							)
							Logger.Warn("Anti-afogamento GPO ativado! Mantendo sobre o mar.")
						end
					end
				end
				task.wait(0.15)
			end
		end)

		-- Voa até o boss no plano horizontal mantendo safe altitude
		local safePos = Vector3.new(bossPos.X, (config.SeaLevel or 0) + config.SafeAltitude, bossPos.Z)
		self.SmartFlight:FlyTo(safePos)

		-- Engaja combate
		if self.Combat then
			self.Combat:SetTarget(bossModel)
		end

		-- Aguarda desfecho
		local timeout = os.clock() + 600
		while os.clock() < timeout do
			local hum = bossModel:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 or not bossModel.Parent then
				break
			end
			task.wait(1)
		end

		pcall(function() task.cancel(antiDrownThread) end)
		self.SmartFlight.HoverOffset = oldHover
	end

	self._currentBoss = nil
	Logger.Success("Sea Event", bossModel.Name, "concluído!")
end

-- ─════════════════════════════════════════════════════════════
--   LOOP PRINCIPAL
-- ══════════════════════════════════════════════════════════════

function BossManager:_loop()
	local cfg = self.Settings

	while self._running do
		local ok, err = pcall(function()

			-- ── 1. Sea Events / Location Bosses (Prioridade máxima em GPO)
			if cfg.LocationBosses then
				for _, bossCfg in pairs(cfg.LocationBosses) do
					if not self._running then break end
					self:_handleLocationBoss(bossCfg)
				end
			end

			-- ── 2. Bosses de Tempo e Ilhas
			if cfg.TimedBosses then
				for _, bossCfg in pairs(cfg.TimedBosses) do
					if not self._running then break end
					self:_handleTimedBoss(bossCfg)
				end
			end

			-- ── 3. Raids e Dungeons
			if cfg.RaidBosses then
				for _, bossCfg in pairs(cfg.RaidBosses) do
					if not self._running then break end
					self:_handleRaidBoss(bossCfg)
				end
			end

		end)

		if not ok then
			Logger.Error("BossManager loop error:", err)
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function BossManager:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
	Logger.Info("BossManager (GPO) iniciado.")
end

function BossManager:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	self._currentBoss = nil
	Logger.Info("BossManager parado.")
end

function BossManager:GetCurrentBoss()
	return self._currentBoss
end

return BossManager

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.ItemFarm
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.ItemFarm", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.ItemFarm
--  Scanneia o workspace por itens (baús, caixas, drops) e
--  coleta automaticamente via SmartFlight.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle Mode] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

local ItemFarm = {}
ItemFarm.__index = ItemFarm

-- ─── Construtor ──────────────────────────────────────────────
function ItemFarm.new(smartFlight, notifications, settings)
	local self = setmetatable({}, ItemFarm)

	self.SmartFlight   = smartFlight
	self.Notifications = notifications
	self.Settings      = settings or {}

	self.ScanInterval  = self.Settings.ScanInterval or 2
	self.ItemTags      = self.Settings.ItemTags or { "Chest", "Baú", "Crate", "Drop" }
	self.CollectRadius = 5

	self._running      = false
	self._thread       = nil
	self._collected    = {}   -- [model] = true, cache anti-duplicata

	return self
end

-- ─── Verifica se modelo é um item coletável ──────────────────
function ItemFarm:_isCollectible(model)
	for _, tag in ipairs(self.ItemTags) do
		-- Nome exato
		if model.Name == tag then return true end
		-- Nome contém a tag
		if model.Name:find(tag, 1, true) then return true end
	end
	return false
end

-- ─── Obtém posição central do item ───────────────────────────
local function getItemPosition(model)
	if model:IsA("Model") then
		local primary = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
		return primary and primary.Position
	elseif model:IsA("BasePart") then
		return model.Position
	end
	return nil
end

-- ─── Coleta um item ──────────────────────────────────────────
function ItemFarm:_collectItem(model)
	if self._collected[model] then return end
	self._collected[model] = true

	local pos = getItemPosition(model)
	if not pos then return end

	Logger.Info("ItemFarm → Coletando:", model.Name, "em", tostring(pos))

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"📦 ITEM DETECTADO",
				model.Name .. " encontrado! Coletando...",
				3
			)
		end
	end

	-- Voa até o item
	if self.SmartFlight then
		self.SmartFlight:FlyTo(pos)
	end

	-- Tenta "tocar" o item para coletar
	local localChar = Players.LocalPlayer.Character
	local root      = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
		task.wait(0.2)
	end

	-- Remove do cache se o modelo sumiu (confirmação de coleta)
	task.delay(3, function()
		if not model or not model.Parent then
			self._collected[model] = nil
			Logger.Success("Item coletado:", model and model.Name or "?")
		else
			-- Item ainda existe → remove do cache para tentar de novo
			self._collected[model] = nil
		end
	end)
end

-- ─── Scan do workspace ───────────────────────────────────────
function ItemFarm:_scan()
	local results = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if (obj:IsA("Model") or obj:IsA("BasePart")) and self:_isCollectible(obj) then
			if not self._collected[obj] then
				table.insert(results, obj)
			end
		end
	end
	return results
end

-- ─── Loop principal ──────────────────────────────────────────
function ItemFarm:_loop()
	self._collected = {}

	while self._running do
		local ok, err = pcall(function()
			local items = self:_scan()

			-- Prioriza por distância
			local localChar = Players.LocalPlayer.Character
			local root      = localChar and localChar:FindFirstChild("HumanoidRootPart")

			if root and #items > 0 then
				table.sort(items, function(a, b)
					local pa = getItemPosition(a) or Vector3.zero
					local pb = getItemPosition(b) or Vector3.zero
					return (pa - root.Position).Magnitude < (pb - root.Position).Magnitude
				end)

				-- Coleta o mais próximo
				task.spawn(function()
					self:_collectItem(items[1])
				end)
			end

			-- Limpa cache de modelos destruídos
			for model in pairs(self._collected) do
				if not model or not model.Parent then
					self._collected[model] = nil
				end
			end
		end)

		if not ok then
			Logger.Error("ItemFarm loop error:", err)
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function ItemFarm:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
	Logger.Info("ItemFarm iniciado. Tags:", table.concat(self.ItemTags, ", "))
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

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.MerchantTracker
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.MerchantTracker", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.MerchantTracker
--  Rastreador do Mercador Viajante (Traveling Merchant) de GPO.
--  Detecta spawns em ilhas, notifica a UI e oferece voo automático.
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle Mode] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

local MerchantTracker = {}
MerchantTracker.__index = MerchantTracker

-- Nomes e variações conhecidas do modelo do mercador no GPO
local MERCHANT_NAMES = {
	"Traveling Merchant",
	"TravelingMerchant",
	"Wandering Merchant",
	"Merchant",
}

-- ─── Construtor ──────────────────────────────────────────────
function MerchantTracker.new(notifications, settings)
	local self = setmetatable({}, MerchantTracker)

	self.Notifications = notifications
	self.Settings      = settings or {}
	self.ScanInterval  = self.Settings.ScanInterval or 1.5
	self.KnownIslands  = self.Settings.KnownIslands or {
		-- ─ First Sea ─
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
		-- ─ Second Sea ─
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

	self._running        = false
	self._thread         = nil
	self._currentMerchant = nil  -- { model = ..., position = ..., island = ..., spawnTime = ... }
	self._smartFlight    = nil  -- injetado externamente
	self._lastState      = false

	-- Callbacks
	self.OnMerchantSpawned   = nil -- function(merchantData)
	self.OnMerchantDespawned = nil -- function()

	return self
end

function MerchantTracker:SetFlight(smartFlight)
	self._smartFlight = smartFlight
end

-- ─── Cálculo do Ciclo do Mercador via Uptime de Servidor ──────
-- No GPO, o Traveling Merchant surge aos 10 minutos (600s) de servidor,
-- permanece por 10 minutos (600s) e reaparece a cada 30 minutos (1800s).
function MerchantTracker:GetSchedule()
	local uptime = workspace.DistributedGameTime or 0

	if uptime < 600 then
		local timeToFirst = math.ceil(600 - uptime)
		return {
			Status        = "WAITING",
			SecondsLeft   = timeToFirst,
			MinutesLeft   = math.floor(timeToFirst / 60),
			SecondsRem    = timeToFirst % 60,
			DisplayText   = string.format("1º Spawn em: %02d:%02d", math.floor(timeToFirst / 60), timeToFirst % 60),
			IsActive      = false,
		}
	end

	local cycleElapsed = (uptime - 600) % 1800

	if cycleElapsed < 600 then
		-- Mercador está atualmente ATIVO no servidor!
		local despawnIn = math.ceil(600 - cycleElapsed)
		return {
			Status        = "ACTIVE",
			SecondsLeft   = despawnIn,
			MinutesLeft   = math.floor(despawnIn / 60),
			SecondsRem    = despawnIn % 60,
			DisplayText   = string.format("MERCADOR ATIVO! Despawn em: %02d:%02d", math.floor(despawnIn / 60), despawnIn % 60),
			IsActive      = true,
		}
	else
		-- Mercador está DESPAWNADO, aguardando próximo ciclo
		local nextIn = math.ceil(1800 - cycleElapsed)
		return {
			Status        = "WAITING",
			SecondsLeft   = nextIn,
			MinutesLeft   = math.floor(nextIn / 60),
			SecondsRem    = nextIn % 60,
			DisplayText   = string.format("Próximo spawn em: %02d:%02d", math.floor(nextIn / 60), nextIn % 60),
			IsActive      = false,
		}
	end
end

-- ─── Identifica a ilha mais próxima de uma posição ───────────
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

-- ─── Scanner de Bússola e Compass no PlayerGui (GPO) ──────────
function MerchantTracker:_scanCompassGui()
	local lp = Players.LocalPlayer
	if not lp then return nil end
	local pg = lp:FindFirstChild("PlayerGui")
	if not pg then return nil end

	-- Procura indicador de bússola com ícone ou texto do Traveling Merchant
	for _, gui in ipairs(pg:GetChildren()) do
		if gui:IsA("ScreenGui") then
			local compass = gui:FindFirstChild("Compass", true) or gui:FindFirstChild("CompassGui", true)
			if compass then
				local marker = compass:FindFirstChild("MerchantMarker", true)
					or compass:FindFirstChild("Merchant", true)
					or compass:FindFirstChild("TravelingMerchant", true)
				if marker then
					return marker
				end
			end
		end
	end
	return nil
end

-- ─── Busca o modelo do mercador no workspace ─────────────────
function MerchantTracker:_findMerchant()
	for _, name in ipairs(MERCHANT_NAMES) do
		local model = workspace:FindFirstChild(name, true)
		if model then
			local root = model:FindFirstChild("HumanoidRootPart")
				or model:FindFirstChildOfClass("BasePart")
			if root then
				return model, root.Position
			end
		end
	end

	-- Busca em NPCs / Spawns caso o nome contenha 'Merchant'
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj.Name:lower():find("merchant", 1, true) then
			local root = obj:FindFirstChild("HumanoidRootPart")
				or obj:FindFirstChildOfClass("BasePart")
			if root then
				return obj, root.Position
			end
		end
	end

	return nil, nil
end

-- ─── Loop de rastreamento ────────────────────────────────────
function MerchantTracker:_loop()
	while self._running do
		local ok, err = pcall(function()
			local model, pos = self:_findMerchant()

			if model and pos then
				if not self._lastState then
					-- Mercador acabou de surgir!
					self._lastState = true
					local islandName, dist = self:_identifyIsland(pos)

					self._currentMerchant = {
						model     = model,
						position  = pos,
						island    = islandName,
						spawnTime = os.time(),
					}

					Logger.Success(string.format(
						"🛒 MERCADOR DETECTADO! Ilha: %s em (%.0f, %.0f, %.0f)",
						islandName, pos.X, pos.Y, pos.Z
					))

					if self.Notifications then
						local localPlayer = Players.LocalPlayer
						if localPlayer and localPlayer.PlayerGui then
							self.Notifications.Create(
								localPlayer.PlayerGui,
								"🛒 MERCADOR VIAJANTE",
								string.format("O Mercador spawnou em %s!\nClique para voar até ele.", islandName),
								8,
								Color3.fromRGB(255, 215, 0)
							)
						end
					end

					if self.OnMerchantSpawned then
						self.OnMerchantSpawned(self._currentMerchant)
					end
				else
					-- Atualiza posição caso o modelo tenha se movido
					if self._currentMerchant then
						self._currentMerchant.model    = model
						self._currentMerchant.position = pos
					end
				end
			else
				if self._lastState then
					-- Mercador despawnou
					self._lastState = false
					Logger.Warn("🛒 Mercador Viajante despawnou ou deixou a ilha.")

					if self.Notifications then
						local localPlayer = Players.LocalPlayer
						if localPlayer and localPlayer.PlayerGui then
							self.Notifications.Create(
								localPlayer.PlayerGui,
								"🛒 MERCADOR DESPAWNOU",
								"O Mercador Viajante não está mais ativo.",
								4,
								Color3.fromRGB(200, 100, 100)
							)
						end
					end

					if self.OnMerchantDespawned then
						self.OnMerchantDespawned()
					end

					self._currentMerchant = nil
				end
			end
		end)

		if not ok then
			Logger.Error("MerchantTracker loop error:", err)
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── Voa até o mercador ──────────────────────────────────────
function MerchantTracker:FlyToMerchant()
	if not self._currentMerchant or not self._currentMerchant.position then
		Logger.Warn("MerchantTracker: Mercador não está ativo no momento.")
		return false
	end

	if not self._smartFlight then
		Logger.Warn("MerchantTracker: SmartFlight não configurado.")
		return false
	end

	local targetPos = self._currentMerchant.position + Vector3.new(0, 4, 0)
	Logger.Info("Voando até o Mercador em:", self._currentMerchant.island)
	self._smartFlight:FlyTo(targetPos)
	return true
end

-- ─── API Pública ─────────────────────────────────────────────
function MerchantTracker:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
	Logger.Info("MerchantTracker iniciado.")
end

function MerchantTracker:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	self._currentMerchant = nil
	self._lastState       = false
	Logger.Info("MerchantTracker parado.")
end

function MerchantTracker:GetMerchant()
	return self._currentMerchant
end

function MerchantTracker:IsActive()
	return self._currentMerchant ~= nil
end

return MerchantTracker

end)

-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.LawFactoryFarm
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.LawFactoryFarm", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.LawFactoryFarm
--  Módulo de Farm Especializado para o Boss Law ("Order") e
--  a Raid da Factory (Fábrica):
--
--  1. Factory Core Farm:
--     - Detecção de abertura da fábrica e do "Core"
--     - Hover seguro acima do chão de ácido tóxico
--     - Foco 100% de dano no Core para garantir a Fruta Gratuita (#1 Damage)
--
--  2. Law / Order Raid Farm:
--     - Detecção do Boss ("Order" / "Law") e auto-start no terminal/pod
--     - Combate vertical acima da cabeça (anti-Tact e blind spot de cortes)
--     - Recuperação instantânea de Shambles (re-engajamento em < 0.2s)
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle Mode] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

local LawFactoryFarm = {}
LawFactoryFarm.__index = LawFactoryFarm

-- ─── Nomes de modelos do Law e Factory no GPO ──────────────
local LAW_NAMES = { "Law", "Trafalgar Law", "Order", "Boss Order" }
local CORE_NAMES = { "Slime Core", "SlimeCore", "Core", "Factory Core", "FactoryCore" }
local FACTORY_ENEMIES = { "Devil Fruit Scientist", "Scientist", "Factory Guard" }
local RAID_POD_NAMES = { "Raid Pod", "Start Raid", "RaidButton", "LaboratoryPod", "FactoryDoor" }

-- ─── Construtor ──────────────────────────────────────────────
function LawFactoryFarm.new(combat, smartFlight, notifications, settings)
	local self = setmetatable({}, LawFactoryFarm)

	self.Combat        = combat
	self.SmartFlight   = smartFlight
	self.Notifications = notifications
	self.Settings      = settings or {}

	-- Configurações Factory (Rose Kingdom / Dressrosa - Second Sea)
	local fCfg = (self.Settings.Factory or {})
	self.FactoryLocation   = fCfg.Location or Vector3.new(450, 120, -180)
	self.CoreHoverHeight   = fCfg.CoreHoverHeight or 14       -- studs acima do Core (imune a ácido, lava e mobs)
	self.FactoryWaitHeight = fCfg.WaitHeight or 200          -- altitude de espera fora da fábrica
	self.MinLavaAltitude   = fCfg.MinLavaAltitude or 135      -- altitude mínima para jamais ser tocado pela lava

	-- Configurações Law (Rose Kingdom Factory 2nd Floor)
	local lCfg = (self.Settings.Law or {})
	self.LawLocation       = lCfg.Location or Vector3.new(450, 145, -180)
	self.LawCombatHeight   = lCfg.CombatHeight or 14         -- studs acima da cabeça do Law (anti-Thorn e anti-Tact)
	self.ShamblesThreshold = lCfg.ShamblesThreshold or 25     -- distância para considerar que levou Shambles
	self.AutoStartRaid     = lCfg.AutoStartRaid ~= false
	self.LadderCheese      = lCfg.LadderCheese ~= false       -- método lendário do GPO para anular o Law

	self.FactoryEnabled    = false
	self.LawEnabled        = false
	self._running          = false
	self._thread           = nil

	-- Status público para UI
	self.FactoryStatus     = "Desativado"
	self.LawStatus         = "Desativado"
	self.CurrentStage      = "Aguardando"

	return self
end

-- ─── Utilitário: busca modelo no workspace ───────────────────
local function findByNames(namesList)
	for _, name in ipairs(namesList) do
		local m = workspace:FindFirstChild(name, true)
		if m then return m end
	end
	return nil
end

-- ─── Detecta e localiza a Lava subindo na Factory ─────────────
function LawFactoryFarm:_detectLava()
	local lava = workspace:FindFirstChild("Lava", true)
		or workspace:FindFirstChild("RisingLava", true)
		or workspace:FindFirstChild("HazardLava", true)
	if lava and lava:IsA("BasePart") then
		return lava.Position.Y
	end
	return -math.huge
end

-- ─── Localiza o Core da Fábrica ──────────────────────────────
function LawFactoryFarm:_findCore()
	for _, name in ipairs(CORE_NAMES) do
		local core = workspace:FindFirstChild(name, true)
		if core then
			local part = core:IsA("BasePart") and core
				or core:FindFirstChild("HumanoidRootPart")
				or core:FindFirstChildOfClass("BasePart")
			if part then
				return core, part
			end
		end
	end
	return nil, nil
end

-- ─── Localiza mobs da Factory (Scientists / DF Scientists) ───
function LawFactoryFarm:_findMinion()
	for _, name in ipairs(FACTORY_ENEMIES) do
		local minion = workspace:FindFirstChild(name, true)
		if minion and minion:IsA("Model") then
			local hum = minion:FindFirstChildOfClass("Humanoid")
			local root = minion:FindFirstChild("HumanoidRootPart") or minion:FindFirstChildOfClass("BasePart")
			if hum and hum.Health > 0 and root then
				return minion, root, hum
			end
		end
	end
	return nil, nil, nil
end

-- ─── Localiza o Boss Law ("Order") ───────────────────────────
function LawFactoryFarm:_findLaw()
	for _, name in ipairs(LAW_NAMES) do
		local boss = workspace:FindFirstChild(name, true)
		if boss then
			local root = boss:FindFirstChild("HumanoidRootPart")
				or boss:FindFirstChildOfClass("BasePart")
			local hum  = boss:FindFirstChildOfClass("Humanoid")
			if root and (not hum or hum.Health > 0) then
				return boss, root, hum
			end
		end
	end
	return nil, nil, nil
end

-- ─════════════════════════════════════════════════════════════
--   ROTINA 1 — FARM DA FACTORY (FÁBRICA)
-- ══════════════════════════════════════════════════════════════

function LawFactoryFarm:_handleFactory()
	local coreModel, corePart = self:_findCore()

	if not coreModel or not corePart then
		self.FactoryStatus = "Aguardando Abertura"
		return
	end

	-- Verifica se o Law está presente no segundo andar da Factory (Estágio 4 do GPO)
	-- No GPO, no Estágio 4 o Slime Core é INVULNERÁVEL até que o Law seja derrotado!
	local lawModel, lawRoot, lawHum = self:_findLaw()
	if lawModel and lawRoot and (not lawHum or lawHum.Health > 0) then
		self.CurrentStage  = "Estágio 4: Boss Law"
		self.FactoryStatus = "Eliminando Law para liberar o Core"
		Logger.Info("🏭 Factory Estágio 4 detectado! Derrotando Law primeiro para destravar o Core...")
		self:_handleLaw()
		-- Após derrotar o Law, continua imediatamente para destruir o Core
	end

	-- Core está presente e vulnerável!
	self.FactoryStatus = "Destruindo Core!"
	Logger.Success("🏭 FACTORY CORE VULNERÁVEL! Atacando Slime Core em:", tostring(corePart.Position))

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"🏭 FACTORY RAID",
				"Fábrica aberta! Destruindo Slime Core para garantir Fruta/Cyborg Gears!",
				6,
				Color3.fromRGB(255, 80, 80)
			)
		end
	end

	-- Altura segura com verificação de Lava subindo
	local lavaY = self:_detectLava()
	local hoverY = math.max(corePart.Position.Y + self.CoreHoverHeight, lavaY + 20, self.MinLavaAltitude)
	local safeCorePos = Vector3.new(
		corePart.Position.X,
		hoverY,
		corePart.Position.Z
	)

	if self.SmartFlight then
		self.SmartFlight:FlyTo(safeCorePos)
	end

	-- Engaja o CombatController exclusivamente no Core
	if self.Combat then
		self.Combat:SetTarget(coreModel)
	end

	-- Loop de ataque com foco total de dano no Core
	local timeout = os.clock() + 300  -- 5 min máx por raid
	while self.FactoryEnabled and os.clock() < timeout do
		if not coreModel.Parent then
			break  -- Core destruído!
		end

		local hum = coreModel:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then
			break  -- Core eliminado!
		end

		-- Checa novamente a altura da lava durante o combate para evitar subir na lava
		local curLavaY = self:_detectLava()
		if curLavaY > (safeCorePos.Y - 10) then
			safeCorePos = Vector3.new(safeCorePos.X, curLavaY + 20, safeCorePos.Z)
		end

		-- Garante que o jogador permaneça suspenso acima do ácido/lava
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - safeCorePos).Magnitude > 6 then
			root.CFrame = CFrame.new(safeCorePos, corePart.Position)
			root.AssemblyLinearVelocity = Vector3.zero
		end

		task.wait(0.2)
	end

	Logger.Success("🏆 CORE DA FÁBRICA DESTRUÍDO! Verificando recompensa (Fruta Rara+ ou Cyborg Gear).")
	self.FactoryStatus = "Core Destruído (Sucesso)"

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"🏆 FACTORY FINALIZADA",
				"Core destruído com sucesso!\nVerificando inventário de frutas.",
				6,
				Color3.fromRGB(46, 204, 113)
			)
		end
	end

	-- Pausa breve para coleta automática e recuo para fora do ácido
	task.wait(3)
	if self.SmartFlight then
		local exitPos = safeCorePos + Vector3.new(0, 80, 0)
		self.SmartFlight:FlyTo(exitPos)
	end

	if self.Combat then
		self.Combat:Stop()
	end

	self.FactoryStatus = "Concluído"
end

-- ─════════════════════════════════════════════════════════════
--   ROTINA 2 — FARM DO BOSS LAW ("ORDER")
-- ══════════════════════════════════════════════════════════════

function LawFactoryFarm:_handleLaw()
	local lawModel, lawRoot, lawHum = self:_findLaw()

	if not lawModel or not lawRoot then
		self.LawStatus = "Aguardando Spawn/Raid"

		-- Se auto-start estiver ativo, tenta acionar o terminal de raid
		if self.AutoStartRaid then
			local pod = findByNames(RAID_POD_NAMES)
			if pod and self.SmartFlight then
				local podPart = pod:IsA("BasePart") and pod or pod:FindFirstChildOfClass("BasePart")
				if podPart then
					local dist = (Players.LocalPlayer.Character.HumanoidRootPart.Position - podPart.Position).Magnitude
					if dist > 8 then
						self.SmartFlight:FlyTo(podPart.Position + Vector3.new(0, 4, 0))
					end
					-- Tenta acionar ProximityPrompt do pod se existir
					local prompt = pod:FindFirstChildOfClass("ProximityPrompt", true)
					if prompt and fireproximityprompt then
						fireproximityprompt(prompt)
					end
				end
			end
		end

		return
	end

	-- Boss Law detectado!
	self.LawStatus = "Combatendo Law"
	Logger.Success("⚡ LAW (ORDER) DETECTADO! Iniciando combate aéreo especializado...")

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"⚡ BOSS LAW (ORDER)",
				"Engajando Law com proteção aérea anti-Shambles!",
				5,
				Color3.fromRGB(241, 196, 15)
			)
		end
	end

	-- Engaja o combate
	if self.Combat then
		self.Combat:SetTarget(lawModel)
	end

	-- Loop de combate aéreo contra o Law
	local timeout = os.clock() + 450
	while self.LawEnabled and os.clock() < timeout do
		if not lawModel.Parent or (lawHum and lawHum.Health <= 0) then
			break
		end

		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")

		if root and lawRoot and lawRoot.Parent then
			local currentLawPos = lawRoot.Position
			local idealPos      = Vector3.new(
				currentLawPos.X,
				currentLawPos.Y + self.LawCombatHeight,
				currentLawPos.Z
			)

			local distToLaw = (root.Position - currentLawPos).Magnitude

			-- ─── ANTI-SHAMBLES HANDLER ────────────────────────────
			-- Se o Law usar Shambles e teleportar o jogador para longe (> threshold):
			if distToLaw > self.ShamblesThreshold then
				self.LawStatus = "Recuperando de Shambles..."
				Logger.Warn("Shambles detectado! Reposicionando instantaneamente acima do Law.")

				-- Teleporta o CFrame diretamente acima dele sem delay
				root.CFrame = CFrame.new(idealPos, currentLawPos)
				root.AssemblyLinearVelocity = Vector3.zero
				task.wait(0.05)
			else
				-- Mantém posição aérea superior (ponto cego do Tact e corte frontal)
				if (root.Position - idealPos).Magnitude > 4 then
					root.CFrame = CFrame.new(idealPos, currentLawPos)
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end

		task.wait(0.1)
	end

	Logger.Success("⚡ BOSS LAW ELIMINADO!")
	self.LawStatus = "Law Derrotado"

	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"⚡ VITÓRIA: LAW",
				"Boss Law eliminado com sucesso!",
				5,
				Color3.fromRGB(46, 204, 113)
			)
		end
	end

	if self.Combat then
		self.Combat:Stop()
	end
end

-- ─── Loop principal ──────────────────────────────────────────
function LawFactoryFarm:_loop()
	while self._running do
		local ok, err = pcall(function()
			-- Prioridade 1: Factory (evento com tempo limitado)
			if self.FactoryEnabled then
				self:_handleFactory()
			end

			-- Prioridade 2: Law Raid
			if self.LawEnabled then
				self:_handleLaw()
			end
		end)

		if not ok then
			Logger.Error("LawFactoryFarm loop error:", err)
		end

		task.wait(2.0)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function LawFactoryFarm:Start()
	if self._running then return end
	self._running = true
	self._thread  = task.spawn(function() self:_loop() end)
	Logger.Info("LawFactoryFarm iniciado.")
end

function LawFactoryFarm:Stop()
	self._running        = false
	self.FactoryEnabled  = false
	self.LawEnabled      = false
	self.FactoryStatus   = "Desativado"
	self.LawStatus       = "Desativado"

	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	Logger.Info("LawFactoryFarm parado.")
end

function LawFactoryFarm:SetFactoryEnabled(enabled)
	self.FactoryEnabled = enabled
	if enabled and not self._running then
		self:Start()
	end
	Logger.Info("Factory Farm:", enabled and "ATIVADO" or "DESATIVADO")
end

function LawFactoryFarm:SetLawEnabled(enabled)
	self.LawEnabled = enabled
	if enabled and not self._running then
		self:Start()
	end
	Logger.Info("Law Farm:", enabled and "ATIVADO" or "DESATIVADO")
end

return LawFactoryFarm

end)

-- ────────────────────────────────────────────────────────────
-- Entrypoint: EliteAutomation.client.lua
-- ────────────────────────────────────────────────────────────
do
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
-- [Bundle Mode] Root redirecionado

-- ─── Core ─────────────────────────────────────────────────────
local Logger         = customRequire("EliteAutomation.Core.Logger")
local TaskManager    = customRequire("EliteAutomation.Core.TaskManager")
local StateMachine   = customRequire("EliteAutomation.Core.StateMachine")
local PriorityManager = customRequire("EliteAutomation.Core.PriorityManager")

-- ─── Config ───────────────────────────────────────────────────
local Settings = customRequire("EliteAutomation.Config.Settings")

-- Configura nível de log
if Settings.General.DebugLogs then
	Logger.SetMinLevel("DEBUG")
else
	Logger.SetMinLevel("INFO")
end

-- ─── UI ───────────────────────────────────────────────────────
local MainUI       = customRequire("EliteAutomation.UI.MainUI")
local TabManager   = customRequire("EliteAutomation.UI.TabManager")
local Components   = customRequire("EliteAutomation.UI.Components")
local Notifications = customRequire("EliteAutomation.UI.Notifications")

-- ─── Sistemas ─────────────────────────────────────────────────
local FruitDatabase   = customRequire("EliteAutomation.Systems.FruitDatabase")
local FruitTracker    = customRequire("EliteAutomation.Systems.FruitTracker")
local BossManager     = customRequire("EliteAutomation.Systems.BossManager")
local ItemFarm        = customRequire("EliteAutomation.Systems.ItemFarm")
local MerchantTracker = customRequire("EliteAutomation.Systems.MerchantTracker")
local LawFactoryFarm  = customRequire("EliteAutomation.Systems.LawFactoryFarm")

-- ─── Combate ──────────────────────────────────────────────────
local CombatController = customRequire("EliteAutomation.Combat.CombatController")
local TargetSelector   = customRequire("EliteAutomation.Combat.TargetSelector")

-- ─── Movimento ────────────────────────────────────────────────
local SmartFlight = customRequire("EliteAutomation.Movement.SmartFlight")

-- ══════════════════════════════════════════════════════════════
--   INICIALIZAÇÃO DOS MÓDULOS
-- ══════════════════════════════════════════════════════════════

Logger.Info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Logger.Info("  Elite Automation Framework v2.0")
Logger.Info("  Grand Piece Online (GPO) | Iniciando...")
Logger.Info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ─ Gerenciador de tarefas ─
local manager = TaskManager.new()

-- ─ Movimento ─
local smartFlight = SmartFlight.new(character, Settings.Movement)

-- ─ Combate ─
local combatController = CombatController.new(Settings.Combat)

-- ─ Sistemas ─
local fruitTracker = FruitTracker.new(
	FruitDatabase,
	Notifications,
	Settings.FruitTracker
)
fruitTracker:SetFlight(smartFlight)  -- injeta o voo

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

-- ─ CombatController: callbacks ─
combatController.OnTargetFound = function(model)
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

-- ─ Anti-Detection Mode ─
manager:Register(
	"AntiDetection",
	function()
		Settings.General.AntiDetectionMode = true
		smartFlight.SpeedBase   = 45   -- velocidade mais lenta = menos suspeito
		combatController.AttackMin = 0.60
		combatController.AttackMax = 1.10
		Logger.Info("Anti-Detection Mode: ATIVADO")
		Notifications.Create(localPlayer.PlayerGui,
			"🛡 ANTI-DETECÇÃO", "Modo furtivo ativado", 4, Color3.fromRGB(255, 200, 0))
	end,
	function()
		Settings.General.AntiDetectionMode = false
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
--   ABA: MAIN
-- ──────────────────────────────────────────────

-- Status label de estado
local statusLabel    = Components.CreateStatusLabel(frameMain, "Estado Geral", "Idle")
local bossLabel      = Components.CreateStatusLabel(frameMain, "Boss Ativo", "—")
local merchantLabel  = Components.CreateStatusLabel(frameMain, "Mercador GPO", "Calculando ciclo...")
local fruitLabel     = Components.CreateStatusLabel(frameMain, "Frutas Coletadas", "0")

merchantTracker.OnMerchantSpawned = function(data)
	merchantLabel.SetValue("Ativo: " .. data.island)
end
merchantTracker.OnMerchantDespawned = function()
	local sched = merchantTracker:GetSchedule()
	merchantLabel.SetValue(sched and sched.DisplayText or "Aguardando spawn")
end

Components.CreateSeparator(frameMain)

-- Toggles principais
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
end, true)

local toggleItemFarm = Components.CreateToggle(frameMain, "Item Farm (Baús)", function(enabled)
	manager:SetEnabled("ItemFarm", enabled)
end)

local toggleAntiDetect = Components.CreateToggle(frameMain, "Anti-Detection Mode", function(enabled)
	manager:SetEnabled("AntiDetection", enabled)
end)

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
--   ABA: COMBAT
-- ──────────────────────────────────────────────

local combatStatusLabel  = Components.CreateStatusLabel(frameCombat, "Estado Combate", "Idle")
local factoryStageLabel  = Components.CreateStatusLabel(frameCombat, "Factory Stage", "Aguardando")
local factoryStatusLabel = Components.CreateStatusLabel(frameCombat, "Factory Core", "Desativado")
local lawStatusLabel     = Components.CreateStatusLabel(frameCombat, "Boss Law (Order)", "Desativado")

Components.CreateSeparator(frameCombat)

-- ─ Farm Especializado: Factory & Law ─
local toggleFactoryFarm = Components.CreateToggle(frameCombat, "Auto-Farm Factory (Core)", function(enabled)
	manager:SetEnabled("FactoryFarm", enabled)
end)

local toggleLawFarm = Components.CreateToggle(frameCombat, "Auto-Farm Law (Order)", function(enabled)
	manager:SetEnabled("LawFarm", enabled)
end)

Components.CreateSeparator(frameCombat)

-- ─ Controles GPO: Haki & Execução ─
Components.CreateToggle(frameCombat, "Auto-Buso Haki ('J')", function(enabled)
	manager:SetEnabled("AutoBuso", enabled)
end, true)

Components.CreateToggle(frameCombat, "Auto-Ken Haki ('K')", function(enabled)
	manager:SetEnabled("AutoKen", enabled)
end, false)

Components.CreateToggle(frameCombat, "Auto-Grip / Executar ('B')", function(enabled)
	manager:SetEnabled("AutoGrip", enabled)
end, true)

Components.CreateSeparator(frameCombat)

-- ─ Boss Farm Geral ─
Components.CreateToggle(frameCombat, "Boss Farm Geral (Mundo/Mar)", function(enabled)
	manager:SetEnabled("BossFarm", enabled)
	toggleBossFarm.SetEnabled(enabled)
end)

-- ─ Botões de Ação Rápida ─
Components.CreateButton(frameCombat, "🏭 Voar para a Factory", function()
	local loc = Settings.LawFactoryFarm.Factory.Location
	smartFlight:FlyTo(loc)
	Notifications.Create(localPlayer.PlayerGui,
		"🏭 VOO FACTORY", "Voando até a Factory...", 3, Color3.fromRGB(255, 80, 80))
end)

Components.CreateButton(frameCombat, "⚡ Voar para o Law (Order)", function()
	local loc = Settings.LawFactoryFarm.Law.Location
	smartFlight:FlyTo(loc)
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
			smartFlight:FlyTo(nearest)
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
	"Framework v2.0 carregado!\nPressione HOME para abrir.",
	6,
	Color3.fromRGB(100, 130, 255)
)

end
