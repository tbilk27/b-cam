# ADR-004: Segurança e Ofuscação de Credenciais de Câmeras

- **Status**: Aceito
- **Data**: 2026-11-20
- **Decisores**: Arquiteto de Software, Especialista Flutter, Analista QA
- **Contexto**: Fluxos RTSP com autenticação contêm o usuário e senha concatenados no formato `rtsp://user:password@ip:port/path`. Exibir essa URL crua na tela ou em relatórios vaza as senhas mestras de CFTV do usuário.

## Decisão
1. **Getter de Ofuscação Universal (`maskedStreamUrl`)**: Todas as exibições na interface, logs de depuração e telas de telemetria utilizam substituição regex mascarando a senha com `******`.
2. **Separação de Entidades**: A entidade `CameraDevice` armazena os campos de forma estruturada (`username`, `password`, `ip`, `channel`) ao invés de apenas uma string de URL estática, permitindo alternar canais e qualidades dinamicamente.
3. **Sandbox do Sistema Operacional**: Os dados locais são gravados em disco exclusivamente dentro da pasta isolada da aplicação.

## Justificativa
- Conformidade com práticas básicas de segurança e privacidade (LGPD / GDPR).
- Prevenção de vazamento acidental em gravações de tela ou compartilhamento de prints.
