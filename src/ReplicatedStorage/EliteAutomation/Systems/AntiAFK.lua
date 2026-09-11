-- ============================================================
--  Elite Automation Framework :: Systems.AntiAFK
--  Sistema anti-kick por inatividade com movimentos aleatórios.
-- ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)
local HumanMovement = require(Root.Movement.HumanMovement)

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

		-- Movimento pequeno
		function()
			local char = Players.LocalPlayer.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart")
				if root then
					local offset = Vector3.new(
						math.random(-2, 2),
						0,
						math.random(-2, 2)
					)
					root.CFrame = root.CFrame + offset
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
