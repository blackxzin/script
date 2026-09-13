-- ============================================================
--  Elite Automation Framework :: Systems.AdaptiveBrain
--  Observa boss atual + HP/stamina/dist e ajusta voo e combate.
--  Sem boss: restaura defaults. Loop 1s, sem spam de input.
-- ============================================================

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

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
