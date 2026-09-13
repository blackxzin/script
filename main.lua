-- ============================================================
--  Elite Automation Framework v2.1 - Standalone Universal Bundle
--  Optimized for Grand Piece Online (GPO)
--  Compatible with: Xeno, Delta, Codex, Fluxus, Hydrogen, Arceus X
--  GitHub: https://github.com/blackxzin/script
--
--  Execute with:
--  loadstring(game:HttpGet("https://raw.githubusercontent.com/blackxzin/script/main/loader.lua"))()
--
--  GERADO por tools/bundle.py — nao edite direto, edite src/
--  e rode: python3 tools/bundle.py
-- ============================================================


-- Previne execucao duplicada
if getgenv and getgenv()._EliteAutomationLoaded then
	warn("[EliteAutomation] Script ja esta em execucao!")
	return
end
if getgenv then getgenv()._EliteAutomationLoaded = true end

-- NOTA: sem hook em game.HttpGet. Hook global quebra chamadas internas
-- do Roblox/GPO (kick/disconnect) e e detectavel pelo anticheat.

local executor = "Unknown"
if identifyexecutor then executor = identifyexecutor()
elseif getexecutorname then executor = getexecutorname()
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  [EliteAutomation v2.1] GPO Hub")
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
-- Module: EliteAutomation.Core.PerformanceManager
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Core.PerformanceManager", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Core.PerformanceManager
--  Otimizador de memória, connection pooling e cleanup.
-- ============================================================

local RunService = game:GetService("RunService")

local PerformanceManager = {}
PerformanceManager.__index = PerformanceManager

function PerformanceManager.new()
	local self = setmetatable({}, PerformanceManager)

	self._connections = {}  -- pool de RBXScriptConnection
	self._tweens = {}       -- pool de Tweens ativos
	self._timers = {}       -- pool de threads
	self._lastCleanup = os.clock()
	self.CleanupInterval = 30  -- segundos

	return self
end

-- ─── Connection pooling ──────────────────────────────────────
function PerformanceManager:Track(name, connection)
	if not self._connections[name] then
		self._connections[name] = {}
	end
	table.insert(self._connections[name], connection)
	return connection
end

function PerformanceManager:Disconnect(name)
	local conns = self._connections[name]
	if not conns then return end

	for _, conn in ipairs(conns) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	self._connections[name] = nil
end

function PerformanceManager:DisconnectAll()
	for name in pairs(self._connections) do
		self:Disconnect(name)
	end
end

-- ─── Tween pooling ───────────────────────────────────────────
function PerformanceManager:TrackTween(tween)
	table.insert(self._tweens, tween)

	tween.Completed:Connect(function()
		for i, t in ipairs(self._tweens) do
			if t == tween then
				table.remove(self._tweens, i)
				break
			end
		end
	end)

	return tween
end

function PerformanceManager:CancelAllTweens()
	for _, tween in ipairs(self._tweens) do
		if tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Cancel()
		end
	end
	self._tweens = {}
end

-- ─── Timer/Thread pooling ────────────────────────────────────
function PerformanceManager:TrackTimer(name, thread)
	if self._timers[name] then
		task.cancel(self._timers[name])
	end
	self._timers[name] = thread
	return thread
end

function PerformanceManager:CancelTimer(name)
	local t = self._timers[name]
	if t then
		task.cancel(t)
		self._timers[name] = nil
	end
end

function PerformanceManager:CancelAllTimers()
	for name, thread in pairs(self._timers) do
		task.cancel(thread)
	end
	self._timers = {}
end

-- ─── Debounce helper ─────────────────────────────────────────
function PerformanceManager:Debounce(name, delay, func)
	self:CancelTimer(name)

	local thread = task.delay(delay, func)
	self:TrackTimer(name, thread)
end

-- ─── Throttle helper ─────────────────────────────────────────
function PerformanceManager:Throttle(name, interval)
	local lastRun = self["_throttle_" .. name] or 0
	local now = os.clock()

	if (now - lastRun) >= interval then
		self["_throttle_" .. name] = now
		return true
	end
	return false
end

-- ─── Auto-cleanup periódico ──────────────────────────────────
function PerformanceManager:AutoCleanup()
	local now = os.clock()
	if (now - self._lastCleanup) < self.CleanupInterval then
		return
	end

	self._lastCleanup = now

	-- Remove connections mortas
	for name, conns in pairs(self._connections) do
		local alive = {}
		for _, conn in ipairs(conns) do
			if conn and conn.Connected then
				table.insert(alive, conn)
			end
		end
		self._connections[name] = alive
	end

	-- Coleta lixo se memória > 500MB
	local stats = game:GetService("Stats")
	local memMB = stats:GetTotalMemoryUsageMb()
	if memMB > 500 then
		collectgarbage("collect")
	end
end

-- ─── Força cleanup total ─────────────────────────────────────
function PerformanceManager:Cleanup()
	self:DisconnectAll()
	self:CancelAllTweens()
	self:CancelAllTimers()
	collectgarbage("collect")
end

return PerformanceManager

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
		RangedMin         = 32,      -- Farm de arma: distância mínima (kite)
		RangedMax         = 60,      -- Farm de arma: distância máxima de tiro
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
			UseCyborgSkills   = true,   -- rotacao Z/X/C/V da Cyborg no Law/Factory
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
-- Module: EliteAutomation.UI.Theme
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.UI.Theme", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: UI.Theme
--  Sistema de temas com glassmorphism, gradientes e animações.
-- ============================================================

local Theme = {}

-- ─── Temas disponíveis ────────────────────────────────────────
Theme.Presets = {
	Dark = {
		Name = "Dark Elite",
		BG = Color3.fromRGB(10, 10, 20),
		BGGradient = {Color3.fromRGB(15, 15, 30), Color3.fromRGB(8, 8, 18)},
		Header = Color3.fromRGB(15, 15, 30),
		Surface = Color3.fromRGB(20, 20, 38),
		Border = Color3.fromRGB(50, 50, 90),
		Accent = Color3.fromRGB(100, 130, 255),
		AccentGlow = Color3.fromRGB(80, 110, 230),
		AccentOff = Color3.fromRGB(55, 55, 90),
		Text = Color3.fromRGB(230, 230, 255),
		TextSub = Color3.fromRGB(130, 130, 180),
		Success = Color3.fromRGB(80, 220, 130),
		Danger = Color3.fromRGB(255, 80, 100),
		Warning = Color3.fromRGB(255, 200, 80),
		TabInactive = Color3.fromRGB(35, 35, 62),
		TabActive = Color3.fromRGB(100, 130, 255),
		Blur = true,
		BlurSize = 12,
	},
	Neon = {
		Name = "Neon Cyber",
		BG = Color3.fromRGB(8, 8, 18),
		BGGradient = {Color3.fromRGB(15, 5, 25), Color3.fromRGB(5, 15, 35)},
		Header = Color3.fromRGB(12, 8, 25),
		Surface = Color3.fromRGB(18, 12, 32),
		Border = Color3.fromRGB(120, 60, 200),
		Accent = Color3.fromRGB(200, 60, 255),
		AccentGlow = Color3.fromRGB(180, 40, 240),
		AccentOff = Color3.fromRGB(60, 30, 80),
		Text = Color3.fromRGB(240, 240, 255),
		TextSub = Color3.fromRGB(160, 120, 200),
		Success = Color3.fromRGB(100, 255, 150),
		Danger = Color3.fromRGB(255, 60, 120),
		Warning = Color3.fromRGB(255, 180, 60),
		TabInactive = Color3.fromRGB(40, 20, 60),
		TabActive = Color3.fromRGB(200, 60, 255),
		Blur = true,
		BlurSize = 16,
	},
	Minimal = {
		Name = "Minimal",
		BG = Color3.fromRGB(18, 18, 18),
		BGGradient = {Color3.fromRGB(20, 20, 20), Color3.fromRGB(15, 15, 15)},
		Header = Color3.fromRGB(22, 22, 22),
		Surface = Color3.fromRGB(25, 25, 25),
		Border = Color3.fromRGB(60, 60, 60),
		Accent = Color3.fromRGB(120, 120, 255),
		AccentGlow = Color3.fromRGB(100, 100, 235),
		AccentOff = Color3.fromRGB(60, 60, 80),
		Text = Color3.fromRGB(240, 240, 240),
		TextSub = Color3.fromRGB(140, 140, 140),
		Success = Color3.fromRGB(100, 200, 120),
		Danger = Color3.fromRGB(240, 80, 80),
		Warning = Color3.fromRGB(240, 180, 60),
		TabInactive = Color3.fromRGB(40, 40, 40),
		TabActive = Color3.fromRGB(120, 120, 255),
		Blur = false,
		BlurSize = 0,
	},
}

Theme.Current = Theme.Presets.Dark

-- ─── Aplica gradiente em frame ────────────────────────────────
function Theme.ApplyGradient(frame, color1, color2, rotation)
	rotation = rotation or 90

	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = frame
	end

	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color1),
		ColorSequenceKeypoint.new(1, color2),
	})
	gradient.Rotation = rotation

	return gradient
end

-- ─── Adiciona blur backdrop (glassmorphism) ───────────────────
function Theme.ApplyBlur(frame, size)
	size = size or Theme.Current.BlurSize
	if not Theme.Current.Blur then return end

	-- Usa BackgroundTransparency + Stroke para simular glass
	frame.BackgroundTransparency = 0.15

	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = frame
	end
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.85

	-- Efeito de brilho interno
	local glow = frame:FindFirstChild("GlowEffect")
	if not glow then
		glow = Instance.new("ImageLabel")
		glow.Name = "GlowEffect"
		glow.Size = UDim2.new(1, 0, 1, 0)
		glow.BackgroundTransparency = 1
		glow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
		glow.ImageTransparency = 0.92
		glow.ImageColor3 = Theme.Current.Accent
		glow.ZIndex = frame.ZIndex - 1
		glow.Parent = frame
	end
end

-- ─── Corner helper ───────────────────────────────────────────
function Theme.Corner(radius, parent)
	local c = parent:FindFirstChildOfClass("UICorner")
	if not c then
		c = Instance.new("UICorner")
		c.Parent = parent
	end
	c.CornerRadius = UDim.new(0, radius)
	return c
end

-- ─── Stroke helper ───────────────────────────────────────────
function Theme.Stroke(color, thick, parent, transparency)
	local s = parent:FindFirstChildOfClass("UIStroke")
	if not s then
		s = Instance.new("UIStroke")
		s.Parent = parent
	end
	s.Color = color
	s.Thickness = thick
	s.Transparency = transparency or 0
	return s
end

-- ─── Muda tema globalmente ───────────────────────────────────
function Theme.SetTheme(presetName)
	local preset = Theme.Presets[presetName]
	if preset then
		Theme.Current = preset
		return true
	end
	return false
end

return Theme

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

	-- ─ Re-execução limpa: remove UI velha (loops duplicados = kick) ─
	pcall(function()
		local old = playerGui:FindFirstChild("EliteAutomationUI")
		if old then old:Destroy() end
		local notifs = playerGui:FindFirstChild("EliteNotifs")
		if notifs then notifs:Destroy() end
	end)

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
	subLabel.Text           = "Grand Piece Online (GPO) v2.1"
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

	-- ─ Content Area (Frame fixo; cada aba tem scroll próprio) ─
	local content = Instance.new("Frame")
	content.Name                 = "ContentArea"
	content.Size                 = UDim2.new(1, 0, 1, -(HEADER_H + TAB_H + 8))
	content.Position             = UDim2.new(0, 0, 0, HEADER_H + TAB_H)
	content.BackgroundTransparency = 1
	content.BorderSizePixel      = 0
	content.ClipsDescendants     = true
	content.Parent = panel
	self.ContentArea = content
	contentArea = content

	self._tabButtons = {}
	self._tabFrames  = {}
	self._tabCount   = 0

	return self
end

-- ─── Cria botão de aba (largura redividida; /4 fixo quebrava com N abas) ───
function MainUI:CreateTabButton(name)
	self._tabCount = self._tabCount + 1

	local tabW = math.floor(PANEL_W / self._tabCount)
	for _, b in ipairs(self._tabButtons) do
		b.Size = UDim2.new(0, tabW, 1, 0)
	end

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
	corner(6, btn)

	table.insert(self._tabButtons, btn)
	return btn
end

