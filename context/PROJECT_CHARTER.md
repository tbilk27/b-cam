# 📋 b-cam • Carta do Projeto (Project Charter)

## 1. Visão Geral do Produto
O **b-cam** é uma aplicação multiplataforma desenvolvida em Flutter criada para revolucionar o acesso, monitoramento e comissionamento de câmeras de vigilância IP conectadas em redes Wi-Fi e cabeadas locais.

Diferente de softwares de CFTV tradicionais (pesados, complexos e visualmente desatualizados), o **b-cam** combina:
1. **Varredura Ativa Multiestratégia**: Descoberta automática de câmeras de múltiplos fabricantes na mesma sub-rede (Intelbras, Dahua, Hikvision, TP-Link Tapo, Xiongmai/Tuya, Reolink e ONVIF genérico).
2. **Comissionamento em 1 Toque**: Dedução inteligente de modelos, resolução de templates de URL RTSP e atalhos para credenciais de fábrica.
3. **Identidade Visual Inspirada em GTA VI (Vice City)**: Marca oficial aprovada (ADR-007) com logotipo widescreen `b-cam SURVEILLANCE RADAR`, ícone em titânio e neon, gradientes Vice City Sunset (`#FF2A85`, `#FF6A00`, `#FFD200`), ciano elétrico de telemetria (`#00F0FF`), superfícies de vidro escurecido (*glassmorphism* em `#090814`/`#1B1834`), elementos HUD de mira digital e radar animado.
4. **Desempenho Nativo em Baixa Latência**: Decodificação de vídeo RTSP H.264/H.265 acelerada por hardware via `media_kit`.

---

## 1.1 Diretriz Institucional de Marca (ADR-007)
- **Logotipo Oficial**: Símbolo da letra minúscula `b` integrada a uma lente objetiva com diafragma animado, ponto `REC` ativo e tipografia display futurista com gradiente pôr do sol.
- **Paleta Canônica**: Magenta Neon (`#FF2A85`), Ciano Elétrico (`#00F0FF`), Laranja Pôr do Sol (`#FF6A00`), Amarelo Solar (`#FFD200`), Vermelho REC (`#FF0055`) e Fundo Obsidiana (`#090814`).
- **Preservação**: Aplicação obrigatória em todas as telas, artefatos de documentação, lojas de aplicativos e compilações multiplataforma.

---

## 2. Metas de Sucesso
- **Tempo de Descoberta**: Varrer uma sub-rede `/24` (254 IPs) em menos de 5 segundos.
- **Atrito Zero**: Permitir que um usuário comissione uma câmera física recém-ligada em menos de 3 toques na tela.
- **Zero Vazamento de Credenciais**: Senhas de câmeras nunca expostas em texto puro em logs, interfaces públicas ou URLs visíveis.
- **Multiplataforma**: Execução consistente em Android (emulador e dispositivos físicos), iOS e macOS desktop.

---

## 3. Stack Tecnológica

| Camada | Tecnologia | Justificativa |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.41+ / Dart 3.11+ | Performance de 60/120 FPS, UI expressiva e compilação nativa multiplataforma |
| **Engine de Vídeo** | `media_kit` (libmpv / ffmpeg) | Padrão ouro da indústria para RTSP, suporte a H.264/H.265 e aceleração por hardware |
| **Gerenciamento de Estado** | `provider` / `ChangeNotifier` | Simplicidade, desacoplamento e atualização seletiva de widgets |
| **Persistência Local** | `shared_preferences` | Armazenamento leve e local com serialização JSON dos dispositivos cadastrados |
| **Descoberta de Rede** | `dart:io` (Sockets TCP + Datagram UDP) | Execução paralela sem dependências nativas pesadas |
| **Tipografia & Animações** | Google Fonts (*Orbitron* e *Rajdhani*) + `flutter_animate` | Estética cibernética de alta definição inspirada no GTA VI |

---

## 4. Requisitos Funcionais Principais
- [x] **RF01 - Varredura Wi-Fi Multicanal**: Descoberta assíncrona com exibição em radar animado.
- [x] **RF02 - Identificação Heurística**: Dedução da marca por porta de controle, banner RTSP e MAC OUI.
- [x] **RF03 - Comissionamento em Lote ou Individual**: Adição instantânea com preenchimento de templates RTSP.
- [x] **RF04 - Player com HUD Cyberpunk**: Retículos de mira, relógio de telemetria e indicador REC.
- [x] **RF05 - Controle PTZ Virtual**: Painel direcional (Cima/Baixo/Esquerda/Direita) e slider de zoom.
- [x] **RF06 - Matriz de Monitoramento**: Grade multiview (1x1, 2x2 e 3x3) para acompanhamento simultâneo.
- [x] **RF07 - Teste de Conexão Pré-Salvar**: Validação do fluxo de vídeo antes de persistir a câmera.
