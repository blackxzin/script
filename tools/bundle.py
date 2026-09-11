#!/usr/bin/env python3
"""
bundle.py — Bundler modular para Elite Automation Framework

Concatena módulos Lua em um único arquivo executável.
Uso: python3 tools/bundle.py
"""

import os
from pathlib import Path

ROOT = Path(__file__).parent.parent
SRC_DIR = ROOT / "src" / "ReplicatedStorage" / "EliteAutomation"
OUT_FILE = ROOT / "dist" / "elite_automation_bundle.lua"

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
    "UI/MainUI.lua",
    "UI/TabManager.lua",
    "UI/Components.lua",
    "UI/Notifications.lua",
    "UI/Theme.lua",

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

    # Combat
    "Combat/CombatController.lua",
    "Combat/TargetSelector.lua",
    "Combat/AdvancedCombat.lua",
    "Combat/ComboSystem.lua",

    # Movement
    "Movement/SmartFlight.lua",
    "Movement/ServerSafeMovement.lua",
    "Movement/HumanMovement.lua",
]

HEADER = """-- ============================================================
--  Elite Automation Framework v2.1 — BUNDLE
--  Grand Piece Online (GPO)
--
--  32 módulos compilados
--  Gerado automaticamente por bundle.py
-- ============================================================

"""

def bundle():
    """Gera bundle unificado"""
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    with open(OUT_FILE, "w", encoding="utf-8") as out:
        out.write(HEADER)

        for mod_path in MODULES:
            full_path = SRC_DIR / mod_path

            if not full_path.exists():
                print(f"⚠ AVISO: {mod_path} não encontrado")
                continue

            with open(full_path, "r", encoding="utf-8") as f:
                content = f.read()

            out.write(f"\n-- ═══════════════════════════════════════════════════════════\n")
            out.write(f"--  MODULE: {mod_path}\n")
            out.write(f"-- ═══════════════════════════════════════════════════════════\n\n")
            out.write(content)
            out.write("\n")

        out.write("\n-- ════════════════════════════════════════════════════════════\n")
        out.write("--  FIM DO BUNDLE\n")
        out.write("-- ════════════════════════════════════════════════════════════\n")

    size_kb = OUT_FILE.stat().st_size / 1024
    print(f"✅ Bundle gerado: {OUT_FILE}")
    print(f"📦 Tamanho: {size_kb:.1f} KB")
    print(f"📂 Módulos: {len(MODULES)}")

if __name__ == "__main__":
    bundle()