-- ─── Cria frame de conteúdo de aba (scroll próprio por aba) ────
function MainUI:CreateTabFrame()
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name                   = "TabContent_" .. tostring(#self._tabFrames + 1)
	scroll.Size                   = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel        = 0
	scroll.Visible                = false
	scroll.Active                 = true
	scroll.ClipsDescendants       = true
	scroll.ScrollingDirection     = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness     = 6
	scroll.ScrollBarImageColor3   = C.Accent
	scroll.ElasticBehaviour       = Enum.ElasticBehavior.WhenScrollable
	scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	scroll.Parent                 = self.ContentArea

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding   = UDim.new(0, 6)
	layout.Parent    = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft   = UDim.new(0, 8)
	pad.PaddingRight  = UDim.new(0, 8)
	pad.PaddingTop    = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent        = scroll

	table.insert(self._tabFrames, scroll)
	return scroll
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
	self.Order     = {}       -- insercao ordenada; pairs() ordem aleatoria
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
	if not self.Tabs[name] then
		table.insert(self.Order, name)
	end
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

	-- Desativa a aba atual (ordem de insercao; pairs() ordem aleatoria)
	for _, tabName in ipairs(self.Order) do
		local tab = self.Tabs[tabName]
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

		-- Mostra/oculta conteúdo (cada aba é um ScrollingFrame próprio)
		if isTarget then
			tab.Content.Visible = true
			pcall(function()
				tab.Content.CanvasPosition = Vector2.new(0, 0)
			end)
		else
			tab.Content.Visible = false
		end
	end

	self.ActiveTab = name
end

-- Ativa a primeira aba registrada (ordem de insercao)
function TabManager:ShowFirst()
	if #self.Order > 0 then
		self:Switch(self.Order[1])
	end
end

function TabManager:GetActive()
	return self.ActiveTab
end

return TabManager

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
Components._order = 0 -- UIListLayout ordena por LayoutOrder; sem contador único a ordem empilha

local function nextOrder()
	Components._order += 1
	return Components._order
end

-- Carrega tema dinâmico
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Theme = customRequire("EliteAutomation.UI.Theme")

-- Paleta dinâmica
local function C()
	return Theme.Current
end

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
	row.BackgroundColor3      = C().Surface
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel       = 0
	row.LayoutOrder           = nextOrder()
	Theme.Corner(8, row)
	row.Parent = parent

	Theme.Stroke(C().Border, 1, row)
	Theme.ApplyBlur(row, 8)

	-- ─ Label ─
	local lbl = Instance.new("TextLabel")
	lbl.Name              = "Label"
	lbl.Size              = UDim2.new(1, -60, 1, 0)
	lbl.Position          = UDim2.new(0, 12, 0, 0)
	lbl.Text              = label
	lbl.TextColor3        = C().Text
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
	track.BackgroundColor3 = enabled and C().Accent or C().AccentOff
	track.BorderSizePixel  = 0
	Theme.Corner(11, track)
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
	Theme.Corner(8, thumb)
	thumb.Parent = track

	-- ─ Animação do toggle ─
	local function animate(state)
		TweenService:Create(track, TweenInfo.new(0.18, Enum.EasingStyle.Sine),
			{ BackgroundColor3 = state and C().Accent or C().AccentOff }
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
	row.LayoutOrder      = nextOrder()
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size             = UDim2.new(0.5, 0, 1, 0)
	lbl.Text             = labelText
	lbl.TextColor3       = C().TextSub
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
	val.TextColor3       = C().Text
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
	sep.BackgroundColor3 = C().Border
	sep.BorderSizePixel  = 0
	sep.LayoutOrder      = nextOrder()
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
	btn.BackgroundColor3 = C().Accent
	btn.Text             = label
	btn.TextColor3       = Color3.fromRGB(255, 255, 255)
	btn.TextSize         = 13
	btn.Font             = Enum.Font.GothamBold
	btn.BorderSizePixel  = 0
	btn.LayoutOrder      = nextOrder()
	Theme.Corner(8, btn)
	Theme.ApplyGradient(btn, C().Accent, C().AccentGlow, 45)
	btn.Parent = parent

	btn.MouseButton1Click:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.08),
			{ BackgroundColor3 = Color3.fromRGB(70, 100, 220) }):Play()
		task.wait(0.1)
		TweenService:Create(btn, TweenInfo.new(0.15),
			{ BackgroundColor3 = C().Accent }):Play()
		if callback then task.spawn(callback) end
	end)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12),
			{ BackgroundColor3 = Color3.fromRGB(120, 150, 255) }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12),
			{ BackgroundColor3 = C().Accent }):Play()
	end)

	return btn
end

-- ─════════════════════════════════════════════════════════════
--   Título de seção (organiza o painel por blocos)
-- ═════════════════════════════════════════════════════════════

function Components.CreateSection(parent, title)
	local lbl = Instance.new("TextLabel")
	lbl.Name             = "Section_" .. title
	lbl.Size             = UDim2.new(1, -10, 0, 20)
	lbl.Text             = string.upper(title)
	lbl.TextColor3       = C().Accent
	lbl.TextSize         = 11
	lbl.Font             = Enum.Font.GothamBold
	lbl.TextXAlignment   = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1
	lbl.LayoutOrder      = nextOrder()
	lbl.Parent = parent

	local sep = Instance.new("Frame")
	sep.Size             = UDim2.new(1, -10, 0, 1)
	sep.BackgroundColor3 = C().Accent
	sep.BackgroundTransparency = 0.6
	sep.BorderSizePixel  = 0
	sep.LayoutOrder      = nextOrder()
	sep.Parent = parent
	return lbl
end

return Components

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
-- [Bundle] Root redirecionado
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
		if obj:IsA("Model") or obj:IsA("BasePart") then
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
				-- Tenta acionar ProximityPrompt caso exista (sem teleport: disconnect)
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
-- [Bundle] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

local BossManager = {}
BossManager.__index = BossManager

-- ─── Índice único por scan: 1x GetDescendants em vez de 30x FindFirstChild(true) ─
local function buildModelIndex()
	local index = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local key = obj.Name:lower()
			if not index[key] then
				if obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildOfClass("Humanoid") then
					index[key] = obj
				end
			end
		end
	end
	return index
end

-- ─── Utilitário: encontra modelo no workspace por nome ou aliases ─
local function findBossModel(config, index)
	if not config then return nil end

	-- Lista de nomes a testar
	local names = { config.Name }
	if config.Aliases then
		for _, alias in ipairs(config.Aliases) do
			table.insert(names, alias)
		end
	end

	for _, name in ipairs(names) do
		local m
		if index then
			m = index[name:lower()]
		else
			m = workspace:FindFirstChild(name, true) or workspace:FindFirstChild(name)
		end
		if m and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildOfClass("Humanoid")) then
			return m
		end
	end

	-- Busca parcial só com índice (sem índice: 1x GetChildren, sem scan recursivo extra)
	if index then
		local lowerName = config.Name:lower()
		for key, obj in pairs(index) do
			if key:find(lowerName, 1, true) then
				return obj
			end
		end
	else
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

function BossManager:_handleRaidBoss(config, index)
	Logger.Info("BossManager → Verificando Raid Boss:", config.Name)

	local bossModel = findBossModel(config, index)
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
		self.Combat:ClearTarget()
	end

	Logger.Success("Raid Boss", config.Name, "finalizado!")
end

-- ─════════════════════════════════════════════════════════════
--   CATEGORIA 2 — BOSSES DE TEMPO E ILHAS (Ryuma, Borj, Gravito, Enel, Neptune)
-- ══════════════════════════════════════════════════════════════

function BossManager:_handleTimedBoss(config, index)
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
	local bossModel = findBossModel(config, index)

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

function BossManager:_handleLocationBoss(config, index)
	local bossModel = findBossModel(config, index)
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
							Logger.Warn("Anti-afogamento GPO ativado! Mantendo sobre o mar.")
							if self.SmartFlight then
								self.SmartFlight:FlyTo(Vector3.new(
									root.Position.X,
									seaLevel + config.SafeAltitude + 5,
									root.Position.Z
								))
							end
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
			local index = buildModelIndex()

			-- ── 1. Sea Events / Location Bosses (Prioridade máxima em GPO)
			if cfg.LocationBosses then
				for _, bossCfg in pairs(cfg.LocationBosses) do
					if not self._running then break end
					self:_handleLocationBoss(bossCfg, index)
				end
			end

			-- ── 2. Bosses de Tempo e Ilhas
			if cfg.TimedBosses then
				for _, bossCfg in pairs(cfg.TimedBosses) do
					if not self._running then break end
					self:_handleTimedBoss(bossCfg, index)
				end
			end

			-- ── 3. Raids e Dungeons
			if cfg.RaidBosses then
				for _, bossCfg in pairs(cfg.RaidBosses) do
					if not self._running then break end
					self:_handleRaidBoss(bossCfg, index)
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
-- [Bundle] Root redirecionado
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

	-- Voa até o item (sem setar CFrame direto: teleport = disconnect)
	if self.SmartFlight then
		self.SmartFlight:FlyTo(pos + Vector3.new(0, 3, 0))
	end
	task.wait(0.2)

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
-- [Bundle] Root redirecionado
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
	local now = os.clock()
	if self._lastFly and (now - self._lastFly) < 5 then return false end -- spam = flag
	if not self._currentMerchant or not self._currentMerchant.position then
		Logger.Warn("MerchantTracker: Mercador não está ativo no momento.")
		return false
	end
	local pos = self._currentMerchant.position
	if pos.X ~= pos.X or math.abs(pos.X) > 1e5
		or pos.Y ~= pos.Y or math.abs(pos.Y) > 1e5
		or pos.Z ~= pos.Z or math.abs(pos.Z) > 1e5 then
		Logger.Warn("MerchantTracker: posição inválida, voo cancelado.")
		return false
	end
	if not self._smartFlight then
		Logger.Warn("MerchantTracker: SmartFlight não configurado.")
		return false
	end
	local targetPos = pos + Vector3.new(0, 4, 0)
	Logger.Info("Voando até o Mercador em:", self._currentMerchant.island)
	self._lastFly = now
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
-- [Bundle] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

local LawFactoryFarm = {}
LawFactoryFarm.__index = LawFactoryFarm

-- Cyborg V2/V3: skills Z/X/C/V com cooldown. Sem spam: 1 skill/4s.
local CYBORG_KEYS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
local CYBORG_CD = { [Enum.KeyCode.Z] = 6, [Enum.KeyCode.X] = 9, [Enum.KeyCode.C] = 12, [Enum.KeyCode.V] = 18 }

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
	self.UseCyborgSkills   = lCfg.UseCyborgSkills ~= false    -- rotacao Z/X/C/V da Cyborg
	self._lastSkill        = 0
	self._skillIdx         = 1
	self._skillTimes       = {}

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

