-- ============================================================
--  Elite Automation Framework :: Combat.TargetSelector
--  Seleciona o melhor alvo dentro de um raio, com filtros e
--  sistema de blacklist para NPCs amigáveis.
-- ============================================================

local Players = game:GetService("Players")

local TargetSelector = {}
TargetSelector.__index = TargetSelector

function TargetSelector.new(settings)
	local self = setmetatable({}, TargetSelector)

	self.AttackRange     = (settings and settings.AttackRange)    or 18
	self.PreferLowHealth = (settings and settings.PreferLowHealth) or true
	self.Blacklist       = {}

	-- Popula blacklist a partir da config
	if settings and settings.BlacklistNPCs then
		for _, name in ipairs(settings.BlacklistNPCs) do
			self.Blacklist[name] = true
		end
	end

	return self
end

-- Verifica se um modelo é um NPC/humanoid válido para atacar
function TargetSelector:_isValidEnemy(model, playerChar)
	if not model or not model.Parent then return false end
	if model == playerChar then return false end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	if humanoid.Health <= 0 then return false end

	-- Não atacar outros players
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character == model then return false end
	end

	-- Checa blacklist por nome do modelo
	if self.Blacklist[model.Name] then return false end

	return true
end

-- Retorna o HumanoidRootPart do modelo ou nil
local function getRoot(model)
	return model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildOfClass("BasePart")
end

--[[
	Scanneia workspace:GetDescendants() (ou um folder específico)
	e retorna o melhor alvo (mais próximo ou menor HP).

	originPos : Vector3 do personagem local
	filter    : função opcional(model) -> bool para filtros extras
]]
function TargetSelector:Select(originPos, filter)
	local playerChar = Players.LocalPlayer.Character

	local bestModel  = nil
	local bestScore  = math.huge  -- menor score = melhor

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and self:_isValidEnemy(obj, playerChar) then
			if (not filter) or filter(obj) then
				local root = getRoot(obj)
				if root then
					local dist = (root.Position - originPos).Magnitude
					if dist <= self.AttackRange then
						local hum    = obj:FindFirstChildOfClass("Humanoid")
						local hpRatio = hum and (hum.Health / math.max(hum.MaxHealth, 1)) or 1

						-- Score: distância ponderada com HP (prefere feridos)
						local score = self.PreferLowHealth
							and (dist * 0.6 + hpRatio * 100 * 0.4)
							or  dist

						if score < bestScore then
							bestScore = score
							bestModel = obj
						end
					end
				end
			end
		end
	end

	return bestModel
end

-- Retorna a humanoid do melhor alvo, se existir
function TargetSelector:SelectHumanoid(originPos, filter)
	local model = self:Select(originPos, filter)
	if model then
		return model:FindFirstChildOfClass("Humanoid"), model
	end
	return nil, nil
end

function TargetSelector:SetAttackRange(range)
	self.AttackRange = range
end

function TargetSelector:AddToBlacklist(name)
	self.Blacklist[name] = true
end

function TargetSelector:RemoveFromBlacklist(name)
	self.Blacklist[name] = nil
end

return TargetSelector
