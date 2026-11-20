# 🎨 b-cam • Design System GTA VI (Vice City Cyber-Surveillance)

Elaborado pelo **Especialista em Usabilidade e Design de Interação** (`ux-ui-specialist`).

---

## 1. Conceito Visual

A identidade visual de **b-cam** é uma releitura de alta fidelidade da estética retro-futurista e neon do universo **GTA VI / Vice City**:
- **Contraste Extremo**: Fundos profundos ultra-escuros com elementos luminosos vibrantes em magenta, ciano elétrico e gradiente de entardecer.
- **Linguagem de HUD de Vigilância**: Elementos visuais que remetem a consoles de monitoramento tático de alta tecnologia: marcas de retículo nos cantos das telas, relógio digital militar sincronizado em segundos, pontos piscantes de gravação e radar pulsante de varredura.
- **Glassmorphism Escuro**: Cartões com fundo escuro semi-translúcido, bordas finas com halo neon sutil e sombras difusas coloridas.

---

## 2. Paleta de Cores e Tokens

| Token | Hex / Valor | Aplicação Primária |
| :--- | :--- | :--- |
| **`neonPink`** | `#FF2A85` | Cor primária da marca, botões de ação principal, status REC ativo |
| **`hotPink`** | `#FF007F` | Realces e estados hover/pressionado |
| **`electricCyan`** | `#00F0FF` | Telemetria, dados técnicos (IP, portas), retículos de mira e acentos |
| **`sunsetOrange`** | `#FF6A00` | Transição de gradientes e alertas de atenção |
| **`sunsetYellow`** | `#FFD200` | Destaque de favoritos (estrelas) e ponto alto do gradiente de pôr do sol |
| **`statusOnline`** | `#00FFA3` | Indicador de câmera online e streaming ativo |
| **`statusOffline`** | `#FF3366` | Falha de sinal ou câmera indisponível |
| **`bgDark`** | `#090814` | Cor de fundo geral do Scaffold |
| **`bgSurface`** | `#121024` | Superfície secundária (inputs, barras superiores) |
| **`bgCard`** | `#1B1834` | Superfície dos cartões de câmeras e módulos |
| **`borderSubtle`** | `#2C2754` | Bordas sutis de cartões e divisórias |

---

## 3. Tipografia

- **Títulos e Identidade (`Orbitron`)**:
  - Fonte display geométrica e futurista.
  - Utilizada em títulos de tela, nome da marca `b-cam`, relógios de telemetria e botões em caixa alta com espaçamento de caracteres ampliado (`letter-spacing: 1.2` a `2.0`).
- **Corpo e Leitura Técnica (`Rajdhani`)**:
  - Fonte condensada de alta densidade de informação e excelente legibilidade em telas móveis.
  - Utilizada em legendas, nomes de câmeras, formulários e status.
- **Dados Monospaçados (`Roboto Mono`)**:
  - Utilizada para endereços IP, portas, URLs RTSP e dados de rede brutos.

---

## 4. Diretrizes de Ergonomia e Acessibilidade

1. **Alvos de Toque Mínimos**: Todos os botões e áreas clicáveis possuem altura mínima de 44x44 dp para garantir facilidade de toque com uma mão.
2. **Feedback Visual Imediato**:
   - Cada botão possui animação de toque em onda translúcida (*splash*).
   - O radar de varredura indica o IP que está sendo testado naquele milissegundo e o percentual de avanço em tempo real.
3. **Prevenção de Sobrecarga Cognitiva no Comissionamento**:
   - O usuário não precisa saber sintaxes RTSP complexas como `/cam/realmonitor?channel=1&subtype=0`. A interface infere o template automaticamente ao selecionar o fabricante.
   - Fornecimento de botões pré-fabricados com credenciais comuns (`admin/admin`, `admin/123456`, etc.).
