# ADR-006: Amarração de Identidade da Câmera ao MAC Address para Resiliência a DHCP

- **Status**: Aceito
- **Data**: 2026-11-20
- **Decisores**: Líder Orquestrador, Arquiteto de Software, Especialista Flutter, Analista QA, Especialista UX/UI
- **Contexto**: Em redes Wi-Fi e cabeadas com roteadores comuns, os endereços IP atribuídos às câmeras de vigilância são dinâmicos (via DHCP). Sempre que o roteador ou a câmera é reiniciado (por queda de energia, reboot programado ou expiração de lease), a câmera pode receber um endereço IP completamente diferente. Se o aplicativo vincular a identidade da câmera (nome, credenciais, localização, favoritos) exclusivamente ao endereço IP, a câmera se tornará inalcançável e o usuário perderá a configuração customizada.

## Decisão
1. **Âncora Primária de Identidade**: O **MAC Address** físico da interface de rede (normalizado para letras maiúsculas e separado por dois-pontos, ex: `98:2A:0A:89:56:62`) torna-se a chave primária de identificação unívoca de cada dispositivo físico.
2. **Auto-Cura e Reconciliação Dinâmica de IP**:
   - Sempre que o scanner de rede detecta um dispositivo com um MAC Address já comissionado, o aplicativo **preserva intactos** o nome customizado pelo usuário, senha, canais e localização, atualizando de forma transparente apenas o endereço IP atual.
   - O repositório `CameraStorageService` provê o método `updateIpForMac(String mac, String newIp)` e `autoReconcileDevices(List<ScanResult> discovered)`.
3. **Mecanismo de Descoberta de MAC**:
   - Leitura direta da tabela ARP do sistema operacional (`/proc/net/arp` no Android e `arp -an` no macOS/iOS/Linux).
   - Extração do MAC ou UUID de hardware embutido no escopo ONVIF WS-Discovery (`onvif://www.onvif.org/mac/...`).
   - Fallback para UUID apenas para câmeras que residam atrás de roteadores NAT/VPN onde o MAC Ethernet não seja visível na camada 2.

## Justificativa
- **Experiência do Usuário Transparente**: O usuário nunca mais precisa reconfigurar o app quando faltar luz ou o roteador Wi-Fi reiniciar.
- **Resiliência Industrial**: Alinha o **b-cam** com as melhores práticas de NVRs corporativos e plataformas IoT de grande porte.

## Consequências
- A necessidade de garantir que o leitor de ARP execute após o handshake TCP ou probe UDP ter aquecido o cache ARP do sistema operacional.
