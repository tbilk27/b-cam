# 🔒 b-cam • Política de Segurança da Informação & Rede

Elaborado pelo **Arquiteto de Software & Líder de Segurança** (`software-architect`).

---

## 1. Princípios Fundamentais

1. **Princípio do Menor Privilégio**: As requisições de rede executadas pelo app devem limitar-se à varredura e comunicação exclusiva com as portas dos serviços de CFTV e streaming.
2. **Proteção de Credenciais em Repouso e em Trânsito**: Senhas de câmeras nunca devem ser expostas desnecessariamente, registradas em logs de depuração (*console logs*) ou transmitidas para servidores externos.
3. **Local-First & Zero Telemetria Externa**: O aplicativo opera em regime estritamente local; nenhuma informação da topologia de rede do usuário ou credenciais é enviada para a nuvem.

---

## 2. Tratamento de Credenciais RTSP

Câmeras de vigilância operam primordialmente via protocolo RTSP (RFC 2326). A autenticação segue o modelo HTTP Digest ou Basic.

### Diretrizes de Implementação:
- **Ofuscação de URLs**: Sempre que uma URL de stream for apresentada na UI ou serializada para exportação visual, ela deve utilizar o getter `maskedStreamUrl`:
  ```dart
  // Exemplo de ofuscação automática:
  // Entrada:  rtsp://admin:minhasenha123@192.168.3.74:554/cam/realmonitor...
  // Saída:    rtsp://admin:******@192.168.3.74:554/cam/realmonitor...
  ```
- **Digest Authentication First**: Priorizar o envio do desafio Digest MD5/SHA-256 para evitar envio de senhas em texto puro via Basic Auth.
- **Armazenamento Local**: A serialização local em `SharedPreferences` armazena as credenciais isoladamente dentro da sandbox do sistema operacional Android (`/data/data/com.bcam.bcam/`) e macOS sandbox (`Containers`). Para versões de produção, recomenda-se a migração para `flutter_secure_storage` (Android Keystore / iOS Keychain).

---

## 3. Segurança de Varredura de Rede (Socket Sweeper)

- **Controle de Concorrência e Resource Starvation**: O scanner varre em blocos de no máximo 32 hosts concorrentes com timeout curto (400-600ms) para evitar saturação da tabela ARP e esgotamento de descritores de arquivo do sistema.
- **Isolamento de Erros de Socket**: Cada conexão TCP de sondagem possui tratamento explícito de exceções e fechamento obrigatório no bloco `finally`, prevenindo vazamento de conexões abertas no roteador.
- **Multicast Bounds**: As sondagens WS-Discovery via UDP são limitadas à sub-rede local (`239.255.255.250:3702` e `x.x.x.255:3702`), com destruição do socket após janela de escuta de 3 segundos.

---

## 4. Política de Tráfego de Rede (Cleartext Traffic)

- Em sistemas Android modernos, o tráfego HTTP/RTSP em portas não criptografadas (porta 80, 554) requer configuração explícita de `android:usesCleartextTraffic="true"`.
- Essa permissão é estritamente justificada pela natureza dos fluxos locais de CFTV legados que não suportam RTSPS / TLS nativo.
- As chamadas de API externas do sistema (ex: MacVendors OUI) utilizam exclusivamente **HTTPS (TLS 1.3)**.
