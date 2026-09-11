# ⚡ Elite Automation Framework v2.1 - Grand Piece Online (GPO)

Framework modular de automação avançada para **Grand Piece Online (GPO)** no Roblox. Totalmente compatível e testado para execução no **Xeno (PC)** e **Delta (Mobile & PC)**, além de Codex, Fluxus, Hydrogen e Arceus X.

**🆕 Novidades v2.1:**
- 🎨 **Sistema de Temas** - Dark Elite, Neon Cyber, Minimal com glassmorphism
- ⚡ **Performance Manager** - Connection pooling, memory cleanup automático
- 🤖 **Movimento Humanizado** - Perlin noise, delays naturais, anti-detecção avançada
- 📜 **Auto-Quest System** - Farm automático de quests com priorização inteligente
- 🌍 **Teleport Manager** - Viagem rápida entre ilhas com 30+ localizações
- 🔄 **Farm Rotation** - Rotação de bosses por eficiência (XP/min)
- 🛡️ **Perfect Block** - Bloqueio perfeito com 150ms timing window
- 🔥 **Combo System** - 5 builds de combo (ThreeSwordStyle, BlackLeg, Electro, DragonClaw, Fishman)
- 👁️ **ESP System** - Highlight de bosses, frutas e players
- 💊 **Auto-Heal** - Cura automática com 8 itens priorizados
- 🤖 **Anti-AFK** - Sistema anti-kick com ações randomizadas
- 📊 **Auto-Stats** - Distribuição automática de pontos em 5 builds
- 🛡️ **Server-Safe Movement** - Validação server-side com suspicion scoring

---

## 🚀 Como Executar

### Opção 1: Loadstring Direto (Recomendado)
Cole a linha abaixo no seu executor (**Xeno**, **Delta**, etc.):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/blackxzin/script/main/main.lua"))()
```

Ou via o loader rápido:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/blackxzin/script/main/loader.lua"))()
```

### Opção 2: Código Standalone (Sem Necessidade de Internet)
Você também pode abrir o arquivo [`main.lua`](main.lua), copiar todo o código e colar diretamente na aba de script do executor. O arquivo é 100% autocontido (todos os módulos já estão empacotados internamente).

> **Atalho:** Pressione a tecla **HOME** no teclado para abrir/fechar o painel a qualquer momento.

---

## 🌟 Recursos Principais

### 🛡️ 1. SmartFlight com Bypass Anticheat 100% Eficaz
- **Estabilizador de Física (`BodyVelocity`)**: Neutraliza inércia e forças de aceleração durante o voo, permitindo ao `TweenService` mover o personagem suavemente sem disparar detecção de velocidade ou teleporte no servidor do GPO.
- **Spoof de Estado (`PlatformStanding` & `Physics`)**: Anula atrito do controlador padrão do Roblox, eliminando o efeito de *rubberbanding* e congelamento de animações.
- **Proteção Estrita Anti-Mar (Devil Fruit Safe)**: Mantém altitude mínima garantida de **35 studs acima do mar**, prevenindo contato acidental com a água salgada que causa dano percentual letal em usuários de Akuma no Mi.
- **Anti-Dano de Queda & Suporte a `StreamingEnabled`**: Pré-carrega os chunks de destino antes do pouso e zera a velocidade de impacto.

---

### 🛒 2. Rastreador do Mercador Viajante (GPO Traveling Merchant)
- **Contagem Regressiva em Tempo Real via Uptime do Servidor**:
  - No GPO, o Mercador surge com precisão aos **10 minutos (600s)** de vida do servidor, permanece **10 minutos ativo**, e reaparece a cada **30 minutos** (10m, 40m, 1h10m, 1h40m...).
  - O painel exibe um cronômetro ao vivo: `Próximo spawn em: MM:SS` ou `MERCADOR ATIVO! Despawn em: MM:SS`.
- **Scanner da Bússola (`PlayerGui.Compass`)**: Detecta o ícone oficial da bússola do GPO para identificar ilha e direção mesmo à distância.
- **Transporte Imediato**: Botão na interface `🛒 Voar até o Mercador` que conduz o jogador diretamente até o NPC em qualquer ilha da First ou Second Sea.

