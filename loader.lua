-- ============================================================
--  Elite Automation Framework - Advanced Bootstrap Loader
--  Versão: 2.1 (Production Ready)
--  Alvo: Grand Piece Online (GPO)
-- ============================================================

-- Configurações de Inicialização
local CONFIG = {
    BASE_URL = "https://raw.githubusercontent.com/blackxzin/script/main/main.lua",
    CACHE_BYPASS = true, -- Força novo download para evitar cache antigo
    MIN_CONTENT_SIZE = 100, -- Validação de integridade do download
    TIMEOUT = 15 -- Tempo máximo de espera por requisição
}

-- Namespace para logs internos do loader
local LoaderLogger = {
    Info = function(msg) print("\27[36m[EliteLoader] %s\27[0m", msg) end,
    Warn = function(msg) print("\27[33m[EliteLoader] %s\27[0m", msg) end,
    Error = function(msg) print("\27[31m[EliteLoader] %s\27[0m", msg) end
}

-- 1. Verificação de Compatibilidade do Executor
local function checkEnvironment()
    local env = {
        HttpGet = game and game.HttpGet and true or false,
        Request = (syn and syn.request) or (http and http.request) or request or http_request or fluxus_request or nil,
        Loadstring = loadstring or load or nil,
        Identity = (identifyexecutor and identifyexecutor()) or "Unknown"
    }
    
    if not env.HttpGet and not env.Request then
        LoaderLogger.Error("Ambiente incompatível! Executor não detectado.")
        return nil
    end
    
    return env
end

-- 2. Motor de Requisição HTTP (Multi-Layer Bypass)
local function performRequest(env)
    local url = CONFIG.BASE_URL .. "?v=" .. os.time() -- Cache busting
    local method = "GET"
    
    -- Camada A: Método Nativo do Jogo (Mais rápido/estável)
    if env.HttpGet then
        local ok, res = pcall(function()
            return game:HttpGet(url, true)
        end)
        if ok and type(res) == "string" and #res >= CONFIG.MIN_CONTENT_SIZE then
            return res
        end
    end

    -- Camada B: API do Executor (Fallback para bypass de proteções)
    if env.Request then
        local ok, res = pcall(function()
            return env.Request({
                Url = url,
                Method = method,
                Headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
            })
        end)
        
        if ok and res then
            local body = type(res) == "table" and (res.Body or res.body or res.Content) or res
            if type(body) == "string" and #body >= CONFIG.MIN_CONTENT_SIZE then
                return body
            end
        end
    end
    
    return nil
end

-- 3. Processo de Boot (Main Logic)
local function bootstrap()
    LoaderLogger.Info("Iniciando Bootstrap do Framework...")
    
    -- Passo 1: Check Env
    local env = checkEnvironment()
    if not env then return end
    LoaderLogger.Info("Executor Detectado: " .. env.Identity)

    -- Passo 2: Fetch Content
    LoaderLogger.Info("Baixando módulos de produção...")
    local content = performRequest(env)
    
    if not content then
        LoaderLogger.Error("Falha crítica no download. Verifique sua conexão ou VPN.")
        return
    end

    -- Passo 3: Compilação e Sanitização
    if not env.Loadstring then
        LoaderLogger.Error("Seu executor não suporta 'loadstring'.")
        return
    end

    local compile = env.Loadstring
    local fn, err = pcall(function()
        return compile(content)
    end)

    if not fn then
        LoaderLogger.Error("Erro de compilação no código fonte.")
        print("\n[Debug Error]: " .. tostring(err))
        return
    end

    -- Passo 4: Execução Segura
    LoaderLogger.Info("Framework pronto. Executando...")
    
    local success, runErr = pcall(function()
        fn()
    end)

    if not success then
        LoaderLogger.Error("Erro durante a execução do framework:")
        print("\n[Runtime Error]: " .. tostring(runErr))
    else
        LoaderLogger.Info("Boot concluído com sucesso!")
    end
end

-- 🚀 Iniciar Processo
task.spawn(function()
    local startTime = os.clock()
    bootstrap()
    local duration = string.format("%.2f", os.clock() - startTime)
    LoaderLogger.Info("Tempo de Boot: " .. duration .. "s")
end)