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
