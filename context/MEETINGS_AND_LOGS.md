# 📝 b-cam • Registro de Reuniões, Decisões e Backlog Ativo

Registro cronológico mantido pelo **Líder de Projeto & Orquestrador Geral**.

---

## 📅 Reunião de Kickoff & Alinhamento Estratégico (Sprint 1)
- **Data**: 2026-11-20
- **Participantes**:
  - Usuário / Stakeholder Principal
  - Líder de Projeto & Orquestrador Geral
  - Arquiteto de Software & Segurança
  - Desenvolvedor Flutter Especialista
  - Analista de Qualidade (QA)
  - Especialista em Usabilidade (UX/UI)

### Pautas Tratadas:
1. **Definição do Propósito**: Criar uma aplicação móvel em Flutter para acesso e comissionamento ultra-facilitado de câmeras de vigilância IP na rede Wi-Fi.
2. **Varredura da Rede Local**: Executada varredura na rede Wi-Fi `192.168.3.0/24` do usuário, localizando 4 câmeras reais (2 Intelbras e 2 Xiongmai/Tuya).
3. **Identidade Visual**: Aprovado o tema baseado nas cores de GTA VI (Vice City), com criação do logotipo `b-cam` e ícones de app.
4. **Governança Multi-Agente**: Formalizada a divisão em 5 papéis e a criação do repositório de contexto `context/` versionado no GitHub.
5. **Execução no Emulador**: Compilação do APK e execução validada com sucesso no Android 14 (`emulator-5554`).

### Decisões Registradas:
- [x] Adoção do `media_kit` como motor padrão de reprodução de vídeo RTSP.
- [x] Criação do radar de varredura visual com detecção automática de fabricante.
- [x] Mascaramento automático de senhas em URLs RTSP para evitar vazamento visual.
- [x] Persistência das decisões no repositório GitHub do usuário sob a pasta `context/`.
- [x] **ADR-006: Amarração de Identidade ao MAC Address**: Nome, credenciais e configurações vinculados ao MAC físico permanente para tolerância total a reboots de roteador e renovação de lease DHCP.

---

## 📅 Sprint 1.1 • Amarração de Identidade ao MAC Address & Resiliência DHCP
- **Data**: 2026-11-20
- **Solicitante**: Usuário
- **Parecer dos Agentes**:
  - **Arquiteto de Software**: Elaborou ADR-006 definindo normalização do MAC como identificador imutável e separação entre camada de hardware e lease de rede.
  - **Desenvolvedor Flutter**: Implementou leitor ARP dinâmico (`/proc/net/arp` no Android e `arp -an` no macOS), reconciliação automática de IPs no `CameraStorageService` e normalizador de MACs.
  - **Analista QA**: Criou cenários de teste unitário simulando alteração de IP pelo roteador com preservação integral de nome e credenciais.
  - **Especialista UX/UI**: Garantiu que o processo de remapeamento ocorra de forma silenciosa e sem exigir intervenção do usuário, exibindo badge de MAC Address na telemetria.

---

## 📅 Sprint 1.2 • Remoção de Câmeras de Exemplo & Estado Pristino na Tela Inicial
- **Data**: 2026-11-20
- **Solicitante**: Usuário
- **Parecer dos Agentes**:
  - **Líder de Projeto / Orquestrador**: Removeu qualquer mock ou pré-população na inicialização do app. O app inicia 100% limpo, exibindo apenas as câmeras reais que o usuário comissionar.
  - **Especialista UX/UI**: Redesenhou o Empty State da `HomeScreen`. Em vez de cards fictícios, exibe um painel HUD elegante com mensagem explicativa e CTA direto para abrir o Radar de Varredura Wi-Fi em um toque.
  - **Desenvolvedor Flutter**: Eliminou o seed mock do `CameraStorageService`, adicionou método `clearAll()`, otimizou a varredura do `NetworkScannerService` com testes de portas simultâneos (`Future.wait`) e injeção em lote da tabela ARP.
  - **Analista QA**: Validou o estado inicial no emulador Android (`emulator-5554`) após limpeza de dados (`pm clear`), confirmando 0 câmeras no boot e transição fluida para a tela de varredura.

---

## 📅 Sprint 1.3 • Criação da Nova Logo, Ícone Oficial e Pipeline Gráfico Multiplataforma
- **Data**: 2026-11-20
- **Solicitante**: Usuário ("crie uma nova logo e ícone para o sistema")
- **Parecer dos Agentes**:
  - **Especialista UX/UI & Designer Gráfico**: Concebeu a nova linguagem visual unificada no estilo GTA VI Vice City Cyber-Surveillance. Criou o ícone primário combinando a inicial minúscula 'b' com uma lente de câmera de segurança (aperture iris) em titânio escuro, iluminação neon dupla (magenta + ciano), ponto LED `REC` pulsante e reflexo de vidro curvo. Produziu também a apresentação widescreen do logotipo oficial `b-cam SURVEILLANCE RADAR`.
  - **Engenheiro de Assets / Automação**: Desenvolveu pipeline de renderização e redimensionamento via Pillow (Lanczos), gerando automaticamente todas as variantes em alta definição para Android (`res/mipmap-*`), iOS (`AppIcon.appiconset`), macOS (`AppIcon.appiconset`), Web (`web/icons/`, `favicon.png`), Windows (`app_icon.ico`) e `assets/images/`.
  - **Desenvolvedor Flutter**: Aprimorou o componente vetorial `GtaLogo` com animação sutil das pás de abertura do diafragma (*iris blades*) e pulso dinâmico do indicador vermelho de gravação.
  - **Analista QA**: Executou os testes unitários e de widget (`flutter test`) confirmando integridade total do app.
