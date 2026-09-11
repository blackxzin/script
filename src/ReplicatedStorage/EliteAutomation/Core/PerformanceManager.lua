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