---

### 🏭 3. Farm da Factory Raid & Boss Law Especializado
- **Suporte Canônico aos 4 Estágios do GPO**:
  - **Estágios 1 e 2**: Eliminação de Cientistas e DPS no Core.
  - **Estágio 3**: Detecção de Cientistas de Fruta (Pika, Mera, Hie, Bane) + Alerta de Lava.
  - **Estágio 4 (Boss Law)**: No GPO, o Slime Core é **invulnerável** enquanto o Law estiver vivo! O script detecta o Law no 2º andar, elimina o boss primeiro e imediatamente redireciona todo o foco para o Core.
- **Proteção Anti-Lava**: Monitora a subida de lava tóxica do 1º andar da fábrica e trava a altitude na passarela superior/ar para evitar morte instantânea (*instakill*).
- **Anulação de Skills do Law**:
  - Combate a **14 studs de altitude** acima da cabeça do Law: ponto cego do `Tact` (pedras) e imune aos espinhos terrestres (`Thorn`).
  - **Anti-Shambles**: Restauração da posição aérea sobre o Law em menos de 0.1s após teleporte forçado.
  - Priorização para garantir **>= 5% de dano** (requisito para drop de Fruta Rara+ e Cyborg Gears) e Top 3 no ranking de dano (2x taxa de frutas lendárias).

---

### ⚔️ 4. Combate GPO Avançado
- **Auto-Buso Haki ('J')**: Ativa e mantém o Haki do Armamento antes dos ataques, perfurando a intangibilidade de inimigos Logia (Enel, Pika, Mera, Suna, etc.) e amplificando o dano base.
- **Auto-Ken Haki ('K')**: Ativação automática do Haki da Observação para esquivas de golpes pesados em combate.
- **Auto-Grip ('B')**: Finaliza automaticamente alvos nocauteados/caídos para assegurar drops de itens e bounty.
- **Regulação de Stamina**: Modula a cadência dos golpes se a estamina cair abaixo de 15%, prevenindo quebras de postura (*Guard Break*) e reservando estamina para o Geppo/esquivas.

---

### 👑 5. Catálogo Completo de Bosses e Sea Events
- **First Sea**: Bandit Boss, Lucid (Sandora), Axe Hand Logan (Shell's Town), Star Clown Buggy (Orange Town), Gorilla King (Sphinx), Saw Shark Arlong (Shark Park), Head Guardian (Sky Castle), Thunder God Enel (Golden City), Gravito (Gravito's Fort), Neptune e Ryu (Fishman Island).
- **Second Sea**: Crab King Cho, Pharaoh Akshan, Musashi, Ghost Princess Perona, Ryuma, Borj, Moria, Soul King Brook, Pica, Donmingo (Mansion), Lucy (Colosseum) e Law.
- **Sea Events**: Kraken (todas as cores: Red, Blue, Green, Gold, Purple), Sea Beast, Ghost Ship, Megalodon e Galleons da Marinha.

---

### 🍎 6. Fruit Tracker & Baús
- **Rastreador de Frutas sob Árvores**: Detecta spawns naturais e notificações de Akuma no Mi pelo mapa, com filtro por raridade (*Common*, *Rare*, *Legendary*, *Mythical*).
- **Coleta Automática**: Voa até a fruta com bypass seguro e adiciona ao inventário.
- **Item Farm**: Coleta automática de baús de tesouro (Wooden, Bronze, Silver, Gold, Rare, Legendary, Mythical) e sacos de Peli.

---

### 📜 7. Auto-Quest System (Novo v2.1)
- **Seleção Inteligente**: Escolhe automaticamente a melhor quest baseado no nível do jogador e recompensas.
- **Farm Automático**: Aceita quest, localiza inimigos, elimina e completa automaticamente.
- **Progresso em Tempo Real**: Contador de kills exibido na UI (ex: 5/10).
- **Suporte a 10+ Quests**: First Sea e Second Sea incluídas.

