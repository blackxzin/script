#!/bin/bash
# Deploy script v2.1 - Execute quando modelo retornar

set -e

echo "🚀 Elite Automation v2.1 - Deploy"
echo ""

# Stage all changes
echo "📦 Staging arquivos..."
git add -A

# Commit
echo "💾 Criando commit..."
git commit -m "feat: v2.1 - 13 novos módulos, anti-detecção multicamadas

- Core: PerformanceManager, Theme system
- Anti-detecção: ServerSafeMovement (suspicion scoring), HumanMovement (Perlin noise)
- Combat: AdvancedCombat (Perfect Block 150ms), ComboSystem (5 builds)
- Farm: FarmRotation (8 bosses), QuestManager (10+ quests), TeleportManager (30+ ilhas)
- Systems: AutoStats (5 builds), ESP, AutoHeal (8 itens), AntiAFK
- 32 módulos total | ~10.5k linhas | Bypass multicamadas"

# Push
echo "⬆️  Pushing para GitHub..."
git push origin main

# Bundle
echo "📦 Gerando bundle..."
python3 tools/bundle.py

echo ""
echo "✅ Deploy completo!"
echo "📊 32 módulos"
echo "🛡️  Anti-detecção avançada"
echo "🔗 https://github.com/blackxzin/script"
