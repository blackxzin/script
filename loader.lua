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
    Info = function(msg) print("\27[36m[EliteLoader]\27[0m " .. tostring(msg)) end,
    Warn = function(msg) print("\27[33m[EliteLoader]\27[0m " .. tostring(msg)) end,
    Error = function(msg) print("\27[31m[EliteLoader]\27[0m " .. tostring(msg)) end
}

-- 1. Verificação de Compatibilidade do Executor
local function checkEnvironment()
    local hasHttpGet = false
    local httpGetOk, httpGet = pcall(function()
        return game and game.HttpGet
    end)
    if httpGetOk and type(httpGet) == "function" then
        hasHttpGet = true
    end

    local requestFn = nil
    local requestSources = {
        function() return syn and syn.request end,
        function() return http and http.request end,
        function() return request end,
        function() return http_request end,
        function() return fluxus_request end,
    }
    for _, source in ipairs(requestSources) do
        local ok, candidate = pcall(source)
        if ok and type(candidate) == "function" then
            requestFn = candidate
            break
        end
    end

    local loadFn = nil
    if type(loadstring) == "function" then
        loadFn = loadstring
    elseif type(load) == "function" then
        loadFn = load
    end

    local identity = "Unknown"
    local identityOk, identityResult = pcall(function()
        if type(identifyexecutor) == "function" then return identifyexecutor() end
        if type(getexecutorname) == "function" then return getexecutorname() end
        return "Unknown"
    end)
    if identityOk and identityResult then identity = tostring(identityResult) end

    local env = {
        HttpGet = hasHttpGet,
        Request = requestFn,
        Loadstring = loadFn,
        Identity = identity,
    }
    
    if not env.HttpGet and not env.Request then
        LoaderLogger.Error("Ambiente incompatível! Executor não detectado.")
        return nil
    end
    
    return env
end

-- 2. Motor de Requisição HTTP (Multi-Layer Bypass)
local function performRequest(env)
    local url = CONFIG.BASE_URL
    if CONFIG.CACHE_BYPASS then
        url = url .. "?v=" .. os.time()
    end
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
                Timeout = CONFIG.TIMEOUT,
                Headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
            })
        end)
        
        if ok and res then
            if type(res) == "table" and res.Success == false then return nil end
            if type(res) == "table" and type(res.StatusCode) == "number"
                and (res.StatusCode < 200 or res.StatusCode >= 300) then
                return nil
            end
            local body = type(res) == "table" and (res.Body or res.body or res.Content) or res
            if type(body) == "string" and #body >= CONFIG.MIN_CONTENT_SIZE then
                return body
            end
        end
    end
    
    return nil
end

local function isValidBundle(content)
    if type(content) ~= "string" or #content < CONFIG.MIN_CONTENT_SIZE then
        return false
    end

    return content:find("EliteAutomation v2.1", 1, true) ~= nil
        and content:find("__register", 1, true) ~= nil
        and content:find("Entrypoint: EliteAutomation.client.lua", 1, true) ~= nil
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
    
    if not content or not isValidBundle(content) then
        LoaderLogger.Error("Bundle inválido ou download incompleto. Execução cancelada.")
        return
    end

    -- Passo 3: Compilação e Sanitização
    if not env.Loadstring then
        LoaderLogger.Error("Seu executor não suporta 'loadstring'.")
        return
    end

    local compile = env.Loadstring
    local compileOk, compiledOrErr = pcall(function()
        return compile(content)
    end)

    if not compileOk or type(compiledOrErr) ~= "function" then
        LoaderLogger.Error("Erro de compilação no código fonte.")
        print("\n[Debug Error]: " .. tostring(compiledOrErr))
        return
    end

    -- Passo 4: Execução Segura
    LoaderLogger.Info("Framework pronto. Executando...")
    
    local success, runErr = pcall(function()
        compiledOrErr()
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
