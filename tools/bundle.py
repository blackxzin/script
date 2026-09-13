#!/usr/bin/env python3
"""
bundle.py — Gera main.lua (bundle do executor) a partir de src/.

Uso: python3 tools/bundle.py
NÃO edite main.lua direto: edite src/ e rode o bundler.

Converte requires estilo Rojo (require(Root.X.Y)) para o
carregador do bundle (customRequire("EliteAutomation.X.Y")).
"""

import re
from pathlib import Path

ROOT = Path(__file__).parent.parent
SRC_DIR = ROOT / "src" / "ReplicatedStorage" / "EliteAutomation"
CLIENT = ROOT / "src" / "StarterPlayer" / "StarterPlayerScripts" / "EliteAutomation.client.lua"
OUT_FILE = ROOT / "main.lua"

MODULES = [
    # Core
    "Core/Logger.lua",
    "Core/TaskManager.lua",
    "Core/StateMachine.lua",
    "Core/PriorityManager.lua",
    "Core/PerformanceManager.lua",

    # Config
    "Config/Settings.lua",

    # UI
    "UI/Theme.lua",
    "UI/MainUI.lua",
    "UI/TabManager.lua",
    "UI/Components.lua",
    "UI/Notifications.lua",

    # Systems
    "Systems/FruitDatabase.lua",
    "Systems/FruitTracker.lua",
    "Systems/BossManager.lua",
    "Systems/ItemFarm.lua",
    "Systems/MerchantTracker.lua",
    "Systems/LawFactoryFarm.lua",
    "Systems/FarmRotation.lua",
    "Systems/QuestManager.lua",
    "Systems/TeleportManager.lua",
    "Systems/AutoStats.lua",
    "Systems/ESP.lua",
    "Systems/AutoHeal.lua",
    "Systems/AntiAFK.lua",
    "Systems/AdaptiveBrain.lua",
    "Systems/KickTelemetry.lua",

    # Combat
    "Combat/TargetSelector.lua",
    "Combat/CombatController.lua",
    "Combat/AdvancedCombat.lua",
    "Combat/ComboSystem.lua",

    # Movement
    "Movement/HumanMovement.lua",
    "Movement/ServerSafeMovement.lua",
    "Movement/SmartFlight.lua",
]

HEADER = """-- ============================================================
--  Elite Automation Framework v2.1 - Standalone Universal Bundle
--  Optimized for Grand Piece Online (GPO)
--  Compatible with: Xeno, Delta, Codex, Fluxus, Hydrogen, Arceus X
--  GitHub: https://github.com/blackxzin/script
--
--  Execute with:
--  loadstring(game:HttpGet("https://raw.githubusercontent.com/blackxzin/script/main/loader.lua"))()
--
--  GERADO por tools/bundle.py — nao edite direto, edite src/
--  e rode: python3 tools/bundle.py
-- ============================================================
"""

GUARD = """
-- Previne execucao duplicada
if getgenv and getgenv()._EliteAutomationLoaded then
\twarn("[EliteAutomation] Script ja esta em execucao!")
\treturn
end
if getgenv then getgenv()._EliteAutomationLoaded = true end

-- NOTA: sem hook em game.HttpGet. Hook global quebra chamadas internas
-- do Roblox/GPO (kick/disconnect) e e detectavel pelo anticheat.

local executor = "Unknown"
if identifyexecutor then executor = identifyexecutor()
elseif getexecutorname then executor = getexecutorname()
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  [EliteAutomation v2.1] GPO Hub")
print("  Executor detectado: " .. tostring(executor))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

local __modules = {}
local __cache = {}

local function __register(name, fn)
\t__modules[name] = fn
end

-- Require customizado que suporta tanto strings quanto referencias de Instancias
local function customRequire(target)
\tlocal name = nil
\tif type(target) == "string" then
\t\tname = target
\telseif typeof and typeof(target) == "Instance" then
\t\tlocal path = {}
\t\tlocal cur = target
\t\twhile cur and cur ~= game do
\t\t\ttable.insert(path, 1, cur.Name)
\t\t\tcur = cur.Parent
\t\tend
\t\tname = table.concat(path, ".")
\t\tlocal eaIdx = string.find(name, "EliteAutomation")
\t\tif eaIdx then
\t\t\tname = string.sub(name, eaIdx)
\t\tend
\tend

\tif name and __modules[name] then
\t\tif __cache[name] == nil then
\t\t\t__cache[name] = __modules[name](customRequire)
\t\tend
\t\treturn __cache[name]
\tend

\treturn getfenv(0).require(target)
end
"""


def transform(content: str, fname: str) -> str:
    """Adapta módulo Rojo para o bundle: Root -> customRequire."""
    content = re.sub(
        r"^[ \t]*local Root\s*=.*WaitForChild.*$",
        "-- [Bundle] Root redirecionado",
        content,
        flags=re.M,
    )
    content = re.sub(
        r"require\(Root\.([A-Za-z0-9_\.]+)\)",
        r'customRequire("EliteAutomation.\1")',
        content,
    )
    leftovers = re.findall(
        r"require\((?:Root|script)[^\)]*\)|WaitForChild\(\"EliteAutomation\"\)",
        content,
    )
    for lo in leftovers:
        print(f"⚠ {fname}: require nao convertido: {lo}")
    return content


def bundle() -> None:
    """Gera bundle unificado em main.lua"""
    parts = [HEADER, GUARD]

    for mod_path in MODULES:
        full_path = SRC_DIR / mod_path
        if not full_path.exists():
            print(f"⚠ AVISO: {mod_path} não encontrado, pulando")
            continue
        content = full_path.read_text(encoding="utf-8")
        mod_name = "EliteAutomation." + mod_path[:-4].replace("/", ".")
        parts.append(
            "\n-- ────────────────────────────────────────────────────────────\n"
            f"-- Module: {mod_name}\n"
            "-- ────────────────────────────────────────────────────────────\n"
            f'__register("{mod_name}", function(customRequire)\n'
            + transform(content, mod_path)
            + "\nend)\n"
        )

    if not CLIENT.exists():
        print("⚠ AVISO: client entrypoint não encontrado")
    else:
        parts.append(
            "\n-- ────────────────────────────────────────────────────────────\n"
            "-- Entrypoint: EliteAutomation.client.lua\n"
            "-- ────────────────────────────────────────────────────────────\n"
            "do\n"
            + transform(CLIENT.read_text(encoding="utf-8"), "client")
            + "\nend\n"
        )

    OUT_FILE.write_text("\n".join(parts), encoding="utf-8")
    size_kb = OUT_FILE.stat().st_size / 1024
    print(f"✅ Bundle gerado: {OUT_FILE}")
    print(f"📦 Tamanho: {size_kb:.1f} KB")


if __name__ == "__main__":
    bundle()
