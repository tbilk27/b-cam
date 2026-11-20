# ADR-013: Esteira de Deploy Contínuo Over-The-Air (OTA) Autônomo via Wireless ADB

## Status
Aprovado / Implementado

## Data
2026-11-20

## Contexto
O usuário solicitou que todas as atualizações no aparelho físico (Xiaomi Redmi Note 10S, `192.168.3.13`) ocorram 100% via rede Wi-Fi local sem exigir qualquer confirmação, toque em botões ou assistência manual do usuário ("atualize o app no meu celular pela wifi sem precisar da minha ajuda. vou deixar o debug wireless aberto").

Em dispositivos Xiaomi (MIUI / HyperOS), o comando padrão `adb install -r <arquivo>` normalmente aciona uma restrição de segurança (`INSTALL_FAILED_USER_RESTRICTED`) ou exibe um pop-up com contagem regressiva de 10 segundos ("Instalar via USB?") quando a opção "Instalar via USB com conta Mi" não está ativada.

## Decisões Arquiteturais

1. **Pipeline de Instalação Silenciosa Autônoma**:
   - Criação do script de automação `scripts/deploy_to_phone.sh`.
   - **Mecanismo de Desvio de Restrição**:
     1. O binário ARM64 otimizado (`dist/b-cam-arm64.apk`) é enviado diretamente via ADB para a área de staging local do sistema: `/data/local/tmp/app.apk`.
     2. A instalação é executada via comando interno do gerenciador de pacotes Android:
        `adb shell "pm install -r /data/local/tmp/app.apk && rm /data/local/tmp/app.apk"`
     3. Esse método instala o APK com permissões nativas do subsistema de pacotes, garantindo retorno `Success` imediato sem exibir janelas de confirmação ou contadores de 10 segundos da MIUI.
     4. A inicialização da aplicação é disparada via `am start -n com.bcam.bcam/.MainActivity`.
     5. O arquivo temporário em `/data/local/tmp` é removido imediatamente para economizar espaço de armazenamento no celular.

2. **Detecção e Resiliência de Conexão Wireless ADB**:
   - O script detecta automaticamente o serial mDNS do dispositivo (`adb-XWQ8EQZTDMI7WO4X-8kCTNJ._adb-tls-connect._tcp`) ou varre dinamicamente a porta de Wireless Debugging no IP `192.168.3.13`.

3. **Validação de Integridade Pós-Deploy**:
   - O script aguarda 3 segundos e consulta o endpoint de status do servidor de telemetria interno: `http://192.168.3.13:8089/api/status`.

## Consequências
- Zero atrito para o usuário: o agente pode atualizar, testar e reiniciar o aplicativo de vigilância no celular do usuário a qualquer momento enquanto o depurador wireless estiver ativo.
- Processo 100% documentado, seguro e auditável.
