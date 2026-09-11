# 🚀 Elite Automation v2.1 - Manual de Deploy

## Status: Pronto para Push

Todos os 18 arquivos (13 novos + 5 modificados) estão prontos para commit.

## Comandos de Deploy

### Opção A - Script Automático
```bash
cd /home/polar/script
bash deploy_v2.1.sh
```

### Opção B - Comandos Manuais
```bash
cd /home/polar/script

# 1. Stage
git add -A

# 2. Commit
git commit -m "feat: v2.1 - 13 novos módulos, anti-detecção multicamadas

- Core: PerformanceManager, Theme system
- Anti-detecção: ServerSafeMovement (suspicion scoring), HumanMovement (Perlin noise)
- Combat: AdvancedCombat (Perfect Block 150ms), ComboSystem (5 builds)
- Farm: FarmRotation (8 bosses), QuestManager (10+ quests), TeleportManager (30+ ilhas)
- Systems: AutoStats (5 builds), ESP, AutoHeal (8 itens), AntiAFK
- 32 módulos total | ~10.5k linhas | Bypass multicamadas"

# 3. Push
git push origin main

# 4. Gerar bundle (opcional)
python3 tools/bundle.py
```

## Arquivos Modificados

### Novos (13)
- src/ReplicatedStorage/EliteAutomation/Core/PerformanceManager.lua
- src/ReplicatedStorage/EliteAutomation/UI/Theme.lua
- src/ReplicatedStorage/EliteAutomation/Movement/ServerSafeMovement.lua
- src/ReplicatedStorage/EliteAutomation/Movement/HumanMovement.lua
- src/ReplicatedStorage/EliteAutomation/Combat/AdvancedCombat.lua
- src/ReplicatedStorage/EliteAutomation/Combat/ComboSystem.lua
- src/ReplicatedStorage/EliteAutomation/Systems/FarmRotation.lua
- src/ReplicatedStorage/EliteAutomation/Systems/QuestManager.lua
- src/ReplicatedStorage/EliteAutomation/Systems/TeleportManager.lua
- src/ReplicatedStorage/EliteAutomation/Systems/AutoStats.lua
- src/ReplicatedStorage/EliteAutomation/Systems/ESP.lua
- src/ReplicatedStorage/EliteAutomation/Systems/AutoHeal.lua
- src/ReplicatedStorage/EliteAutomation/Systems/AntiAFK.lua

### Atualizados (5)
- src/StarterPlayer/StarterPlayerScripts/EliteAutomation.client.lua
- src/ReplicatedStorage/EliteAutomation/UI/Components.lua
- src/ReplicatedStorage/EliteAutomation/Combat/CombatController.lua
- tools/bundle.py
- README.md

### Documentação
- CHANGELOG_v2.1.md (novo)
- deploy_v2.1.sh (novo)
- DEPLOY.md (este arquivo)

## Verificação Pós-Deploy

Após push, verificar:
1. GitHub Actions (se configurado)
2. README.md renderizado corretamente
3. CHANGELOG_v2.1.md visível
4. Gerar bundle: `python3 tools/bundle.py`
5. Testar loadstring:
   ```lua
   loadstring(game:HttpGet("https://raw.githubusercontent.com/blackxzin/script/main/main.lua"))()
   ```

## Estatísticas v2.1

- **Módulos:** 19 → 32 (+13)
- **Linhas:** ~6k → ~10.5k (+75%)
- **Sistemas:** 6 → 13 (+7)
- **Anti-detecção:** 5 camadas
- **Bosses catalogados:** 8
- **Quests:** 10+
- **Ilhas:** 30+

## Recursos Principais v2.1

✅ Farm Rotation (XP/min optimization)
✅ Perfect Block (150ms timing)
✅ Combo System (5 builds)
✅ Auto-Quest (10+ quests)
✅ Teleport Manager (30+ ilhas)
✅ Auto-Stats (5 builds)
✅ ESP (bosses/frutas/players)
✅ Auto-Heal (8 itens)
✅ Anti-AFK (4 ações)
✅ Server-Safe Movement (suspicion scoring)
✅ Human Movement (Perlin noise + Box-Muller)
✅ Performance Manager (pooling + GC)
✅ Theme System (glassmorphism)

---

**Build:** 2026-09-11  
**Repo:** https://github.com/blackxzin/script  
**Branch:** main