-- ─── Rotacao Cyborg Z/X/C/V com cooldown (sem spam = kick) ────
function LawFactoryFarm:_cyborgTick()
	if not self.UseCyborgSkills then return end
	local now = os.clock()
	if (now - self._lastSkill) < 4 then return end
	local key = CYBORG_KEYS[self._skillIdx]
	self._skillIdx = (self._skillIdx % #CYBORG_KEYS) + 1
	local cd = CYBORG_CD[key] or 8
	if (now - (self._skillTimes[key] or 0)) < cd then return end
	self._skillTimes[key] = now
	self._lastSkill = now
	local vim = game:GetService("VirtualInputManager")
	if vim then
		pcall(function()
			vim:SendKeyEvent(true, key, false, game)
			task.wait(0.05)
			vim:SendKeyEvent(false, key, false, game)
		end)
	end
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

		-- Mantém suspenso acima do ácido/lava via tween (sem CFrame direto)
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and self.SmartFlight and (root.Position - safeCorePos).Magnitude > 10 then
			self.SmartFlight:FlyTo(safeCorePos)
		end

		task.wait(0.5)
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
		self.Combat:ClearTarget()
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
	-- Sem CFrame direto aqui: teleport por frame = disconnect no GPO.
	-- Correções só via FlyTo (tween) e com throttle.
	local timeout = os.clock() + 450
	local lastCorrect = 0
	while self.LawEnabled and os.clock() < timeout do
		if not lawModel.Parent or (lawHum and lawHum.Health <= 0) then
			break
		end

		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")

		if root and lawRoot and lawRoot.Parent and self.SmartFlight then
			local currentLawPos = lawRoot.Position
			local idealPos      = Vector3.new(
				currentLawPos.X,
				currentLawPos.Y + self.LawCombatHeight,
				currentLawPos.Z
			)

			local distToLaw = (root.Position - currentLawPos).Magnitude
			local now = os.clock()

			-- ─── ANTI-SHAMBLES HANDLER ────────────────────────────
			-- Se o Law usar Shambles e teleportar o jogador para longe (> threshold):
			if distToLaw > self.ShamblesThreshold then
				self.LawStatus = "Recuperando de Shambles..."
				Logger.Warn("Shambles detectado! Reposicionando acima do Law.")
				self.SmartFlight:FlyTo(idealPos)
				lastCorrect = os.clock()
			elseif (root.Position - idealPos).Magnitude > 12 and (now - lastCorrect) > 1.0 then
				-- Mantém posição aérea superior (ponto cego do Tact e corte frontal)
				lastCorrect = now
				self.SmartFlight:FlyTo(idealPos)
			end
		end

		task.wait(0.3)
		self:_cyborgTick()
	end

	Logger.Success("⚡ BOSS LAW ELIMINADO!")
	self.LawStatus = "Law Derrotado"
	-- ponytail: Law sai do mapa (despawn/Port). Sem ClearTarget: controller reataca fantasma.
	-- Upgrade: validar Parent antes de setar alvo.

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
		self.Combat:ClearTarget()
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
-- Module: EliteAutomation.Systems.FarmRotation
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.FarmRotation", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.FarmRotation
--  Sistema de rotação inteligente de bosses baseado em:
--  XP/hora, drops, respawn time, distância.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local FarmRotation = {}
FarmRotation.__index = FarmRotation

-- ─── Database de bosses com dados reais do GPO ─────────────────
local BOSS_DATABASE = {
	-- First Sea (ordenado por eficiência)
	{
		Name = "Bandit Boss",
		Location = Vector3.new(1050, 18, 1220),
		Level = 5,
		HP = 800,
		RespawnTime = 300,  -- 5 min
		ExpReward = 250,
		PeliReward = 2000,
		Drops = {"Bandit Cape"},
		DropRate = 0.05,
		KillTime = 60,  -- Estimado para build média
		Priority = 3,
	},
	{
		Name = "Lucid",
		Location = Vector3.new(-1150, 18, 1420),
		Level = 15,
		HP = 2000,
		RespawnTime = 600,  -- 10 min
		ExpReward = 800,
		PeliReward = 5000,
		Drops = {"Lucid's Cloak"},
		DropRate = 0.05,
		KillTime = 90,
		Priority = 4,
	},
	{
		Name = "Axe Hand Logan",
		Location = Vector3.new(-3800, 20, -4200),
		Level = 25,
		HP = 3000,
		RespawnTime = 900,  -- 15 min
		ExpReward = 1200,
		PeliReward = 8000,
		Drops = {"Logan's Outfit", "Logan's Axe"},
		DropRate = 0.05,
		KillTime = 120,
		Priority = 5,
	},
	{
		Name = "Gravito",
		Location = Vector3.new(2800, 80, -3200),
		Level = 100,
		HP = 3600,
		RespawnTime = 720,  -- 12 min
		ExpReward = 3500,
		PeliReward = 15000,
		Drops = {"Gravity Blade", "Hoverboard", "Gravito's Cape"},
		DropRate = 0.02,
		KillTime = 180,
		Priority = 8,
	},
	{
		Name = "Enel",
		Location = Vector3.new(-1200, 450, 6000),
		Level = 150,
		HP = 5000,
		RespawnTime = 2700,  -- 45 min
		ExpReward = 8000,
		PeliReward = 45000,
		Drops = {"Golden Staff"},
		DropRate = 0.05,
		KillTime = 240,
		Priority = 9,
	},
	{
		Name = "Neptune",
		Location = Vector3.new(7200, -300, 1100),
		Level = 180,
		HP = 6000,
		RespawnTime = 2400,  -- 40 min
		ExpReward = 9000,
		PeliReward = 38000,
		Drops = {"Neptune's Trident", "Neptune's Crown"},
		DropRate = 0.15,
		KillTime = 300,
		Priority = 8,
	},

	-- Second Sea
	{
		Name = "Ryuma",
		Location = Vector3.new(-5400, 120, -7800),
		Level = 350,
		HP = 8000,
		RespawnTime = 1800,  -- 30 min
		ExpReward = 15000,
		PeliReward = 35000,
		Drops = {"Shusui"},
		DropRate = 0.01,
		KillTime = 360,
		Priority = 10,
	},
	{
		Name = "Law",
		Location = Vector3.new(-4716, 28, 1263),
		Level = 400,
		HP = 10000,
		RespawnTime = 3600,  -- 60 min
		ExpReward = 25000,
		PeliReward = 70000,
		Drops = {"Kikoku"},
		DropRate = 0.005,
		KillTime = 450,
		Priority = 10,
	},
}

function FarmRotation.new(combat, movement, notifications)
	local self = setmetatable({}, FarmRotation)

	self.Combat = combat
	self.Movement = movement
	self.Notifications = notifications

	self.Enabled = false
	self._thread = nil
	self._bossTimers = {}  -- [bossName] = lastKillTime
	self._currentRoute = {}

	return self
end

-- ─── Calcula eficiência de farm (XP/minuto) ───────────────────
function FarmRotation:_calculateEfficiency(boss)
	-- Eficiência = (XP + valor dos drops) / (kill time + respawn wait)
	local totalTime = boss.KillTime + boss.RespawnTime
	local expPerMin = (boss.ExpReward / totalTime) * 60

	-- Considera valor dos drops
	local dropValue = boss.PeliReward * boss.DropRate
	local peliPerMin = (dropValue / totalTime) * 60

	-- Score combinado (XP pesa mais)
	return (expPerMin * 0.7) + (peliPerMin * 0.0003)
end

-- ─── Seleciona melhor boss disponível ─────────────────────────
function FarmRotation:_selectBestBoss()
	local playerLevel = self:_getPlayerLevel()
	local now = os.clock()

	local available = {}

	for _, boss in ipairs(BOSS_DATABASE) do
		-- Ignora bosses muito acima do nível
		if boss.Level <= (playerLevel + 50) then
			-- Verifica se respawn passou
			local lastKill = self._bossTimers[boss.Name] or 0
			local elapsed = now - lastKill

			if elapsed >= boss.RespawnTime then
				local efficiency = self:_calculateEfficiency(boss)
				table.insert(available, {
					Boss = boss,
					Efficiency = efficiency,
				})
			end
		end
	end

	if #available == 0 then return nil end

	-- Ordena por eficiência
	table.sort(available, function(a, b)
		return a.Efficiency > b.Efficiency
	end)

	return available[1].Boss
end

-- ─── Cria rota otimizada (TSP simplificado) ───────────────────
function FarmRotation:_buildRoute()
	local playerLevel = self:_getPlayerLevel()
	local now = os.clock()

	local eligible = {}

	for _, boss in ipairs(BOSS_DATABASE) do
		if boss.Level <= (playerLevel + 50) then
			local lastKill = self._bossTimers[boss.Name] or 0
			local elapsed = now - lastKill

			if elapsed >= boss.RespawnTime then
				table.insert(eligible, boss)
			end
		end
	end

	if #eligible == 0 then return {} end

	-- Ordena por prioridade + eficiência
	table.sort(eligible, function(a, b)
		local effA = self:_calculateEfficiency(a)
		local effB = self:_calculateEfficiency(b)
		return (a.Priority * 10 + effA) > (b.Priority * 10 + effB)
	end)

	-- Pega top 5 para rotação
	local route = {}
	for i = 1, math.min(5, #eligible) do
		table.insert(route, eligible[i])
	end

	return route
end

-- ─── Obtém nível do player ────────────────────────────────────
function FarmRotation:_getPlayerLevel()
	local lp = Players.LocalPlayer
	if not lp then return 1 end

	local leaderstats = lp:FindFirstChild("leaderstats")
	if leaderstats then
		local lvl = leaderstats:FindFirstChild("Level")
		if lvl then return lvl.Value or 1 end
	end

	return 1
end

-- ─── Farm um boss específico ──────────────────────────────────
function FarmRotation:_farmBoss(boss)
	Logger.Info("Farmando boss:", boss.Name, "| Eficiência:", string.format("%.1f", self:_calculateEfficiency(boss)))

	-- Notifica
	if self.Notifications then
		local lp = Players.LocalPlayer
		if lp and lp.PlayerGui then
			self.Notifications.Create(
				lp.PlayerGui,
				"🎯 ROTAÇÃO DE FARM",
				boss.Name .. " selecionado - " .. boss.ExpReward .. " XP",
				4,
				Color3.fromRGB(255, 200, 0)
			)
		end
	end

	-- Voa até boss
	if self.Movement then
		self.Movement:FlyTo(boss.Location)
	end

	task.wait(1)

	-- Procura modelo do boss
	local bossModel = workspace:FindFirstChild(boss.Name, true)
	if not bossModel then
		Logger.Warn("Boss não encontrado:", boss.Name)
		return false
	end

	-- Engaja combate
	if self.Combat then
		self.Combat:SetTarget(bossModel)
	end

	-- Aguarda morte
	local timeout = os.clock() + boss.KillTime + 60
	while os.clock() < timeout do
		if not bossModel.Parent then break end

		local hum = bossModel:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then break end

		task.wait(0.5)
	end

	-- Registra kill
	self._bossTimers[boss.Name] = os.clock()

	Logger.Success("Boss eliminado:", boss.Name)
	return true
end

-- ─── Loop de rotação ──────────────────────────────────────────
function FarmRotation:_loop()
	while self.Enabled do
		-- Reconstrói rota a cada ciclo
		self._currentRoute = self:_buildRoute()

		if #self._currentRoute == 0 then
			Logger.Debug("Nenhum boss disponível, aguardando...")
			task.wait(30)
		else
			Logger.Info("Rota de farm:", #self._currentRoute, "bosses")

			for _, boss in ipairs(self._currentRoute) do
				if not self.Enabled then break end
				self:_farmBoss(boss)
				task.wait(2)
			end
		end

		task.wait(5)
	end
end

function FarmRotation:Start()
	if self.Enabled then return end
	self.Enabled = true
	self._thread = task.spawn(function() self:_loop() end)
	Logger.Info("FarmRotation iniciado")
end

function FarmRotation:Stop()
	self.Enabled = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	Logger.Info("FarmRotation parado")
end

function FarmRotation:GetCurrentRoute()
	return self._currentRoute
end

return FarmRotation

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.QuestManager
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.QuestManager", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.QuestManager
--  Auto-Quest system para GPO com priorização inteligente.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local QuestManager = {}
QuestManager.__index = QuestManager

-- ─── Quest database GPO ───────────────────────────────────────
local QUESTS = {
	-- First Sea
	{
		Name = "Bandit Quest",
		NPC = "Quest Giver",
		Location = Vector3.new(1100, 18, 1230),
		Island = "Town of Beginnings",
		Level = 1,
		ExpReward = 150,
		PeliReward = 500,
		Enemies = {"Bandit", "Thug"},
		Count = 5,
	},
	{
		Name = "Desert Bandits",
		NPC = "Desert Quest Giver",
		Location = Vector3.new(-1100, 18, 1400),
		Island = "Sandora",
		Level = 10,
		ExpReward = 400,
		PeliReward = 1200,
		Enemies = {"Desert Bandit", "Sandora Thug"},
		Count = 8,
	},
	{
		Name = "Marine Quest",
		NPC = "Marine Officer",
		Location = Vector3.new(-3800, 20, -4200),
		Island = "Shell's Town",
		Level = 20,
		ExpReward = 800,
		PeliReward = 2500,
		Enemies = {"Marine", "Marine Private"},
		Count = 10,
	},
	-- Second Sea
	{
		Name = "Desert Kingdom Quest",
		NPC = "Desert Kingdom Guard",
		Location = Vector3.new(-1200, 25, -3000),
		Island = "Desert Kingdom",
		Level = 60,
		ExpReward = 5000,
		PeliReward = 8000,
		Enemies = {"Desert Warrior", "Kingdom Guard"},
		Count = 12,
	},
}

function QuestManager.new(combat, smartFlight, notifications, settings)
	local self = setmetatable({}, QuestManager)

	self.Combat = combat
	self.SmartFlight = smartFlight
	self.Notifications = notifications
	self.Settings = settings or {}

	self._running = false
	self._thread = nil
	self._currentQuest = nil
	self._questProgress = 0

	return self
end

-- ─── Detecta nível do player ──────────────────────────────────
function QuestManager:_getPlayerLevel()
	local lp = Players.LocalPlayer
	if not lp then return 1 end

	-- GPO armazena level em leaderstats ou PlayerData
	local leaderstats = lp:FindFirstChild("leaderstats")
	if leaderstats then
		local lvl = leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("level")
		if lvl and lvl.Value then
			return tonumber(lvl.Value) or 1
		end
	end

	-- Fallback: Character Attribute
	local char = lp.Character
	if char then
		local level = char:GetAttribute("Level")
		if level then return level end
	end

	return 1
end

-- ─── Seleciona melhor quest baseado em nível ─────────────────
function QuestManager:_selectBestQuest()
	local playerLevel = self:_getPlayerLevel()
	local best = nil
	local bestScore = -math.huge

	for _, quest in ipairs(QUESTS) do
		-- Ignora quests muito acima do nível
		if quest.Level <= (playerLevel + 10) then
			-- Score = ExpReward / Dificuldade
			local difficulty = math.max(1, quest.Level - playerLevel + quest.Count * 0.5)
			local score = quest.ExpReward / difficulty

			if score > bestScore then
				bestScore = score
				best = quest
			end
		end
	end

	return best
end

-- ─── Aceita quest no NPC ──────────────────────────────────────
function QuestManager:_acceptQuest(quest)
	Logger.Info("Aceitando quest:", quest.Name)

	-- Voa até o NPC
	if self.SmartFlight and quest.Location then
		self.SmartFlight:FlyTo(quest.Location)
	end

	task.wait(0.5)

	-- Procura NPC no workspace
	local npc = workspace:FindFirstChild(quest.NPC, true)
	if not npc then
		Logger.Warn("NPC não encontrado:", quest.NPC)
		return false
	end

	-- Tenta clicar no NPC (ProximityPrompt ou ClickDetector)
	local prompt = npc:FindFirstChildOfClass("ProximityPrompt", true)
	if prompt and fireproximityprompt then
		fireproximityprompt(prompt)
		task.wait(0.3)
	end

	local detector = npc:FindFirstChildOfClass("ClickDetector", true)
	if detector and fireclickdetector then
		fireclickdetector(detector)
		task.wait(0.3)
	end

	Logger.Success("Quest aceita:", quest.Name)
	return true
end

-- ─── Farm inimigos da quest ───────────────────────────────────
function QuestManager:_farmEnemies(quest)
	Logger.Info("Farmando inimigos:", table.concat(quest.Enemies, ", "))

	local killed = 0
	local timeout = os.clock() + 300  -- 5 min max

	while self._running and killed < quest.Count and os.clock() < timeout do
		local target = nil

		-- Procura inimigo da quest
		for _, enemyName in ipairs(quest.Enemies) do
			local enemy = workspace:FindFirstChild(enemyName, true)
			if enemy then
				local hum = enemy:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					target = enemy
					break
				end
			end
		end

		if target then
			-- Engaja combate
			local root = target:FindFirstChild("HumanoidRootPart")
			if root and self.SmartFlight then
				self.SmartFlight:FlyTo(root.Position)
			end

			if self.Combat then
				self.Combat:SetTarget(target)
			end

			-- Aguarda morte
			local hum = target:FindFirstChildOfClass("Humanoid")
			while hum and hum.Health > 0 and target.Parent do
				task.wait(0.2)
			end

			killed = killed + 1
			self._questProgress = killed / quest.Count
			Logger.Info(string.format("Progresso: %d/%d", killed, quest.Count))
		else
			-- Nenhum inimigo encontrado, aguarda respawn
			task.wait(2)
		end
	end

	return killed >= quest.Count
end

-- ─── Loop principal ───────────────────────────────────────────
function QuestManager:_loop()
	while self._running do
		local ok, err = pcall(function()
			-- Seleciona melhor quest
			local quest = self:_selectBestQuest()
			if not quest then
				Logger.Warn("Nenhuma quest disponível para o nível atual")
				task.wait(10)
				return
			end

			self._currentQuest = quest
			self._questProgress = 0

			-- Aceita quest
			local accepted = self:_acceptQuest(quest)
			if not accepted then
				task.wait(5)
				return
			end

			-- Notifica UI
			if self.Notifications then
				local lp = Players.LocalPlayer
				if lp and lp.PlayerGui then
					self.Notifications.Create(
						lp.PlayerGui,
						"📜 QUEST INICIADA",
						quest.Name .. " - " .. quest.Island,
						4,
						Color3.fromRGB(100, 200, 255)
					)
				end
			end

			-- Farm inimigos
			local completed = self:_farmEnemies(quest)

			if completed then
				Logger.Success("Quest completada:", quest.Name, "| +", quest.ExpReward, "EXP")

				if self.Notifications then
					local lp = Players.LocalPlayer
					if lp and lp.PlayerGui then
						self.Notifications.Create(
							lp.PlayerGui,
							"✅ QUEST COMPLETA",
							string.format("+%d EXP | +%d Peli", quest.ExpReward, quest.PeliReward),
							5,
							Color3.fromRGB(80, 220, 130)
						)
					end
				end
			end

			self._currentQuest = nil
			task.wait(2)
		end)

		if not ok then
			Logger.Error("QuestManager loop error:", err)
		end

		task.wait(1)
	end
end

-- ─── API Pública ──────────────────────────────────────────────
function QuestManager:Start()
	if self._running then return end
	self._running = true
	self._thread = task.spawn(function() self:_loop() end)
	Logger.Info("QuestManager iniciado.")
end

function QuestManager:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	self._currentQuest = nil
	Logger.Info("QuestManager parado.")
end

function QuestManager:GetCurrentQuest()
	return self._currentQuest
end

function QuestManager:GetProgress()
	return self._questProgress
end

return QuestManager

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.TeleportManager
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.TeleportManager", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.TeleportManager
--  Sistema de teleporte seguro entre ilhas com anti-detecção.
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local TeleportManager = {}
TeleportManager.__index = TeleportManager

-- ─── Mapa de ilhas GPO (First & Second Sea) ──────────────────
local ISLANDS = {
	-- First Sea
	["Town of Beginnings"] = Vector3.new(1100, 18, 1230),
	["Sandora"] = Vector3.new(-1150, 18, 1420),
	["Shell's Town"] = Vector3.new(-3800, 20, -4200),
	["Orange Town"] = Vector3.new(-820, 18, 830),
	["Baratie"] = Vector3.new(-3100, 12, 4800),
	["Kori Island"] = Vector3.new(2200, 18, 1850),
	["Sphinx Island"] = Vector3.new(-6500, 35, -2100),
	["Shark Park"] = Vector3.new(1250, 18, -3420),
	["Land of the Sky"] = Vector3.new(-1200, 450, 6000),
	["Golden City"] = Vector3.new(-1200, 450, 6000),
	["Gravito's Fort"] = Vector3.new(2800, 80, -3200),
	["Fishman Island"] = Vector3.new(7200, -300, 1100),
	["Underwater"] = Vector3.new(7200, -300, 1100),

	-- Second Sea
	["Desert Kingdom"] = Vector3.new(-1200, 25, -3000),
	["Sashi Island"] = Vector3.new(4100, 30, -1500),
	["Rovo Island"] = Vector3.new(-2500, 22, 3800),
	["Spirit Island"] = Vector3.new(3200, 32, 4500),
	["Foro Island"] = Vector3.new(-4800, 22, 1100),
	["Umi Island"] = Vector3.new(5200, 22, -4200),
	["Thriller Bark"] = Vector3.new(-5400, 80, -7800),
	["Rose Kingdom"] = Vector3.new(450, 120, -180),
	["Colosseum"] = Vector3.new(-600, 30, 5200),
	["Colosseum of Arc"] = Vector3.new(-600, 30, 5200),
}

-- ─── Aliases populares ────────────────────────────────────────
local ALIASES = {
	["start"] = "Town of Beginnings",
	["starter"] = "Town of Beginnings",
	["beginning"] = "Town of Beginnings",
	["desert"] = "Sandora",
	["marine"] = "Shell's Town",
	["shells"] = "Shell's Town",
	["baratie"] = "Baratie",
	["restaurant"] = "Baratie",
	["sky"] = "Land of the Sky",
	["skypiea"] = "Land of the Sky",
	["golden"] = "Golden City",
	["fishman"] = "Fishman Island",
	["underwater"] = "Fishman Island",
	["thriller"] = "Thriller Bark",
	["rose"] = "Rose Kingdom",
	["factory"] = "Rose Kingdom",
}

function TeleportManager.new(smartFlight, notifications)
	local self = setmetatable({}, TeleportManager)

	self.SmartFlight = smartFlight
	self.Notifications = notifications
	self.TeleportHistory = {}  -- últimos 5 teleportes

	return self
end

-- ─── Resolve nome de ilha (com aliases) ──────────────────────
function TeleportManager:_resolveIsland(name)
	name = name:lower()

	-- Tenta alias primeiro
	if ALIASES[name] then
		return ALIASES[name], ISLANDS[ALIASES[name]]
	end

	-- Tenta match parcial
	for islandName, pos in pairs(ISLANDS) do
		if islandName:lower():find(name, 1, true) then
			return islandName, pos
		end
	end

	return nil, nil
end

-- ─── Teleporte seguro com bypass ──────────────────────────────
function TeleportManager:TeleportTo(islandName)
	local fullName, position = self:_resolveIsland(islandName)

	if not fullName or not position then
		Logger.Warn("Ilha não encontrada:", islandName)
		return false
	end

	Logger.Info("Teleportando para:", fullName)

	local char = Players.LocalPlayer.Character
	if not char then return false end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	-- Notifica UI
	if self.Notifications then
		local lp = Players.LocalPlayer
		if lp and lp.PlayerGui then
			self.Notifications.Create(
				lp.PlayerGui,
				"🌍 TELEPORTE",
				"Viajando para " .. fullName .. "...",
				3,
				Color3.fromRGB(100, 200, 255)
			)
		end
	end

	-- Sem fallback de CFrame direto: teleport = disconnect no GPO.
	if self.SmartFlight then
		self.SmartFlight:FlyTo(position)
	else
		Logger.Warn("TeleportManager: SmartFlight ausente, teleporte cancelado.")
		return false
	end

	-- Registra no histórico
	table.insert(self.TeleportHistory, 1, {
		Island = fullName,
		Time = os.time(),
	})
	if #self.TeleportHistory > 5 then
		table.remove(self.TeleportHistory)
	end

	Logger.Success("Chegou em:", fullName)
	return true
end

-- ─── Lista ilhas disponíveis ──────────────────────────────────
function TeleportManager:ListIslands()
	local list = {}
	for name in pairs(ISLANDS) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

-- ─── Teleporte para ilha mais próxima ────────────────────────
function TeleportManager:TeleportToNearest()
	local char = Players.LocalPlayer.Character
	if not char then return false end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local nearest, nearestDist = nil, math.huge
	local currentPos = root.Position

	for name, pos in pairs(ISLANDS) do
		local dist = (pos - currentPos).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearest = name
		end
	end

	if nearest then
		return self:TeleportTo(nearest)
	end

	return false
end

-- ─── Histórico de teleportes ──────────────────────────────────
function TeleportManager:GetHistory()
	return self.TeleportHistory
end

return TeleportManager

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.AutoStats
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.AutoStats", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.AutoStats
--  Distribuição automática de stats com builds pré-configurados.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local AutoStats = {}
AutoStats.__index = AutoStats

-- ─── Builds pré-configurados para GPO ─────────────────────────
local BUILDS = {
	-- Sword Main (Full Melee)
	SwordMain = {
		Name = "Sword Main",
		Priority = {"Strength", "Defense", "Stamina", "Fruit"},
		Distribution = {Strength = 0.50, Defense = 0.25, Stamina = 0.20, Fruit = 0.05},
	},

	-- Devil Fruit Main
	DevilFruitMain = {
		Name = "Devil Fruit Main",
		Priority = {"Fruit", "Stamina", "Defense", "Strength"},
		Distribution = {Fruit = 0.55, Stamina = 0.20, Defense = 0.15, Strength = 0.10},
	},

	-- Balanced Hybrid
	Hybrid = {
		Name = "Hybrid",
		Priority = {"Strength", "Fruit", "Defense", "Stamina"},
		Distribution = {Strength = 0.35, Fruit = 0.35, Defense = 0.20, Stamina = 0.10},
	},

	-- Tank (PvP Survival)
	Tank = {
		Name = "Tank",
		Priority = {"Defense", "Stamina", "Strength", "Fruit"},
		Distribution = {Defense = 0.45, Stamina = 0.30, Strength = 0.20, Fruit = 0.05},
	},

	-- Glass Cannon (Max Damage)
	GlassCannon = {
		Name = "Glass Cannon",
		Priority = {"Strength", "Fruit", "Stamina", "Defense"},
		Distribution = {Strength = 0.45, Fruit = 0.40, Stamina = 0.10, Defense = 0.05},
	},
}

function AutoStats.new(buildName, notifications)
	local self = setmetatable({}, AutoStats)

	self.Build = BUILDS[buildName] or BUILDS.Hybrid
	self.Notifications = notifications
	self.Enabled = false
	self._lastCheck = 0

	return self
end

-- ─── Detecta stats points disponíveis ─────────────────────────
function AutoStats:_getAvailablePoints()
	local lp = Players.LocalPlayer
	if not lp then return 0 end

	-- GPO armazena stat points em leaderstats ou PlayerData
	local leaderstats = lp:FindFirstChild("leaderstats")
	if leaderstats then
		local points = leaderstats:FindFirstChild("StatPoints")
			or leaderstats:FindFirstChild("Points")
		if points and points.Value then
			return tonumber(points.Value) or 0
		end
	end

	-- Fallback: Character attribute
	local char = lp.Character
	if char then
		local pts = char:GetAttribute("StatPoints")
		if pts then return pts end
	end

	return 0
end

-- ─── Distribui stats automaticamente ──────────────────────────
function AutoStats:_distributeStats()
	local points = self:_getAvailablePoints()
	if points <= 0 then return end

	Logger.Info("Distribuindo", points, "stat points com build:", self.Build.Name)

	local dist = self.Build.Distribution

	-- Calcula quantos pontos para cada stat
	local allocation = {
		Strength = math.floor(points * dist.Strength),
		Defense = math.floor(points * dist.Defense),
		Stamina = math.floor(points * dist.Stamina),
		Fruit = math.floor(points * dist.Fruit),
	}

	-- Distribui pontos restantes pelo prioridade
	local remainder = points - (allocation.Strength + allocation.Defense + allocation.Stamina + allocation.Fruit)
	for _, stat in ipairs(self.Build.Priority) do
		if remainder > 0 then
			allocation[stat] = allocation[stat] + 1
			remainder = remainder - 1
		end
	end

	-- Executa distribuição
	for stat, amount in pairs(allocation) do
		if amount > 0 then
			self:_addStat(stat, amount)
		end
	end

	-- Notifica UI
	if self.Notifications then
		local lp = Players.LocalPlayer
		if lp and lp.PlayerGui then
			self.Notifications.Create(
				lp.PlayerGui,
				"📊 STATS DISTRIBUÍDOS",
				string.format("%d pontos alocados (%s)", points, self.Build.Name),
				4,
				Color3.fromRGB(100, 200, 255)
			)
		end
	end
end

-- ─── Adiciona pontos em um stat específico ────────────────────
function AutoStats:_addStat(statName, amount)
	Logger.Debug("Adicionando", amount, "pontos em", statName)

	-- GPO usa RemoteEvent para adicionar stats
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if remotes then
		local addStat = remotes:FindFirstChild("AddStat")
			or remotes:FindFirstChild("Stats")
			or remotes:FindFirstChild("StatUpgrade")

		if addStat and addStat:IsA("RemoteEvent") then
			for i = 1, amount do
				addStat:FireServer(statName)
				task.wait(0.05)  -- Pequeno delay para evitar spam
			end
		end
	end
end

-- ─── Loop de verificação ──────────────────────────────────────
function AutoStats:Check()
	if not self.Enabled then return end

	local now = os.clock()
	if (now - self._lastCheck) < 5 then return end  -- Verifica a cada 5s
	self._lastCheck = now

	local points = self:_getAvailablePoints()
	if points > 0 then
		self:_distributeStats()
	end
end

-- ─── Muda build em tempo real ─────────────────────────────────
function AutoStats:SetBuild(buildName)
	if BUILDS[buildName] then
		self.Build = BUILDS[buildName]
		Logger.Info("Build de stats alterada para:", self.Build.Name)
		return true
	end
	return false
end

function AutoStats:Enable()
	self.Enabled = true
	Logger.Info("AutoStats ativado:", self.Build.Name)
end

function AutoStats:Disable()
	self.Enabled = false
	Logger.Info("AutoStats desativado")
end

function AutoStats:GetBuildList()
	local list = {}
	for name, build in pairs(BUILDS) do
		table.insert(list, {Name = name, Display = build.Name})
	end
	return list
end

return AutoStats

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.ESP
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.ESP", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.ESP
--  ESP visual para NPCs, Bosses, Frutas e Players.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local ESP = {}
ESP.__index = ESP

-- ─── Cores por categoria ──────────────────────────────────────
local COLORS = {
	Boss = Color3.fromRGB(255, 50, 50),
	NPC = Color3.fromRGB(255, 200, 0),
	Fruit = Color3.fromRGB(200, 50, 255),
	Player = Color3.fromRGB(50, 150, 255),
	Chest = Color3.fromRGB(255, 215, 0),
}

function ESP.new()
	local self = setmetatable({}, ESP)

	self.Enabled = {
		Boss = false,
		NPC = false,
		Fruit = false,
		Player = false,
		Chest = false,
	}

	self._highlights = {}  -- [model] = Highlight instance
	self._billboards = {}  -- [model] = BillboardGui
	self._connections = {}
	self._updateThread = nil

	return self
end

-- ─── Cria Highlight em modelo ─────────────────────────────────
function ESP:_createHighlight(model, color)
	if self._highlights[model] then return end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model

	self._highlights[model] = highlight
end

-- ─── Cria Billboard com texto ─────────────────────────────────
function ESP:_createBillboard(model, text, color)
	if self._billboards[model] then return end

	local root = model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Head")
		or model:FindFirstChildOfClass("BasePart")

	if not root then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = root
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard

	-- Adiciona distância
	local char = Players.LocalPlayer.Character
	if char then
		local playerRoot = char:FindFirstChild("HumanoidRootPart")
		if playerRoot then
			RunService.Heartbeat:Connect(function()
				if not billboard.Parent then return end
				local dist = (root.Position - playerRoot.Position).Magnitude
				label.Text = string.format("%s [%.0fm]", text, dist)
			end)
		end
	end

	self._billboards[model] = billboard
end

-- ─── Remove ESP de modelo ─────────────────────────────────────
function ESP:_removeESP(model)
	if self._highlights[model] then
		self._highlights[model]:Destroy()
		self._highlights[model] = nil
	end

	if self._billboards[model] then
		self._billboards[model]:Destroy()
		self._billboards[model] = nil
	end
end

-- ─── Atualiza ESP de Bosses ───────────────────────────────────
function ESP:_updateBosses()
	if not self.Enabled.Boss then return end

	-- Lista de nomes de boss conhecidos
	local bossNames = {
		"Kraken", "Sea Beast", "Ghost Ship", "Megalodon",
		"Law", "Moria", "Enel", "Gravito", "Neptune",
		"Ryuma", "Borj", "Pica", "Donmingo", "Lucy",
	}

	for _, name in ipairs(bossNames) do
		local boss = workspace:FindFirstChild(name, true)
		if boss and boss:IsA("Model") then
			local hum = boss:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				self:_createHighlight(boss, COLORS.Boss)
				self:_createBillboard(boss, "👑 " .. name, COLORS.Boss)
			end
		end
	end
end

-- ─── Atualiza ESP de Frutas ───────────────────────────────────
function ESP:_updateFruits()
	if not self.Enabled.Fruit then return end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "Fruit" or obj.Name:find("Fruit", 1, true) then
			if obj:IsA("Model") or obj:IsA("Tool") then
				self:_createHighlight(obj, COLORS.Fruit)
				self:_createBillboard(obj, "🍎 Devil Fruit", COLORS.Fruit)
			end
		end
	end
end

-- ─── Atualiza ESP de Players ──────────────────────────────────
function ESP:_updatePlayers()
	if not self.Enabled.Player then return end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= Players.LocalPlayer then
			local char = player.Character
			if char then
				self:_createHighlight(char, COLORS.Player)
				self:_createBillboard(char, player.Name, COLORS.Player)
			end
		end
	end
end

-- ─── Atualiza ESP de Chests ───────────────────────────────────
function ESP:_updateChests()
	if not self.Enabled.Chest then return end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name:find("Chest", 1, true) and obj:IsA("Model") then
			self:_createHighlight(obj, COLORS.Chest)
			self:_createBillboard(obj, "📦 Chest", COLORS.Chest)
		end
	end
end

-- ─── Loop de atualização ──────────────────────────────────────
function ESP:_updateLoop()
	while self._updateThread do
		self:_updateBosses()
		self:_updateFruits()
		self:_updatePlayers()
		self:_updateChests()

		task.wait(1)  -- Atualiza a cada 1s
	end
end

-- ─── API Pública ──────────────────────────────────────────────
function ESP:Toggle(category, enabled)
	if self.Enabled[category] ~= nil then
		self.Enabled[category] = enabled

		-- Remove ESP existente se desativado
		if not enabled then
			for model in pairs(self._highlights) do
				self:_removeESP(model)
			end
		end

		Logger.Info("ESP", category, enabled and "ativado" or "desativado")
	end
end

function ESP:Start()
	if self._updateThread then return end
	self._updateThread = task.spawn(function()
		self:_updateLoop()
	end)
	Logger.Info("ESP iniciado")
end

function ESP:Stop()
	if self._updateThread then
		task.cancel(self._updateThread)
		self._updateThread = nil
	end

	-- Remove todos os ESP
	for model in pairs(self._highlights) do
		self:_removeESP(model)
	end

	Logger.Info("ESP parado")
end

return ESP

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.AutoHeal
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.AutoHeal", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.AutoHeal
--  Sistema de cura automática com priorização inteligente.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local AutoHeal = {}
AutoHeal.__index = AutoHeal

-- ─── Items de cura conhecidos no GPO ──────────────────────────
local HEAL_ITEMS = {
	-- Comidas (ordenadas por eficiência)
	{Name = "Pineapple", HealAmount = 500, Priority = 1},
	{Name = "Apple", HealAmount = 300, Priority = 2},
	{Name = "Banana", HealAmount = 250, Priority = 3},
	{Name = "Orange", HealAmount = 200, Priority = 4},
	{Name = "Meat", HealAmount = 400, Priority = 1},
	{Name = "Cooked Meat", HealAmount = 600, Priority = 1},

	-- Poções
	{Name = "Health Potion", HealAmount = 1000, Priority = 1},
	{Name = "Small Health Potion", HealAmount = 500, Priority = 2},
}

function AutoHeal.new(settings)
	local self = setmetatable({}, AutoHeal)

	self.Settings = settings or {}
	self.HealThreshold = self.Settings.HealThreshold or 0.50  -- Cura abaixo de 50% HP
	self.EmergencyThreshold = self.Settings.EmergencyThreshold or 0.25  -- Emergência <25%
	self.Enabled = false
	self._lastHeal = 0
	self._lastCheck = 0

	return self
end

-- ─── Obtém HP atual do jogador ────────────────────────────────
function AutoHeal:_getHealthPct()
	local char = Players.LocalPlayer.Character
	if not char then return 1.0 end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return 1.0 end

	return hum.Health / math.max(hum.MaxHealth, 1)
end

-- ─── Verifica se tem item no inventário ───────────────────────
function AutoHeal:_hasItem(itemName)
	local lp = Players.LocalPlayer
	if not lp then return false end

	-- Procura no inventário/backpack
	local backpack = lp:FindFirstChild("Backpack")
	if backpack and backpack:FindFirstChild(itemName) then
		return true
	end

	-- Procura no personagem (equipado)
	local char = lp.Character
	if char and char:FindFirstChild(itemName) then
		return true
	end

	return false
end

-- ─── Usa item de cura ─────────────────────────────────────────
function AutoHeal:_useItem(itemName)
	Logger.Info("Usando item de cura:", itemName)

	local lp = Players.LocalPlayer
	if not lp then return false end

	-- Tenta equipar do backpack
	local backpack = lp:FindFirstChild("Backpack")
	local item = backpack and backpack:FindFirstChild(itemName)

	if item and item:IsA("Tool") then
		-- Equipa ferramenta
		local char = lp.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:EquipTool(item)
				task.wait(0.2)

				-- Ativa ferramenta (GPO usa :Activate())
				pcall(function()
					item:Activate()
				end)

				task.wait(0.3)

				-- Desequipa
				pcall(function()
					hum:UnequipTools()
				end)

				self._lastHeal = os.clock()
				return true
			end
		end
	end

	return false
end

-- ─── Seleciona melhor item disponível ─────────────────────────
function AutoHeal:_getBestHealItem(emergency)
	-- Se emergência, pega qualquer item
	-- Senão, pega o mais eficiente disponível

	local available = {}
	for _, item in ipairs(HEAL_ITEMS) do
		if self:_hasItem(item.Name) then
			table.insert(available, item)
		end
	end

	if #available == 0 then return nil end

	-- Ordena por prioridade
	table.sort(available, function(a, b)
		return a.Priority < b.Priority
	end)

	return available[1]
end

-- ─── Verifica e cura se necessário ────────────────────────────
function AutoHeal:Check()
	if not self.Enabled then return end

	local now = os.clock()
	if (now - self._lastCheck) < 0.5 then return end
	self._lastCheck = now

	-- Cooldown de 2s entre curas
	if (now - self._lastHeal) < 2.0 then return end

	local hpPct = self:_getHealthPct()
	local isEmergency = hpPct <= self.EmergencyThreshold

	if hpPct <= self.HealThreshold or isEmergency then
		local item = self:_getBestHealItem(isEmergency)
		if item then
			self:_useItem(item.Name)

			if isEmergency then
				Logger.Warn("HP CRÍTICO! Usando", item.Name)
			else
				Logger.Info("Auto-Heal ativado:", item.Name)
			end
		else
			Logger.Warn("HP baixo mas nenhum item de cura disponível!")
		end
	end
end

function AutoHeal:Enable()
	self.Enabled = true
	Logger.Info("AutoHeal ativado (threshold:", self.HealThreshold * 100, "%)")
end

function AutoHeal:Disable()
	self.Enabled = false
	Logger.Info("AutoHeal desativado")
end

function AutoHeal:SetThreshold(threshold)
	self.HealThreshold = math.clamp(threshold, 0.1, 0.9)
	Logger.Info("Heal threshold alterado para:", self.HealThreshold * 100, "%")
end

return AutoHeal

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.AntiAFK
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.AntiAFK", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.AntiAFK
--  Sistema anti-kick por inatividade com movimentos aleatórios.
-- ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")
local HumanMovement = customRequire("EliteAutomation.Movement.HumanMovement")

local AntiAFK = {}
AntiAFK.__index = AntiAFK

function AntiAFK.new()
	local self = setmetatable({}, AntiAFK)

	self.Enabled = false
	self._thread = nil
	self._lastAction = os.clock()
	self.ActionInterval = 120  -- Ação a cada 2 minutos

	return self
end

-- ─── Simula input aleatório ───────────────────────────────────
function AntiAFK:_simulateInput()
	local actions = {
		-- Movimento de câmera
		function()
			local cam = workspace.CurrentCamera
			if cam then
				local randomX = math.random(-30, 30)
				local randomY = math.random(-15, 15)
				cam.CFrame = cam.CFrame * CFrame.Angles(
					math.rad(randomY),
					math.rad(randomX),
					0
				)
			end
		end,

		-- Pulo
		function()
			local char = Players.LocalPlayer.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end,

		-- Passo pequeno via Humanoid (sem CFrame direto: kick)
		function()
			local char = Players.LocalPlayer.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local root = char:FindFirstChild("HumanoidRootPart")
				if hum and root and hum.Health > 0 then
					hum:MoveTo(root.Position + Vector3.new(
						math.random(-2, 2),
						0,
						math.random(-2, 2)
					))
				end
			end
		end,

		-- Simula tecla aleatória
		function()
			local keys = {
				Enum.KeyCode.W,
				Enum.KeyCode.A,
				Enum.KeyCode.S,
				Enum.KeyCode.D,
			}
			local key = keys[math.random(#keys)]

			local vim = game:GetService("VirtualInputManager")
			if vim then
				vim:SendKeyEvent(true, key, false, game)
				task.wait(HumanMovement.HumanDelay(0.1, 0.05))
				vim:SendKeyEvent(false, key, false, game)
			end
		end,
	}

	-- Executa ação aleatória
	local action = actions[math.random(#actions)]
	action()

	Logger.Debug("Anti-AFK: ação executada")
end

-- ─── Loop anti-AFK ────────────────────────────────────────────
function AntiAFK:_loop()
	while self.Enabled do
		local now = os.clock()
		local elapsed = now - self._lastAction

		if elapsed >= self.ActionInterval then
			self:_simulateInput()
			self._lastAction = now

			-- Randomiza próximo intervalo (1.5-2.5 min)
			self.ActionInterval = HumanMovement.HumanDelay(120, 30)
		end

		task.wait(5)
	end
end

-- ─── Detecção de AFK kick warning (GPO) ───────────────────────
function AntiAFK:_watchForKickWarning()
	local lp = Players.LocalPlayer
	if not lp then return end

	local pg = lp:FindFirstChild("PlayerGui")
	if not pg then return end

	-- Procura GUI de warning
	for _, gui in ipairs(pg:GetDescendants()) do
		if gui:IsA("TextLabel") or gui:IsA("TextButton") then
			local text = gui.Text:lower()
			if text:find("afk", 1, true) or text:find("kicked", 1, true) then
				Logger.Warn("AFK kick warning detectado! Forçando ação...")
				self:_simulateInput()
				self._lastAction = os.clock()
			end
		end
	end
end

function AntiAFK:Start()
	if self.Enabled then return end
	self.Enabled = true

	self._thread = task.spawn(function()
		self:_loop()
	end)

	-- Thread de monitoramento de warning
	task.spawn(function()
		while self.Enabled do
			self:_watchForKickWarning()
			task.wait(10)
		end
	end)

	Logger.Info("Anti-AFK ativado (intervalo:", self.ActionInterval, "s)")
end

function AntiAFK:Stop()
	self.Enabled = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	Logger.Info("Anti-AFK desativado")
end

return AntiAFK

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.AdaptiveBrain
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.AdaptiveBrain", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.AdaptiveBrain
--  Observa boss atual + HP/stamina/dist e ajusta voo e combate.
--  Sem boss: restaura defaults. Loop 1s, sem spam de input.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local SEA_NAMES = { Kraken = true, ["Sea Beast"] = true, ["Ghost Ship"] = true, Megalodon = true }
local LAW_NAMES = { Law = true, Order = true }

-- Presets por contexto (studs/s, segundos)
local PRESET_SEA   = { Speed = 45, Hover = 40, AtkMin = 0.60, AtkMax = 1.10 }
local PRESET_LAW   = { Speed = 52, Hover = 25, AtkMin = 0.40, AtkMax = 0.75 }
local PRESET_WORLD = { Speed = 52, Hover = 25, AtkMin = 0.40, AtkMax = 0.75 }
local PRESET_SAFE  = { Speed = 40, Hover = 40, AtkMin = 0.80, AtkMax = 1.20 } -- HP baixo
local LOW_HP_PCT   = 0.30

local AdaptiveBrain = {}
AdaptiveBrain.__index = AdaptiveBrain

function AdaptiveBrain.new(combat, smartFlight, bossManager, lawFarm)
	local self = setmetatable({}, AdaptiveBrain)

	self.Combat      = combat
	self.SmartFlight = smartFlight
	self.Bosses      = bossManager
	self.LawFarm     = lawFarm

	-- Defaults para restaurar quando idle
	self._defSpeed  = smartFlight and smartFlight.SpeedBase or 52
	self._defHover  = smartFlight and smartFlight.HoverOffset or 25
	self._defAtkMin = combat and combat.AttackMin or 0.40
	self._defAtkMax = combat and combat.AttackMax or 0.75

	self._running = false
	self._thread  = nil
	self._status  = "Idle"
	self.OnAdjust = nil -- function(statusText)

	return self
end

-- ─── Foto do momento: boss, HP, stamina, distância ─────────────
function AdaptiveBrain:_snapshot()
	local snap = { Kind = "Idle", BossName = nil, HpPct = 1, StamPct = 1, Dist = math.huge }
	local lp = Players.LocalPlayer
	local char = lp and lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if hum then
		snap.HpPct = hum.Health / math.max(hum.MaxHealth, 1)
	end
	if char then
		local stam = char:GetAttribute("Stamina") or 100
		local maxStam = char:GetAttribute("MaxStamina") or 100
		if type(stam) == "number" and type(maxStam) == "number" and maxStam > 0 then
			snap.StamPct = stam / maxStam
		end
	end

	local boss = self.Bosses and self.Bosses:GetCurrentBoss()
		or (self.LawFarm and self.LawFarm.LawStatus == "Combatendo Law" and { Name = "Law" })
	if boss and boss.Name then
		snap.BossName = boss.Name
		if LAW_NAMES[boss.Name] then
			snap.Kind = "Law"
		elseif SEA_NAMES[boss.Name] then
			snap.Kind = "Sea"
		else
			snap.Kind = "World"
		end
		local bRoot = boss.FindFirstChild and (boss:FindFirstChild("HumanoidRootPart") or boss:FindFirstChildOfClass("BasePart"))
		if bRoot and root then
			snap.Dist = (bRoot.Position - root.Position).Magnitude
		end
	end

	return snap
end

-- ─── Aplica preset conforme contexto ───────────────────────────
function AdaptiveBrain:_apply(snap)
	local preset, label
	if snap.HpPct <= LOW_HP_PCT then
		preset, label = PRESET_SAFE, "Recuando (HP baixo)"
	elseif snap.Kind == "Sea" then
		preset, label = PRESET_SEA, "Mar: " .. (snap.BossName or "?")
	elseif snap.Kind == "Law" then
		preset, label = PRESET_LAW, "Law (Order)"
	elseif snap.Kind == "World" then
		preset, label = PRESET_WORLD, snap.BossName or "Boss"
	else
		self:_restore()
		self:_report("Idle")
		return
	end

	if self.SmartFlight then
		self.SmartFlight.SpeedBase = preset.Speed
		self.SmartFlight.HoverOffset = preset.Hover
	end
	if self.Combat then
		self.Combat.AttackMin = preset.AtkMin
		self.Combat.AttackMax = preset.AtkMax
	end

	local distTxt = (snap.Dist == math.huge) and "?" or string.format("%dm", snap.Dist)
	self:_report(string.format("%s | HP %d%% | %s", label, snap.HpPct * 100, distTxt))
end

function AdaptiveBrain:_restore()
	if self.SmartFlight then
		self.SmartFlight.SpeedBase = self._defSpeed
		self.SmartFlight.HoverOffset = self._defHover
	end
	if self.Combat then
		self.Combat.AttackMin = self._defAtkMin
		self.Combat.AttackMax = self._defAtkMax
	end
end

function AdaptiveBrain:_report(text)
	self._status = text
	if self.OnAdjust then
		pcall(self.OnAdjust, text)
	end
end

function AdaptiveBrain:_loop()
	while self._running do
		local ok, err = pcall(function()
			self:_apply(self:_snapshot())
		end)
		if not ok then
			Logger.Error("AdaptiveBrain loop error:", err)
		end
		task.wait(1)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function AdaptiveBrain:Start()
	if self._running then return end
	self._running = true
	self._thread = task.spawn(function() self:_loop() end)
	Logger.Info("AdaptiveBrain iniciado.")
end

function AdaptiveBrain:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	self:_restore()
	self:_report("Idle")
	Logger.Info("AdaptiveBrain parado.")
end

function AdaptiveBrain:GetStatus()
	return self._status
end

return AdaptiveBrain

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.KickTelemetry
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.KickTelemetry", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.KickTelemetry
--  Log de inject + últimas ações + dump no kick/disconnect.
--  Arquivo: EliteAutomation_kicklog.txt (writefile se executor expor).
--  ponytail: mapa mínimo de error codes; upgrade: tabela 267/277/279/282/284/286 + ação auto.
-- ============================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LogService = game:GetService("LogService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local FILE = "EliteAutomation_kicklog.txt"
local MAX_EVENTS = 50

local KickTelemetry = {}
KickTelemetry.__index = KickTelemetry

function KickTelemetry.new(notifications)
	local self = setmetatable({}, KickTelemetry)
	self.Notifications = notifications
	self._events = {}
	self._manager = nil
	self._running = false
	self._thread = nil
	self._dumped = false
	return self
end

function KickTelemetry:BindManager(manager)
	self._manager = manager
end

local function stamp()
	return os.date("%H:%M:%S")
end

local function executorName()
	if identifyexecutor then
		local ok, name = pcall(identifyexecutor)
		if ok and name then return tostring(name) end
	end
	if getexecutorname then
		local ok, name = pcall(getexecutorname)
		if ok and name then return tostring(name) end
	end
	return "Unknown"
end

-- ─── Append em arquivo (só inject + dump; heartbeat fica em memória) ─
function KickTelemetry:_append(blob)
	if writefile == nil then return end
	pcall(function()
		local prev = ""
		if readfile ~= nil then
			prev = readfile(FILE) or ""
		end
		writefile(FILE, prev .. blob .. "\n")
	end)
end

-- ─── Registra ação (toggle, flyto, beat, inject) ─────────────────
function KickTelemetry:Event(action, detail)
	local lp = Players.LocalPlayer
	local char = lp and lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	table.insert(self._events, {
		t = stamp(),
		action = tostring(action),
		detail = tostring(detail or ""),
		pos = root and tostring(root.Position) or "?",
	})
	if #self._events > MAX_EVENTS then
		table.remove(self._events, 1)
	end
end

local function activeTasks(manager)
	if not manager or not manager.Tasks then return "-" end
	local on = {}
	for name, t in pairs(manager.Tasks) do
		if t.Enabled then table.insert(on, name) end
	end
	if #on == 0 then return "-" end
	return table.concat(on, ",")
end

function KickTelemetry:_logInject()
	local lp = Players.LocalPlayer
	local line = string.format("[%s] inject exec=%s place=%s job=%s user=%s",
		stamp(), executorName(), tostring(game.PlaceId),
		tostring(game.JobId), lp and lp.Name or "?")
	Logger.Info(line)
	self:_append(line)
	self:Event("inject", "exec=" .. executorName())
end

-- ─── Dump: o que estava ligado + últimas 50 ações ───────────────
function KickTelemetry:_dump(reason)
	if self._dumped then return end
	self._dumped = true
	local lines = { string.format("[%s] KICK/DISCONNECT reason=%s tasks=%s",
		stamp(), tostring(reason), activeTasks(self._manager)) }
	for _, e in ipairs(self._events) do
		table.insert(lines, string.format("[%s] %s %s @%s", e.t, e.action, e.detail, e.pos))
	end
	local blob = table.concat(lines, "\n")
	Logger.Warn(blob)
	self:_append(blob)
end

local function looksLikeKick(text)
	if not text or text == "" then return false end
	local t = text:lower()
	return t:find("disconnect", 1, true) ~= nil
		or t:find("you were kicked", 1, true)
		or t:find("kicked", 1, true)
		or t:find("error code", 1, true)
		or t:find("267", 1, true)
		or t:find("277", 1, true)
		or t:find("279", 1, true)
		or t:find("282", 1, true)
end

-- ─── Vigia prompt de disconnect + saída do player + erros ───────
function KickTelemetry:_watchPrompt()
	pcall(function()
		local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
		if promptGui then
			local overlay = promptGui:FindFirstChild("promptOverlay", true)
			if overlay then
				overlay.ChildAdded:Connect(function()
					for _, d in ipairs(overlay:GetDescendants()) do
						if d:IsA("TextLabel") or d:IsA("TextButton") then
							if looksLikeKick(d.Text) then
								self:_dump(d.Text)
								return
							end
						end
					end
				end)
			end
			for _, d in ipairs(promptGui:GetDescendants()) do
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					if looksLikeKick(d.Text) then
						self:_dump(d.Text)
						return
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		if p == Players.LocalPlayer then
			self:_dump("player-removing")
		end
	end)

	pcall(function()
		LogService.MessageOut:Connect(function(msg)
			if looksLikeKick(tostring(msg)) then
				self:_dump(msg)
			end
		end)
	end)
end

function KickTelemetry:_heartbeat()
	while self._running do
		local char = Players.LocalPlayer and Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hp = hum and math.floor(hum.Health / math.max(hum.MaxHealth, 1) * 100) or -1
		self:Event("beat", "hp=" .. hp .. " tasks=" .. activeTasks(self._manager))
		task.wait(5)
	end
end

-- ─── API Pública ─────────────────────────────────────────────
function KickTelemetry:Start()
	if self._running then return end
	self._running = true
	self:_logInject()
	self:_watchPrompt()
	self._thread = task.spawn(function() self:_heartbeat() end)
	Logger.Info("KickTelemetry ativo.")
end

function KickTelemetry:Stop()
	self._running = false
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
	Logger.Info("KickTelemetry parado.")
end

function KickTelemetry:GetEvents()
	return self._events
end

return KickTelemetry

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
-- [Bundle] Root redirecionado
local StateMachine  = customRequire("EliteAutomation.Core.StateMachine")
local TargetSelector = customRequire("EliteAutomation.Combat.TargetSelector")
local Logger        = customRequire("EliteAutomation.Core.Logger")
local HumanMovement = customRequire("EliteAutomation.Movement.HumanMovement")

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
	-- Default false: manager task liga. Default true ativava sem toggle = UI mentirosa.
	self.AutoBusoHaki   = self.Settings.AutoBusoHaki == true     -- Busoshoku Haki ('J')
	self.AutoKenHaki    = self.Settings.AutoKenHaki == true      -- Kenbunshoku Haki ('K')
	self.AutoGrip       = self.Settings.AutoGrip == true         -- Executa alvos nocauteados ('B')
	self.UseCombo       = self.Settings.UseCombo or false        -- Usa sistema de combos
	self._lastHakiCheck = 0
	self._lastGripCheck = 0

	-- Farm de arma (GUN): kite numa faixa segura atirando de longe
	self.RangedMode = false
	self.RangedMin  = self.Settings.RangedMin or 32
	self.RangedMax  = self.Settings.RangedMax or 60
	self._flight    = nil -- SmartFlight injetado via SetFlight
	self._lastKite  = 0

	self.Selector       = TargetSelector.new(settings)
	self.FSM            = StateMachine.new("Idle")
	self.Target         = nil
	self.RetryCount     = 0
	self._running       = false
	self._thread        = nil
	self._lastAttack    = 0
	self._nextInterval  = HumanMovement.HumanDelay(self.AttackMin, (self.AttackMax - self.AttackMin) / 2)

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
	if not self:_getLocalChar() then return end
	local tRoot = self.Target and self.Target:FindFirstChild("HumanoidRootPart")
	if not tRoot then return end

	-- Regulação de Stamina: Se a stamina estiver crítica (<15%), desacelera ataques para evitar Guard Break
	local stamPct = self:_getStaminaPct()
	if stamPct < self.StaminaThreshold then
		task.wait(0.3)
	end

	-- Sem CFrame direto: teleport por ataque = kick. Humanoid auto-vira no M1.

	-- Garante que Haki esteja ativo antes de atacar
	self:_checkHaki()

	-- Em Grand Piece Online (GPO), ataques corpo-a-corpo e armas usam M1 (Mouse1).
	local vim = game:GetService("VirtualInputManager")
	if vim then
		-- Usa movimento humanizado para clique
		HumanMovement.HumanClick(function(pressed)
			vim:SendMouseButtonEvent(0, 0, 0, pressed, game, 1)
		end)
	end

	-- Executa grip se o alvo estiver caído
	self:_checkGrip()

	self._lastAttack   = os.clock()
	self._nextInterval = HumanMovement.HumanDelay(self.AttackMin, (self.AttackMax - self.AttackMin) / 2)
	Logger.Debug("Attack fired | next in", string.format("%.2fs", self._nextInterval))
end

-- ─── Farm de arma: kite na faixa segura atirando (M1 a distância) ──
function CombatController:_kiteTick()
	local root = self:_getLocalRoot()
	local tRoot = self.Target and self.Target:FindFirstChild("HumanoidRootPart")
	if not root or not tRoot then return end

	local now = os.clock()
	local dist = (tRoot.Position - root.Position).Magnitude

	-- Reposiciona 1x/s: perto demais afasta, longe demais aproxima
	if (now - self._lastKite) >= 1.0 and self._flight then
		local mid = Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z)
		local dir = (root.Position - mid)
		if dir.Magnitude > 0.5 then dir = dir.Unit else dir = Vector3.new(0, 0, 1) end
		if dist < self.RangedMin then
			self._lastKite = now
			self._flight:FlyTo(mid + dir * ((self.RangedMin + self.RangedMax) / 2))
		elseif dist > (self.RangedMax + 10) then
			self._lastKite = now
			self._flight:FlyTo(mid + dir * ((self.RangedMin + self.RangedMax) / 2))
		end
	end

	-- Atira dentro da faixa (M1 na arma equipada)
	if dist >= self.RangedMin and dist <= (self.RangedMax + 10) then
		if (now - self._lastAttack) >= self._nextInterval then
			self:_performAttack()
		end
	end
end

function CombatController:SetFlight(flight)
	self._flight = flight
end

function CombatController:SetRangedMode(enabled)
	self.RangedMode = enabled
	Logger.Info("RangedMode (arma):", enabled and "ON" or "OFF")
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
			elseif self.RangedMode then
				self:_kiteTick()
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

-- Limpa alvo sem parar loop (managers compartilham controller; Stop matava tudo)
function CombatController:ClearTarget()
	self.Target = nil
	self.RetryCount = 0
	if self.FSM:Get() ~= "Idle" then
		self.FSM:ForceTransition("Idle")
	end
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
-- Module: EliteAutomation.Combat.AdvancedCombat
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Combat.AdvancedCombat", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Combat.AdvancedCombat
--  Sistema de combate avançado baseado em dados reais do GPO.
--  Implementa: Perfect Block, Block Break, Combo chains, iframes.
-- ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")
local HumanMovement = customRequire("EliteAutomation.Movement.HumanMovement")

local AdvancedCombat = {}
AdvancedCombat.__index = AdvancedCombat

-- ─── Timing de Perfect Block (baseado em observações GPO) ────
local PERFECT_BLOCK_WINDOW = 0.15  -- 150ms antes do hit

-- ─── Combos conhecidos por build ──────────────────────────────
local COMBO_CHAINS = {
	-- Sword Main (3SS)
	ThreeSwordStyle = {
		{M1 = 3, Skill = "Z", M1 = 2, Skill = "X", M1 = 1, Skill = "C"},
	},

	-- Black Leg → Demon Step
	BlackLegCombo = {
		{Skill = "Z", M1 = 2, Skill = "X", M1 = 3, Skill = "C"},
	},

	-- Electro (M1 enhanced)
	ElectroCombo = {
		{Skill = "Z", M1 = 4, Skill = "X", M1 = 3},  -- Electro Fist amplia M1
	},

	-- Dragon Claw
	DragonClawCombo = {
		{Skill = "Z", M1 = 2, Skill = "X", Skill = "C", M1 = 2},
	},

	-- Fishman Karate
	FishmanCombo = {
		{M1 = 2, Skill = "Z", Skill = "X", M1 = 3, Skill = "C"},
	},
}

function AdvancedCombat.new(buildType)
	local self = setmetatable({}, AdvancedCombat)

	self.BuildType = buildType or "ThreeSwordStyle"
	self.Enabled = false
	self.AutoBlock = false
	self.AutoPerfectBlock = false
	self.AutoBlockBreak = true

	self._lastBlock = 0
	self._blockCooldown = 0.5
	self._comboActive = false

	return self
end

-- ─── Detecta ataque iminente (previsão) ───────────────────────
function AdvancedCombat:_predictIncomingAttack(enemy)
	if not enemy or not enemy.Parent then return false end

	local hum = enemy:FindFirstChildOfClass("Humanoid")
	if not hum then return false end

	-- Verifica se animação de ataque está rodando
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		local tracks = animator:GetPlayingAnimationTracks()
		for _, track in ipairs(tracks) do
			local name = track.Name:lower()
			if name:find("punch", 1, true)
				or name:find("kick", 1, true)
				or name:find("slash", 1, true)
				or name:find("attack", 1, true) then
				return true
			end
		end
	end

	-- Verifica distância + estado do humanoid
	local root = enemy:FindFirstChild("HumanoidRootPart")
	local playerRoot = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

	if root and playerRoot then
		local dist = (root.Position - playerRoot.Position).Magnitude
		if dist < 8 then  -- Range de M1 típico
			return true
		end
	end

	return false
end

-- ─── Perfect Block (timing preciso) ───────────────────────────
function AdvancedCombat:_attemptPerfectBlock()
	if not self.AutoPerfectBlock then return end

	local now = os.clock()
	if (now - self._lastBlock) < self._blockCooldown then return end

	-- Timing humanizado
	task.wait(HumanMovement.HumanDelay(0.02, 0.01))

	-- Pressiona F (block no GPO)
	local vim = game:GetService("VirtualInputManager")
	if vim then
		vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
		task.wait(PERFECT_BLOCK_WINDOW)
		vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
	end

	self._lastBlock = now
	Logger.Debug("Perfect Block attempt")
end

-- ─── Block Break (quebra defesa do inimigo) ───────────────────
function AdvancedCombat:_useBlockBreak()
	-- Skills que quebram Block no GPO:
	-- - Muitas habilidades "C" e "V"
	-- - Dragon Claw Z
	-- - Fishman Karate C
	-- - etc.

	-- Usa skill C (comum ter Block Break)
	local vim = game:GetService("VirtualInputManager")
	if vim then
		vim:SendKeyEvent(true, Enum.KeyCode.C, false, game)
		task.wait(0.05)
		vim:SendKeyEvent(false, Enum.KeyCode.C, false, game)
	end

	Logger.Debug("Block Break usado")
end

-- ─── Executa combo chain ──────────────────────────────────────
function AdvancedCombat:ExecuteCombo(target)
	if not self.Enabled or self._comboActive then return end
	if not target or not target.Parent then return end

	self._comboActive = true

	local combo = COMBO_CHAINS[self.BuildType]
	if not combo or #combo == 0 then
		self._comboActive = false
		return
	end

	local chain = combo[1]
	local vim = game:GetService("VirtualInputManager")

	for _, action in ipairs(chain) do
		if not target or not target.Parent then break end

		if action.M1 then
			-- M1 combo
			for i = 1, action.M1 do
				HumanMovement.HumanClick(function(pressed)
					vim:SendMouseButtonEvent(0, 0, 0, pressed, game, 1)
				end)
				task.wait(HumanMovement.HumanDelay(0.35, 0.08))
			end

		elseif action.Skill then
			-- Skill
			local key = Enum.KeyCode[action.Skill]
			vim:SendKeyEvent(true, key, false, game)
			task.wait(0.05)
			vim:SendKeyEvent(false, key, false, game)
			task.wait(HumanMovement.HumanDelay(0.6, 0.15))
		end
	end

	self._comboActive = false
	Logger.Info("Combo completo executado")
end

-- ─── Loop de defesa automática ────────────────────────────────
function AdvancedCombat:DefenseLoop(enemies)
	if not self.AutoBlock and not self.AutoPerfectBlock then return end

	for _, enemy in ipairs(enemies) do
		if self:_predictIncomingAttack(enemy) then
			if self.AutoPerfectBlock then
				self:_attemptPerfectBlock()
			elseif self.AutoBlock then
				-- Block normal (segura F)
				local vim = game:GetService("VirtualInputManager")
				if vim then
					vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
					task.wait(0.3)
					vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
				end
			end
			break
		end
	end
end

function AdvancedCombat:Enable()
	self.Enabled = true
	Logger.Info("AdvancedCombat ativado:", self.BuildType)
end

function AdvancedCombat:Disable()
	self.Enabled = false
	Logger.Info("AdvancedCombat desativado")
end

return AdvancedCombat

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Combat.ComboSystem
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Combat.ComboSystem", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Combat.ComboSystem
--  Sistema de combos inteligente para GPO com skill rotation.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")
local HumanMovement = customRequire("EliteAutomation.Movement.HumanMovement")

local ComboSystem = {}
ComboSystem.__index = ComboSystem

-- ─── Combos pré-configurados por tipo de build ────────────────
local COMBOS = {
	-- Sword Main (Espada)
	Sword = {
		{Key = Enum.KeyCode.Z, Name = "Skill 1 (Z)", Cooldown = 8, Priority = 1},
		{Key = Enum.KeyCode.X, Name = "Skill 2 (X)", Cooldown = 10, Priority = 2},
		{Key = Enum.KeyCode.C, Name = "Skill 3 (C)", Cooldown = 15, Priority = 3},
	},

	-- Devil Fruit (Akuma no Mi)
	DevilFruit = {
		{Key = Enum.KeyCode.Z, Name = "DF Move 1", Cooldown = 6, Priority = 1},
		{Key = Enum.KeyCode.X, Name = "DF Move 2", Cooldown = 9, Priority = 2},
		{Key = Enum.KeyCode.C, Name = "DF Move 3", Cooldown = 12, Priority = 3},
		{Key = Enum.KeyCode.V, Name = "DF Move 4", Cooldown = 18, Priority = 4},
	},

	-- Fighting Style (Estilo de Luta)
	FightingStyle = {
		{Key = Enum.KeyCode.Z, Name = "Combat Art 1", Cooldown = 7, Priority = 1},
		{Key = Enum.KeyCode.X, Name = "Combat Art 2", Cooldown = 10, Priority = 2},
		{Key = Enum.KeyCode.C, Name = "Combat Art 3", Cooldown = 14, Priority = 3},
	},

	-- Hybrid (Mix de tudo)
	Hybrid = {
		{Key = Enum.KeyCode.Z, Name = "Sword Z", Cooldown = 8, Priority = 1},
		{Key = Enum.KeyCode.X, Name = "DF X", Cooldown = 9, Priority = 2},
		{Key = Enum.KeyCode.C, Name = "Sword C", Cooldown = 15, Priority = 3},
		{Key = Enum.KeyCode.V, Name = "DF V", Cooldown = 18, Priority = 4},
	},
}

function ComboSystem.new(buildType)
	local self = setmetatable({}, ComboSystem)

	self.BuildType = buildType or "Hybrid"
	self.Combo = COMBOS[self.BuildType] or COMBOS.Hybrid
	self.Cooldowns = {}  -- [skillName] = lastUseTime
	self.Enabled = false

	for _, skill in ipairs(self.Combo) do
		self.Cooldowns[skill.Name] = 0
	end

	return self
end

-- ─── Verifica se skill está em cooldown ───────────────────────
function ComboSystem:_isOnCooldown(skill)
	local lastUse = self.Cooldowns[skill.Name] or 0
	local elapsed = os.clock() - lastUse
	return elapsed < skill.Cooldown
end

-- ─── Usa uma skill específica ─────────────────────────────────
function ComboSystem:_useSkill(skill)
	Logger.Debug("Usando skill:", skill.Name)

	local vim = game:GetService("VirtualInputManager")
	if not vim then return false end

	-- Input humanizado
	local delay = HumanMovement.InputDelay()

	vim:SendKeyEvent(true, skill.Key, false, game)
	task.wait(delay)
	vim:SendKeyEvent(false, skill.Key, false, game)

	self.Cooldowns[skill.Name] = os.clock()
	return true
end

-- ─── Executa combo completo ────────────────────────────────────
function ComboSystem:ExecuteCombo(target)
	if not self.Enabled then return end
	if not target or not target.Parent then return end

	-- Ordena skills por prioridade
	local available = {}
	for _, skill in ipairs(self.Combo) do
		if not self:_isOnCooldown(skill) then
			table.insert(available, skill)
		end
	end

	table.sort(available, function(a, b)
		return a.Priority < b.Priority
	end)

	-- Executa skills disponíveis em sequência
	for _, skill in ipairs(available) do
		if not target or not target.Parent then break end

		local hum = target:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then break end

		self:_useSkill(skill)

		-- Aguarda entre skills (timing humanizado)
		task.wait(HumanMovement.HumanDelay(0.4, 0.15))
	end
end

-- ─── Usa melhor skill disponível (single) ─────────────────────
function ComboSystem:UseBestSkill()
	if not self.Enabled then return false end

	for _, skill in ipairs(self.Combo) do
		if not self:_isOnCooldown(skill) then
			self:_useSkill(skill)
			return true
		end
	end

	return false
end

-- ─── Muda build type em tempo real ────────────────────────────
function ComboSystem:SetBuildType(buildType)
	if COMBOS[buildType] then
		self.BuildType = buildType
		self.Combo = COMBOS[buildType]
		Logger.Info("Build type alterado para:", buildType)
	end
end

function ComboSystem:Enable()
	self.Enabled = true
	Logger.Info("ComboSystem ativado:", self.BuildType)
end

function ComboSystem:Disable()
	self.Enabled = false
	Logger.Info("ComboSystem desativado")
end

return ComboSystem

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Movement.HumanMovement
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Movement.HumanMovement", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Movement.HumanMovement
--  Movimento humanizado com Perlin noise e delays naturais.
--  Anti-detecção avançada para GPO.
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local HumanMovement = {}

-- ─── Perlin noise 1D simplificado ────────────────────────────
local function perlin1D(x, seed)
	seed = seed or 0
	x = x + seed * 1000
	local xi = math.floor(x)
	local xf = x - xi

	local fade = xf * xf * (3 - 2 * xf)

	local a = math.sin(xi * 12.9898 + 78.233) * 43758.5453
	local b = math.sin((xi + 1) * 12.9898 + 78.233) * 43758.5453
	a = a - math.floor(a)
	b = b - math.floor(b)

	return a + fade * (b - a)
end

-- ─── Gera delay humanizado (baseado em distribuição normal) ──
function HumanMovement.HumanDelay(base, variance)
	base = base or 0.15
	variance = variance or 0.05

	-- Box-Muller transform para distribuição normal
	local u1 = math.random()
	local u2 = math.random()
	local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)

	local delay = base + z * variance
	return math.max(0.05, math.min(delay, base + variance * 3))
end

-- ─── Velocity com Perlin noise (movimento orgânico) ──────────
function HumanMovement.PerlinVelocity(baseSpeed, time, seed)
	baseSpeed = baseSpeed or 50
	time = time or os.clock()
	seed = seed or 42

	local noise = perlin1D(time * 0.5, seed)
	local variance = noise * 8  -- ±8 studs/s

	return math.max(20, baseSpeed + variance)
end

-- ─── Path com micro-desvios (evita linha reta perfeita) ──────
function HumanMovement.OrganicPath(start, finish, segments)
	segments = segments or 5
	local path = { start }

	local direction = (finish - start).Unit
	local distance = (finish - start).Magnitude
	local step = distance / segments

	for i = 1, segments - 1 do
		local progress = i / segments
		local basePoint = start:Lerp(finish, progress)

		-- Adiciona desvio perpendicular pequeno
		local perpendicular = Vector3.new(-direction.Z, 0, direction.X)
		local offset = perpendicular * (perlin1D(progress * 10, i) - 0.5) * 4

		table.insert(path, basePoint + offset)
	end

	table.insert(path, finish)
	return path
end

-- ─── Delay entre ações (input timing humanizado) ─────────────
function HumanMovement.InputDelay()
	-- Humanos têm 150-300ms de reação típica
	return HumanMovement.HumanDelay(0.22, 0.08)
end

-- ─── Jitter de posição (anti-bot detection) ──────────────────
function HumanMovement.AddJitter(position, radius)
	radius = radius or 0.5
	local rx = (math.random() - 0.5) * radius * 2
	local ry = (math.random() - 0.5) * radius * 2
	local rz = (math.random() - 0.5) * radius * 2
	return position + Vector3.new(rx, ry, rz)
end

-- ─── Padrão de clique humanizado (não instantâneo) ───────────
function HumanMovement.HumanClick(callback)
	-- Press down
	task.spawn(callback, true)

	-- Hold time variável (50-150ms)
	task.wait(HumanMovement.HumanDelay(0.08, 0.04))

	-- Release
	task.spawn(callback, false)
end

return HumanMovement

end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Movement.ServerSafeMovement
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Movement.ServerSafeMovement", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Movement.ServerSafeMovement
--  Movimento com validação server-side em mente.
--  Baseado em análise do anti-cheat GPO.
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")
local HumanMovement = customRequire("EliteAutomation.Movement.HumanMovement")

local ServerSafeMovement = {}
ServerSafeMovement.__index = ServerSafeMovement

-- ─── Limites de velocidade seguros (GPO observado) ────────────
local SAFE_LIMITS = {
	-- Velocidades máximas observadas como seguras
	WalkSpeed = 20,        -- Velocidade padrão do humanoid
	MaxTweenSpeed = 48,    -- Velocidade máxima de tween segura
	DashSpeed = 35,        -- Dash/Geppo típico
	FruitSpeed = 60,       -- Algumas frutas (Pika, etc) são mais rápidas

	-- Distâncias
	MaxTeleportDist = 100, -- Distância máxima segura para "teleporte"

	-- Tempos
	MinTweenTime = 0.8,    -- Tempo mínimo de tween (evita instantâneo)

	-- Altitude
	MaxAltitude = 500,     -- Altura máxima segura
	SeaLevel = 0,
	SafeSeaOffset = 35,
}

function ServerSafeMovement.new(character, settings)
	local self = setmetatable({}, ServerSafeMovement)

	self.Character = character
	self.Settings = settings or {}

	-- Modo extremamente conservador (padrão)
	self.SafetyLevel = self.Settings.SafetyLevel or "Extreme"  -- Extreme, High, Medium

	self._lastPosition = nil
	self._lastMoveTime = 0
	self._movementHistory = {}  -- Últimos 10 movimentos
	self._suspicionScore = 0    -- Score de suspeita (0-100)

	return self
end

-- ─── Calcula velocidade segura baseada em contexto ────────────
function ServerSafeMovement:_getSafeSpeed(distance)
	local baseSpeed = SAFE_LIMITS.MaxTweenSpeed

	-- Ajusta por nível de segurança
	if self.SafetyLevel == "Extreme" then
		baseSpeed = baseSpeed * 0.75  -- 36 studs/s
	elseif self.SafetyLevel == "High" then
		baseSpeed = baseSpeed * 0.85  -- 40.8 studs/s
	end

	-- Adiciona variação Perlin
	local speed = HumanMovement.PerlinVelocity(baseSpeed, os.clock(), 123)

	-- Limita ao máximo absoluto
	return math.clamp(speed, 20, SAFE_LIMITS.MaxTweenSpeed)
end

-- ─── Valida se movimento é server-safe ────────────────────────
function ServerSafeMovement:_validateMovement(startPos, endPos, duration)
	local distance = (endPos - startPos).Magnitude
	local speed = distance / duration

	-- Check 1: Velocidade impossível
	if speed > SAFE_LIMITS.FruitSpeed then
		Logger.Warn("Movimento rejeitado: velocidade muito alta", speed)
		return false, "speed_too_high"
	end

	-- Check 2: Teleporte suspeito
	if distance > SAFE_LIMITS.MaxTeleportDist and duration < SAFE_LIMITS.MinTweenTime then
		Logger.Warn("Movimento rejeitado: teleporte detectado", distance, duration)
		return false, "teleport_detected"
	end

	-- Check 3: Altitude impossível
	if endPos.Y > SAFE_LIMITS.MaxAltitude then
		Logger.Warn("Movimento rejeitado: altitude muito alta", endPos.Y)
		return false, "altitude_too_high"
	end

	-- Check 4: Frequência de movimento (anti-spam)
	local now = os.clock()
	if (now - self._lastMoveTime) < 0.3 then
		Logger.Warn("Movimento rejeitado: frequência muito alta")
		return false, "move_spam"
	end

	return true, "ok"
end

-- ─── Registra movimento no histórico (para análise) ───────────
function ServerSafeMovement:_recordMovement(startPos, endPos, duration, speed)
	table.insert(self._movementHistory, {
		Start = startPos,
		End = endPos,
		Duration = duration,
		Speed = speed,
		Time = os.clock(),
	})

	-- Mantém apenas últimos 10
	if #self._movementHistory > 10 then
		table.remove(self._movementHistory, 1)
	end

	-- Calcula score de suspeita
	self:_updateSuspicionScore()
end

-- ─── Atualiza score de suspeita baseado em padrões ────────────
function ServerSafeMovement:_updateSuspicionScore()
	local score = 0

	-- Analisa últimos 5 movimentos
	local recent = {}
	for i = math.max(1, #self._movementHistory - 4), #self._movementHistory do
		table.insert(recent, self._movementHistory[i])
	end

	if #recent >= 3 then
		-- Check: Velocidade muito consistente (não humano)
		local speeds = {}
		for _, move in ipairs(recent) do
			table.insert(speeds, move.Speed)
		end

		local avgSpeed = 0
		for _, s in ipairs(speeds) do
			avgSpeed = avgSpeed + s
		end
		avgSpeed = avgSpeed / #speeds

		local variance = 0
		for _, s in ipairs(speeds) do
			variance = variance + math.abs(s - avgSpeed)
		end
		variance = variance / #speeds

		-- Velocidade muito consistente = suspeito
		if variance < 2 then
			score = score + 15
		end

		-- Check: Mudanças de direção perfeitas (linhas retas)
		local straightLines = 0
		for i = 2, #recent do
			local prev = recent[i - 1]
			local curr = recent[i]

			local dir1 = (prev.End - prev.Start).Unit
			local dir2 = (curr.End - curr.Start).Unit

			local dot = dir1:Dot(dir2)
			if dot > 0.99 then  -- Quase paralelo
				straightLines = straightLines + 1
			end
		end

		if straightLines == #recent - 1 then
			score = score + 20  -- Todos movimentos em linha reta
		end
	end

	self._suspicionScore = math.clamp(score, 0, 100)

	if self._suspicionScore > 50 then
		Logger.Warn("⚠ SCORE DE SUSPEITA ALTO:", self._suspicionScore, "- Aumentando aleatoriedade")
	end
end

-- ─── Movimento seguro com validação completa ───────────────────
function ServerSafeMovement:SafeMoveTo(targetPos)
	local root = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local startPos = root.Position
	local distance = (targetPos - startPos).Magnitude

	-- Calcula duração baseada em velocidade segura
	local speed = self:_getSafeSpeed(distance)
	local duration = distance / speed

	-- Adiciona tempo mínimo
	duration = math.max(duration, SAFE_LIMITS.MinTweenTime)

	-- Valida movimento
	local valid, reason = self:_validateMovement(startPos, targetPos, duration)
	if not valid then
		Logger.Error("Movimento cancelado:", reason)
		return false
	end

	-- Adiciona micro-desvios se score alto
	local finalPos = targetPos
	if self._suspicionScore > 30 then
		finalPos = HumanMovement.AddJitter(targetPos, 1.5)
	end

	-- Executa tween
	local tween = TweenService:Create(
		root,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{CFrame = CFrame.new(finalPos)}
	)

	tween:Play()
	tween.Completed:Wait()

	-- Registra movimento
	self:_recordMovement(startPos, finalPos, duration, speed)
	self._lastPosition = finalPos
	self._lastMoveTime = os.clock()

	Logger.Debug("Movimento seguro concluído:", distance, "studs em", string.format("%.2fs", duration))
	return true
end

-- ─── Movimento em segmentos (para distâncias longas) ──────────
function ServerSafeMovement:SafeLongDistance(targetPos)
	local root = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local startPos = root.Position
	local totalDist = (targetPos - startPos).Magnitude

	-- Se distância > 100, divide em segmentos
	if totalDist > SAFE_LIMITS.MaxTeleportDist then
		local segments = math.ceil(totalDist / 80)  -- Segmentos de ~80 studs
		local path = HumanMovement.OrganicPath(startPos, targetPos, segments)

		for i, waypoint in ipairs(path) do
			local success = self:SafeMoveTo(waypoint)
			if not success then
				Logger.Error("Falha no segmento", i, "de", #path)
				return false
			end

			-- Pausa natural entre segmentos
			if i < #path then
				task.wait(HumanMovement.HumanDelay(0.2, 0.1))
			end
		end

		return true
	else
		return self:SafeMoveTo(targetPos)
	end
end

-- ─── Reseta score de suspeita (quando ficar idle) ─────────────
function ServerSafeMovement:ResetSuspicion()
	self._suspicionScore = math.max(0, self._suspicionScore - 5)
	self._movementHistory = {}
end

function ServerSafeMovement:GetSuspicionScore()
	return self._suspicionScore
end

function ServerSafeMovement:SetSafetyLevel(level)
	if level == "Extreme" or level == "High" or level == "Medium" then
		self.SafetyLevel = level
		Logger.Info("Safety level alterado para:", level)
	end
end

return ServerSafeMovement

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

-- ponytail: sem pathfinding; linha reta chunkada. Upgrade: waypoints desviando de ilhas.
local SEG_LEN = 200 -- studs por tween; tween gigante = flag teleport + disconnect
local SEG_TIME_MAX = 8 -- s por segmento; evita tween preso

local function aliveChar(self)
	local char = self.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not char.Parent or not root or not root.Parent then return nil end
	if hum and hum.Health <= 0 then return nil end
	return root
end

-- ─── Utilitário: aguarda tween terminar de forma segura ──────
local function awaitTween(tween, timeout)
	if not tween then return end
	timeout = timeout or SEG_TIME_MAX
	local done = false
	local conn
	conn = tween.Completed:Connect(function()
		done = true
	end)
	local t0 = os.clock()
	while not done and tween.PlaybackState == Enum.PlaybackState.Playing do
		if os.clock() - t0 > timeout then
			pcall(function() tween:Cancel() end)
			break
		end
		task.wait()
	end
	if conn then conn:Disconnect() end
end

local function lookCFrame(pos, dir)
	if dir and dir.Magnitude > 1 then
		return CFrame.new(pos, pos + dir.Unit)
	end
	return CFrame.new(pos) -- sem Unit de vetor zero (NaN = fling pro void)
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
	self._flightId     = 0 -- token: novo FlyTo/Stop cancela o anterior (voo sobreposto = fling)

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

	-- NOTA: sem BodyVelocity/BodyMovers no character. GPO escaneia
	-- BodyMovers estranhos no RootPart e kicka. Tween de CFrame +
	-- noclip + velocidade zerada já estabilizam sem assinatura.
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

		-- NOTA: sem ChangeState por frame. ChangeState(Physics) a cada
		-- Stepped é assinatura conhecida de noclip e causa kick no GPO.
		-- PlatformStand + velocidade zerada já estabilizam o tween.
	end)
end

function SmartFlight:_stopNoclip()
	if self._noclipConn then
		self._noclipConn:Disconnect()
		self._noclipConn = nil
	end

	local root = self:_getRoot()
	if root then
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
	local groundY = self.SeaLevel
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { self.Character }
		local res = workspace:Raycast(
			Vector3.new(targetPos.X, 5000, targetPos.Z),
			Vector3.new(0, -6000, 0),
			params
		)
		if res then groundY = res.Position.Y end
	end)

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
	local root = aliveChar(self)
	if not root then return false end

	local dist = (targetCFrame.Position - root.Position).Magnitude
	if dist < 0.5 then return true end

	-- Pre-requisita streaming da área de destino
	self:_requestStream(targetCFrame.Position)

	local duration = dist / math.max(speed, 5)
	duration = math.min(duration, SEG_TIME_MAX)

	local tween
	pcall(function()
		tween = TweenService:Create(root,
			TweenInfo.new(duration, self.TweenStyle, self.TweenDir),
			{ CFrame = targetCFrame })
	end)
	if not tween then return false end
	self._currentTween = tween
	tween:Play()

	awaitTween(tween, math.max(duration + 2, 3))

	-- Limpa referência
	if self._currentTween == tween then
		self._currentTween = nil
	end

	return aliveChar(self) ~= nil
end

-- ─── Voa até uma posição com trajetória otimizada ────────────
--[[
	targetPos : Vector3 do destino
	Usa estratégia de voo em 3 fases:
	  1. Subida até a altitude segura de cruzeiro (evita bater em montanhas/ilhas)
	  2. Cruzeiro horizontal em segmentos curtos até as coordenadas X, Z
	  3. Descida suave até o alvo final
]]
function SmartFlight:FlyTo(targetPos)
	if typeof(targetPos) ~= "Vector3" then return false end
	-- NaN/Inf = CFrame inválido = disconnect na hora. Barato checar.
	if targetPos.X ~= targetPos.X or math.abs(targetPos.X) > 1e5
		or targetPos.Y ~= targetPos.Y or math.abs(targetPos.Y) > 1e5
		or targetPos.Z ~= targetPos.Z or math.abs(targetPos.Z) > 1e5 then
		return false
	end

	self._flightId += 1
	local myFlight = self._flightId
	if self._currentTween then
		pcall(function() self._currentTween:Cancel() end)
		self._currentTween = nil
	end

	-- Tween sentado (barco/cadeira) = weld fight = disconnect. Levanta antes.
	local hum = self:_getHumanoid()
	if hum and hum.Seated then
		pcall(function() hum.Sit = false end)
		task.wait(0.3)
	end

	local root = aliveChar(self)
	if not root then return false end
	if myFlight ~= self._flightId then return false end

	self._flying = true
	self:_startNoclip()

	local speed = self.SpeedBase + randBetween(self.JitterMin, self.JitterMax)
	speed       = math.max(speed, 10)

	local startPos    = root.Position
	local targetSafeY = self:_safeY(targetPos)
	local cruiseY     = math.max(startPos.Y, targetSafeY, self.SeaLevel + self.SeaFloor)
	local alive = function()
		return myFlight == self._flightId and aliveChar(self) ~= nil
	end

	-- Fase 1: eleva até cruzeiro
	if startPos.Y < (cruiseY - 5) then
		if not alive() then self:_cleanup(); return false end
		self:_tweenTo(CFrame.new(Vector3.new(startPos.X, cruiseY, startPos.Z)), speed * 1.2)
	end

	-- Fase 2: cruzeiro chunkado (tween gigante = flag teleport + disconnect)
	if alive() then
		local flatDir = Vector3.new(targetPos.X - startPos.X, 0, targetPos.Z - startPos.Z)
		local hDist = flatDir.Magnitude
		local steps = math.max(1, math.ceil(hDist / SEG_LEN))
		for i = 1, steps do
			if not alive() then self:_cleanup(); return false end
			local t = i / steps
			local wp = Vector3.new(
				startPos.X + (targetPos.X - startPos.X) * t,
				cruiseY,
				startPos.Z + (targetPos.Z - startPos.Z) * t
			)
			self:_requestStream(wp)
			self:_tweenTo(lookCFrame(wp, flatDir), speed)
		end
	end

	-- Fase 3: descida suave
	if alive() then
		local finalY = math.max(targetPos.Y, self.SeaLevel + 5)
		self:_tweenTo(CFrame.new(Vector3.new(targetPos.X, finalY, targetPos.Z)), speed * 1.1)
	end

	self:_cleanup()
	return alive()
end

-- ─── Voa até um alvo com margem de parada ───────────────────
function SmartFlight:FlyToTarget(targetPart, stopRadius)
	stopRadius = stopRadius or 10
	if not aliveChar(self) then return false end

	self._flightId += 1
	local myFlight = self._flightId
	self._flying = true
	self:_startNoclip()

	local t0 = os.clock()
	local lastTween = 0
	while myFlight == self._flightId do
		local root = aliveChar(self)
		if not root or not targetPart or not targetPart.Parent then break end
		if (targetPart.Position - root.Position).Magnitude <= stopRadius then break end
		if os.clock() - t0 > 120 then break end -- alvo fugindo; sem loop infinito
		if os.clock() - lastTween >= 1.0 then -- tween spam = flag teleport
			lastTween = os.clock()
			self:_tweenTo(lookCFrame(targetPart.Position, targetPart.Position - root.Position), self.SpeedBase)
		end
		task.wait(0.2)
	end

	self:_cleanup()
	return true
end

-- ─── Hover estático em uma posição ──────────────────────────
function SmartFlight:HoverAt(position, durationSecs)
	local root = aliveChar(self)
	if not root then return end

	local safeY  = self:_safeY(position)
	local hoverPos = Vector3.new(position.X, safeY, position.Z)

	self:FlyTo(hoverPos) -- sem CFrame direto: teleport = disconnect
	task.wait(durationSecs or 0)
end

-- ─── Limpeza e encerramento do voo ───────────────────────────
function SmartFlight:_cleanup()
	self._flying = false
	self:_stopNoclip()
	if self._currentTween then
		pcall(function() self._currentTween:Cancel() end)
		self._currentTween = nil
	end
end

-- ─── Para qualquer movimento em curso ───────────────────────
function SmartFlight:Stop()
	self._flightId += 1 -- cancela loop de voo em andamento
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
-- [Bundle] Root redirecionado

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
local AdaptiveBrain   = customRequire("EliteAutomation.Systems.AdaptiveBrain")
local KickTelemetry   = customRequire("EliteAutomation.Systems.KickTelemetry")

-- ─── Combate ──────────────────────────────────────────────────
local CombatController = customRequire("EliteAutomation.Combat.CombatController")
local TargetSelector   = customRequire("EliteAutomation.Combat.TargetSelector")

-- ─── Movimento ────────────────────────────────────────────────
local SmartFlight = customRequire("EliteAutomation.Movement.SmartFlight")

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

end
