-- ============================================================
--  Elite Automation Framework v2.0 - Official Loader
--  Grand Piece Online (GPO)
--  GitHub: https://github.com/blackxzin/script
--  Compatible with: Xeno, Delta, Codex, Fluxus, Hydrogen, Arceus X
-- ============================================================

local url = "https://raw.githubusercontent.com/blackxzin/script/main/main.lua"

local success, content = pcall(function()
	return game:HttpGet(url, true)
end)

if success and content and #content > 50 then
	local fn, compileErr = loadstring(content)
	if fn then
		fn()
	else
		warn("[EliteAutomation Loader] Erro ao compilar script:", compileErr)
	end
else
	warn("[EliteAutomation Loader] Falha ao baixar script principal via HttpGet:", content)
end
