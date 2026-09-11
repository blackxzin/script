#!/usr/bin/env python3
import os
import re

modules = [
    ("EliteAutomation.Core.Logger", "src/ReplicatedStorage/EliteAutomation/Core/Logger.lua"),
    ("EliteAutomation.Core.PriorityManager", "src/ReplicatedStorage/EliteAutomation/Core/PriorityManager.lua"),
    ("EliteAutomation.Core.StateMachine", "src/ReplicatedStorage/EliteAutomation/Core/StateMachine.lua"),
    ("EliteAutomation.Core.TaskManager", "src/ReplicatedStorage/EliteAutomation/Core/TaskManager.lua"),
    ("EliteAutomation.Config.Settings", "src/ReplicatedStorage/EliteAutomation/Config/Settings.lua"),
    ("EliteAutomation.UI.Notifications", "src/ReplicatedStorage/EliteAutomation/UI/Notifications.lua"),
    ("EliteAutomation.UI.Components", "src/ReplicatedStorage/EliteAutomation/UI/Components.lua"),
    ("EliteAutomation.UI.TabManager", "src/ReplicatedStorage/EliteAutomation/UI/TabManager.lua"),
    ("EliteAutomation.UI.MainUI", "src/ReplicatedStorage/EliteAutomation/UI/MainUI.lua"),
    ("EliteAutomation.Combat.TargetSelector", "src/ReplicatedStorage/EliteAutomation/Combat/TargetSelector.lua"),
    ("EliteAutomation.Combat.CombatController", "src/ReplicatedStorage/EliteAutomation/Combat/CombatController.lua"),
    ("EliteAutomation.Movement.SmartFlight", "src/ReplicatedStorage/EliteAutomation/Movement/SmartFlight.lua"),
    ("EliteAutomation.Systems.FruitDatabase", "src/ReplicatedStorage/EliteAutomation/Systems/FruitDatabase.lua"),
    ("EliteAutomation.Systems.FruitTracker", "src/ReplicatedStorage/EliteAutomation/Systems/FruitTracker.lua"),
    ("EliteAutomation.Systems.BossManager", "src/ReplicatedStorage/EliteAutomation/Systems/BossManager.lua"),
    ("EliteAutomation.Systems.ItemFarm", "src/ReplicatedStorage/EliteAutomation/Systems/ItemFarm.lua"),
    ("EliteAutomation.Systems.MerchantTracker", "src/ReplicatedStorage/EliteAutomation/Systems/MerchantTracker.lua"),
    ("EliteAutomation.Systems.LawFactoryFarm", "src/ReplicatedStorage/EliteAutomation/Systems/LawFactoryFarm.lua"),
]

bundle = []
bundle.append("""-- ============================================================
--  Elite Automation Framework v2.0 - Standalone Universal Bundle
--  Optimized for Grand Piece Online (GPO)
--  Compatible with: Xeno, Delta, Codex, Fluxus, Hydrogen, Arceus X
--  GitHub: https://github.com/blackxzin/script
--
--  Execute with:
--  loadstring(game:HttpGet("https://raw.githubusercontent.com/blackxzin/script/main/main.lua"))()
-- ============================================================

-- Previne execucao duplicada
if getgenv and getgenv()._EliteAutomationLoaded then
	warn("[EliteAutomation] Script ja esta em execucao!")
	return
end
if getgenv then getgenv()._EliteAutomationLoaded = true end

local executor = "Unknown"
if identifyexecutor then executor = identifyexecutor()
elseif getexecutorname then executor = getexecutorname()
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  [EliteAutomation v2.0] GPO Hub")
print("  Executor detectado: " .. tostring(executor))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

local __modules = {}
local __cache = {}

local function __register(name, fn)
	__modules[name] = fn
end

-- Require customizado que suporta tanto strings quanto referencias de Instancias
local function customRequire(target)
	local name = nil
	if type(target) == "string" then
		name = target
	elseif typeof and typeof(target) == "Instance" then
		local path = {}
		local cur = target
		while cur and cur ~= game do
			table.insert(path, 1, cur.Name)
			cur = cur.Parent
		end
		name = table.concat(path, ".")
		local eaIdx = string.find(name, "EliteAutomation")
		if eaIdx then
			name = string.sub(name, eaIdx)
		end
	end

	if name and __modules[name] then
		if __cache[name] == nil then
			__cache[name] = __modules[name](customRequire)
		end
		return __cache[name]
	end

	return getfenv(0).require(target)
end
""")