- **Aprovação do Stakeholder & Formalização (ADR-007)**:
  - O usuário manifestou aprovação explícita da logo e da paleta ("gostei da logo e das cores, defina esa logo e core nas diretrizes do projeto").
  - Redigida e aprovada a **ADR-007: Definição Oficial do Logotipo, Ícone do App e Diretrizes Cromáticas**.
  - Atualizadas as diretrizes centrais no `PROJECT_CHARTER.md` (Seção 1.1) e `UX_DESIGN_SYSTEM.md` (Seção 2 e 5), tornando estes padrões obrigatórios e canônicos para todo o ciclo de evolução do produto.

---

## 📅 Sprint 1.4 • Testes Práticos na Rede Local com Câmeras Reais e Perfis Especializados
- **Data**: 2026-11-20
- **Solicitante**: Usuário ("Implemente tudo o que precisa nas câmeras e faça um teste na rede local... tome suas decisões q volto mais tarde")
- **Credenciais Fornecidas**:
  - Intelbras Frente da Casa: Usuário `admin`, Senha `Zs29364835`
  - Yoosee: Conta `hostemd@gmail.com`, Senha `Compras10@`
  - Intelbras Mibo: Conta `hostemd@gmail.com`, Senha `compras10`
- **Parecer dos Agentes e Implementações**:
  - **Arquiteto de Software & Segurança**:
    - Elaborou **ADR-008: Perfis Especializados (Yoosee & Mibo), URL Encoding e Negociação de Transporte UDP/TCP**.
    - Identificou e corrigiu vulnerabilidade de parsing em URLs RTSP quando a senha possui caracteres especiais (`@`), instituindo `Uri.encodeComponent`.
    - Mapeou as diferenças de protocolo: Yoosee (`RtspServer_0.0.0.2`) opera estritamente com pacotes RTP via UDP; Intelbras opera com RTSP Digest sobre TCP.
  - **Desenvolvedor Flutter**:
    - Adicionou perfis dedicados `CameraManufacturer.yoosee` e `CameraManufacturer.intelbrasMibo` em `lib/models/manufacturer.dart`.
    - Ajustou `LivePlayerView` (`media_kit`) para configurar dinamicamente propriedades de socket `rtsp-transport=udp` e `demuxer-lavf-o=rtsp_transport=udp` para dispositivos Yoosee.
    - Implementou atalhos e avisos contextuais na tela de comissionamento (`CommissionScreen`).
    - Eliminou qualquer overflow na `MultiGridScreen` (ajuste adaptativo para miniaturas offline).
  - **Analista QA**:
    - Executou testes práticos na rede local `192.168.3.0/24`, capturando frames reais (`ffprobe` / `ffmpeg`):
      1. `192.168.3.74`: Intelbras Frente da Casa (3MP 2304x1296 H.265 a 25 fps) -> **100% OPERACIONAL**.
      2. `192.168.3.23`: Yoosee Corredor & Jardim (1080p 1920x1080 H.265 a 15 fps via UDP) -> **100% OPERACIONAL**.
      3. `192.168.3.24`: Yoosee Área Gourmet / Fundos (1080p 1920x1080 H.265 a 15 fps via UDP) -> **100% OPERACIONAL**.
      4. `192.168.3.22`: Intelbras Mibo (App-webs / Realm `180d2c...`). Mapeada a necessidade do Código de Verificação (Safety Code) caso criptografia esteja ativa.
    - Validou no emulador Android (`emulator-5554`) a reprodução simultânea de todas as câmeras em modo Matriz (2x2 Quad) e modo Individual com telemetria completa.

---

