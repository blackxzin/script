-- ============================================================
--  Elite Automation Framework :: Systems.KickTelemetry
--  Arquitetura de Diagnóstico e Monitoramento de Crash/Kick
-- ============================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
local Logger = require(Root.Core.Logger)

local FILE = "EliteAutomation_kicklog.txt"
local MAX_EVENTS = 50

local KickTelemetry = {}
KickTelemetry.__index = KickTelemetry

-- ─── [1] CONFIGURAÇÕES E CONSTANTES ──────────────────────────

local ERROR_CODES = { "267", "277", "279", "282", "284", "286" }

-- ─── [2] CONSTRUTOR ──────────────────────────────────────────

function KickTelemetry.new(notifications)
    local self = setmetatable({}, KickTelemetry)
    self.Notifications = notifications
    self._events = {}
    self._manager = nil
    self._running = false
    self._thread = nil
    self._dumped = false
    self._start_time = os.clock()

    return self
end

-- ─── [3] MÉTODOS DE LOG E TELEMETRIA ─────────────────────────

function KickTelemetry:BindManager(manager)
    self._manager = manager
end

local function stamp()
    return os.date("%H:%M:%S")
end

local function getExecutor()
    local name = "Unknown"
    local ok, res = pcall(function()
        if identifyexecutor then return identifyexecutor() end
        if getexecutorname then return getexecutorname() end
        return "Unknown"
    end)
    return ok and res or name
end

-- Escrita em arquivo (apenas se o executor permitir)
function KickTelemetry:_append(blob)
    if not writefile or not readfile then return end
    
    pcall(function()
        local content = ""
        local ok, existing = pcall(readfile, FILE)
        if ok then content = existing end
        
        writefile(FILE, content .. "\n" .. blob .. "\n")
    end)
end

-- Registro de evento de atividade
function KickTelemetry:Event(action, detail)
    local lp = Players.LocalPlayer
    local char = lp and lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    
    local eventData = {
        t = stamp(),
        action = tostring(action),
        detail = tostring(detail or ""),
        pos = root and string.format("%.1f, %.1f, %.1f", root.Position.X, root.Position.Y, root.Position.Z) or "N/A"
    }
    
    table.insert(self._events, eventData)
    if #self._events > MAX_EVENTS then table.remove(self._events, 1) end
end

-- ─── [4] DETECÇÃO DE CRASH E DISCONNECT ─────────────────────

local function isKickMessage(text)
    if not text or text == "" then return false end
    local t = text:lower()
    
    -- Verifica códigos de erro e palavras-chave
    for _, code in ipairs(ERROR_CODES) do
        if t:find(code, 1, true) then return true end
    end
    
    local keywords = { "disconnect", "kicked", "error code", "connection lost", "unexpected" }
    for _, kw in ipairs(keywords) do
        if t:find(kw, 1, true) then return true end
    end
    
    return false
end

-- Dump completo de informações para debug
function KickTelemetry:_dump(reason)
    if self._dumped then return end
    self._dumped = true
    
    local uptime = string.format("%.1fs", os.clock() - self._start_time)
    local activeTasks = "-"
    
    -- Tenta pegar tarefas ativas do Manager
    if self._manager and self._manager.Tasks then
        local tasks = {}
        for name, t in pairs(self._manager.Tasks) do
            if t.Enabled then table.insert(tasks, name) end
        end
        activeTasks = #tasks > 0 and table.concat(tasks, ",") or "None"
    end

    local logHeader = string.format("\n[!!! CRITICAL DUMP !!!]\nReason: %s\nUptime: %s\nActive Tasks: %s\n----------------------\n", 
        tostring(reason), uptime, activeTasks)
    
    local logBody = ""
    for _, e in ipairs(self._events) do
        logBody = logBody .. string.format("[%s] %s | %s | Pos: %s\n", e.t, e.action, e.detail, e.pos)
    end

    local finalBlob = logHeader .. "\n[Event History]\n" .. logBody
    
    Logger.Error(finalBlob)
    self:_append(finalBlob)
end

-- ─── [5] MONITORAMENTO (LOOP E WATCHERS) ────────────────────

function KickTelemetry:_watchSystem()
    -- 1. Monitoramento do LogService (Erros de Engine/Script)
    local connection = LogService.MessageOut:Connect(function(msg)
        if isKickMessage(msg) then
            self:_dump("LogService Detected: " .. msg)
        end
    end)
    self._logConnection = connection

    -- 2. Monitoramento do Player (Disconnect)
    local playerConn = Players.PlayerRemoving:Connect(function(p)
        if p == Players.LocalPlayer then
            self:_dump("PlayerRemoving Detected")
        end
    end)
    self._playerConn = playerConn

    -- 3. Monitoramento de UI (Prompt de Kick do Roblox)
    task.spawn(function()
        while self._running do
            local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
            if promptGui then
                for _, descendant in ipairs(promptGui:GetDescendants()) do
                    if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                        if isKickMessage(descendant.Text) then
                            self:_dump("RobloxPromptGui Detected: " .. descendant.Text)
                            break
                        end
                    end
                end
            end
            task.wait(2)
        end
    end)
end

-- ─── [6] API PÚBLICA ─────────────────────────────────────────

function KickTelemetry:Start()
    if self._running then return end
    self._running = true
    
    Logger.Info("KickTelemetry: Iniciando monitoramento...")
    
    -- Log de Injeção Inicial
    self:Event("inject", "Executor: " .. getExecutor())
    
    self:_watchSystem()
    
    -- Thread de Heartbeat (Monitoramento de HP/Status)
    self._thread = task.spawn(function()
        while self._running do
            local char = Players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hp = hum and math.floor((hum.Health / hum.MaxHealth) * 100) or -1
            
            self:Event("heartbeat", "HP: " .. tostring(hp))
            task.wait(5)
        end
    end)
    
    Logger.Success("KickTelemetry: Sistema Ativo.")
end

function KickTelemetry:Stop()
    self._running = false
    if self._thread then task.cancel(self._thread) end
    if self._logConnection then self._logConnection:Disconnect() end
    if self._playerConn then self._playerConn:Disconnect() end
    
    Logger.Info("KickTelemetry: Sistema Parado.")
end

function KickTelemetry:GetEvents()
    return self._events
end

return KickTelemetry
