# ADR-011: Motor de Resiliência com Auto-Reconexão Contínua, Filtro Não-Fatal libmpv e Diagnóstico Mibo

## Status
Aprovado / Implementado

## Data
2026-11-20

## Contexto
Durante os testes de campo realizados com o dispositivo físico Xiaomi Redmi Note 10S (`model: M2101K7BNY`, IP `192.168.3.13`), foram identificados dois pontos críticos através da telemetria ativa do `DiagnosticLoggerService` (porta HTTP 8089):

1. **Necessidade de Reconexão Manual na Tela Principal**:
   - As câmeras exibiam frequentemente estado `OFFLINE` / `FLUXO INDISPONÍVEL` exigindo que o usuário clicasse manualmente em "Reconectar".
   - A telemetria revelou que o `libmpv` emite avisos normais de seek durante o handshake de streams RTSP ao vivo: `libmpv: Cannot seek in this stream.` e `libmpv: You can force it with --force-seekable=yes`.
   - O player de vídeo tratava qualquer evento no canal de erro como falha fatal, derrubando o fluxo de câmeras plenamente operacionais (como a Intelbras Frente `192.168.3.74`).
   - Quando ocorriam quedas ou trocas de aplicativo, não havia reconexão automática em segundo plano nem retenção de estado de decodificação.

2. **Câmera Intelbras Mibo (192.168.3.22) Offline**:
   - A câmera está online e ativa na rede (portas 80 e 554 abertas, MAC `18:0D:2C:5D:96:FD`).
   - O servidor RTSP da câmera retorna consistentemente `401 Unauthorized` (`realm="180d2c5d96fd"`).
   - O motivo decorre da arquitetura do firmware Intelbras Mibo: as credenciais da nuvem (`hostemd@gmail.com` / `compras10`) não são aceitas pelo daemon RTSP local da câmera. O usuário do stream local é obrigatoriamente `admin`, e a senha é o **Safety Code / Código de Verificação** de 6 caracteres impresso na etiqueta física da câmera (ou a senha local do dispositivo cadastrada no app Mibo Cam).

3. **RenderFlex Overflows**:
   - Estouro de 28 pixels na coluna de erro/reconexão do player em telas compactas.
   - Estouro de 6.5 pixels na barra de ações da tela principal.

## Decisões Arquiteturais

1. **Filtro de Eventos Não-Fatais no libmpv**:
   - `LivePlayerView` filtra e descarta mensagens benignas de seek (`Cannot seek`, `force-seekable`, `Seeking is not supported`, `demux_rtsp`).
   - O player permanece reproduzindo o vídeo sem interrupções indesejadas.

2. **Motor de Reconexão Automática Escalonada (Auto-Reconnect Engine)**:
   - Implementado algoritmo de retry progressivo com contagem regressiva em tempo real: 2s (1ª tentativa), 4s (2ª), 7s (3ª) e 10s (subsequentes).
   - Listeners dedicados para `_player.stream.completed` (quedas de socket) e `_player.stream.playing` (auto-cancelamento do retry ao reconectar).
   - Watchdog periódico que detecta streams congelados ou em buffering excessivo e dispara reconexão preventiva.
   - Alternância dinâmica de transporte (UDP ↔ TCP) para fabricantes sensíveis (Yoosee) caso tentativas sucessivas falhem.

3. **Sincronização de Ciclo de Vida (`WidgetsBindingObserver`) e Retenção (`AutomaticKeepAliveClientMixin`)**:
   - `LivePlayerView` implementa `WidgetsBindingObserver`: ao retomar o app do segundo plano (`AppLifecycleState.resumed`), verifica e revalida imediatamente todos os fluxos.
   - `AutomaticKeepAliveClientMixin` com `wantKeepAlive => true` impede o descarte do decodificador durante rolagem vertical na lista.

4. **Botão de Reconexão Geral e Responsividade 0-Overflow**:
   - Botão de atualização rápida (`FluentIcons.refresh`) na barra de ferramentas da tela principal para disparo simultâneo de reconexão de todas as câmeras via chave reativa.
   - Todos os painéis de erro e reconexão encapsulados em `FittedBox(fit: BoxFit.scaleDown)` garantindo 0 pixel overflow em qualquer resolução ou densidade de tela.

5. **Diretrizes para Comissionamento de Câmeras Intelbras Mibo**:
   - O app e a documentação orientam o usuário a utilizar o usuário `admin` acompanhado do Código de Verificação (Safety Code) da etiqueta QR code da câmera para liberação do RTSP.

## Consequências
- Fim da necessidade de intervenção manual do usuário para manter as câmeras conectadas.
- Experiência contínua e autônoma de videovigilância residencial.
- 0 pixel overflow verificado.
- Telemetria transparente via porta `8089` para monitoramento contínuo.
