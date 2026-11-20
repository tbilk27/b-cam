# 🎨 b-cam • Design System (Microsoft Fluent 2 & Vigilância Executiva)

Elaborado pelo **Especialista em Usabilidade e Design de Interação** (`ux-ui-specialist`) em conjunto com a equipe Multi-Agente.

---

## 1. Evolução do Design System (Sprint 1.5)

Após a fase conceitual com estética vibrante ("GTA VI / Vice City Neon"), o usuário solicitou uma mudança estética em direção a uma experiência **sóbria, moderna, simples e objetiva**, com base na biblioteca [`fluent_ui`](https://pub.dev/packages/fluent_ui) (Microsoft Fluent Design System 2).

### Princípios da Nova Identidade Visual:
1. **Redução da Fadiga Visual (Mission-Critical Surveillance)**:
   - Eliminação de gradientes neon intensos (rosa e ciano estridentes).
   - Uso de superfícies escuras neutras em tonalidades Dark Zinc e Slate (`#1B1B1F` e `#242429`), permitindo que a atenção do operador convirja 100% para os fluxos de vídeo.
2. **Minimalismo e Clareza Funcional**:
   - Elementos em cantos sutilmente arredondados (Fluent border radius de 4 a 8 dp).
   - Bordas finas de alto contraste com iluminação sutil de profundidade (*acrylic & card depth*).
   - Tipografia limpa baseada na família **Inter**, complementada por **Roboto Mono** para telemetria de rede.
3. **Preservação Absoluta da Marca**:
   - Manutenção do avatar e ícone oficial da íris com lente ótica e letra `b` minúscula (`assets/images/b_cam_icon.jpg`).
   - Apresentação em formato executivo com tipografia Inter sem serifa e tag sutil "PRO".

---

## 2. Paleta de Cores e Tokens Fluent 2

| Token | Hex / Valor | Aplicação Primária |
| :--- | :--- | :--- |
| **`darkBackground`** | `#1B1B1F` | Fundo principal da aplicação e scaffolds |
| **`darkSurface`** | `#242429` | Superfície secundária e cartões de conteúdo (Mica/Acrylic) |
| **`darkCard`** | `#2B2B32` | Fundo de cartões de câmeras e blocos de código |
| **`darkCardElevated`** | `#32323A` | Cards com elevação e diálogos modais |
| **`darkBorder`** | `#3E3E47` | Bordas e divisores de alto contraste |
| **`darkBorderSubtle`** | `#303038` | Bordas sutis de cartões e inputs |
| **`accentBlue`** | `#0078D4` | Cor de destaque primária (Cobalt Blue Fluent) |
| **`accentLightBlue`**| `#4CC2FF` | Acento secundário para telemetria e botões selecionados |
| **`statusOnline`** | `#107C41` | Indicador operacional de câmera conectada (Microsoft Green) |
| **`statusOnlineGlow`**| `#28A745` | Ponto luminoso e badge "WI-FI ONLINE" |
| **`statusOffline`**| `#D83B01` | Câmera sem sinal ou ação destrutiva/parada |
| **`statusWarning`**| `#FFB900` | Avisos importantes (ex: Mibo Safety Code) e favoritos |
| **`textPrimary`** | `#F3F3F3` | Texto principal de alta legibilidade |
| **`textSecondary`** | `#A1A1A6` | Legendas e rótulos de segundo nível |
| **`textTertiary`** | `#71717A` | Metadados e textos desativados |

---

## 3. Tipografia

- **Interface Geral e Rótulos (`Inter`)**:
  - Fonte sans-serif neutra, amplamente adotada em interfaces modernas de sistemas operacionais.
  - Títulos principais em peso 700 (Bold), subtítulos em peso 600 (Semi-Bold), e texto regular em peso 400.
- **Telemetria e Dados Técnicos (`Roboto Mono`)**:
  - Usada exclusivamente para dados numéricos de precisão: IPs (`192.168.3.74`), portas (`554`), endereços MAC (`98:2A:0A:89:56:62`), relógio de timestamp militar (`13:14:01`) e strings de URL RTSP.

---

## 4. Componentes Chave

1. **`BCamLogo` (`lib/widgets/b_cam_logo.dart`)**:
   - Ícone quadrado de cantos arredondados contendo a imagem oficial da íris (`assets/images/b_cam_icon.jpg`).
   - Título em caixa baixa estilizada `b-cam`, badge sutil `PRO` em fundo azul cobalto e subtítulo `SURVEILLANCE RADAR`.

2. **`LivePlayerView` (`lib/widgets/live_player_view.dart`)**:
   - Renderização limpa de vídeo via `media_kit` (libmpv).
   - HUD discreto nos cantos com retículos finos em cinza e timestamp sincronizado.
   - Badge de fabricante e canal com cores corporativas sóbrias (Intelbras verde floresta, Yoosee azul cobalto).
   - Auto-ajuste de transporte UDP vs TCP com base no fabricante.

3. **Cartões de Câmera (`HomeScreen`)**:
   - Estruturados em `Card` Fluent UI com superfície `#242429`.
   - Área de toque expandida com navegação direta para `CameraDetailScreen`.
   - Botões de favoritos (estrela) e menu contextual com `ContentDialog`.

4. **Matriz de Monitoramento (`MultiGridScreen`)**:
   - Grid dinâmico com alternador de colunas (1 Coluna, 2 Colunas, 3 Colunas).
   - Miniaturas de alta densidade sem quebra de proporção 16:9.

5. **Comissionamento e Scan (`ScanScreen` e `CommissionScreen`)**:
   - Barra de progresso linear (`ProgressBar`).
   - Atalhos de credenciais em pílulas discretas com destaque visual para correspondências de IP.
   - `InfoBar` corporativo para avisos e dicas de segurança.

---

## 5. Logotipo e Ícone Oficial do Sistema

- **Arquivo Vetorial/Raster**: `assets/images/b_cam_icon.jpg`
- **Ícones do Sistema Android**:
  - `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
  - `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
  - `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
  - `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
  - `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
