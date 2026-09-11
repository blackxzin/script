# ⚡ Elite Automation Framework v2.0 - Grand Piece Online (GPO)

Framework modular de automação avançada para **Grand Piece Online (GPO)** no Roblox. Totalmente compatível e testado para execução no **Xeno (PC)** e **Delta (Mobile & PC)**, além de Codex, Fluxus, Hydrogen e Arceus X.

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

## 📁 Estrutura do Repositório

```text
├── main.lua                    # Bundle único compilado para executores (Xeno / Delta)
├── loader.lua                  # Script de carregamento remoto via HttpGet
├── default.project.json        # Configuração para Rojo / Roblox Studio
├── tools/
│   └── bundle.py               # Script utilitário de empacotamento do bundle
└── src/
    ├── ReplicatedStorage/
    │   └── EliteAutomation/
    │       ├── Core/           # Logger, StateMachine, TaskManager, PriorityManager
    │       ├── Config/         # Settings (Bosses, velocidades, intervalos)
    │       ├── Movement/       # SmartFlight (Tween bypass, anti-mar, anti-queda)
    │       ├── Combat/         # CombatController (Buso, Ken, Grip, Stamina)
    │       ├── Systems/        # LawFactoryFarm, MerchantTracker, BossManager, FruitTracker...
    │       └── UI/             # MainUI, Components, TabManager, Notifications
    └── StarterPlayer/
        └── StarterPlayerScripts/
            └── EliteAutomation.client.lua
```

---

## 📜 Licença

Distribuído sob a licença MIT. Desenvolvido para uso educacional e automação avançada no Grand Piece Online.
