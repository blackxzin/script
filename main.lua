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
local __shared = _G
if type(getgenv) == "function" then
	local __ok, __env = pcall(getgenv)
	if __ok and type(__env) == "table" then __shared = __env end
end

if __shared._EliteAutomationLoaded or __shared._EliteAutomationBooting then
	warn("[EliteAutomation] Script ja esta em execucao!")
	return
end
__shared._EliteAutomationBooting = true

-- NOTA: sem hook em game.HttpGet. Hook global quebra chamadas internas
-- do Roblox/GPO (kick/disconnect) e e detectavel pelo anticheat.

local executor = "Unknown"
local __identityOk, __identity = pcall(function()
	if type(identifyexecutor) == "function" then return identifyexecutor() end
	if type(getexecutorname) == "function" then return getexecutorname() end
	return "Unknown"
end)
if __identityOk and __identity then executor = tostring(__identity) end

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

	error("[EliteAutomation] Modulo nao registrado no bundle: " .. tostring(name or target))
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
				t.Enabled = false
				t.Thread = nil
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
--  Configurações Globais e Parâmetros de Engenharia (GPO)
-- ============================================================

return {

	-- ─── [1] GERAIS (Sistema e Debug) ───────────────────────
	General = {
		GameName          = "Grand Piece Online",
		AntiDetectionMode = true,    -- Ativa jitter, delay humano e desvios de trajetória
		AutoReconnect     = true,    -- Tenta reconectar em caso de queda de conexão
		DebugLogs         = false,   -- Ativa logs detalhados no console para desenvolvedores
		Version           = "2.1",   -- Versão do Framework
	},

	-- ─── [2] MOVIMENTAÇÃO (SmartFlight & Anti-Mar) ──────────
	Movement = {
		-- Velocidades Base
		DefaultSpeed    = 52,        -- Velocidade padrão de voo (studs/s)
		MaxSafeSpeed    = 60,        -- Limite máximo para evitar detecção de velocidade
		MinSafeSpeed    = 35,        -- Velocidade mínima para manobras de fuga

		-- Jitter (Humanização de Movimento)
		SpeedJitterMin  = -6,        -- Variação negativa de velocidade
		SpeedJitterMax  =  6,        -- Variação positiva de velocidade

		-- Altitude e Segurança de Mar
		HoverOffset     = 25,        -- Altitude padrão acima do solo/objeto
		SeaFloorOffset  = 35,        -- Altitude de segurança acima do nível do mar (Anti-Afogamento)
		SeaLevel        = 0,         -- Coordenada Y da superfície do mar

		-- Estética de Movimento (Tweening)
		TweenStyle      = Enum.EasingStyle.Sine,
		TweenDirection  = Enum.EasingDirection.InOut,
		DefaultDuration = 2.5,       -- Tempo base para transições de posição

		-- Verificação de Segurança
		SafetyCheckRate = 0.1,       -- Frequência de checagem de altitude (segundos)
		MaxAltitude     = 500,       -- Limite de altura para evitar detecção de voo infinito
	},

	-- ─── [3] COMBATE (CombatController & Advanced) ──────────
	Combat = {
		-- Ciclo de Ataque
		UpdateInterval    = 0.1,     -- Frequência do loop de combate (Hz)
		AttackRange       = 18,      -- Distância máxima de engajamento (Melee/Armas)
		AttackIntervalMin = 0.40,    -- Intervalo mínimo entre ataques (M1)
		AttackIntervalMax = 0.75,    -- Intervalo máximo entre ataques (M1)

		-- Gestão de Risco
		MaxRetries        = 5,       -- Tentativas de re-engajamento antes de desistir
		FleeHealthPct     = 0.20,    -- Porcentagem de HP para iniciar protocolo de fuga
		StaminaThreshold  = 0.15,    -- Stamina mínima para manter ataques (evita Guard Break)

		-- Modo Ranged (Kite/Armas)
		RangedMin         = 32,      -- Distância mínima de combate à distância
		RangedMax         = 60,      -- Distância máxima de combate à distância

		-- Haki e Defesa
		AutoBusoHaki      = false,   -- Ativação explícita de Haki do Armamento
		AutoKenHaki       = false,   -- Ativação explícita de Haki da Observação
		AutoGrip          = false,   -- Execução explícita de alvos nocauteados ('B')

		-- Combos e Skills
		UseCombo          = true,    -- Ativa cadeias de combos pré-configuradas
		BlockWindow       = 0.15,    -- Janela de tempo para Perfect Block (segundos)
	},

	-- ─── [4] SELEÇÃO DE ALVO (TargetSelector) ───────────────
	TargetSelector = {
		PreferLowHealth = true,      -- Prioriza alvos com menor HP para finalização
		MinTargetHealth = 10,        -- Ignora alvos com HP abaixo disso (evita desperdício)

		BlacklistNPCs   = {          -- Lista de IDs/Nomes para ignorar
			"Dummy", "Trainer", "Shopkeeper", "Shipwright",
			"Sailor", "Civilian", "Quest Giver", "Merchant"
		},
	},

	-- ─── [5] BOSSES & SEA EVENTS ───────────────────────────
	BossManager = {
		ScanInterval    = 2.0,       -- Frequência de varredura de bosses no mapa
		AttackRadius    = 90,        -- Raio de detecção de bosses ativos

		-- Configurações de Sea Events (Kraken, Sea Beast, etc)
		SeaEventSettings = {
			SafeAltitude   = 40,       -- Altitude de segurança sobre o mar
			DiveProtection = true,     -- Ativa modo de voo estrito para evitar afogamento
			DetectionRadius = 10000,   -- Raio de detecção de eventos oceânicos
		},

		-- Base de Dados de Bosses (Timers e Localizações)
		TimedBosses = {
			-- Exemplo de estrutura para os bosses de ilha
			BanditBoss = { Name = "Bandit Boss", Location = Vector3.new(1050, 18, 1220), Cooldown = 300, Reward = 2000 },
			-- ... (outros bosses carregados dinamicamente)
		},

		RaidBosses = {
			-- Configurações de Raids (Moria, Baal, etc)
			Moria = { Name = "Moria", PhaseCount = 2, WaveCount = 5, RewardPeli = 75000 },
		}
	},

	-- ─── [6] SISTEMAS DE FARM (Fruit, Item, Merchant) ───────
	FruitTracker = {
		ScanInterval    = 1.5,       -- Frequência de scan de frutas
		AutoCollect     = true,      -- Voo automático até a fruta
		MinRarity       = "Common",  -- Common, Rare, Legendary, Mythical
		NotifyOnDetect  = true,      -- Notificações visuais na UI
		CollectRadius   = 5,         -- Distância para coleta automática
	},

	ItemFarm = {
		ScanInterval = 1.8,
		ItemTags     = { "Chest", "Peli", "Drop", "Gold", "Silver" }, -- Tags de itens
	},

	MerchantTracker = {
		ScanInterval   = 2.0,        -- Frequência de scan do mercador
		NotifyOnSpawn  = true,       -- Alerta visual imediato
		KnownIslands   = {           -- Coordenadas de referência para o mapa
			["Desert Kingdom"] = Vector3.new(-1200, 20, -3000),
			["Sandora"]        = Vector3.new(-1150, 15, 1400),
		},
	},

	-- ─── [7] LAW & FACTORY (Especializado) ──────────────────
	LawFactoryFarm = {
		Factory = {
			Location        = Vector3.new(450, 120, -180),
			CoreHoverHeight = 14,       -- Altitude sobre o Core (anti-ácido)
			WaitHeight      = 200,      -- Altitude de espera
		},
		Law = {
			Location          = Vector3.new(-4716, 28, 1263),
			CombatHeight      = 12,     -- Altitude de combate (anti-Tact)
			ShamblesThreshold = 25,     -- Distância de correção de teleporte
			AutoStartRaid     = true,
			UseCyborgSkills   = true,   -- Ativa rotação de skills da Cyborg
		},
	},

	-- ─── [8] UI & NOTIFICAÇÕES ─────────────────────────────
	Notifications = {
		Duration     = 5,            -- Tempo de exibição das mensagens
		MaxVisible   = 4,            -- Limite de notificações simultâneas
		SlideInTime  = 0.3,          -- Animação de entrada
		SlideOutTime = 0.25,         -- Animação de saída
	},

	-- ─── [9] PERFORMANCE & MEMÓRIA ─────────────────────────
	Performance = {
		CleanupInterval = 30,        -- Segundos entre limpezas de memória
		MaxMemoryUsage = 500,        -- MB para disparar coletor de lixo (GC)
		UpdateRate      = 0.1,       -- Taxa de atualização do sistema de controle
	}
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
--  Arquitetura de Dados de Itens e Raridades (GPO)
-- ============================================================

-- [[ NOTA TÉCNICA ]]
-- O uso de normalização de strings permite que o sistema identifique
-- a fruta mesmo que o nome no Workspace venha com erros de digitação,
-- espaços extras ou sufixos como "no Mi".

local FruitDatabase = {}

-- ─── [1] CONFIGURAÇÕES DE RARIDADE ───────────────────────────
FruitDatabase.RarityPriority = {
	Common    = 1,
	Rare      = 2,
	Legendary = 4,
	Mythical  = 5,
}

-- ─── [2] DATABASE DE ITENS (Otimizada) ───────────────────────
-- Estrutura: [ID] = { Dados }
local DATA = {
	-- COMUNS
	Suke       = { name = "Suke Suke no Mi", fullName = "Suke Suke no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 5000   },
	Spin       = { name = "Guru Guru no Mi", fullName = "Guru Guru no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 7500   },
	Kilo       = { name = "Kilo Kilo no Mi", fullName = "Kilo Kilo no Mi", rarity = "Common",    priority = 1, color = Color3.fromRGB(180, 180, 180), value = 10000  },

	-- RARAS
	Bomu       = { name = "Bomu Bomu no Mi", fullName = "Bomu Bomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 150000 },
	Bari       = { name = "Bari Bari no Mi", fullName = "Bari Bari no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 180000 },
	Mero       = { name = "Mero Mero no Mi", fullName = "Mero Mero no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 220000 },
	Gomu       = { name = "Gomu Gomu no Mi", fullName = "Gomu Gomu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 250000 },
	Horu       = { name = "Horu Horu no Mi", fullName = "Horu Horu no Mi", rarity = "Rare",      priority = 2, color = Color3.fromRGB(52, 152, 219),  value = 200000 },

	-- LENDÁRIAS
	Pika       = { name = "Pika Pika no Mi", fullName = "Pika Pika no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15),  value = 2500000 },
	Magu       = { name = "Magu Magu no Mi", fullName = "Magu Magu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 126, 34),  value = 2400000 },
	Mera       = { name = "Mera Mera no Mi", fullName = "Mera Mera no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(230, 80, 25),   value = 2200000 },
	Goro       = { name = "Goro Goro no Mi", fullName = "Goro Goro no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 215, 0),   value = 2100000 },
	Hie        = { name = "Hie Hie no Mi",   fullName = "Hie Hie no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(130, 210, 255), value = 1800000 },
	Ito        = { name = "Ito Ito no Mi",   fullName = "Ito Ito no Mi",   rarity = "Legendary", priority = 4, color = Color3.fromRGB(233, 30, 99),   value = 1600000 },
	Suna       = { name = "Suna Suna no Mi", fullName = "Suna Suna no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(218, 165, 32),  value = 1500000 },
	Zushi      = { name = "Zushi Zushi no Mi", fullName = "Zushi Zushi no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(155, 89, 182), value = 1700000 },
	Paw        = { name = "Nikyu Nikyu no Mi", fullName = "Nikyu Nikyu no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(255, 105, 180), value = 1750000 },
	Kage       = { name = "Kage Kage no Mi", fullName = "Kage Kage no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(75, 0, 130),    value = 1900000 },
	Yuki       = { name = "Yuki Yuki no Mi", fullName = "Yuki Yuki no Mi", rarity = "Legendary", priority = 4, color = Color3.fromRGB(200, 240, 255), value = 1850000 },

	-- MÍTICAS
	Mochi      = { name = "Mochi Mochi no Mi", fullName = "Mochi Mochi no Mi", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 45, 85),  value = 5000000 },
	Tori       = { name = "Tori Tori no Mi",   fullName = "Tori Tori no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(0, 240, 255),   value = 4500000 },
	Ope        = { name = "Ope Ope no Mi",     fullName = "Ope Ope no Mi",     rarity = "Mythical", priority = 5, color = Color3.fromRGB(142, 68, 173),  value = 4800000 },
	Venom      = { name = "Doku Doku no Mi",   fullName = "Doku Doku no Mi",   rarity = "Mythical", priority = 5, color = Color3.fromRGB(186, 85, 211),  value = 4200000 },
	Buddha     = { name = "Hito Hito: Daibutsu", fullName = "Hito Hito no Mi, Model: Daibutsu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(255, 215, 0), value = 4000000 },
	Dragon     = { name = "Uo Uo: Seiryu",     fullName = "Uo Uo no Mi, Model: Seiryu", rarity = "Mythical", priority = 5, color = Color3.fromRGB(46, 204, 113),  value = 5500000 },

	-- ITENS ESPECIAIS
	MythicalChest  = { name = "Mythical Chest",  fullName = "Mythical Fruit Chest",  rarity = "Mythical",  priority = 5, color = Color3.fromRGB(255, 45, 85),  value = 3500000 },
	LegendaryChest = { name = "Legendary Chest", fullName = "Legendary Fruit Chest", rarity = "Legendary", priority = 4, color = Color3.fromRGB(241, 196, 15), value = 1500000 },
	RareChest      = { name = "Rare Chest",      fullName = "Rare Fruit Chest",      rarity = "Rare",      priority = 3, color = Color3.fromRGB(52, 152, 219),  value = 500000  },
	DarkRoot       = { name = "Dark Root",       fullName = "Dark Root",             rarity = "Rare",      priority = 3, color = Color3.fromRGB(110, 50, 160),  value = 250000  },
	SPReset        = { name = "SP Reset Root",   fullName = "SP Reset Root",         rarity = "Rare",      priority = 3, color = Color3.fromRGB(46, 204, 113),  value = 150000  },
}

-- ─── [3] MÉTODOS DE BUSCA (Matching Engine) ──────────────────

-- Normalização de strings para busca fuzzy (remove espaços, traços e sufixos)
local function normalize(str)
	if not str then return "" end
	return str:lower()
		:gsub("%s*no%s*mi", "") -- Remove "no Mi"
		:gsub("[_%-%s]", "")     -- Remove caracteres especiais e espaços
end

-- Busca rápida por ID ou Nome Exato
function FruitDatabase:Get(name)
	if not name or type(name) ~= "string" then return nil end

	-- 1. Match Direto (O mais rápido)
	if DATA[name] then return DATA[name] end

	-- 2. Match por Nome Normalizado (Para casos como "Mera-Mera" vs "MeraMera")
	local targetNorm = normalize(name)

	for key, info in pairs(DATA) do
		-- Teste o ID normalizado
		if normalize(key) == targetNorm then
			return info
		end

		-- Teste o Nome Completo normalizado
		if info.name and normalize(info.name) == targetNorm then
			return info
		end

		-- Teste o FullName (para casos complexos)
		if info.fullName and normalize(info.fullName) == targetNorm then
			return info
		end

		-- 3. Match Parcial (Fallback para nomes incompletos como "Mera")
		if targetNorm:len() >= 4 then -- Evita falsos positivos com nomes muito curtos
			if targetNorm:find(normalize(key), 1, true) or
			   (info.name and targetNorm:find(normalize(info.name), 1, true)) then
				return info
			end
		end
	end

	return nil
end

-- Verifica se a raridade atende ao requisito mínimo
function FruitDatabase:MeetsMinRarity(fruitName, minRarity)
	local data = self:Get(fruitName)
	if not data then return false end

	local minPriority = self.RarityPriority[minRarity] or 1
	return data.priority >= minPriority
end

-- ─── [4] EXPORTAÇÃO ──────────────────────────────────────────

-- Expõe os dados junto com os métodos de busca do módulo.
-- Retornar DATA aqui descartaria Get/MeetsMinRarity e quebraria o FruitTracker.
for k, v in pairs(DATA) do
    FruitDatabase[k] = v
end

return FruitDatabase
end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.FruitTracker
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.FruitTracker", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.FruitTracker
--  Arquitetura de Rastreamento e Coleta Inteligente (GPO)
-- ============================================================

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger         = customRequire("EliteAutomation.Core.Logger")

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
        -- Inclui o próprio Model e seus filhos; frutas podem ser o objeto raiz.
        local descendants = {obj}
        if obj:IsA("Model") then
            for _, descendant in ipairs(obj:GetDescendants()) do
                table.insert(descendants, descendant)
            end
        end

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
        -- Uma coleta por vez evita que vários voos disputem o SmartFlight.
        local ok, err = pcall(function() self:_collect(entry) end)
        if not ok then Logger.Error("FruitTracker Collect Error: " .. tostring(err)) end
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
    self._knownFruits = {}
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
end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.BossManager
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.BossManager", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: BossManager v2.1
--  Gerenciador de Inteligência de Combate e Eventos de Mundo
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

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
end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.ItemFarm
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.ItemFarm", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.ItemFarm
--  Arquitetura de Coleta de Recursos e Otimização de Loot
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local ItemFarm = {}
ItemFarm.__index = ItemFarm

-- ─── [1] CONFIGURAÇÕES E CONSTANTES ──────────────────────────

local SCAN_LIMIT_DISTANCE = 300 -- Distância máxima para considerar um item para coleta
local MIN_DISTANCE_TO_COLLECT = 8 -- Distância mínima para acionar a coleta

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function ItemFarm.new(smartFlight, notifications, settings)
	local self = setmetatable({}, ItemFarm)

	self.SmartFlight   = smartFlight
	self.Notifications = notifications
	self.Settings      = settings or {}

	self.ScanInterval  = self.Settings.ScanInterval or 2
	self.ItemTags      = self.Settings.ItemTags or { "Chest", "Baú", "Crate", "Drop", "Peli", "Pouch" }
	self.CollectRadius = self.Settings.CollectRadius or 5

	self._running      = false
	self._thread       = nil
	self._collected    = {}  -- Cache de itens em processo de coleta
	self._lastScanTime = 0

	return self
end

-- ─── [3] MÉTODOS DE VALIDAÇÃO E BUSCA ───────────────────────

-- Verifica se o objeto é um item válido baseado nas tags
function ItemFarm:_isCollectible(model)
	if not model:IsA("Model") and not model:IsA("BasePart") then return false end

	for _, tag in ipairs(self.ItemTags) do
		if model.Name:find(tag, 1, true) then
			return true
		end
	end
	return false
end

-- Obtém a posição central do item com fallback para PrimaryPart
local function getItemPosition(model)
	if model:IsA("Model") then
		local primary = model.PrimaryPart or model:FindFirstChildOfClass("BasePart")
		return primary and primary.Position
	elseif model:IsA("BasePart") then
		return model.Position
	end
	return nil
end

-- ─── [4] LÓGICA DE COLETA (Core Logic) ───────────────────────

-- Coleta um item específico com segurança
function ItemFarm:_collectItem(model, name)
	if self._collected[model] then return end
	self._collected[model] = true

	local pos = getItemPosition(model)
	if not pos then
		self._collected[model] = nil
		return
	end

	Logger.Info(string.format("ItemFarm → Coletando: %s em (%.0f, %.0f, %.0f)", name, pos.X, pos.Y, pos.Z))

	-- 1. Notificação Visual
	if self.Notifications then
		local localPlayer = Players.LocalPlayer
		if localPlayer and localPlayer.PlayerGui then
			self.Notifications.Create(
				localPlayer.PlayerGui,
				"📦 ITEM DETECTADO",
				name .. " encontrado! Iniciando coleta...",
				3
			)
		end
	end

	-- 2. Deslocamento Seguro via SmartFlight
	if self.SmartFlight then
		-- Voa para uma posição ligeiramente acima do item para evitar colisões
		self.SmartFlight:FlyTo(pos + Vector3.new(0, 4, 0))
	end

	-- 3. Verificação de Proximidade e Interação
	local localChar = Players.LocalPlayer.Character
	local root = localChar and localChar:FindFirstChild("HumanoidRootPart")

	if root then
		local timeout = os.clock() + 15 -- Timeout de segurança para o processo de coleta
		while os.clock() < timeout do
			if not model.Parent then break end -- Item sumiu (coletado ou deletado)

			local currentPos = getItemPosition(model)
			if not currentPos then break end

			local dist = (currentPos - root.Position).Magnitude
			if dist <= self.CollectRadius then
				-- Tenta interagir via ProximityPrompt ou método de clique
				local prompt = model:FindFirstChildOfClass("ProximityPrompt", true)
				if prompt and fireproximityprompt then
					fireproximityprompt(prompt)
				end

				task.wait(0.3) -- Delay para a animação de coleta
				break
			end
			task.wait(0.1)
		end
	end

	-- 4. Limpeza do Cache
	task.delay(5, function()
		self._collected[model] = nil
		Logger.Debug("ItemFarm: Cache limpo para " .. name)
	end)
end

-- ─── [5] LOOP DE VARREDURA (Scan Engine) ─────────────────────

-- Escaneia o ambiente de forma otimizada
function ItemFarm:_scan()
	local results = {}
	local localChar = Players.LocalPlayer.Character
	local root = localChar and localChar:FindFirstChild("HumanoidRootPart")

	if not root then return results end
	local myPos = root.Position

	-- Scan otimizado: foca em objetos que fazem sentido
	for _, obj in ipairs(workspace:GetChildren()) do
		-- Se o objeto for muito grande, escaneia os descendentes (como baús dentro de modelos)
		local targets = {obj}
		if obj:IsA("Model") then
			for _, descendant in ipairs(obj:GetDescendants()) do
				table.insert(targets, descendant)
			end
		end

		for _, item in ipairs(targets) do
			if item:IsA("Model") or item:IsA("BasePart") then
				if self:_isCollectible(item) then
					local pos = getItemPosition(item)
					if pos then
						local dist = (pos - myPos).Magnitude
						-- Filtro de distância para evitar scan de itens muito longe
						if dist <= SCAN_LIMIT_DISTANCE then
							table.insert(results, {
								model = item,
								name = item.Name,
								pos = pos,
								dist = dist
							})
						end
					end
				end
			end
		end
	end

	-- Ordena por proximidade para priorizar o item mais próximo
	table.sort(results, function(a, b)
		return a.dist < b.dist
	end)

	return results
end

-- ─── [6] MODO DE EXECUÇÃO (Main Loop) ────────────────────────

function ItemFarm:_loop()
	while self._running do
		local ok, items = pcall(function()
			return self:_scan()
		end)

		if ok and #items > 0 then
			-- Processa o item mais próximo da lista
			local target = items[1]

			if target and not self._collected[target.model] then
				self:_collectItem(target.model, target.name)
			end
		elseif not ok then
			Logger.Error("ItemFarm Loop Error: " .. tostring(items))
		end

		task.wait(self.ScanInterval)
	end
end

-- ─── [7] API PÚBLICA ──────────────────────────────────────────

function ItemFarm:Start()
	if self._running then return end
	self._running = true
	self._thread = task.spawn(function() self:_loop() end)
	Logger.Info("ItemFarm iniciado. Modo: Otimizado.")
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
--  Arquitetura de Monitoramento de Ciclo e Spawn de Eventos
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

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
end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.LawFactoryFarm
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.LawFactoryFarm", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.LawFactoryFarm
--  Arquitetura de Raid Especializada (Law & Factory)
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

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
end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.FarmRotation
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.FarmRotation", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.FarmRotation
--  Arquitetura de Otimização de Lucro (XP/Min) e Eficiência
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

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
end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Systems.QuestManager
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Systems.QuestManager", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Systems.QuestManager
--  Arquitetura de Progressão e Automação de Missões
-- ============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger     = customRequire("EliteAutomation.Core.Logger")

local QuestManager = {}
QuestManager.__index = QuestManager

-- ─── [1] DATABASE DE QUESTS (Otimizada) ──────────────────────

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

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function QuestManager.new(combat, smartFlight, notifications, settings)
	local self = setmetatable({}, QuestManager)

	self.Combat        = combat
	self.SmartFlight   = smartFlight
	self.Notifications = notifications
	self.Settings      = settings or {}

	self._running        = false
	self._thread         = nil
	self._currentQuest   = nil
	self._questProgress  = 0
	self._lastQuestTime  = 0

	return self
end

-- ─── [3] LÓGICA DE DECISÃO (Inteligência de Nível) ──────────

-- Verifica o nível atual do jogador (com fallback de segurança)
function QuestManager:_getPlayerLevel()
	local lp = Players.LocalPlayer
	if not lp then return 1 end

	local leaderstats = lp:FindFirstChild("leaderstats")
	if leaderstats then
		local lvl = leaderstats:FindFirstChild("Level") or leaderstats:FindFirstChild("level")
		if lvl and lvl.Value then
			return tonumber(lvl.Value) or 1
		end
	end

	local char = lp.Character
	if char then
		local level = char:GetAttribute("Level")
		if level then return level end
	end

	return 1
end

-- Seleciona a melhor quest baseada em Score de Eficiência (Exp/Dificuldade)
function QuestManager:_selectBestQuest()
	local playerLevel = self:_getPlayerLevel()
	local best = nil
	local bestScore = -math.huge

	for _, quest in ipairs(QUESTS) do
		-- Filtro de Nível: Evita quests muito difíceis para o nível atual
		if quest.Level <= (playerLevel + 10) then
			-- Score = Recompensa de XP / (Nível da Quest + Contagem de Inimigos)
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

-- ─── [4] EXECUÇÃO DE AÇÕES (Interação e Combate) ────────────

-- Gerencia a aceitação da quest no NPC
function QuestManager:_acceptQuest(quest)
	Logger.Info("Aceitando Quest: " .. quest.Name)

	-- 1. Deslocamento para o NPC
	if self.SmartFlight then
		if not self.SmartFlight:FlyTo(quest.Location) then
			Logger.Warn("Deslocamento para a quest interrompido: " .. quest.Name)
			return false
		end
		task.wait(1.5) -- Delay de estabilização de voo
	end

	-- 2. Busca do NPC no Workspace
	local npc = workspace:FindFirstChild(quest.NPC, true)
	if not npc then
		Logger.Warn("NPC não encontrado: " .. quest.NPC)
		return false
	end

	-- 3. Interação (ProximityPrompt ou ClickDetector)
	local prompt = npc:FindFirstChildOfClass("ProximityPrompt", true)
	if prompt and fireproximityprompt then
		pcall(function() fireproximityprompt(prompt) end)
		task.wait(0.5)
	end

	local detector = npc:FindFirstChildOfClass("ClickDetector", true)
	if detector and fireclickdetector then
		pcall(function() fireclickdetector(detector) end)
		task.wait(0.5)
	end

	Logger.Success("Quest aceita: " .. quest.Name)
	return true
end

-- Gerencia o combate contra os inimigos da quest
function QuestManager:_farmEnemies(quest)
	Logger.Info("Iniciando Farm: " .. quest.Name)
	local killed = 0
	local timeout = os.clock() + 300 -- Timeout de 5 minutos por quest

	while self._running and killed < quest.Count and os.clock() < timeout do
		local target = nil

		-- Busca o inimigo mais próximo da lista de inimigos da quest
		for _, enemyName in ipairs(quest.Enemies) do
			local enemy = workspace:FindFirstChild(enemyName, true)
			if enemy and enemy:IsA("Model") then
				local hum = enemy:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					target = enemy
					break
				end
			end
		end

		if target then
			-- 1. Posicionamento e Combate
			if self.SmartFlight then
				self.SmartFlight:FlyTo(target.PrimaryPart and target.PrimaryPart.Position or target:GetPivot().Position)
			end

			if self.Combat then
				self.Combat:SetTarget(target)
			end

			-- 2. Monitoramento de Morte
			local hum = target:FindFirstChildOfClass("Humanoid")
			while hum and hum.Health > 0 and target.Parent and self._running do
				task.wait(0.5)
			end

			killed += 1
			self._questProgress = killed / quest.Count
			Logger.Info(string.format("Progresso de %s: %d/%d", quest.Name, killed, quest.Count))
		else
			-- Aguarda respawn do inimigo
			task.wait(2)
		end
	end

	return killed >= quest.Count
end

-- ─── [5] LOOP PRINCIPAL (Thread de Execução) ─────────────────

function QuestManager:_loop()
	while self._running do
		local ok, err = pcall(function()
			-- 1. Seleção da Próxima Quest
			local quest = self:_selectBestQuest()
			if not quest then
				Logger.Warn("Nenhuma quest viável para o nível atual.")
				task.wait(10)
				return
			end

			self._currentQuest = quest
			self._questProgress = 0

			-- 2. Processo de Aceitação
			local accepted = self:_acceptQuest(quest)
			if not accepted then
				task.wait(5)
				return
			end

			-- 3. Notificação de Início
			if self.Notifications then
				self.Notifications.Create(Players.LocalPlayer.PlayerGui, "📜 QUEST INICIADA",
					quest.Name .. " [" .. quest.Island .. "]", 4, Color3.fromRGB(100, 200, 255))
			end

			-- 4. Fase de Farm
			local completed = self:_farmEnemies(quest)

			-- 5. Finalização e Recompensa
			if completed then
				Logger.Success(string.format("Quest Completa: %s! (+%d EXP)", quest.Name, quest.ExpReward))
				if self.Notifications then
					self.Notifications.Create(Players.LocalPlayer.PlayerGui, "✅ QUEST COMPLETA",
						quest.Name .. " finalizada!", 5, Color3.fromRGB(80, 220, 130))
				end
			end

			self._currentQuest = nil
			task.wait(2)
		end)

		if not ok then
			Logger.Error("QuestManager Loop Error: " .. tostring(err))
		end

		task.wait(1)
	end
end

-- ─── [6] API PÚBLICA ──────────────────────────────────────────

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
--  Arquitetura de Navegação Segura e Inteligente
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local TeleportManager = {}
TeleportManager.__index = TeleportManager

-- ─── [1] DATABASE DE ILHAS (Otimizada) ───────────────────────

local ISLANDS = {
	-- First Sea
	["Town of Beginnings"] = Vector3.new(1100, 18, 1230),
	["Sandora"]            = Vector3.new(-1150, 18, 1420),
	["Shell's Town"]       = Vector3.new(-3800, 20, -4200),
	["Orange Town"]        = Vector3.new(-820, 18, 830),
	["Baratie"]            = Vector3.new(-3100, 12, 4800),
	["Kori Island"]        = Vector3.new(2200, 18, 1850),
	["Sphinx Island"]      = Vector3.new(-6500, 35, -2100),
	["Shark Park"]         = Vector3.new(1250, 18, -3420),
	["Land of the Sky"]    = Vector3.new(-1200, 450, 6000),
	["Golden City"]        = Vector3.new(-1200, 450, 6000),
	["Gravito's Fort"]     = Vector3.new(2800, 80, -3200),
	["Fishman Island"]     = Vector3.new(7200, -300, 1100),
	["Underwater"]         = Vector3.new(7200, -300, 1100),

	-- Second Sea
	["Desert Kingdom"]     = Vector3.new(-1200, 25, -3000),
	["Sashi Island"]       = Vector3.new(4100, 30, -1500),
	["Rovo Island"]        = Vector3.new(-2500, 22, 3800),
	["Spirit Island"]      = Vector3.new(3200, 32, 4500),
	["Foro Island"]        = Vector3.new(-4800, 22, 1100),
	["Umi Island"]         = Vector3.new(5200, 22, -4200),
	["Thriller Bark"]      = Vector3.new(-5400, 80, -7800),
	["Rose Kingdom"]       = Vector3.new(450, 120, -180),
	["Colosseum"]          = Vector3.new(-600, 30, 5200),
	["Colosseum of Arc"]   = Vector3.new(-600, 30, 5200),
}

-- Aliases para busca rápida
local ALIASES = {
	["start"] = "Town of Beginnings",
	["beginning"] = "Town of Beginnings",
	["desert"] = "Sandora",
	["marine"] = "Shell's Town",
	["shells"] = "Shell's Town",
	["baratie"] = "Baratie",
	["sky"] = "Land of the Sky",
	["golden"] = "Golden City",
	["fishman"] = "Fishman Island",
	["underwater"] = "Fishman Island",
	["thriller"] = "Thriller Bark",
	["rose"] = "Rose Kingdom",
	["factory"] = "Rose Kingdom",
}

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function TeleportManager.new(smartFlight, notifications)
	local self = setmetatable({}, TeleportManager)

	self.SmartFlight   = smartFlight
	self.Notifications = notifications

	self.TeleportHistory = {}  -- Histórico de viagens para debug
	self._maxHistory     = 5

	return self
end

-- ─── [3] LÓGICA DE BUSCA (Engine) ────────────────────────────

-- Resolve o nome da ilha usando Alias ou Match Parcial
function TeleportManager:_resolveIsland(name)
	if type(name) ~= "string" or name == "" then return nil, nil end
	name = name:lower():gsub("%s+", "") -- Limpa espaços

	-- 1. Match por Alias
	local aliasMatch = nil
	for alias, fullName in pairs(ALIASES) do
		if name:find(alias, 1, true) then
			aliasMatch = fullName
			break
		end
	end

	if aliasMatch then return aliasMatch, ISLANDS[aliasMatch] end

	-- 2. Match por Nome Completo ou Parcial
	for islandName, pos in pairs(ISLANDS) do
		local lowerIsland = islandName:lower()
		if lowerIsland:find(name, 1, true) or name:find(lowerIsland, 1, true) then
			return islandName, pos
		end
	end

	return nil, nil
end

-- ─── [4] EXECUÇÃO DE VIAGEM (Core Method) ────────────────────

function TeleportManager:TeleportTo(islandName)
	local fullName, position = self:_resolveIsland(islandName)

	if not fullName or not position then
		Logger.Warn("TeleportManager: Ilha não encontrada: " .. tostring(islandName))
		return false
	end

	-- Validação de Integridade da Posição (Anti-NaN/Infinity)
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z
		or math.abs(position.X) > 1e5 or math.abs(position.Y) > 1e5 or math.abs(position.Z) > 1e5 then
		Logger.Error("TeleportManager: Posição inválida detectada!")
		return false
	end

	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	-- Notificação de Início
	if self.Notifications then
		self.Notifications.Create(Players.LocalPlayer.PlayerGui, "🌍 VIAGEM INICIADA",
			"Indo para: " .. fullName, 3, Color3.fromRGB(100, 200, 255))
	end

	-- O uso do SmartFlight é OBRIGATÓRIO para evitar detecção de teleporte
	if self.SmartFlight then
		-- O SmartFlight cuidará do Tweening e da trajetória orgânica
		if not self.SmartFlight:FlyTo(position) then
			Logger.Warn("TeleportManager: deslocamento interrompido para " .. fullName)
			return false
		end
	else
		Logger.Error("TeleportManager: SmartFlight não configurado! Viagem abortada.")
		return false
	end

	-- Registro de Histórico
	table.insert(self.TeleportHistory, 1, {
		Island = fullName,
		Time = os.time()
	})
	if #self.TeleportHistory > self._maxHistory then
		table.remove(self.TeleportHistory)
	end

	Logger.Success("Chegou em: " .. fullName)
	return true
end

-- ─── [5] UTILITÁRIOS E API PÚBLICA ───────────────────────────

-- Teleporte para a ilha mais próxima do jogador
function TeleportManager:TeleportToNearest()
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
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

-- Lista todas as ilhas catalogadas
function TeleportManager:ListIslands()
	local list = {}
	for name in pairs(ISLANDS) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

-- Retorna o histórico de viagens
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

function AutoStats:Start()
	if self._thread then return end
	self:Enable()
	self._thread = task.spawn(function()
		while self.Enabled do
			local ok, err = pcall(function() self:Check() end)
			if not ok then Logger.Error("AutoStats: " .. tostring(err)) end
			task.wait(1)
		end
		self._thread = nil
	end)
end

function AutoStats:Stop()
	self:Disable()
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
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
	self._updateThread = nil

	return self
end

-- ─── Cria Highlight em modelo ─────────────────────────────────

function ESP:_createHighlight(model, color, category)
	if not model or not model.Parent then return end
	if self._highlights[model] then return end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model

	self._highlights[model] = { Instance = highlight, Category = category }
end

-- ─── Cria Billboard com texto ─────────────────────────────────
function ESP:_createBillboard(model, text, color, category)
	if not model or not model.Parent then return end
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

	self._billboards[model] = {
		Instance = billboard,
		Label = label,
		Root = root,
		Text = text,
		Category = category,
	}
end

-- ─── Remove ESP de modelo ─────────────────────────────────────
function ESP:_removeESP(model)
	if self._highlights[model] then
		self._highlights[model].Instance:Destroy()
		self._highlights[model] = nil
	end

	if self._billboards[model] then
		self._billboards[model].Instance:Destroy()
		self._billboards[model] = nil
	end
end

function ESP:_updateDistances()
	local localPlayer = Players.LocalPlayer
	local char = localPlayer and localPlayer.Character
	local playerRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not playerRoot then return end

	for model, data in pairs(self._billboards) do
		if not model.Parent or not data.Instance.Parent or not data.Root.Parent then
			self:_removeESP(model)
		else
			local dist = (data.Root.Position - playerRoot.Position).Magnitude
			data.Label.Text = string.format("%s [%.0fm]", data.Text, dist)
		end
	end

	for model, data in pairs(self._highlights) do
		if not model.Parent or not data.Instance.Parent then
			self:_removeESP(model)
		end
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
		"Doflamingo", "Luci",
	}

	for _, name in ipairs(bossNames) do
		local boss = workspace:FindFirstChild(name, true)
		if boss and boss:IsA("Model") then
			local hum = boss:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				self:_createHighlight(boss, COLORS.Boss, "Boss")
				self:_createBillboard(boss, "👑 " .. name, COLORS.Boss, "Boss")
			end
		end
	end
end

-- ─── Atualiza ESP de NPCs ────────────────────────────────────
function ESP:_updateNPCs()
	if not self.Enabled.NPC then return end

	local playerCharacters = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then playerCharacters[player.Character] = true end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and not playerCharacters[obj]
			and obj:FindFirstChildOfClass("Humanoid") then
			self:_createHighlight(obj, COLORS.NPC, "NPC")
			self:_createBillboard(obj, "NPC: " .. obj.Name, COLORS.NPC, "NPC")
		end
	end
end

-- ─── Atualiza ESP de Frutas ───────────────────────────────────
function ESP:_updateFruits()
	if not self.Enabled.Fruit then return end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name == "Fruit" or obj.Name:find("Fruit", 1, true) then
			if obj:IsA("Model") or obj:IsA("Tool") then
				self:_createHighlight(obj, COLORS.Fruit, "Fruit")
				self:_createBillboard(obj, "🍎 Devil Fruit", COLORS.Fruit, "Fruit")
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
				self:_createHighlight(char, COLORS.Player, "Player")
				self:_createBillboard(char, player.Name, COLORS.Player, "Player")
			end
		end
	end
end

-- ─── Atualiza ESP de Chests ───────────────────────────────────
function ESP:_updateChests()
	if not self.Enabled.Chest then return end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj.Name:find("Chest", 1, true) and obj:IsA("Model") then
			self:_createHighlight(obj, COLORS.Chest, "Chest")
			self:_createBillboard(obj, "📦 Chest", COLORS.Chest, "Chest")
		end
	end
end

-- ─── Loop de atualização ──────────────────────────────────────
function ESP:_updateLoop()
	while self._updateThread do
		local ok, err = pcall(function()
			self:_updateBosses()
			self:_updateNPCs()
			self:_updateFruits()
			self:_updatePlayers()
			self:_updateChests()
			self:_updateDistances()
		end)
		if not ok then Logger.Error("ESP loop error:", err) end

		task.wait(1)  -- Atualiza a cada 1s
	end
end

-- ─── API Pública ──────────────────────────────────────────────
function ESP:Toggle(category, enabled)
	if self.Enabled[category] ~= nil then
		self.Enabled[category] = enabled

		-- Remove ESP existente se desativado
		if not enabled then
			for model, data in pairs(self._highlights) do
				if data.Category == category then self:_removeESP(model) end
			end
			for model, data in pairs(self._billboards) do
				if data.Category == category then self:_removeESP(model) end
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
	for category in pairs(self.Enabled) do
		self.Enabled[category] = false
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

function AutoHeal:Start()
	if self._thread then return end
	self:Enable()
	self._thread = task.spawn(function()
		while self.Enabled do
			local ok, err = pcall(function() self:Check() end)
			if not ok then Logger.Error("AutoHeal: " .. tostring(err)) end
			task.wait(0.5)
		end
		self._thread = nil
	end)
end

function AutoHeal:Stop()
	self:Disable()
	if self._thread then
		task.cancel(self._thread)
		self._thread = nil
	end
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
	self._movementGuard = nil

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

			local ok, vim = pcall(function()
				return game:GetService("VirtualInputManager")
			end)
			if ok and vim then
				pcall(function()
					vim:SendKeyEvent(true, key, false, game)
					task.wait(HumanMovement.HumanDelay(0.1, 0.05))
					vim:SendKeyEvent(false, key, false, game)
				end)
			end
		end,
	}

	-- Durante um farm, evita Humanoid:MoveTo/pulo/teclas para não disputar
	-- controle com o SmartFlight. A câmera continua gerando atividade segura.
	local movementBusy = false
	if self._movementGuard then
		local ok, result = pcall(self._movementGuard)
		movementBusy = ok and result == true
	end

	local action = movementBusy and actions[1] or actions[math.random(#actions)]
	action()

	Logger.Debug("Anti-AFK: ação executada")
end

function AntiAFK:SetMovementGuard(callback)
	self._movementGuard = callback
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
	self._lastAction = os.clock()

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

local SEA_NAMES = {
	Kraken = true,
	["Sea Beast"] = true,
	["Ghost Ship"] = true,
	Megalodon = true,
}
local LAW_NAMES = {
	Law = true,
	Order = true,
	["Trafalgar Law"] = true,
	["Boss Order"] = true,
}

-- Presets por contexto (studs/s, segundos)
local PRESET_SEA   = { Speed = 45, Hover = 40, AtkMin = 0.60, AtkMax = 1.10 }
local PRESET_LAW   = { Speed = 52, Hover = 25, AtkMin = 0.40, AtkMax = 0.75 }
local PRESET_WORLD = { Speed = 52, Hover = 25, AtkMin = 0.40, AtkMax = 0.75 }
local PRESET_SAFE  = { Speed = 40, Hover = 40, AtkMin = 0.80, AtkMax = 1.20 } -- HP baixo
local PRESET_STAM  = { Speed = 42, Hover = 30, AtkMin = 0.75, AtkMax = 1.10 } -- Stamina baixa
local LOW_HP_PCT   = 0.30
local LOW_STAM_PCT = 0.15

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
		snap.HpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
	end
	if char then
		local stam = char:GetAttribute("Stamina") or 100
		local maxStam = char:GetAttribute("MaxStamina") or 100
		if type(stam) == "number" and type(maxStam) == "number" and maxStam > 0 then
			snap.StamPct = math.clamp(stam / maxStam, 0, 1)
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
	elseif snap.StamPct <= LOW_STAM_PCT then
		preset, label = PRESET_STAM, "Recuperando stamina"
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

function AdaptiveBrain:IsRunning()
	return self._running
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
--  Arquitetura de Diagnóstico e Monitoramento de Crash/Kick
-- ============================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- [Bundle] Root redirecionado
local Logger = customRequire("EliteAutomation.Core.Logger")

local FILE = "EliteAutomation_kicklog.txt"
local MAX_EVENTS = 50

local KickTelemetry = {}
KickTelemetry.__index = KickTelemetry

-- ─── [1] CONFIGURAÇÕES E CONSTANTES ──────────────────────────

local ERROR_CODES = { "267", "277", "279", "282", "284", "286" }

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function KickTelemetry.new(notifications)
    local self = setmetatable({}, KickTelemetry)
    self.Notifications = notifications
    self._events = {}
    self._manager = nil
    self._running = false
    self._thread = nil
    self._dumped = false
    self._start_time = os.clock()

    return self
end

-- ─── [3] MÉTODOS DE LOG E TELEMETRIA ─────────────────────────

function KickTelemetry:BindManager(manager)
    self._manager = manager
end

local function stamp()
    return os.date("%H:%M:%S")
end

local function getExecutor()
    local name = "Unknown"
    local ok, res = pcall(function()
        if identifyexecutor then return identifyexecutor() end
        if getexecutorname then return getexecutorname() end
        return "Unknown"
    end)
    return ok and res or name
end

-- Escrita em arquivo (apenas se o executor permitir)
function KickTelemetry:_append(blob)
    if not writefile or not readfile then return end

    pcall(function()
        local content = ""
        local ok, existing = pcall(readfile, FILE)
        if ok then content = existing end

        writefile(FILE, content .. "\n" .. blob .. "\n")
    end)
end

-- Registro de evento de atividade
function KickTelemetry:Event(action, detail)
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")

    local eventData = {
        t = stamp(),
        action = tostring(action),
        detail = tostring(detail or ""),
        pos = root and string.format("%.1f, %.1f, %.1f", root.Position.X, root.Position.Y, root.Position.Z) or "N/A"
    }

    table.insert(self._events, eventData)
    if #self._events > MAX_EVENTS then table.remove(self._events, 1) end
end

-- ─── [4] DETECÇÃO DE CRASH E DISCONNECT ─────────────────────

local function isKickMessage(text)
    if not text or text == "" then return false end
    local t = text:lower()

    -- Verifica códigos de erro e palavras-chave
    for _, code in ipairs(ERROR_CODES) do
        if t:find(code, 1, true) then return true end
    end

    local keywords = { "disconnect", "kicked", "error code", "connection lost", "unexpected" }
    for _, kw in ipairs(keywords) do
        if t:find(kw, 1, true) then return true end
    end

    return false
end

-- Dump completo de informações para debug
function KickTelemetry:_dump(reason)
    if self._dumped then return end
    self._dumped = true

    local uptime = string.format("%.1fs", os.clock() - self._start_time)
    local activeTasks = "-"

    -- Tenta pegar tarefas ativas do Manager
    if self._manager and self._manager.Tasks then
        local tasks = {}
        for name, t in pairs(self._manager.Tasks) do
            if t.Enabled then table.insert(tasks, name) end
        end
        activeTasks = #tasks > 0 and table.concat(tasks, ",") or "None"
    end

    local logHeader = string.format("\n[!!! CRITICAL DUMP !!!]\nReason: %s\nUptime: %s\nActive Tasks: %s\n----------------------\n",
        tostring(reason), uptime, activeTasks)

    local logBody = ""
    for _, e in ipairs(self._events) do
        logBody = logBody .. string.format("[%s] %s | %s | Pos: %s\n", e.t, e.action, e.detail, e.pos)
    end

    local finalBlob = logHeader .. "\n[Event History]\n" .. logBody

    Logger.Error(finalBlob)
    self:_append(finalBlob)
end

-- ─── [5] MONITORAMENTO (LOOP E WATCHERS) ────────────────────

function KickTelemetry:_watchSystem()
    -- 1. Monitoramento do LogService (Erros de Engine/Script)
    local connection = LogService.MessageOut:Connect(function(msg)
        if isKickMessage(msg) then
            self:_dump("LogService Detected: " .. msg)
        end
    end)
    self._logConnection = connection

    -- 2. Monitoramento do Player (Disconnect)
    local playerConn = Players.PlayerRemoving:Connect(function(p)
        if p == Players.LocalPlayer then
            self:_dump("PlayerRemoving Detected")
        end
    end)
    self._playerConn = playerConn

    -- 3. Monitoramento de UI (Prompt de Kick do Roblox)
    task.spawn(function()
        while self._running do
            local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
            if promptGui then
                for _, descendant in ipairs(promptGui:GetDescendants()) do
                    if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                        if isKickMessage(descendant.Text) then
                            self:_dump("RobloxPromptGui Detected: " .. descendant.Text)
                            break
                        end
                    end
                end
            end
            task.wait(2)
        end
    end)
end

-- ─── [6] API PÚBLICA ─────────────────────────────────────────

function KickTelemetry:Start()
    if self._running then return end
    self._running = true

    Logger.Info("KickTelemetry: Iniciando monitoramento...")

    -- Log de Injeção Inicial
    self:Event("inject", "Executor: " .. getExecutor())

    self:_watchSystem()

    -- Thread de Heartbeat (Monitoramento de HP/Status)
    self._thread = task.spawn(function()
        while self._running do
            local char = Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hp = hum and math.floor((hum.Health / hum.MaxHealth) * 100) or -1

            self:Event("heartbeat", "HP: " .. tostring(hp))
            task.wait(5)
        end
    end)

    Logger.Success("KickTelemetry: Sistema Ativo.")
end

function KickTelemetry:Stop()
    self._running = false
    if self._thread then task.cancel(self._thread) end
    if self._logConnection then self._logConnection:Disconnect() end
    if self._playerConn then self._playerConn:Disconnect() end

    Logger.Info("KickTelemetry: Sistema Parado.")
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

local function getTargetRoot(target)
	return target and (target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildOfClass("BasePart"))
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
	local tRoot  = getTargetRoot(self.Target)
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
	local tRoot = getTargetRoot(self.Target)
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
	local ok, vim = pcall(function()
		return game:GetService("VirtualInputManager")
	end)
	if ok and vim then
		-- Usa movimento humanizado para clique
		pcall(function()
			HumanMovement.HumanClick(function(pressed)
				vim:SendMouseButtonEvent(0, 0, 0, pressed, game, 1)
			end)
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
	local tRoot = getTargetRoot(self.Target)
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
--  Arquitetura de Movimento Orgânico e Anti-Detecção Avançada
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local HumanMovement = {}

-- ─── [1] MATEMÁTICA DE DISTRIBUIÇÃO (Gaussian/Normal) ─────────
-- Simula o erro humano usando a Transformação de Box-Muller
local function getGaussianRandom(mean, stdDev)
    local u1 = math.random()
    local u2 = math.random()
    local z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)
    return z0 * stdDev + mean
end

-- ─── [2] PERLIN NOISE (Movimento Fluido) ─────────────────────
-- Gera uma variação suave e contínua, evitando "saltos" de velocidade
local function getPerlinNoise(t, seed, frequency, amplitude)
    seed = seed or 42
    local noise = math.noise(t * frequency, seed, t * frequency * 0.5)
    return noise * amplitude
end

-- ─── [3] DELAY HUMANIZADO ────────────────────────────────────
-- Implementa tempos de reação que variam de forma natural
function HumanMovement.HumanDelay(base, variance)
    base = base or 0.15
    variance = variance or 0.05

    -- O delay não é apenas aleatório, ele tem uma média (mean)
    local delay = getGaussianRandom(base, variance)
    return math.max(0.05, delay)
end

-- ─── [4] VELOCIDADE ORGÂNICA (Perlin Velocity) ───────────────
-- Em vez de uma velocidade constante, usamos uma curva de aceleração
function HumanMovement.PerlinVelocity(baseSpeed, time, seed)
    local frequency = 0.5
    local amplitude = baseSpeed * 0.15 -- 15% de variação de velocidade

    local noise = getPerlinNoise(time, seed or 1, frequency, amplitude)
    return math.max(baseSpeed * 0.8, baseSpeed + noise)
end

-- ─── [5] TRAJETÓRIA ORGÂNICA (Anti-Line Path) ────────────────
-- Cria um caminho com desvios laterais para evitar o "vôo em linha reta"
function HumanMovement.OrganicPath(startPos, finishPos, segments)
    segments = segments or 6
    local path = { startPos }
    local direction = (finishPos - startPos).Unit
    local distance = (finishPos - startPos).Magnitude

    -- Vetor perpendicular para criar o desvio lateral
    local upVector = Vector3.new(0, 1, 0)
    local sideVector = direction:Cross(upVector).Unit
    if sideVector.Magnitude < 0.1 then sideVector = Vector3.new(1, 0, 0) end

    for i = 1, segments - 1 do
        local progress = i / segments
        local basePoint = startPos:Lerp(finishPos, progress)

        -- Adiciona um desvio lateral usando Perlin Noise para suavidade
        local deviation = getPerlinNoise(progress * 5, i, 0.5, 3)
        local lateralOffset = sideVector * deviation

        -- Adiciona um pequeno desvio de altura (Y) para não ser perfeitamente plano
        local verticalOffset = math.sin(progress * math.pi) * 2

        table.insert(path, basePoint + lateralOffset + Vector3.new(0, verticalOffset, 0))
    end

    table.insert(path, finishPos)
    return path
end

-- ─── [6] INPUT TIMING (Reação Humana) ────────────────────────
-- Simula o tempo de clique e pressionamento de tecla
function HumanMovement.InputDelay()
    -- Reação típica de 180ms a 320ms
    return getGaussianRandom(0.25, 0.05)
end

-- ─── [7] JITTER DE POSIÇÃO (Anti-Bot Detection) ───────────────
-- Adiciona micro-tremores na posição para evitar padrões estáticos
function HumanMovement.AddJitter(position, radius)
    radius = radius or 0.5
    local jitterX = getGaussianRandom(0, radius)
    local jitterY = getGaussianRandom(0, radius)
    local jitterZ = getGaussianRandom(0, radius)

    return position + Vector3.new(jitterX, jitterY, jitterZ)
end

-- ─── [8] CLIQUE HUMANIZADO (Hold Time) ───────────────────────
-- Simula o tempo que um humano mantém o botão pressionado
function HumanMovement.HumanClick(callback)
    -- Simula o pressionar (Down)
    task.spawn(function()
        callback(true)
    end)

    -- Delay de pressão variável (Hold time)
    local holdTime = getGaussianRandom(0.1, 0.04)
    task.wait(holdTime)

    -- Simula o soltar (Up)
    task.spawn(function()
        callback(false)
    end)
end

-- ─── [9] INTERPOLAÇÃO DE CURVA (Easing Helper) ───────────────
-- Ajuda o SmartFlight a não dar saltos bruscos de velocidade
function HumanMovement.GetSmoothStep(t)
    -- Smoothstep formula: 3t^2 - 2t^3
    return t * t * (3 - 2 * t)
end

return HumanMovement
end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Movement.ServerSafeMovement
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Movement.ServerSafeMovement", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Movement.ServerSafeMovement
--  Arquitetura de Movimento com Validação de Padrão e Anti-Detection
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

-- ─── [1] CONSTANTES DE SEGURANÇA (Hard Limits) ──────────────
local SAFE_LIMITS = {
	MaxTweenSpeed    = 48,    -- Limite para evitar detecção de velocidade
	MaxTeleportDist  = 85,    -- Distância máxima por segmento (Chunking)
	MinTweenTime     = 0.8,   -- Tempo mínimo para evitar "snapping"
	MaxAltitude      = 500,   -- Limite de altura para evitar detecção de voo
	MaxSuspicion     = 100,   -- Score máximo de suspeita
}

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────
function ServerSafeMovement.new(character, settings)
	local self = setmetatable({}, ServerSafeMovement)

	self.Character = character
	self.Settings = settings or {}

	-- Níveis de Segurança: Extreme (Mais lento/seguro) -> Medium (Mais rápido)
	self.SafetyLevel = self.Settings.SafetyLevel or "Extreme"

	self._lastMoveTime = 0
	self._movementHistory = {}  -- Armazena os últimos 10 movimentos para análise de padrão
	self._suspicionScore = 0    -- Score de suspeita baseado em comportamento
	self._isMoving = false

	return self
end

-- ─── [3] MOTOR DE VELOCIDADE (Gaussian Velocity) ─────────────
function ServerSafeMovement:_getSafeSpeed(distance)
	local baseSpeed = SAFE_LIMITS.MaxTweenSpeed

	-- Ajuste por nível de segurança
	if self.SafetyLevel == "Extreme" then
		baseSpeed = baseSpeed * 0.70 -- ~33 studs/s
	elseif self.SafetyLevel == "High" then
		baseSpeed = baseSpeed * 0.85 -- ~40 studs/s
	end

	-- Aplica variação orgânica (Perlin Noise) para não ser constante
	return HumanMovement.PerlinVelocity(baseSpeed, os.clock(), 123)
end

-- ─── [4] VALIDAÇÃO DE PADRÃO (Anti-Pattern Detection) ────────
function ServerSafeMovement:_validateMovement(startPos, endPos, duration)
	local distance = (endPos - startPos).Magnitude
	local speed = distance / duration

	-- Check 1: Velocidade (Speed Hack Detection)
	if speed > SAFE_LIMITS.MaxTweenSpeed + 5 then
		Logger.Warn("Segurança: Velocidade excessiva detectada!")
		return false, "speed_limit_exceeded"
	end

	-- Check 2: Teleporte (Snap Detection)
	if distance > SAFE_LIMITS.MaxTeleportDist and duration < SAFE_LIMITS.MinTweenTime then
		return false, "teleport_snap"
	end

	-- Check 3: Altitude (Sky Hack Detection)
	if endPos.Y > SAFE_LIMITS.MaxAltitude then
		return false, "altitude_too_high"
	end

	-- Check 4: Anti-Spam (Movement Frequency)
	local now = os.clock()
	if (now - self._lastMoveTime) < 0.25 then
		return false, "movement_spam"
	end

	return true, "ok"
end

-- ─── [5] ANÁLISE DE COMPORTAMENTO (Suspicion Score) ──────────
function ServerSafeMovement:_updateSuspicionScore(newMove)
	table.insert(self._movementHistory, newMove)
	if #self._movementHistory > 10 then table.remove(self._movementHistory, 1) end

	local score = 0
	if #self._movementHistory < 5 then return end

	-- Check: Linha Reta Perfeita (Bot Detection)
	local straightLines = 0
	for i = 2, #self._movementHistory do
		local m1 = self._movementHistory[i-1]
		local m2 = self._movementHistory[i]

		local dir1 = (m1.End - m1.Start).Unit
		local dir2 = (m2.End - m2.Start).Unit

		if dir1:Dot(dir2) > 0.995 then -- Quase paralelo
			straightLines += 1
		end
	end

	if straightLines >= 3 then score += 30 end

	-- Check: Velocidade Constante (Inconsistência Humana)
	local avgSpeed = 0
	for _, m in ipairs(self._movementHistory) do avgSpeed += m.speed end
	avgSpeed /= #self._movementHistory

	local variance = 0
	for _, m in ipairs(self._movementHistory) do variance += math.abs(m.speed - avgSpeed) end
	variance /= #self._movementHistory

	if variance < 1.5 then score += 25 end -- Velocidade muito estável é suspeita

	self._suspicionScore = math.clamp(score, 0, SAFE_LIMITS.MaxSuspicion)
end

-- ─── [6] MOVIMENTO SEGURO (Core Method) ───────────────────────
function ServerSafeMovement:SafeMoveTo(targetPos)
	local root = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	if not root or self._isMoving then return false end

	local startPos = root.Position
	local distance = (targetPos - startPos).Magnitude

	-- Calcula duração baseada em velocidade dinâmica
	local speed = self:_getSafeSpeed(distance)
	local duration = math.max(distance / speed, SAFE_LIMITS.MinTweenTime)

	-- Validação antes de iniciar
	local valid, reason = self:_validateMovement(startPos, targetPos, duration)
	if not valid then
		Logger.Error("Movimento Bloqueado: " .. reason)
		return false
	end

	self._isMoving = true

	-- Aplica o caminho orgânico (Curvas em vez de linhas retas)
	local pathPoints = HumanMovement.OrganicPath(startPos, targetPos, 4)

	for i = 1, #pathPoints - 1 do
		local p1 = pathPoints[i]
		local p2 = pathPoints[i+1]
		local segmentDist = (p2 - p1).Magnitude
		local segmentDuration = math.max(segmentDist / speed, 0.2)

		-- Adiciona Jitter se a suspeita estiver alta
		local finalTarget = p2
		if self._suspicionScore > 40 then
			finalTarget = HumanMovement.AddJitter(p2, 1.2)
		end

		local tween = TweenService:Create(root,
			TweenInfo.new(segmentDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{CFrame = CFrame.new(finalTarget)}
		)

		tween:Play()
		tween.Completed:Wait()

		-- Pequena pausa entre segmentos para simular hesitação humana
		task.wait(HumanMovement.HumanDelay(0.1, 0.05))
	end

	-- Finalização do movimento
	self._lastMoveTime = os.clock()
	self._isMoving = false

	-- Registra para análise de padrão
	self:_updateSuspicionScore({
		speed = speed,
		dist = distance,
		time = os.clock()
	})

	Logger.Debug("Movimento Seguro Finalizado: " .. string.format("%.1f", distance) .. " studs")
	return true
end

-- ─── [7] MOVIMENTO DE LONGA DISTÂNCIA (Chunking) ─────────────
function ServerSafeMovement:SafeLongDistance(targetPos)
	local root = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end

	local startPos = root.Position
	local totalDist = (targetPos - startPos).Magnitude

	-- Se a distância for muito grande, divide em segmentos (chunks)
	-- Isso evita o "Teleporte" que o servidor detecta
	local segments = math.ceil(totalDist / SAFE_LIMITS.MaxTeleportDist)

	for i = 1, segments do
		local progress = i / segments
		local nextWaypoint = startPos:Lerp(targetPos, progress)

		-- Adiciona um pequeno atraso entre os chunks
		local success = self:SafeMoveTo(nextWaypoint)

		if not success then
			Logger.Error("Falha no trajeto longo no segmento: " .. i)
			return false
		end

		task.wait(HumanMovement.HumanDelay(0.2, 0.1))
	end

	return true
end

-- ─── [8] UTILITÁRIOS ─────────────────────────────────────────
function ServerSafeMovement:ResetSuspicion()
	self._suspicionScore = 0
	self._movementHistory = {}
	Logger.Info("Score de suspeita resetado.")
end

function ServerSafeMovement:GetSuspicionScore()
    return self._suspicionScore
end

function ServerSafeMovement:SetSafetyLevel(level)
    self.SafetyLevel = level
    Logger.Info("Nível de Segurança: " .. level)
end

return ServerSafeMovement
end)


-- ────────────────────────────────────────────────────────────
-- Module: EliteAutomation.Movement.SmartFlight
-- ────────────────────────────────────────────────────────────
__register("EliteAutomation.Movement.SmartFlight", function(customRequire)
-- ============================================================
--  Elite Automation Framework :: Movement.SmartFlight
--  Arquitetura de Voo Orgânico e Bypass de Física Avançado
-- ============================================================

local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local Players       = game:GetService("Players")

local SmartFlight = {}
SmartFlight.__index = SmartFlight

-- ─── [1] CONSTANTES DE SEGURANÇA ─────────────────────────────
local SEG_LEN        = 45    -- Tamanho do segmento (menor = mais seguro/detectável)
local SEG_TIME_MAX   = 6     -- Tempo máximo por segmento
local MIN_SPEED      = 25    -- Velocidade mínima para evitar travamentos
local MAX_SPEED      = 55    -- Velocidade máxima para evitar kick de velocidade

-- ─── [2] UTILITÁRIOS INTERNOS ────────────────────────────────

local function aliveChar(self)
    local char = self.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not char.Parent or not root or not root.Parent then return nil end
    if hum and hum.Health <= 0 then return nil end
    return root
end

function SmartFlight:_getHumanoid()
    local char = self.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function lookCFrame(pos, dir)
    if dir and dir.Magnitude > 0.1 then
        return CFrame.new(pos, pos + dir.Unit)
    end
    return CFrame.new(pos)
end

-- ─── [3] CONSTRUTOR ──────────────────────────────────────────

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
    self._noclipConn   = nil
    self._currentTween = nil
    self._flightId     = 0

    return self
end

-- ─── [4] MOTOR DE FÍSICA (Noclip & Anti-Gravity) ─────────────

function SmartFlight:_startNoclip()
    if self._noclipConn then return end

    local char = self.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hum then hum.PlatformStand = true end

    -- O Stepped é executado antes da física, ideal para desativar colisões
    self._noclipConn = RunService.Stepped:Connect(function()
        if not char or not char.Parent then return end

        -- Desativa colisões para evitar "fling" em objetos
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end

        -- Zera a velocidade para evitar acumular inércia (essencial para o Tween)
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

function SmartFlight:_stopNoclip()
    if self._noclipConn then
        self._noclipConn:Disconnect()
        self._noclipConn = nil
    end

    local hum = self.Character and self.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
end

-- ─── [5] SEGURANÇA DE ALTITUDE (Anti-Mar) ────────────────────

function SmartFlight:_safeY(targetPos)
    local groundY = self.SeaLevel

    -- Raycast para detectar o chão real e manter altitude segura
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { self.Character }

    local res = workspace:Raycast(
        Vector3.new(targetPos.X, 500, targetPos.Z),
        Vector3.new(0, -1000, 0),
        params
    )

    if res then groundY = res.Position.Y end

    local safeMin = self.SeaLevel + self.SeaFloor
    return math.max(groundY + self.HoverOffset, safeMin)
end

-- ─── [6] MOVIMENTO EM SEGMENTOS (Chunked Movement) ───────────

function SmartFlight:_tweenTo(targetCFrame, speed)
    local root = aliveChar(self)
    if not root then return false end

    local dist = (targetCFrame.Position - root.Position).Magnitude
    if dist < 0.5 then return true end

    -- Calcula duração baseada na velocidade para manter o movimento constante
    local duration = math.clamp(dist / speed, 0.5, SEG_TIME_MAX)

    local tween = TweenService:Create(root,
        TweenInfo.new(duration, self.TweenStyle, self.TweenDir),
        {CFrame = targetCFrame}
    )

    self._currentTween = tween
    tween:Play()

    -- Aguarda o término do tween ou timeout
    local completed = false
    local conn
    conn = tween.Completed:Connect(function() completed = true end)

    local start = os.clock()
    while not completed and (os.clock() - start) < (duration + 1) do
        if not root.Parent then break end
        task.wait()
    end

    if conn then conn:Disconnect() end
    return completed
end

-- ─── [7] API PÚBLICA (FlyTo, Stop, etc) ───────────────────────

function SmartFlight:FlyTo(targetPos)
    if typeof(targetPos) ~= "Vector3" then return false end

    -- Incrementa ID para cancelar voos anteriores (evita sobreposição de tweens)
    self._flightId += 1
    local myFlight = self._flightId

    local root = aliveChar(self)
    if not root then return false end

    self._flying = true
    self:_startNoclip()

    -- 1. Cálculo de Velocidade com Jitter
    local speed = math.clamp(self.SpeedBase + (math.random(-6, 6)), MIN_SPEED, MAX_SPEED)

    -- 2. Determinação de Altitude Segura
    -- Mantém a altura mínima segura, mas respeita uma altura explícita
    -- enviada pelo farm (por exemplo, a altura da Factory/Law).
    local targetSafeY = math.max(targetPos.Y, self:_safeY(targetPos))
    local startPos = root.Position

    -- 3. Trajetória em segmentos até a posição com altitude segura.
    -- Comparar com targetPos.Y poderia deixar o loop infinito quando o alvo
    -- estivesse abaixo do nível seguro calculado pelo sistema.
    local targetFinalPos = Vector3.new(targetPos.X, targetSafeY, targetPos.Z)

    -- Loop de Segmentos (Chunking)
    local currentPos = startPos
    while myFlight == self._flightId do
        local distToTarget = (targetFinalPos - currentPos).Magnitude
        if distToTarget < 2 then break end

        -- Calcula o próximo waypoint para o chunk
        local direction = (targetFinalPos - currentPos).Unit
        local nextStep = currentPos + (direction * math.min(distToTarget, SEG_LEN))
        local nextStepPos = Vector3.new(nextStep.X, targetSafeY, nextStep.Z)

        -- Executa o movimento segmentado e orienta o personagem para o
        -- próximo trecho. CFrame.new(pos) movia, mas deixava a orientação
        -- antiga, dando a impressão de que o personagem não seguia o rumo.
        local waypointCFrame = lookCFrame(nextStepPos, direction)
        local success = self:_tweenTo(waypointCFrame, speed)
        if not success then break end

        local currentRoot = aliveChar(self)
        currentPos = currentRoot and currentRoot.Position or nextStepPos
        task.wait(0.05) -- Micro-pausa para estabilização
    end

    self:_cleanup()
    return myFlight == self._flightId
end

function SmartFlight:FlyToTarget(targetPart, stopRadius)
    if not targetPart or not targetPart.Parent then return false end
    local stopRadius = stopRadius or 10
    local targetPos = targetPart.Position

    local root = aliveChar(self)
    if not root then return false end

    -- Voa até a posição alvo mantendo a margem de segurança
    self:FlyTo(targetPos)

    return true
end

-- ─── [8] LIMPEZA E UTILITÁRIOS ───────────────────────────────

function SmartFlight:_cleanup()
    self._flying = false
    self:_stopNoclip()

    local hum = self:_getHumanoid()
    if hum then
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end

    if self._currentTween then
        pcall(function() self._currentTween:Cancel() end)
        self._currentTween = nil
    end
end

function SmartFlight:Stop()
    self._flightId += 1
    self._flying = false
    self:_cleanup()
end

function SmartFlight:SetCharacter(newChar)
    self.Character = newChar
    self:Stop()
end

function SmartFlight:SetSpeed(speed)
    self.SpeedBase = math.clamp(speed, MIN_SPEED, MAX_SPEED)
end

return SmartFlight
end)


-- Pre-carregamento dos módulos exigidos diretamente pelo entrypoint
-- (executado antes do entrypoint para garantir que customRequire
-- resolva antes que MainUI.new() seja chamado)
local Components   = customRequire("EliteAutomation.UI.Components")
local TabManager    = customRequire("EliteAutomation.UI.TabManager")
local Notifications = customRequire("EliteAutomation.UI.Notifications")


-- ────────────────────────────────────────────────────────────
-- Entrypoint: EliteAutomation.client.lua
-- ────────────────────────────────────────────────────────────
local __bootOk, __bootErr = xpcall(function()
	do
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
	-- [Bundle] Root redirecionado
	if not Root then
	    warn("[EliteAutomation] Erro: Root não encontrado no ReplicatedStorage!")
	    return
	end

	-- 2. IMPORTAÇÃO DOS MÓDULOS (Ordem de Dependência)
	-- Core primeiro
	local Logger         = customRequire("EliteAutomation.Core.Logger")
	local TaskManager    = customRequire("EliteAutomation.Core.TaskManager")
	local StateMachine   = customRequire("EliteAutomation.Core.StateMachine")
	local PriorityManager = customRequire("EliteAutomation.Core.PriorityManager")
	local Settings       = customRequire("EliteAutomation.Config.Settings")

	-- Sistemas de Movimento e Combate (Base para outros sistemas)
	local SmartFlight    = customRequire("EliteAutomation.Movement.SmartFlight")
	local CombatController = customRequire("EliteAutomation.Combat.CombatController")
	local TargetSelector   = customRequire("EliteAutomation.Combat.TargetSelector")

	-- Sistemas de Mundo (Dependem de Combate e Movimento)
	local FruitDatabase   = customRequire("EliteAutomation.Systems.FruitDatabase")
	local FruitTracker    = customRequire("EliteAutomation.Systems.FruitTracker")
	local BossManager     = customRequire("EliteAutomation.Systems.BossManager")
	local ItemFarm        = customRequire("EliteAutomation.Systems.ItemFarm")
	local MerchantTracker = customRequire("EliteAutomation.Systems.MerchantTracker")
	local LawFactoryFarm  = customRequire("EliteAutomation.Systems.LawFactoryFarm")
	local AntiAFK         = customRequire("EliteAutomation.Systems.AntiAFK")
	local FarmRotation    = customRequire("EliteAutomation.Systems.FarmRotation")
	local QuestManager    = customRequire("EliteAutomation.Systems.QuestManager")
	local AutoHeal        = customRequire("EliteAutomation.Systems.AutoHeal")
	local AutoStats       = customRequire("EliteAutomation.Systems.AutoStats")
	local ESP             = customRequire("EliteAutomation.Systems.ESP")
	local TeleportManager = customRequire("EliteAutomation.Systems.TeleportManager")
	local AdaptiveBrain   = customRequire("EliteAutomation.Systems.AdaptiveBrain")
	local KickTelemetry   = customRequire("EliteAutomation.Systems.KickTelemetry")

	-- Interface (UI)
	local MainUI       = customRequire("EliteAutomation.UI.MainUI")
	local TabManager   = customRequire("EliteAutomation.UI.TabManager")
	local Components   = customRequire("EliteAutomation.UI.Components")
	local Notifications = customRequire("EliteAutomation.UI.Notifications")

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
	end
end, function(err)
	if debug and debug.traceback then return debug.traceback(tostring(err), 2) end
	return tostring(err)
end)
if not __bootOk then
	__shared._EliteAutomationBooting = nil
	__shared._EliteAutomationLoaded = nil
	error(__bootErr)
end
__shared._EliteAutomationBooting = nil
__shared._EliteAutomationLoaded = true