for mod_name, file_path in modules:
    with open(file_path, "r", encoding="utf-8") as f:
        code = f.read()
    
    # Replace internal requires inside modules:
    # local Root = ReplicatedStorage:WaitForChild("EliteAutomation")
    # require(Root.Core.Logger) -> customRequire("EliteAutomation.Core.Logger")
    code_mod = code
    code_mod = re.sub(r'local\s+Root\s*=\s*ReplicatedStorage:WaitForChild\("EliteAutomation"\)', '-- [Bundle Mode] Root redirecionado', code_mod)
    code_mod = re.sub(r'require\(Root\.Core\.(\w+)\)', r'customRequire("EliteAutomation.Core.\1")', code_mod)
    code_mod = re.sub(r'require\(Root\.Config\.(\w+)\)', r'customRequire("EliteAutomation.Config.\1")', code_mod)
    code_mod = re.sub(r'require\(Root\.UI\.(\w+)\)', r'customRequire("EliteAutomation.UI.\1")', code_mod)
    code_mod = re.sub(r'require\(Root\.Systems\.(\w+)\)', r'customRequire("EliteAutomation.Systems.\1")', code_mod)
    code_mod = re.sub(r'require\(Root\.Combat\.(\w+)\)', r'customRequire("EliteAutomation.Combat.\1")', code_mod)
    code_mod = re.sub(r'require\(Root\.Movement\.(\w+)\)', r'customRequire("EliteAutomation.Movement.\1")', code_mod)

    bundle.append(f"""-- ────────────────────────────────────────────────────────────
-- Module: {mod_name}
-- ────────────────────────────────────────────────────────────
__register("{mod_name}", function(customRequire)
{code_mod}
end)
""")

with open("src/StarterPlayer/StarterPlayerScripts/EliteAutomation.client.lua", "r", encoding="utf-8") as f:
    entrypoint = f.read()

entrypoint_clean = entrypoint
entrypoint_clean = re.sub(r'local\s+Root\s*=\s*ReplicatedStorage:WaitForChild\("EliteAutomation"\)', '-- [Bundle Mode] Root redirecionado', entrypoint_clean)
entrypoint_clean = re.sub(r'require\(Root\.Core\.(\w+)\)', r'customRequire("EliteAutomation.Core.\1")', entrypoint_clean)
entrypoint_clean = re.sub(r'require\(Root\.Config\.(\w+)\)', r'customRequire("EliteAutomation.Config.\1")', entrypoint_clean)
entrypoint_clean = re.sub(r'require\(Root\.UI\.(\w+)\)', r'customRequire("EliteAutomation.UI.\1")', entrypoint_clean)
entrypoint_clean = re.sub(r'require\(Root\.Systems\.(\w+)\)', r'customRequire("EliteAutomation.Systems.\1")', entrypoint_clean)
entrypoint_clean = re.sub(r'require\(Root\.Combat\.(\w+)\)', r'customRequire("EliteAutomation.Combat.\1")', entrypoint_clean)
entrypoint_clean = re.sub(r'require\(Root\.Movement\.(\w+)\)', r'customRequire("EliteAutomation.Movement.\1")', entrypoint_clean)

bundle.append("""-- ────────────────────────────────────────────────────────────
-- Entrypoint: EliteAutomation.client.lua
-- ────────────────────────────────────────────────────────────
do
""" + entrypoint_clean + """
end
""")

with open("main.lua", "w", encoding="utf-8") as f:
    f.write("\n".join(bundle))

print("Successfully generated main.lua! Size:", os.path.getsize("main.lua"), "bytes")
