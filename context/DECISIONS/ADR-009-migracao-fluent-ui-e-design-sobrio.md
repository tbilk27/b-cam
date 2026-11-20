# ADR-009: Migração para Fluent UI (Microsoft Fluent 2) e Design System Sóbrio

- **Status**: Aceito (Accepted)
- **Data**: 2026-11-20
- **Decisores**: Equipe Multi-Agente (Arquiteto de Software, Especialista Flutter, Designer UX/UI, Analista QA, Líder de Projeto)
- **Alvo**: `pubspec.yaml`, `lib/theme/fluent_theme.dart`, `lib/widgets/b_cam_logo.dart`, `lib/widgets/live_player_view.dart`, `lib/screens/*`

---

## 1. Contexto e Problema

O design system inicial do projeto utilizava uma identidade visual inspirada em "GTA VI", caracterizada por cores neon vibrantes (rosa choque `#FF1493`, ciano elétrico `#00F0FF`, gradientes saturados e cards com sombras brilhantes). 

Embora visualmente chamativo, o usuário solicitou expressamente a mudança de direcionamento estético:
> *"Mude o tema base do app para usar uma biblioteca como `fluent_ui` e com cores mais sóbrias, ficou muito 'escandaloso' este design system. Quero algo mais moderno, simples e objetivo. Mas mantenha a definição da logo e ícones do projeto."*

Para um sistema profissional de monitoramento por CFTV (surveillance), uma interface de missão crítica exige:
1. **Redução de Fadiga Visual**: Telas operacionais e grids com múltiplos feeds simultâneos exigem paleta neutra e escura com foco no conteúdo de vídeo.
2. **Clube Executivo e Corporativo**: Controles discretos, profundidade sutil (acrylic/mica dark surfaces), botões de alto contraste onde necessário (cobalt blue) e sem ruído visual.
3. **Preservação de Identidade da Marca**: Manter o logotipo oficial da íris com abertura focal `b-cam` (`assets/images/b_cam_icon.jpg`) e iconografia do app.

---

## 2. Decisão Arquitetural

1. **Adoção do Microsoft Fluent Design 2 (`fluent_ui`)**:
   - Integração da biblioteca [`fluent_ui: 4.15.1`](https://pub.dev/packages/fluent_ui) no Flutter.
   - Pinned `fluent_ui: 4.15.1` especificamente para compatibilidade com o SDK Flutter 3.41.9 / Dart 3.11.5 (evitando quebras de compilação introduzidas no suporte a Flutter 3.44+ do fluent_ui 4.16+).
   - Resolução de dependências mantendo `intl: ^0.20.2` alinhado ao `flutter_localizations`.

2. **Nova Paleta Sóbria de Cores de Vigilância (`BCamTheme`)**:
   - Background Base: `#1B1B1F` (Dark Zinc/Slate profundo).
   - Superfície dos Cards: `#242429` (Mica Surface).
   - Cards Elevados: `#2B2B32` / `#32323A`.
   - Bordas Sutis: `#3E3E47` e `#303038`.
   - Accent Principal: `#0078D4` (Cobalt Accent Blue) e `#4CC2FF` (Light Blue para telemetria).
   - Status Operacional:
     - Online: `#107C41` (Microsoft Corporate Green).
     - Offline / Alerta: `#D83B01` / `#B3261E`.
     - Warning: `#FFB900`.
   - Tipografia: Inter (UI geral, limpa e legível) e RobotoMono (IPs, endereços MAC, portas e telemetrias técnicas).

3. **Refatoração de Telas e Componentes**:
   - `lib/widgets/b_cam_logo.dart`: Componente executivo moderno combinando o avatar oficial da íris `b-cam` com tipografia Inter sem serifa e tag sutil "PRO".
   - `lib/main.dart`: Root widget atualizado para `FluentApp` com `BCamTheme.darkTheme()`.
   - `lib/screens/home_screen.dart`: Estruturado com `SafeArea`, `ScaffoldPage.scrollable`, `PageHeader`, pílulas de filtro dinâmicas ("TODAS", "FAVORITAS", "ZONAS"), cards de câmera com telemetria HUD e menu de opções com `ContentDialog`.
   - `lib/screens/scan_screen.dart`: Barra de progresso com `ProgressBar`, formulário de sub-rede com `TextBox`, cards de hardware descoberto com identificador permanente MAC e comissionamento em 1 clique.
   - `lib/screens/multi_grid_screen.dart`: Matriz com seletores de colunas (1 Coluna, 2 Colunas, 3 Colunas), visualização compacta dos feeds e zero overflow de pixels.
   - `lib/screens/camera_detail_screen.dart`: Reprodutor 16:9, botões compactos ("Snapshot", "HD Principal"), controle virtual PTZ (D-Pad + Slider com `-` e `+`) e tabela detalhada de telemetria.
   - `lib/screens/commission_screen.dart`: Seletor de fabricante, `TextFormBox`, dropdown de qualidade do fluxo com `ComboBox`, atalhos de credenciais da residência (`admin/Zs29364835`, `admin/Compras10@`, `admin/compras10`) e `InfoBar` orientativa da linha Mibo.

4. **Tratamento de SafeArea em Dispositivos Móveis**:
   - Todas as telas encapsulam seus respectivos `ScaffoldPage` em `SafeArea`, garantindo que os headers e botões não sejam obscurecidos pela barra de status, notch ou câmera frontal no Android e iOS.

---

## 3. Consequências e Resultados

- **Positivas**:
  - Estética sóbria, elegante e de nível empresarial conforme exigido pelo usuário.
  - Eliminação de gradientes neon estridentes sem perder modernidade e legibilidade.
  - Compatibilidade 100% com os testes unitários e de widget existentes (9 testes passando com sucesso).
  - Testado e homologado no emulador Android (`emulator-5554`) com screenshots comprovando zero pixel overflow e estabilidade.
- **Negativas/Trade-offs**:
  - A biblioteca `fluent_ui` possui convenções próprias de widgets (`ScaffoldPage`, `PageHeader`, `TextBox`, `TextFormBox`, `InfoBar`, `Button`, `FilledButton`), exigindo atenção para evitar conflitos de namespace com Material Design (`ButtonState` vs `WidgetStateProperty`, etc.).

---

## 4. Aprovação Multi-Agente

- **Arquiteto de Software**: Aprovado. A segregação de tema em `fluent_theme.dart` e o encapsulamento de rotas e componentes mantêm o desacoplamento arquitetural.
- **Especialista Flutter**: Aprovado. Resolvido o conflito de SDK pins (`fluent_ui: 4.15.1`, `intl: ^0.20.2`) e adicionado suporte a `SafeArea`.
- **Designer UX/UI**: Aprovado. Transição perfeita do estilo chamativo para uma paleta sóbria de centro de comando de vigilância executiva (Dark Slate + Cobalt Blue).
- **Analista QA**: Aprovado. Validação completa via suite de testes e execução no emulador físico/virtual com zero erros de compilação ou overflow visual.
