-- ============================================================
--  Elite Automation Framework :: Core.StateMachine
--  Máquina de estados finitos com listeners e histórico.
-- ============================================================

local StateMachine = {}
StateMachine.__index = StateMachine

--[[
	Estados válidos do agente:
	  "Idle"     - Aguardando próxima ação
	  "Combat"   - Em combate ativo
	  "Moving"   - Deslocando até alvo
	  "Farming"  - Coletando item/fruta
	  "Fleeing"  - Fugindo de perigo
	  "Waiting"  - Aguardando cooldown (boss de tempo)
]]

function StateMachine.new(initialState)
	local self = setmetatable({}, StateMachine)

	self.State       = initialState
	self.PrevState   = nil
	self.Transitions = {}
	self.Listeners   = { OnEnter = {}, OnLeave = {} }
	self.History     = {}

	return self
end

function StateMachine:AddTransition(fromState, toState, condition)
	self.Transitions[fromState] = self.Transitions[fromState] or {}
	table.insert(self.Transitions[fromState], {
		To        = toState,
		Condition = condition,
	})
end

-- Registra callback ao ENTRAR em um estado
function StateMachine:OnEnter(state, callback)
	self.Listeners.OnEnter[state] = callback
end

-- Registra callback ao SAIR de um estado
function StateMachine:OnLeave(state, callback)
	self.Listeners.OnLeave[state] = callback
end

-- Força transição direta sem checar condições (uso interno controlado)
function StateMachine:ForceTransition(toState, ...)
	local prevState = self.State

	if self.Listeners.OnLeave[prevState] then
		self.Listeners.OnLeave[prevState](...)
	end

	table.insert(self.History, prevState)
	if #self.History > 10 then table.remove(self.History, 1) end

	self.PrevState = prevState
	self.State     = toState

	if self.Listeners.OnEnter[toState] then
		self.Listeners.OnEnter[toState](...)
	end
end

-- Avalia as condições registradas e faz transição automaticamente
function StateMachine:Update(...)
	local rules = self.Transitions[self.State]
	if not rules then return end

	for _, rule in ipairs(rules) do
		if rule.Condition(...) then
			self:ForceTransition(rule.To, ...)
			return
		end
	end
end

function StateMachine:Get()
	return self.State
end

function StateMachine:Is(state)
	return self.State == state
end

function StateMachine:WasIn(state)
	return self.PrevState == state
end

return StateMachine
