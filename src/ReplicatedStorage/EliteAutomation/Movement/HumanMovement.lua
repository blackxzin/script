-- ============================================================
--  Elite Automation Framework :: Movement.HumanMovement
--  Movimento humanizado com Perlin noise e delays naturais.
--  Anti-detecção avançada para GPO.
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local HumanMovement = {}

-- ─── Perlin noise 1D simplificado ────────────────────────────
local function perlin1D(x, seed)
	seed = seed or 0
	x = x + seed * 1000
	local xi = math.floor(x)
	local xf = x - xi

	local fade = xf * xf * (3 - 2 * xf)

	local a = math.sin(xi * 12.9898 + 78.233) * 43758.5453
	local b = math.sin((xi + 1) * 12.9898 + 78.233) * 43758.5453
	a = a - math.floor(a)
	b = b - math.floor(b)

	return a + fade * (b - a)
end

-- ─── Gera delay humanizado (baseado em distribuição normal) ──
function HumanMovement.HumanDelay(base, variance)
	base = base or 0.15
	variance = variance or 0.05

	-- Box-Muller transform para distribuição normal
	local u1 = math.random()
	local u2 = math.random()
	local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)

	local delay = base + z * variance
	return math.max(0.05, math.min(delay, base + variance * 3))
end

-- ─── Velocity com Perlin noise (movimento orgânico) ──────────
function HumanMovement.PerlinVelocity(baseSpeed, time, seed)
	baseSpeed = baseSpeed or 50
	time = time or os.clock()
	seed = seed or 42

	local noise = perlin1D(time * 0.5, seed)
	local variance = noise * 8  -- ±8 studs/s

	return math.max(20, baseSpeed + variance)
end

-- ─── Path com micro-desvios (evita linha reta perfeita) ──────
function HumanMovement.OrganicPath(start, finish, segments)
	segments = segments or 5
	local path = { start }

	local direction = (finish - start).Unit
	local distance = (finish - start).Magnitude
	local step = distance / segments

	for i = 1, segments - 1 do
		local progress = i / segments
		local basePoint = start:Lerp(finish, progress)

		-- Adiciona desvio perpendicular pequeno
		local perpendicular = Vector3.new(-direction.Z, 0, direction.X)
		local offset = perpendicular * (perlin1D(progress * 10, i) - 0.5) * 4

		table.insert(path, basePoint + offset)
	end

	table.insert(path, finish)
	return path
end

-- ─── Delay entre ações (input timing humanizado) ─────────────
function HumanMovement.InputDelay()
	-- Humanos têm 150-300ms de reação típica
	return HumanMovement.HumanDelay(0.22, 0.08)
end

-- ─── Jitter de posição (anti-bot detection) ──────────────────
function HumanMovement.AddJitter(position, radius)
	radius = radius or 0.5
	local rx = (math.random() - 0.5) * radius * 2
	local ry = (math.random() - 0.5) * radius * 2
	local rz = (math.random() - 0.5) * radius * 2
	return position + Vector3.new(rx, ry, rz)
end

-- ─── Padrão de clique humanizado (não instantâneo) ───────────
function HumanMovement.HumanClick(callback)
	-- Press down
	task.spawn(callback, true)

	-- Hold time variável (50-150ms)
	task.wait(HumanMovement.HumanDelay(0.08, 0.04))

	-- Release
	task.spawn(callback, false)
end

return HumanMovement
