-- ============================================================
--  Elite Automation Framework - Loader robusto
--  Grand Piece Online (GPO)
--  Uso: loadstring(game:HttpGet("https://raw.githubusercontent.com/blackxzin/script/main/loader.lua"))()
-- ============================================================

local BASE = "https://raw.githubusercontent.com/blackxzin/script/main/main.lua"
local URL = BASE .. "?t=" .. tostring(os.time())

local function fetch(url)
	local httpGet = (game and game.HttpGet) or HttpGet
	-- 1) metodo padrao do executor/jogo
	if game and game.HttpGet then
		local ok, res = pcall(function()
			return game:HttpGet(url, true)
		end)
		if ok and type(res) == "string" and #res > 50 then
			return res
		end
	end
	-- 2) APIs de request de executores (Xeno, Delta, Codex, Fluxus, Hydrogen, Arceus X)
	local req = (syn and syn.request) or (http and http.request) or request or http_request or fluxus_request
	if req then
		local ok, res = pcall(function()
			return req({ Url = url, Method = "GET" })
		end)
		if ok and res then
			local body = type(res) == "table" and (res.Body or res.body or res.Content) or res
			if type(body) == "string" and #body > 50 then
				return body
			end
		end
	end
	return nil, "sem resposta util"
end

local content, ferr = fetch(URL)
if not content then
	warn("[EliteAutomation Loader] Falha ao baixar main.lua: " .. tostring(ferr))
	warn("[EliteAutomation Loader] Confira HttpEnabled do jogo / VPN / branch main.")
	return
end

local compile = loadstring or load
local fn, cerr = compile(content)
if not fn then
	warn("[EliteAutomation Loader] Erro ao compilar main.lua: " .. tostring(cerr))
	return
end

local ok, rerr = pcall(fn)
if not ok then
	warn("[EliteAutomation Loader] Erro ao executar main.lua: " .. tostring(rerr))
end
