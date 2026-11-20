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

## 🚀 Backlog Priorizado (Próximos Passos)

- [ ] **EPIC-01: Controle PTZ Real via ONVIF SOAP**:
  - Implementar o envio real dos comandos PTZ (Pan/Tilt/Zoom) usando chamadas SOAP HTTP para o serviço ONVIF `PTZBinding` das câmeras compatíveis.
- [ ] **EPIC-02: Gravação e Captura de Clipes Locais**:
  - Permitir gravação contínua ou por detecção de movimento em formato MP4 armazenado no armazenamento interno do celular.
- [ ] **EPIC-03: Notificações de Alarme / Movimento**:
  - Integração com webhooks ou detecção de eventos ONVIF (`PullPointSubscription`) para notificar o usuário quando houver movimento.
- [ ] **EPIC-04: Suporte a RTSPS (TLS) e Criptografia no Repouso com Keystore**:
  - Migrar o armazenamento de credenciais de `SharedPreferences` para `flutter_secure_storage`.
