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
local Root       = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger     = require(Root.Core.Logger)

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
