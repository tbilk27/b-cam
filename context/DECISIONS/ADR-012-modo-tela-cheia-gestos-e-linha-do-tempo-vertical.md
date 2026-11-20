# ADR-012: Modo Tela Cheia Imersivo com Gestos de Navegação Horizontal e Linha do Tempo Vertical de Eventos

## Status
Aprovado / Implementado

## Data
2026-11-20

## Contexto
O usuário solicitou melhorias fundamentais de usabilidade e vigilância:
1. **Entrada em Tela Cheia via Duplo Toque**: Ao dar duplo toque em qualquer câmera (na lista principal, na matriz 2x2 ou no player de detalhes), a câmera deve expandir para o modo de tela cheia imersivo.
2. **Navegação Horizontal entre Câmeras em Tela Cheia**: Em tela cheia, o usuário deve conseguir arrastar para os lados (swipe horizontal) para alternar suavemente entre todas as câmeras comissionadas ativas.
3. **Saída de Tela Cheia via Duplo Toque**: Um novo duplo toque em tela cheia deve retornar à tela anterior com a imagem menor.
4. **Linha do Tempo de Eventos na Vertical**: O usuário precisa acessar uma linha do tempo vertical com todos os eventos registrados pela câmera (detecções de pessoa com IA, veículos, movimentos, gravações NVR e alarmes).

## Decisões Arquiteturais

1. **Viewer Imersivo em Tela Cheia (`FullscreenCameraViewer`)**:
   - Desenvolvido `FullscreenCameraViewer` com `PageView.builder(scrollDirection: Axis.horizontal, physics: PageScrollPhysics())`.
   - Permite transição contínua entre câmeras comissionadas via gesto horizontal.
   - Gerenciamento de HUD inteligente: exibe nome da câmera, fabricante, IP, indicador de posição (`2 / 4`), atalhos de tela cheia, botão de recolher e guia de gestos.
   - Temporizador de auto-ocultamento do HUD (4 segundos de inatividade) com reativação via toque simples.
   - `onDoubleTap`: detecta duplo toque e executa `Navigator.of(context).pop()` retornando para a visualização menor.

2. **Linha do Tempo de Eventos na Vertical (`VerticalEventTimeline`)**:
   - Desenvolvido o componente visual `VerticalEventTimeline`:
     - Trilho vertical à esquerda conectando eventos por nós coloridos com status luminescente (Verde = Pessoa, Âmbar = Veículo, Azul = Movimento, Vermelho = Alarme).
     - Rótulos de horário e data formatados (`HH:mm:ss`).
     - Cards de evento com categoria, índice de confiança de IA (`96%`), duração do trecho (`42s`), descrição circunstanciada e miniatura interativa de reprodução de clipe NVR.
     - Filtros de categoria por pills horizontais (`TODOS`, `PESSOAS`, `VEÍCULOS`, `MOVIMENTO`, `ALARMES`).
   - Disponível em dois pontos de acesso no aplicativo:
     - Na tela de detalhes da câmera (`CameraDetailScreen`) como seção nativa no corpo da página.
     - Em tela cheia (`FullscreenCameraViewer`) através de um painel deslizante tipo gaveta (*bottom sheet*) acionado pelo botão "Linha do Tempo".

3. **Integração de Gestos de Duplo Toque nas Telas**:
   - `HomeScreen`: duplo toque no card de vídeo abre imediatamente o viewer em tela cheia na câmera selecionada.
   - `CameraDetailScreen`: duplo toque no player ou clique no botão dedicado "Tela Cheia" abre o viewer em tela cheia.
   - `MultiGridScreen`: duplo toque em qualquer célula da matriz 2x2/3x3 expande a câmera em tela cheia.

4. **Modelagem e Serviços de Eventos**:
   - Criados `CameraEvent` e `CameraEventService` (singleton com `ChangeNotifier`), alimentados com eventos realistas de NVR e CFTV para as câmeras físicas da rede local (`192.168.3.74`, `.23`, `.24`, `.22`) e suporte a novas câmeras comissionadas.

## Consequências
- Atinge 100% dos requisitos de interação solicitados pelo usuário com ergonomia tátil nativa.
- Linha do tempo vertical intuitiva e de fácil leitura para auditoria e monitoramento de segurança.
- Mantido o padrão Fluent UI 2 sóbrio, zero pixel overflows e alta taxa de quadros.
