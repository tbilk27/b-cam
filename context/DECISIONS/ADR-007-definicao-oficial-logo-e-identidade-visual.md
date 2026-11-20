# ADR-007: Definição Oficial do Logotipo, Ícone do App e Diretrizes Cromáticas

- **Status**: Aceito (Aprovado pelo Stakeholder / Usuário)
- **Data**: 2026-11-20
- **Decisores**: Usuário / Stakeholder Principal, Especialista em Usabilidade e Design (UX/UI), Líder Orquestrador Geral
- **Contexto**: Após a evolução do sistema e a criação dos novos ativos gráficos inspirados no universo retro-futurista e neon de GTA VI (Vice City), o usuário aprovou expressamente o logotipo widescreen e o ícone squircle do aplicativo. Tornou-se mandatório formalizar estes ativos e a paleta de cores como diretrizes oficiais, imutáveis e de cumprimento obrigatório em todo o ciclo de vida do projeto **b-cam**.

---

## Decisão

1. **Logotipo Canônico do Sistema**:
   - O logotipo oficial do sistema é a composição widescreen formada por:
     - **Emblema**: A fusão da letra minúscula **`b`** estilizada em titânio beveled escuro com o elemento circular de uma lente de câmera CFTV dotada de íris mecânica (*aperture iris blades*), retículo de mira tática e indicador LED `REC` pulsante.
     - **Wordmark**: `b-cam` em tipografia display geométrica (*Orbitron Black*), vazado com o gradiente *Vice City Sunset* (`#FF2A85` Neon Pink -> `#FF6A00` Sunset Orange -> `#FFD200` Sunset Yellow) e halo difuso.
     - **Subtítulo Militar**: `SURVEILLANCE RADAR` em tipografia condensada de alta precisão (*Rajdhani Bold*), caixa alta, espaçamento de caracteres estendido (`letter-spacing: 2.5`), em Ciano Elétrico (`#00F0FF`).
   - O arquivo matriz do logotipo é mantido permanentemente em `assets/images/b_cam_logo.jpg`.

2. **Ícone Oficial do Aplicativo**:
   - O ícone do aplicativo é o container *squircle* em fundo preto obsidiana (`#090814`) com textura sutil de fibra de carbono.
   - O corpo da letra `b` possui acabamento em titânio escuro com dupla iluminação perimetral (*rim lighting*): Magenta Neon na face esquerda e Ciano Elétrico na face direita.
   - A concavidade circular abriga a ótica da câmera em azul-ciano translúcido com retículo militar e indicador de gravação ativo em Vermelho Vibrante (`#FF0055`).
   - O arquivo de referência principal é mantido em `assets/images/b_cam_icon.jpg` e a variante de emblema expandido em `assets/images/b_cam_app_icon_fullbleed.jpg`.

3. **Diretrizes Cromáticas Obrigatórias (Tokens Canônicos)**:
   - **`GtaColors.neonPink` (`#FF2A85`)**: Cor primária da marca e destaques principais.
   - **`GtaColors.electricCyan` (`#00F0FF`)**: Telemetria, endereços IP, portas, ótica e retículos de mira.
   - **`GtaColors.sunsetOrange` (`#FF6A00`)**: Transição de gradientes e alertas.
   - **`GtaColors.sunsetYellow` (`#FFD200`)**: Ponto alto de luminosidade e favoritos.
   - **`GtaColors.recRed` (`#FF0055`)**: Indicador de gravação ativa (`REC • LIVE`).
   - **`GtaColors.statusOnline` (`#00FFA3`)**: Câmera online e stream decodificado com sucesso.
   - **`GtaColors.statusOffline` (`#FF3366`)**: Falha de conexão ou câmera inacessível.
   - **`GtaColors.bgDark` (`#090814`)**: Fundo principal do Scaffold e superfícies escuras.
   - **`GtaColors.bgSurface` (`#121024`)**: Fundo de caixas de entrada e barras superiores.
   - **`GtaColors.bgCard` (`#1B1834`)**: Superfície dos cartões semi-translúcidos.

4. **Regras de Aplicação e Preservação**:
   - É estritamente proibido alterar a proporção, paleta de cores ou distorcer o logotipo em qualquer tela ou canal de comunicação.
   - Todas as compilações nativas (Android APK/AAB, iOS IPA, macOS App, Web PWA e Windows EXE) devem ser geradas a partir do pipeline de assets padronizado pelo ícone aprovado.
   - Qualquer nova funcionalidade que exija elementos visuais de marca deve reutilizar o componente vetorial `GtaLogo` ou os assets homologados.

---

## Consequências

- **Positivas**:
  - Consolidação de uma identidade de produto premium, coesa e memorável, diferenciando radicalmente o **b-cam** de softwares utilitários genéricos de CFTV.
  - Consistência estética garantida em todas as plataformas (mobile, desktop e web).
  - Alinhamento pleno com a aprovação formal do usuário/stakeholder.

- **Mitigações de Performance**:
  - A renderização in-app no widget `GtaLogo` continua utilizando primitivas vetoriais nativas otimizadas via `CustomPainter`, garantindo execução suave a 60/120 FPS sem alocação contínua de memória.
