-- ============================================================
--  Elite Automation Framework :: Core.PriorityManager
--  Gerencia prioridade de tarefas concorrentes.
--  Mais alto = mais prioritário. Apenas 1 tarefa ativa por vez.
-- ============================================================

local PriorityManager = {}
PriorityManager.__index = PriorityManager

function PriorityManager.new()
	local self = setmetatable({}, PriorityManager)

	self.ActiveTask    = nil   -- nome da tarefa atualmente ativa
	self.Tasks         = {}    -- [name] = { priority, onActivate, onDeactivate }

	return self
end

--[[
	Registra uma tarefa com prioridade.
	priority     : número (maior = mais importante)
	onActivate   : função chamada quando esta tarefa se torna ativa
	onDeactivate : função chamada quando perde o controle
]]
function PriorityManager:Register(name, priority, onActivate, onDeactivate)
	self.Tasks[name] = {
		Priority     = priority,
		OnActivate   = onActivate,
		OnDeactivate = onDeactivate,
		Active       = false,
	}
end

-- Pede para ativar uma tarefa; só ativa se tiver prioridade suficiente.
function PriorityManager:Request(name)
	local requestedTask = self.Tasks[name]
	if not requestedTask then return false end

	-- Sem tarefa ativa → ativa imediatamente
	if not self.ActiveTask then
		self.ActiveTask         = name
		requestedTask.Active    = true
		requestedTask.OnActivate()
		return true
	end

	-- Compara com tarefa atual
	local currentTask = self.Tasks[self.ActiveTask]
	if requestedTask.Priority > currentTask.Priority then
		-- Preempta a tarefa atual
		currentTask.Active = false
		currentTask.OnDeactivate()

		self.ActiveTask         = name
		requestedTask.Active    = true
		requestedTask.OnActivate()
		return true
	end

	return false -- sem prioridade suficiente
end

-- Libera a tarefa; deixa o sistema escolher a próxima mais prioritária ativa.
function PriorityManager:Release(name)
	local task = self.Tasks[name]
	if not task or not task.Active then return end

	task.Active = false
	task.OnDeactivate()

	if self.ActiveTask == name then
		self.ActiveTask = nil
	end
end

function PriorityManager:GetActive()
	return self.ActiveTask
end

function PriorityManager:IsActive(name)
	local task = self.Tasks[name]
	return task ~= nil and task.Active
end

return PriorityManager