---

### 🌍 8. Teleport Manager (Novo v2.1)
- **30+ Ilhas Catalogadas**: Todas as ilhas principais de First Sea e Second Sea.
- **Aliases Inteligentes**: Digite "sky" para ir até "Land of the Sky", "desert" para Sandora, etc.
- **Teleporte Seguro**: Usa SmartFlight para bypass 100% eficaz.
- **Histórico**: Últimas 5 viagens registradas.
- **Teleporte para Ilha Mais Próxima**: Comando rápido para voltar à civilização.

---

### 🎨 9. Sistema de Temas (Novo v2.1)
- **3 Temas Pré-configurados**:
  - **Dark Elite** (Padrão): Roxo/azul escuro com glassmorphism
  - **Neon Cyber**: Roxo/rosa vibrante estilo cyberpunk
  - **Minimal**: Cinza minimalista sem blur
- **Glassmorphism Real**: Blur backdrop, gradientes, efeitos de brilho
- **Troca Dinâmica**: Muda tema sem reiniciar o script

---

### ⚡ 10. Performance & Anti-Detecção (Novo v2.1)
- **Connection Pooling**: Gerenciamento automático de eventos para evitar memory leaks
- **Tween Pooling**: Cancela tweens órfãos automaticamente
- **Auto-Cleanup**: Coleta de lixo inteligente a cada 30s
- **Movimento Humanizado**: 
  - Perlin noise 1D para velocidade orgânica
  - Delays baseados em distribuição normal (Box-Muller)
  - Micro-desvios em trajetórias (não caminha em linha reta perfeita)
  - Input timing variável (150-300ms de reação humana)
- **Jitter de Posição**: Adiciona aleatoriedade sub-stud para evitar padrões robóticos

---

### 🔄 11. Farm Rotation System (Novo v2.1)
- **Rotação Inteligente por Eficiência**: Calcula XP/minuto de cada boss considerando:
  - Tempo de kill estimado
  - Tempo de respawn
  - Recompensas (XP + valor de drops ponderado pela drop rate)
- **8 Bosses Catalogados**: Bandit Boss, Lucid, Axe Hand Logan, Gravito, Enel, Neptune, Ryuma, Law
- **Rota Dinâmica**: Reconstrói rota a cada ciclo baseado em:
  - Bosses disponíveis (respawn completo)
  - Nível do jogador (ignora bosses 50+ níveis acima)
  - Prioridade + Eficiência combinados
- **Top 5 Route**: Seleciona os 5 bosses mais eficientes para rotação otimizada

---

### 🛡️ 12. Perfect Block & Combo System (Novo v2.1)
- **Perfect Block (150ms window)**: 
  - Detecção de animações de ataque inimigo
  - Ativação precisa do bloqueio no timing exato
  - Reduz dano em 90% e nega stun
- **Block Break**: Usa skill de quebra (tecla C) automaticamente contra inimigos em guard
- **Combo Chains**: 5 builds com rotações otimizadas:
  - **ThreeSwordStyle**: M1×3 → Z → M1×2 → X → M1×4 → C
  - **BlackLeg**: M1×3 → Z → M1×3 → X → M1×2 → C
  - **Electro**: Z → M1×4 → X → M1×3 → C
  - **DragonClaw**: M1×2 → Z → M1×3 → X → M1×4 → C
  - **Fishman**: M1×3 → Z → M1×2 → X → M1×3 → C
- **Cooldown Tracking**: Aguarda cooldown real de cada skill antes de reuso

---

### 👁️ 13. ESP System (Novo v2.1)
- **Highlight System**: Destaca entidades através de paredes
- **Billboard Labels**: Mostra nome e distância em tempo real
- **Categorias com Cores**:
  - Bosses: Vermelho
  - Frutas: Roxo
  - Players: Azul
  - NPCs: Verde
- **Filtros**: Ativa/desativa por categoria
- **Performance**: Auto-cleanup de objetos destruídos

---

