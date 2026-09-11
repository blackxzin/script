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
