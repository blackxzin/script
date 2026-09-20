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
