⚡ Elite Automation Framework v2.1 | GPO Advanced Automation

Version Status Compatibility

O Elite Automation Framework é um ecossistema de automação de alto nível desenvolvido para Grand Piece Online (GPO). Diferente de scripts comuns, o framework utiliza uma arquitetura modular baseada em Máquinas de Estados (FSM) e Gerenciamento de Prioridades, garantindo uma execução fluida, inteligente e com mínima assinatura de detecção.
🚀 Execução Rápida
1. via Loadstring (Recomendado para produção)

lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/blackxzin/script/main/loader.lua"))()

2. via Standalone (Para desenvolvedores)

Copie o código completo do arquivo main.lua e cole diretamente no seu executor de preferência.

    ⌨️ Atalho de Interface: Pressione a tecla HOME para abrir/fechar o painel de controle.

🧠 Arquitetura de Inteligência (Core Engine)

O diferencial do Elite Automation reside no seu motor de decisão, que evita o comportamento robótico padrão:

    🤖 Adaptive Brain (IA de Contexto): O sistema monitora seu HP, Stamina e proximidade de inimigos para ajustar automaticamente sua velocidade de voo e cadência de ataque.
    🛡️ Server-Safe Movement: Implementação de trajetórias segmentadas e validação de velocidade para evitar o rubberbanding e detecções de teleporte.
    📊 Suspicion Scoring: Monitora o padrão de movimento e adiciona micro-desvios (jitter) para simular uma navegação humana orgânica.
    🔄 Farm Rotation Engine: Sistema de rotação baseado em eficiência matemática (XP/Minuto + Valor de Drops), selecionando o alvo mais lucrativo no momento.

🌟 Principais Módulos de Automação
⚔️ Combat & Raid Optimization

    Advanced Combat Controller: Suporte a combos otimizados para 5 builds (Sword, Fruit, Hybrid, etc.) com regulação de cadência baseada em Stamina.
    Boss & Sea Event Manager: Automação completa para Sea Beasts, Kraken e eventos de mar com proteção anti-afogamento.
    Law/Factory Specialist: Sistema de combate vertical para anular o Tact do Law e proteção contra a subida de lava na Raid.
    Haki Automation: Ativação inteligente de Busoshoku ('J') e Kenbunshoku ('K') para maximizar DPS e defesa.

🌍 Exploração & Coleta

    SmartFlight (Bypass 100%): Voo com neutralização de inércia e noclip contínuo via RunService.Stepped.
    Fruit & Item Tracker: Scanner de mundo para detecção de Akuma no Mi, Baús e Drops de Peli com sistema de notificação em tempo real.
    Merchant Tracker: Monitoramento do ciclo de vida do Mercador Viajante (Uptime do servidor) com alertas de spawn.
    Teleport Manager: Sistema de viagem rápida entre mais de 30 ilhas com suporte a aliases inteligentes.

🛡️ Segurança & Utilidades

    Anti-Detection Mode: Reduz a velocidade de processamento e aumenta o delay de input para máxima furtividade.
    Auto-Heal System: Gestão de inventário para uso automático de itens de cura baseados em thresholds de HP.
    Anti-AFK System: Simulação de inputs humanos (câmera, pulo e movimento) para evitar kicks por inatividade.
    Auto-Stats: Distribuição automática de pontos de status conforme a build selecionada.

🎨 Customização & UI

O painel de controle oferece uma experiência premium com:

    Glassmorphism Design: Interface moderna com efeitos de transparência e blur.
    Temas Dinâmicos: Escolha entre Dark Elite, Neon Cyber ou Minimal.
    Dashboard de Status: Monitoramento em tempo real de HP, Boss Ativo e estado da IA.

📁 Estrutura do Projeto

text
├── src/
│   ├── Core/           # Motor principal (TaskManager, StateMachine, Logger)
│   ├── Movement/       # Sistema de voo e física segura
│   ├── Combat/         # Lógica de combate, combos e seleção de alvos
│   ├── Systems/        # Módulos de farm, quests, teleporte e utilitários
│   └── UI/             # Interface de usuário e temas
└── main.lua            # Entrypoint principal (Integrador)

📜 Licença & Disclaimer

Este framework é distribuído sob a licença MIT. Desenvolvido para fins de estudo de engenharia de software e automação de jogos. Use por sua conta e risco.
💡 Dicas do Desenvolvedor

    Para obter a melhor performance, utilize o modo Anti-Detection ao farmar em servidores públicos. Para máxima eficiência de XP, utilize a função Farm Rotation em servidores privados.
