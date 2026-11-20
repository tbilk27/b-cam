# ADR-008: Perfis Especializados (Yoosee & Mibo), URL Encoding e Negociação de Transporte UDP/TCP

- **Status**: Aceito (Accepted)
- **Data**: 2026-11-20
- **Decisores**: Equipe Multi-Agente (Arquiteto de Software, Especialista Flutter, Analista QA, Líder de Projeto)
- **Alvo**: `lib/models/manufacturer.dart`, `lib/models/camera_device.dart`, `lib/services/network_scanner_service.dart`, `lib/widgets/live_player_view.dart`

---

## 1. Contexto e Problema

Durante a validação prática na rede local do usuário (`192.168.3.0/24`) com equipamentos físicos reais (Intelbras e Yoosee/Xiongmai), foram detectados três comportamentos fundamentais do mundo real:

1. **Credenciais com Caracteres Especiais**:
   - Senhas como `Compras10@` possuem caracteres reservados em especificações de URI (`RFC 3986`).
   - A concatenação direta `rtsp://admin:Compras10@@IP:554/onvif1` corrompe o parser RTSP/FFmpeg, gerando erro de hostname ou sintaxe inválida.

2. **Divergência de Transporte RTSP (UDP vs. TCP Interleaved)**:
   - Câmeras padrão corporativo (Intelbras / Dahua / Hikvision) suportam RTSP interleaved sobre TCP na porta 554 com digest authentication.
   - Câmeras Yoosee (`RtspServer_0.0.0.2`) aceitam comandos RTSP mas rejeitam interleaving TCP no método `SETUP` (`Nonmatching transport in server reply`), operando exclusivamente com pacotes RTP via UDP.

3. **Câmeras Intelbras Linha Mibo**:
   - As câmeras Intelbras Mibo (`iM3`, `iM4`, `iC3`) utilizam servidor embarcado `App-webs/` com Realm no formato do MAC address da câmera (`180d2c...`).
   - Quando a criptografia de vídeo está ativa no aplicativo Mibo Cam, a senha RTSP local exigida é o **Código de Verificação de 6 dígitos** (Safety Code) impresso na etiqueta adesiva da câmera, e não a senha da nuvem.

---

## 2. Decisão Arquitetural

1. **Codificação Obrigatória de Credenciais em URIs**:
   - Todo usuário e senha fornecido na construção de URLs RTSP passa por `Uri.encodeComponent()`.
   - Exemplo: `Compras10@` torna-se `Compras10%40`, garantindo conformidade absoluta com `RFC 3986` e aceitação por demuxers FFmpeg / mpv.

2. **Criação de Perfis Nativos `yoosee` e `intelbrasMibo`**:
   - `CameraManufacturer.yoosee`: Caminho padrão `/onvif1` (Main) e `/onvif2` (Sub), portas 554 / 5000.
   - `CameraManufacturer.intelbrasMibo`: Caminho padrão `/cam/realmonitor?channel=1&subtype=0`, portas 554 / 80 / 443.

3. **Ajuste Dinâmico de Transporte de Fluxo (`media_kit`)**:
   - Em `LivePlayerView`, a engine `media_kit` (libmpv) ajusta os parâmetros de socket com base no fabricante detectado:
     - `yoosee`: `rtsp-transport = udp`, `demuxer-lavf-o = rtsp_transport=udp`.
     - `intelbras / outros`: `rtsp-transport = tcp`.

4. **Presets de Comissionamento Rápido no Frontend**:
   - A tela `CommissionScreen` detecta o IP e fabricante e oferece atalhos de 1 toque para as credenciais conhecidas, além de exibir um aviso orientando sobre o Código de Verificação (Safety Code) nas câmeras Mibo.

---

## 3. Consequências e Resultados

- **Positivas**:
  - Reprodução simultânea fluida de fluxos H.265/HEVC das câmeras Yoosee e Intelbras em 1080p e 3MP.
  - Eliminação de falhas de autenticação causadas por `@`, `#`, `$` ou caracteres especiais em senhas.
  - Visualização unificada na Matriz de Monitoramento com ajuste automático de aspect ratio para evitar qualquer overflow visual.
- **Negativas / Riscos Mitigados**:
  - Para câmeras Mibo com criptografia ativa, o usuário deve consultar a etiqueta física caso a senha da conta não seja aceita pelo firmware local. Orientações claras foram integradas na interface.
