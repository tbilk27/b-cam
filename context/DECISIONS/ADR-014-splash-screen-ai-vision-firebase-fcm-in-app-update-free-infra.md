# ADR-014: Splash Screen, Agente de IA com Bounding Boxes, Firebase Push & Deeplink, Infra Google 100% Grátis e In-App Auto-Update

- **Status**: Aceito (Accepted)
- **Data**: 2026-11-20
- **Decisores**: Equipe Multi-Agente (Arquiteto de Software, Especialista Flutter, Designer UX/UI, Analista QA, Líder Orquestrador)
- **Contexto**: Expansão do sistema **b-cam** para incorporar visão computacional inteligente, alertas em tempo real via Firebase, navegação direta por deeplink, visualização de caixas delimitadoras (*bounding boxes*), infraestrutura em nuvem de custo zero (Google Cloud Free Tier), tela de inicialização (*splash screen*) sóbria alinhada à identidade de marca e esteira de atualização in-app com versionamento automatizado.

---

## 1. Decisão Arquitetural

### 1.1. Splash Screen & Identidade Visual Canônica (UX/UI)
- Segue rigorosamente o **ADR-007** e **ADR-009**:
  - Fundo em ardósia escura neutra `BCamTheme.darkBackground` (`#1B1B1F`).
  - Emblema central oficial com a íris de abertura focal e letra `b` minúscula (`assets/images/b_cam_icon.jpg`) dentro de um squircle com sutil brilho perimetral e respiração suave.
  - Wordmark `b-cam` com badge `PRO` em azul cobalto (`#0078D4`) e subtítulo `SURVEILLANCE RADAR`.
  - Sequência de inicialização assistida com telemetria visual (*loading subsistemas de IA, carregar câmeras, roteamento de deeplinks*).
  - Remoção de telas brancas no arranque nativo Android configurando `launch_background.xml` com a mesma cor escura de fundo.

### 1.2. Agente de Visão Computacional (AI Vision Agent) & Bounding Boxes
- Modelagem de caixas delimitadoras (`BoundingBox`) com coordenadas normalizadas `[0.0, 1.0]`, rótulo da classe (`Pessoa`, `Veículo`, `Movimento`, `Animal`, etc.), pontuação de certeza (*confidence*) e cor de destaque Fluent.
- Filtro de limiar de confiança configurável por câmera (`aiMinConfidence`):
  - Exemplo: com o limiar em **25%**, qualquer detecção ou objeto com certeza inferior a 25% é descartado silenciosamente.
  - Nenhum evento é gravado e nenhuma notificação é disparada para detecções abaixo do limiar.
- Camada de sobreposição visual (`BoundingBoxOverlay`):
  - Retângulos fluorescentes discretos sobre a cena com pílula informativa no topo (`👤 Pessoa 94%`, `🚗 Veículo 88%`).
  - Suporte a interpretação semântica de cena gerada pela IA (ex: *"Pessoa se aproximando do portão principal com encomenda"*).

### 1.3. Firebase Cloud Messaging (FCM) & Roteamento por Deeplink
- Notificações push parametrizadas via Firebase Cloud Messaging com canais de alta prioridade no Android (`b_cam_surveillance_alerts`).
- Esquema de Deeplink padronizado:
  - `bcam://event/{eventId}` e `https://b-cam.app/event/{eventId}`.
- Ao clicar na notificação (ou abrir o link), o aplicativo inicializa e navega imediatamente para `EventDetailScreen`, exibindo o clipe de vídeo do evento, a descrição interpretada pela IA e a marcação das bounding boxes na cena.

### 1.4. Infraestrutura Google Cloud 100% Gratuita (Custo Zero Perpétuo)
- Toda a solução é desenhada para operar estritamente dentro dos limites perpétuos do **Google Cloud Always Free Tier** e **Firebase Spark Plan**:
  1. **Google Gemini 1.5 / 2.0 Flash API (Google AI Studio Free Tier)**: 15 requisições/minuto gratuitas, 1 milhão de tokens por minuto, sem necessidade de cartão de crédito.
  2. **Google Cloud Run / Cloud Functions**: 2 milhões de invocações gratuitas por mês e 360.000 vCPU-segundos.
  3. **Cloud Firestore (Modo Datastore/Nativo)**: 1 GB de armazenamento, 50.000 leituras/dia e 20.000 gravações/dia gratuitas.
  4. **Firebase Cloud Messaging (FCM)**: 100% Ilimitado e gratuito.
  5. **Cloud Storage**: 5 GB de armazenamento gratuito.

### 1.5. In-App Auto-Update & Esteira de Versionamento Automatizado
- O aplicativo consulta periodicamente (ou sob demanda no botão *"Atualizar App"*) o endpoint `/api/version` no servidor de distribuição.
- Caso haja versão mais recente:
  - Exibe diálogo modal com notas de lançamento e botão de confirmação.
  - Realiza o download do APK com barra de progresso em tempo real.
  - Aciona o instalador de pacotes nativo do Android (`application/vnd.android.package-archive`) via FileProvider.
- Pipeline de automação (`scripts/auto_build_and_release.sh`):
  - Incrementa automaticamente o `versionName` e `versionCode` no `pubspec.yaml`.
  - Executa testes automatizados (`flutter test`).
  - Compila binários otimizados por ABI (`arm64-v8a`).
  - Gera manifesto `dist/version.json` com checksum SHA-256 e tamanho.
  - Atualiza o servidor de distribuição e realiza deploy OTA se o celular estiver conectado.

---

## 2. Consequências

- **Positivas**:
  - Atende integralmente a todas as exigências do usuário de forma coesa e escalável.
  - Custo operacional zero para inteligência de vídeo e infraestrutura em nuvem.
  - Experiência de uso premium com tela cheia, caixas delimitadoras e deeplink instantâneo.
  - Ciclo de atualização contínua sem necessidade de recompilações manuais pelo usuário.
