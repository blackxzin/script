-- ============================================================
--  Elite Automation Framework :: Movement.HumanMovement
--  Arquitetura de Movimento Orgânico e Anti-Detecção Avançada
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local HumanMovement = {}

-- ─── [1] MATEMÁTICA DE DISTRIBUIÇÃO (Gaussian/Normal) ─────────
-- Simula o erro humano usando a Transformação de Box-Muller
local function getGaussianRandom(mean, stdDev)
    local u1 = math.random()
    local u2 = math.random()
    local z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)
    return z0 * stdDev + mean
end

-- ─── [2] PERLIN NOISE (Movimento Fluido) ─────────────────────
-- Gera uma variação suave e contínua, evitando "saltos" de velocidade
local function getPerlinNoise(t, seed, frequency, amplitude)
    seed = seed or 42
    local noise = math.noise(t * frequency, seed, t * frequency * 0.5)
    return noise * amplitude
end

-- ─── [3] DELAY HUMANIZADO ────────────────────────────────────
-- Implementa tempos de reação que variam de forma natural
function HumanMovement.HumanDelay(base, variance)
    base = base or 0.15
    variance = variance or 0.05
    
    -- O delay não é apenas aleatório, ele tem uma média (mean)
    local delay = getGaussianRandom(base, variance)
    return math.max(0.05, delay)
end

-- ─── [4] VELOCIDADE ORGÂNICA (Perlin Velocity) ───────────────
-- Em vez de uma velocidade constante, usamos uma curva de aceleração
function HumanMovement.PerlinVelocity(baseSpeed, time, seed)
    local frequency = 0.5
    local amplitude = baseSpeed * 0.15 -- 15% de variação de velocidade
    
    local noise = getPerlinNoise(time, seed or 1, frequency, amplitude)
    return math.max(baseSpeed * 0.8, baseSpeed + noise)
end

-- ─── [5] TRAJETÓRIA ORGÂNICA (Anti-Line Path) ────────────────
-- Cria um caminho com desvios laterais para evitar o "vôo em linha reta"
function HumanMovement.OrganicPath(startPos, finishPos, segments)
    segments = segments or 6
    local path = { startPos }
    local direction = (finishPos - startPos).Unit
    local distance = (finishPos - startPos).Magnitude
    
    -- Vetor perpendicular para criar o desvio lateral
    local upVector = Vector3.new(0, 1, 0)
    local sideVector = direction:Cross(upVector).Unit
    if sideVector.Magnitude < 0.1 then sideVector = Vector3.new(1, 0, 0) end

    for i = 1, segments - 1 do
        local progress = i / segments
        local basePoint = startPos:Lerp(finishPos, progress)
        
        -- Adiciona um desvio lateral usando Perlin Noise para suavidade
        local deviation = getPerlinNoise(progress * 5, i, 0.5, 3) 
        local lateralOffset = sideVector * deviation
        
        -- Adiciona um pequeno desvio de altura (Y) para não ser perfeitamente plano
        local verticalOffset = math.sin(progress * math.pi) * 2 
        
        table.insert(path, basePoint + lateralOffset + Vector3.new(0, verticalOffset, 0))
    end

    table.insert(path, finishPos)
    return path
end

-- ─── [6] INPUT TIMING (Reação Humana) ────────────────────────
-- Simula o tempo de clique e pressionamento de tecla
function HumanMovement.InputDelay()
    -- Reação típica de 180ms a 320ms
    return getGaussianRandom(0.25, 0.05)
end

-- ─── [7] JITTER DE POSIÇÃO (Anti-Bot Detection) ───────────────
-- Adiciona micro-tremores na posição para evitar padrões estáticos
function HumanMovement.AddJitter(position, radius)
    radius = radius or 0.5
    local jitterX = getGaussianRandom(0, radius)
    local jitterY = getGaussianRandom(0, radius)
    local jitterZ = getGaussianRandom(0, radius)
    
    return position + Vector3.new(jitterX, jitterY, jitterZ)
end

-- ─── [8] CLIQUE HUMANIZADO (Hold Time) ───────────────────────
-- Simula o tempo que um humano mantém o botão pressionado
function HumanMovement.HumanClick(callback)
    -- Simula o pressionar (Down)
    task.spawn(function()
        callback(true)
    end)

    -- Delay de pressão variável (Hold time)
    local holdTime = getGaussianRandom(0.1, 0.04)
    task.wait(holdTime)

    -- Simula o soltar (Up)
    task.spawn(function()
        callback(false)
    end)
end

-- ─── [9] INTERPOLAÇÃO DE CURVA (Easing Helper) ───────────────
-- Ajuda o SmartFlight a não dar saltos bruscos de velocidade
function HumanMovement.GetSmoothStep(t)
    -- Smoothstep formula: 3t^2 - 2t^3
    return t * t * (3 - 2 * t)
end

return HumanMovement