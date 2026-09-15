-- ============================================================
--  Elite Automation Framework :: Movement.SmartFlight
--  Arquitetura de Voo Orgânico e Bypass de Física Avançado
-- ============================================================

local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local Players       = game:GetService("Players")

local SmartFlight = {}
SmartFlight.__index = SmartFlight

-- ─── [1] CONSTANTES DE SEGURANÇA ─────────────────────────────
local SEG_LEN        = 45    -- Tamanho do segmento (menor = mais seguro/detectável)
local SEG_TIME_MAX   = 6     -- Tempo máximo por segmento
local MIN_SPEED      = 25    -- Velocidade mínima para evitar travamentos
local MAX_SPEED      = 55    -- Velocidade máxima para evitar kick de velocidade

-- ─── [2] UTILITÁRIOS INTERNOS ────────────────────────────────

local function aliveChar(self)
    local char = self.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not char.Parent or not root or not root.Parent then return nil end
    if hum and hum.Health <= 0 then return nil end
    return root
end

local function lookCFrame(pos, dir)
    if dir and dir.Magnitude > 0.1 then
        return CFrame.new(pos, pos + dir.Unit)
    end
    return CFrame.new(pos)
end

-- ─── [3] CONSTRUTOR ──────────────────────────────────────────

function SmartFlight.new(character, settings)
    local self = setmetatable({}, SmartFlight)

    self.Character     = character
    self.Settings      = settings or {}
    self.HoverOffset   = self.Settings.HoverOffset   or 25
    self.SeaFloor      = self.Settings.SeaFloorOffset or 35
    self.SeaLevel      = self.Settings.SeaLevel       or 0
    self.SpeedBase     = self.Settings.DefaultSpeed   or 52
    self.JitterMin     = self.Settings.SpeedJitterMin or -6
    self.JitterMax     = self.Settings.SpeedJitterMax or  6
    self.TweenStyle    = self.Settings.TweenStyle     or Enum.EasingStyle.Sine
    self.TweenDir      = self.Settings.TweenDirection or Enum.EasingDirection.InOut

    self._flying       = false
    self._noclipConn   = nil
    self._currentTween = nil
    self._flightId     = 0 

    return self
end

-- ─── [4] MOTOR DE FÍSICA (Noclip & Anti-Gravity) ─────────────

function SmartFlight:_startNoclip()
    if self._noclipConn then return end

    local char = self.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hum then hum.PlatformStand = true end

    -- O Stepped é executado antes da física, ideal para desativar colisões
    self._noclipConn = RunService.Stepped:Connect(function()
        if not char or not char.Parent then return end

        -- Desativa colisões para evitar "fling" em objetos
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end

        -- Zera a velocidade para evitar acumular inércia (essencial para o Tween)
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

function SmartFlight:_stopNoclip()
    if self._noclipConn then
        self._noclipConn:Disconnect()
        self._noclipConn = nil
    end

    local hum = self.Character and self.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
end

-- ─── [5] SEGURANÇA DE ALTITUDE (Anti-Mar) ────────────────────

function SmartFlight:_safeY(targetPos)
    local groundY = self.SeaLevel
    
    -- Raycast para detectar o chão real e manter altitude segura
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { self.Character }
    
    local res = workspace:Raycast(
        Vector3.new(targetPos.X, 500, targetPos.Z),
        Vector3.new(0, -1000, 0),
        params
    )
    
    if res then groundY = res.Position.Y end

    local safeMin = self.SeaLevel + self.SeaFloor
    return math.max(groundY + self.HoverOffset, safeMin)
end

-- ─── [6] MOVIMENTO EM SEGMENTOS (Chunked Movement) ───────────

function SmartFlight:_tweenTo(targetCFrame, speed)
    local root = aliveChar(self)
    if not root then return false end

    local dist = (targetCFrame.Position - root.Position).Magnitude
    if dist < 0.5 then return true end

    -- Calcula duração baseada na velocidade para manter o movimento constante
    local duration = math.clamp(dist / speed, 0.5, SEG_TIME_MAX)

    local tween = TweenService:Create(root,
        TweenInfo.new(duration, self.TweenStyle, self.TweenDir),
        {CFrame = targetCFrame}
    )

    self._currentTween = tween
    tween:Play()
    
    -- Aguarda o término do tween ou timeout
    local completed = false
    local conn
    conn = tween.Completed:Connect(function() completed = true end)
    
    local start = os.clock()
    while not completed and (os.clock() - start) < (duration + 1) do
        if not root.Parent then break end
        task.wait()
    end
    
    if conn then conn:Disconnect() end
    return completed
end

-- ─── [7] API PÚBLICA (FlyTo, Stop, etc) ───────────────────────

function SmartFlight:FlyTo(targetPos)
    if typeof(targetPos) ~= "Vector3" then return false end

    -- Incrementa ID para cancelar voos anteriores (evita sobreposição de tweens)
    self._flightId += 1
    local myFlight = self._flightId

    local root = aliveChar(self)
    if not root then return false end

    self._flying = true
    self:_startNoclip()

    -- 1. Cálculo de Velocidade com Jitter
    local speed = math.clamp(self.SpeedBase + (math.random(-6, 6)), MIN_SPEED, MAX_SPEED)

    -- 2. Determinação de Altitude Segura
    local targetSafeY = self:_safeY(targetPos)
    local startPos = root.Position
    
    -- 3. Trajetória em 3 Fases: Subida -> Cruzeiro -> Descida
    local targetFinalCFrame = CFrame.new(targetPos.X, targetSafeY, targetPos.Z)
    
    -- Fase de Subida/Ajuste de Altitude
    local cruiseY = math.max(startPos.Y, targetSafeY)
    local cruisePos = Vector3.new(startPos.X, cruiseY, startPos.Z)

    -- Loop de Segmentos (Chunking)
    local currentPos = startPos
    while myFlight == self._flightId do
        local distToTarget = (targetPos - currentPos).Magnitude
        if distToTarget < 2 then break end

        -- Calcula o próximo waypoint para o chunk
        local direction = (targetPos - currentPos).Unit
        local nextStep = currentPos + (direction * math.min(distToTarget, SEG_LEN))
        local nextStepPos = Vector3.new(nextStep.X, targetSafeY, nextStep.Z)

        -- Executa o movimento segmentado
        local success = self:_tweenTo(CFrame.new(nextStepPos), speed)
        if not success then break end
        
        currentPos = nextStepPos
        task.wait(0.05) -- Micro-pausa para estabilização
    end

    self:_cleanup()
    return myFlight == self._flightId
end

function SmartFlight:FlyToTarget(targetPart, stopRadius)
    local stopRadius = stopRadius or 10
    local targetPos = targetPart.Position

    local root = aliveChar(self)
    if not root then return false end

    -- Voa até a posição alvo mantendo a margem de segurança
    self:FlyTo(targetPos)
    
    return true
end

-- ─── [8] LIMPEZA E UTILITÁRIOS ───────────────────────────────

function SmartFlight:_cleanup()
    self._flying = false
    self._noclipConn = nil
    
    local hum = self:_getHumanoid()
    if hum then
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end

    if self._currentTween then
        pcall(function() self._currentTween:Cancel() end)
        self._currentTween = nil
    end
end

function SmartFlight:Stop()
    self._flightId += 1
    self._flying = false
    self:_cleanup()
end

function SmartFlight:SetCharacter(newChar)
    self.Character = newChar
    self:Stop()
end

function SmartFlight:SetSpeed(speed)
    self.SpeedBase = math.clamp(speed, MIN_SPEED, MAX_SPEED)
end

return SmartFlight