## 📅 Sprint 1.5 • Migração para Microsoft Fluent UI (Fluent 2) e Paleta Sóbria de Monitoramento
- **Data**: 2026-11-20
- **Solicitante**: Usuário ("mude o tema base do app para usar uma biblioteca como fluent_ui e com cores mais sóbrias, ficou muito 'escandaloso' este design system. quero algo mais moderno, simples e objetivo. Mas mantenha a definição da logo e ícones do projeto.")
- **Parecer dos Agentes e Implementações**:
  - **Especialista UX/UI**:
    - Substituiu o tema vibrante/neon anterior por uma linguagem executiva baseada no Microsoft Fluent Design System 2.
    - Definiu a nova paleta de vigilância sóbria (`#1B1B1F` dark zinc base, `#242429` mica surface, `#0078D4` cobalt blue accent, `#107C41` green online status).
    - Preservou a marca oficial e o avatar `b-cam` (`assets/images/b_cam_icon.jpg`), criando o componente `BCamLogo` corporativo com badge "PRO".
  - **Arquiteto de Software**:
    - Formalizou **ADR-009: Migração para Fluent UI (Microsoft Fluent 2) e Design System Sóbrio**.
    - Garantiu o desacoplamento do novo tema em `lib/theme/fluent_theme.dart` e compatibilidade total de tipos e rotas com `FluentPageRoute`.
  - **Desenvolvedor Flutter**:
    - Adicionou `fluent_ui: 4.15.1` ao `pubspec.yaml`, pinado para compatibilidade exata com o SDK Flutter 3.41.9 / Dart 3.11.5 da máquina.
    - Refatorou todas as 5 telas da aplicação para Fluent UI:
      1. `HomeScreen`: `PageHeader`, pills dinâmicos de filtro, cards de câmera com HUD limpo e menus em `ContentDialog`.
      2. `ScanScreen`: `ProgressBar`, formulário de sub-rede `TextBox`, `InfoBar` corporativo e comissionamento em 1 clique.
      3. `MultiGridScreen`: Alternador de modos 1, 2 e 3 colunas, grid responsivo sem overflow.
      4. `CameraDetailScreen`: Player 16:9, botões compactos ("Snapshot", "HD Principal"), controle virtual PTZ (D-Pad + Slider com `-` e `+`) e tabela detalhada de telemetria.
      5. `CommissionScreen`: Seletor horizontal de fabricantes, campos `TextFormBox`, dropdown `ComboBox`, atalhos de credenciais da rede e `InfoBar` de dicas para câmeras Mibo.
    - Encapsulou todos os `ScaffoldPage` em `SafeArea` para perfeita integração com notches e barras de status de dispositivos móveis.
  - **Analista QA**:
    - `flutter analyze`: 0 erros.
    - `flutter test`: 9/9 testes unitários e de widget passando com 100% de sucesso.
    - Validou no emulador Android (`emulator-5554`), capturando screenshots de todas as telas (Home, Scan, Matriz Grid, Detalhe e Comissionamento), confirmando 0 pixel overflow e alta fidelidade visual.
  - **Líder de Projeto & Orquestrador**:
    - Contexto atualizado, ADR-009 arquivada e sincronização realizada no GitHub.

---

## 📅 Sprint 1.6 • Telemetria Contínua, Diagnósticos em Tempo Real e Distribuição Mobile
- **Data**: 2026-11-20
- **Solicitante**: Usuário ("pode gerar uma versão e mandar para meu celular p eu testar? já implemente tudo o que precisa de log de depuração pera capturar tudo o que precisa para testes. Depois você pode ler os dados do meu celular para identificar possíveis erros...")
- **Parecer dos Agentes e Implementações**:
  - **Arquiteto de Software & Segurança**:
    - Elaborou a **ADR-010: Sistema de Telemetria, Diagnósticos em Tempo Real e Distribuição Mobile**.
    - Projetou arquitetura de diagnóstico de 4 vias: buffer em memória, arquivo local persistente rotativo, servidor HTTP embutido no celular (porta 8089) e servidor de distribuição/coleta no Mac (porta 8088).
  - **Desenvolvedor Flutter**:
    - Desenvolveu `DiagnosticLoggerService`: captura de ciclo de vida, varreduras de rede, eventos de reprodução RTSP, erros de decodificação e exceções globais.
    - Criou a tela `DiagnosticsScreen` em Fluent UI com visualização em tempo real, filtros por categoria, busca, cópia e transmissão para o Mac.
    - Compilou os pacotes APK divididos por arquitetura (`b-cam-arm64.apk` de 105MB e `b-cam.apk` universal).
  - **Analista QA**:
    - Criou suite de testes unitários para o serviço de telemetria (`test/diagnostic_logger_test.dart`). Totalizando 11 testes automatizados (100% aprovados).
    - Validou no emulador Android e no servidor local Mac (`192.168.3.62:8088`), confirmando recepção de logs e download de APKs.
  - **Líder de Projeto & Orquestrador**:
    - Iniciou o servidor local de distribuição e recepção de logs, disponibilizando o portal de instalação na rede Wi-Fi.

---

## 🚀 Backlog Priorizado (Próximos Passos)

- [ ] **EPIC-01: Controle PTZ Real via ONVIF SOAP**:
  - Implementar o envio real dos comandos PTZ (Pan/Tilt/Zoom) usando chamadas SOAP HTTP para o serviço ONVIF `PTZBinding` das câmeras compatíveis.
- [ ] **EPIC-02: Gravação e Captura de Clipes Locais**:
  - Permitir gravação contínua ou por detecção de movimento em formato MP4 armazenado no armazenamento interno do celular.
- [ ] **EPIC-03: Notificações de Alarme / Movimento**:
  - Integração com webhooks ou detecção de eventos ONVIF (`PullPointSubscription`) para notificar o usuário quando houver movimento.
- [ ] **EPIC-04: Suporte a RTSPS (TLS) e Criptografia no Repouso com Keystore**:
  - Migrar o armazenamento de credenciais de `SharedPreferences` para `flutter_secure_storage`.
