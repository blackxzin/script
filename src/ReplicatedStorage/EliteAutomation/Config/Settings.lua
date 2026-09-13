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