### 💊 14. Auto-Heal System (Novo v2.1)
- **8 Itens Catalogados** (prioridade decrescente):
  1. Dough Donut (instant 100%)
  2. Bento Box (80% + regen)
  3. Meat (70%)
  4. Fishman Karate Gi (50% + buff)
  5. Cake (50%)
  6. Apple (30%)
  7. Pear (25%)
  8. Banana (20%)
- **Dual Thresholds**: 50% (normal), 25% (emergência)
- **Cooldown**: 2s entre heals para evitar spam
- **Verificação de Estoque**: Só tenta usar itens disponíveis no inventário

---

### 🤖 15. Anti-AFK System (Novo v2.1)
- **4 Ações Randomizadas**:
  - Movimento de câmera (random yaw/pitch)
  - Pulo (jump input)
  - Deslocamento curto (2-5 studs)
  - Teclas WASD aleatórias
- **Intervalos Variáveis**: 1.5-2.5 minutos entre ações
- **Detecção de Kick Warning**: Monitora PlayerGui para alertas de AFK
- **Action Randomizer**: Nunca repete a mesma ação duas vezes seguidas

---

### 📊 16. Auto-Stats System (Novo v2.1)
- **5 Builds Pré-configurados**:
  - **SwordMain**: 50% Strength, 25% Defense, 20% Stamina, 5% Fruit
  - **DevilFruitMain**: 55% Fruit, 20% Stamina, 15% Defense, 10% Strength
  - **Hybrid**: 35% Strength, 30% Fruit, 20% Stamina, 15% Defense
  - **Tank**: 40% Defense, 30% Stamina, 20% Strength, 10% Fruit
  - **GlassCannon**: 45% Strength, 40% Fruit, 10% Stamina, 5% Defense
- **Distribuição Automática**: Aloca pontos por porcentagem ao subir de nível
- **Verificação de Pontos**: Só distribui se houver pontos disponíveis
- **Seleção Dinâmica**: Troca de build via UI sem reiniciar

---

### 🛡️ 17. Server-Safe Movement (Novo v2.1)
- **Suspicion Scoring (0-100)**:
  - Analisa padrões de movimento
  - Detecta velocidades anômalas
  - Identifica teleports suspeitos
  - Monitora altitude (max 500 studs)
- **Safe Limits**:
  - MaxTweenSpeed: 48 studs/s
  - MaxTeleportDist: 100 studs
  - MinTweenTime: 0.8s
  - MaxAltitude: 500 studs
- **Movement History**: Rastreia últimos 10 movimentos
- **Validation**: Rejeita movimentos que violem limites server-side
- **3 Safety Levels**:
  - Extreme: 75% velocidade
  - High: 85% velocidade
  - Medium: 100% velocidade
- **Segmented Travel**: Divide viagens longas em segmentos < 100 studs

---

## 📁 Estrutura do Repositório

```text
├── main.lua                    # Bundle único compilado (32 módulos, ~250KB)
├── loader.lua                  # Script de carregamento remoto via HttpGet
├── default.project.json        # Configuração para Rojo / Roblox Studio
├── tools/
│   └── bundle.py               # Script utilitário de empacotamento
└── src/
    ├── ReplicatedStorage/
    │   └── EliteAutomation/
    │       ├── Core/           # Logger, StateMachine, TaskManager, PerformanceManager, PriorityManager
    │       ├── Config/         # Settings (Bosses, velocidades, intervalos)
    │       ├── Movement/       # SmartFlight, ServerSafeMovement, HumanMovement
    │       ├── Combat/         # CombatController, AdvancedCombat, ComboSystem, TargetSelector
    │       ├── Systems/        # 13 sistemas (Boss, Quest, Teleport, Merchant, Law, Fruit, Item, FarmRotation, AutoStats, ESP, AutoHeal, AntiAFK)
    │       └── UI/             # MainUI, Components, TabManager, Theme, Notifications
    └── StarterPlayer/
        └── StarterPlayerScripts/
            └── EliteAutomation.client.lua
```

---

## 📜 Licença

Distribuído sob a licença MIT. Desenvolvido para uso educacional e automação avançada no Grand Piece Online.
