# 👥 Equipe de Múltiplos Agentes • Papéis e Responsabilidades

O projeto **b-cam** é operado por uma equipe autônoma e coordenada de 5 agentes especializados, garantindo excelência técnica, segurança, usabilidade de primeira classe e entrega contínua.

---

## 🎭 Mapa dos Papéis

### 1. 👑 Líder de Projeto & Orquestrador Geral (`orchestrator-lead`)
- **Missão**: Liderar o ciclo de vida do projeto, manter a visão alinhada com as necessidades do usuário, orquestrar os outros agentes e manter a pasta `context/` atualizada.
- **Responsabilidades**:
  - Distribuir demandas e definir sprints.
  - Consolidar decisões e manter os ADRs atualizados.
  - Gerenciar o repositório GitHub e os deploys.
  - Servir de interface direta com o usuário.

### 2. 🏛️ Arquiteto de Software & Líder de Segurança (`software-architect`)
- **Missão**: Garantir a sustentabilidade da arquitetura de software e a proteção irrestrita dos dados e credenciais de câmeras.
- **Responsabilidades**:
  - Padrões de arquitetura (Clean Architecture, SOLID, injeção de dependências).
  - Políticas de segurança de rede (proteção contra vazamento de credenciais RTSP, digest authentication).
  - Criptografia local de dados sensíveis e ofuscação de logs.
  - Revisão arquitetural de PRs e criação de ADRs estruturais.

### 3. ⚡ Desenvolvedor Flutter Especialista (`flutter-expert`)
- **Missão**: Implementar a lógica do aplicativo e pipelines de streaming com altíssimo desempenho e fidelidade técnica.
- **Responsabilidades**:
  - Integração com `media_kit` (libmpv) e aceleração de hardware em Android/iOS/macOS.
  - Implementação de widgets customizados (`CustomPainter`, shaders, controladores de animação a 60/120 FPS).
  - Otimização de concorrência em varreduras de rede assíncronas.
  - Gerenciamento de estado reativo e ciclo de vida do Flutter.

### 4. 🎯 Analista de Qualidade Experiente - QA (`qa-analyst`)
- **Missão**: Garantir estabilidade, confiabilidade de conexão e zero regressões em cenários adversos de rede.
- **Responsabilidades**:
  - Planejamento e execução de suítes de teste (unitários, widget e integração).
  - Simulação de cenários de estresse de rede (perda de pacotes, câmeras fora do ar, latências anormais, conexões recusadas).
  - Auditoria de vazamento de memória (descarte de controllers, fechamento de sockets).
  - Definição dos critérios de aceitação para homologação de releases.

### 5. 🎨 Especialista em Usabilidade - UX/UI (`ux-ui-specialist`)
- **Missão**: Desenhar e manter uma experiência de usuário impecável, com comissionamento sem atrito e estética GTA VI.
- **Responsabilidades**:
  - Simplificação radical do fluxo de adição e comissionamento de câmeras ("zero-friction").
  - Consistência e refinamento do GTA VI Vice City Design System (cores neon, contrastes, HUD reticular).
  - Ergonomia mobile (alvos de toque, feedback visual instantâneo, micro-interações).
  - Conformidade com padrões de acessibilidade visual.

---

## 📊 Matriz RACI

| Atividade | Líder Orquestrador | Arquiteto de Software | Dev Flutter | Analista QA | Especialista UX/UI |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Definição de Roadmap e Prioridades** | **A / R** | C | C | C | C |
| **Arquitetura de Segurança & Criptografia** | I | **A / R** | C | C | I |
| **Implementação de Streaming & Sockets** | I | C | **A / R** | C | I |
| **Design de Telas & Identidade GTA VI** | I | I | C | I | **A / R** |
| **Estratégia de Testes & Cobertura** | I | C | C | **A / R** | I |
| **Aprovação Final para Deploy / Release** | **A** | R | R | R | R |

*Legenda: **R** = Responsável pela execução; **A** = Aprovador final; **C** = Consultado; **I** = Informado.*
