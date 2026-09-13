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
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

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
