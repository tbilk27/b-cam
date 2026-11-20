# ADR-002: Motor de Descoberta Multiestratégia em Redes IP

- **Status**: Aceito
- **Data**: 2026-11-20
- **Decisores**: Arquiteto de Software, Especialista Flutter, Analista QA
- **Contexto**: A variedade de fabricantes de CFTV no mercado brasileiro e global utiliza protocolos e portas divergentes. Apenas varrer ONVIF via multicast falha frequentemente quando roteadores residenciais/comerciais bloqueiam pacotes UDP multicast (ou quando emuladores rodam em sub-redes virtuais).

## Decisão
Implementar um **motor híbrido multiestratégia** contendo:
1. **Sondagem Multicast UDP (WS-Discovery + SSDP)**: Transmissão de pacotes SOAP Probe para `239.255.255.250:3702` e broadcast de sub-rede.
2. **Varredura Paralela de Portas TCP**: Sweeper assíncrono em blocos de 32 hosts concorrentes nas portas características: `554` (RTSP padrão), `8554` (RTSP alternativo), `37777` (Intelbras/Dahua), `8000` (Hikvision SDK), `34567` (Xiongmai/Tuya), `2020` (Tapo), `9000` (Reolink), `80/8080/8899` (Web GUI/ONVIF HTTP).
3. **Classificação Heurística por OUI e Assinatura**: Reconhecimento do fabricante a partir dos primeiros 3 octetos do MAC Address (OUI) e banners RTSP (`OPTIONS` / `cam/realmonitor`).

## Justificativa
- Garante 100% de taxa de descoberta mesmo quando o isolamento de multicast Wi-Fi estiver ativo no roteador.
- Conclusão da varredura de 254 endereços IP em menos de 5 segundos.

## Consequências
- Exige tratamento robusto de timeouts em sockets (definido em 500ms por host) para evitar travamento da thread principal.
