-- ============================================================
--  Elite Automation Framework :: Combat.CombatController
--  Motor de combate com AttackInterval jitterizado,
--  StateMachine de estados e proteção de fuga (flee).
-- ============================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")

-- Módulos internos
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root          = ReplicatedStorage:WaitForChild("EliteAutomation")
local StateMachine  = require(Root.Core.StateMachine)
local TargetSelector = require(Root.Combat.TargetSelector)
local Logger        = require(Root.Core.Logger)
local HumanMovement = require(Root.Movement.HumanMovement)

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
