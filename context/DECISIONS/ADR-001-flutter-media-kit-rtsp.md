# ADR-001: Seleção do Flutter e media_kit para Streaming RTSP Multiplataforma

- **Status**: Aceito
- **Data**: 2026-11-20
- **Decisores**: Líder Orquestrador, Arquiteto de Software, Especialista Flutter
- **Contexto**: A aplicação necessita reproduzir fluxos RTSP H.264/H.265 de baixa latência em Android, iOS e macOS, com suporte a múltiplos players simultâneos (grade multiview) e aceleração de hardware.

## Decisão
Adotar o ecossistema **Flutter** com o pacote **`media_kit`** (`media_kit_video` + `media_kit_libs_*`).

## Justificativa
1. **Desempenho Baseado em libmpv / ffmpeg**: `media_kit` é a biblioteca de streaming de vídeo mais madura e performática no ecossistema Flutter atual, suportando decodificação por hardware direta (MediaCodec no Android, VideoToolbox no macOS/iOS).
2. **Suporte Nativo a RTSP / H.264 / H.265**: Não requer conversão em servidor para WebRTC ou HLS intermediário. A conexão conecta diretamente da aplicação cliente para a câmera IP.
3. **Múltiplas Instâncias em Grade**: Capacidade de renderizar grids 2x2 e 3x3 com baixo consumo de memória RAM e GPU.

## Consequências
- Exigência de configuração do NDK e compilação de binários nativos no Gradle Android.
- Necessidade de permissão explícita de `usesCleartextTraffic="true"` no Android para fluxos RTSP locais sem criptografia TLS.
