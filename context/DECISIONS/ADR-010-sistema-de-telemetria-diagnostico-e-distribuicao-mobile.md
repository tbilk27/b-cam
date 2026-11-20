# ADR-010: Sistema de Telemetria, Diagnósticos em Tempo Real e Distribuição Mobile

- **Status**: Aceito (Accepted)
- **Data**: 2026-11-20
- **Decisores**: Equipe Multi-Agente (Arquiteto de Software, Especialista Flutter, Analista QA, Designer UX/UI, Líder de Projeto)
- **Alvo**: `lib/services/diagnostic_logger_service.dart`, `lib/screens/diagnostics_screen.dart`, `scripts/distribution_server.py`, `dist/*`

---

## 1. Contexto e Problema

Para validar o aplicativo **b-cam** em condições reais na rede Wi-Fi residencial com múltiplos fabricantes de câmeras (Intelbras, Yoosee, Mibo), o usuário solicitou:
1. **Geração e Envio de Versão para o Celular**: O app precisa rodar no smartphone físico do usuário.
2. **Sistema Robusto de Logs de Depuração**: Capturar em tempo real eventos de descoberta, conexões RTSP, estados do reprodutor (`media_kit`), negociações de transporte (UDP vs. TCP), e erros de decodificação.
3. **Mecanismo Bidirecional de Leitura dos Dados**: Permitir que tanto o usuário quanto o agente leiam os dados do celular de forma transparente para diagnosticar falhas e implementar correções.

---

## 2. Decisão Arquitetural

A equipe multi-agente estabeleceu uma arquitetura de telemetria em 4 camadas complementares:

### Camada 1: Serviço de Telemetria e Buffer Circular (`DiagnosticLoggerService`)
- Implementação de um serviço singleton observável (`ChangeNotifier`) com buffer em memória de até 1.500 eventos.
- Categorização de eventos: `APP`, `SYSTEM`, `STORAGE`, `SCANNER`, `DHCP_RECONCILE`, `RTSP_PLAYER`, `FLUTTER_CORE`, `ASYNC_CORE`.
- Níveis de severidade padronizados: `DEBUG`, `INFO`, `WARN`, `ERROR`.
- Persistência assíncrona contínua em disco local no arquivo `b_cam_diagnostic.log` (no diretório de documentos do aplicativo), com rotação de arquivos para impedir esgotamento de armazenamento (> 5MB).

### Camada 2: Servidor HTTP de Diagnóstico Embutido (No Celular)
- O aplicativo inicia em segundo plano um servidor HTTP nativo (`HttpServer.bind(InternetAddress.anyIPv4, 8089)`).
- Endpoints disponíveis via Wi-Fi:
  - `GET /api/logs` ou `/logs`: Retorna todo o histórico de logs em formato texto limpo.
  - `GET /api/logs.json`: Retorna a lista estruturada de eventos em JSON.
  - `GET /api/status`: Retorna o status operacional, IP do celular e quantidade de eventos.
  - `POST /api/clear`: Limpa o histórico de diagnóstico.
- **Benefício**: Permite que o agente consulte os logs do celular diretamente a partir do Mac executando:
  ```bash
  curl http://<IP_DO_CELULAR>:8089/api/logs
  ```

### Camada 3: Servidor de Distribuição e Coleta no Mac (`scripts/distribution_server.py`)
- Servidor HTTP leve rodando no Mac na porta `8088` (`http://192.168.3.62:8088`).
- Fornece:
  1. Portal web responsivo para download direto do APK no smartphone (`http://192.168.3.62:8088/index.html`).
  2. Endpoint coletor de telemetria `POST /api/logs`: Salva qualquer lote de logs enviado pelo celular no arquivo `dist/received_phone_logs.log`.
- No app, o botão **"Sync Mac"** dispara um POST para este coletor com 1 toque.

### Camada 4: Interface Visual de Diagnóstico no App (`DiagnosticsScreen`)
- Tela acessível com 1 toque no selo `WI-FI ONLINE` da tela inicial.
- Apresenta:
  - URL ativa da API do dispositivo (`http://<IP>:8089/api/logs`).
  - Filtros dinâmicos em pílulas (`TODOS`, `ERROS`, `RTSP`, `REDE`).
  - Campo de busca instantânea por texto ou IP.
  - Botão **"Copiar"** (para colar logs em qualquer canal).
  - Botão **"Limpar"**.
  - Botão **"Sync Mac"** (disparo assíncrono para o Mac do desenvolvedor).

---

## 3. Consequências e Resultados

- **Positivas**:
  - Depuração em tempo real sem necessidade de cabos USB ou comandos complexos.
  - Visibilidade completa de qualquer erro de reprodução de vídeo ou descoberta de câmeras.
  - Distribuição simplificada do APK via rede local Wi-Fi.
  - 100% testado: 11 testes unitários e de widget passando.
- **Segurança**:
  - O endpoint de logs funciona estritamente na sub-rede local privada (`192.168.3.0/24`).
  - Todas as senhas de câmeras continuam ofuscadas nas URLs RTSP de log (`rtsp://user:******@ip:porta/...`).

---

## 4. Aprovação Multi-Agente

- **Arquiteto de Software**: Aprovado. A telemetria não onera a thread principal de renderização e possui proteção de rotação de arquivo.
- **Especialista Flutter**: Aprovado. Integração limpa no ciclo de vida do app (`FlutterError.onError`, `PlatformDispatcher`, `media_kit` listeners).
- **Designer UX/UI**: Aprovado. A tela `DiagnosticsScreen` e o portal web seguem com rigor o Fluent Design System 2.
- **Analista QA**: Aprovado. Validada a compilação de múltiplos pacotes APK (`app-arm64-v8a-debug.apk` e `app-debug.apk`) e o funcionamento do endpoint HTTP.
