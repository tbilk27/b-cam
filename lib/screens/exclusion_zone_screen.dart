import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/bounding_box.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../models/exclusion_zone.dart';
import '../services/ai_vision_agent_service.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/exclusion_mask_painter.dart';
import '../widgets/live_player_view.dart';

enum MaskTool {
  paint,
  erase,
}

class ExclusionZoneScreen extends StatefulWidget {
  final CameraDevice camera;

  const ExclusionZoneScreen({
    super.key,
    required this.camera,
  });

  @override
  State<ExclusionZoneScreen> createState() => _ExclusionZoneScreenState();
}

class _ExclusionZoneScreenState extends State<ExclusionZoneScreen> {
  late Set<int> _excludedCells;
  bool _exclusionEnabled = true;
  MaskTool _currentTool = MaskTool.paint;
  int _brushSize = 1; // 1 = Fino (1x1), 2 = Médio (2x2), 3 = Grosso (3x3)
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _excludedCells = Set<int>.from(widget.camera.exclusionMask);
    _exclusionEnabled = widget.camera.exclusionZoneEnabled;
  }

  void _handleTouch(Offset localPosition) {
    if (_canvasSize.width <= 0 || _canvasSize.height <= 0) return;

    final affected = ExclusionGrid.brushCellsAt(
      localPosition,
      _canvasSize,
      brushRadius: _brushSize,
    );

    if (affected.isEmpty) return;

    setState(() {
      if (_currentTool == MaskTool.paint) {
        _excludedCells.addAll(affected);
      } else {
        _excludedCells.removeAll(affected);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _excludedCells.clear();
    });
  }

  void _invertSelection() {
    setState(() {
      final inverted = <int>{};
      for (int i = 0; i < ExclusionGrid.totalCells; i++) {
        if (!_excludedCells.contains(i)) {
          inverted.add(i);
        }
      }
      _excludedCells = inverted;
    });
  }

  Future<void> _saveExclusionZone() async {
    final updatedCamera = widget.camera.copyWith(
      exclusionMask: _excludedCells.toList(),
      exclusionZoneEnabled: _exclusionEnabled,
    );

    await context.read<CameraStorageService>().updateCamera(updatedCamera);

    if (mounted) {
      displayInfoBar(
        context,
        duration: const Duration(seconds: 4),
        builder: (context, close) => InfoBar(
          title: const Text('Zona de Exclusão Salva'),
          content: Text(
            'Máscara atualizada com sucesso (${_excludedCells.length} células protegidas). Eventos nessas áreas serão ignorados.',
          ),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
      Navigator.of(context).pop(updatedCamera);
    }
  }

  void _testExclusionDetection() {
    final tempCam = widget.camera.copyWith(
      exclusionMask: _excludedCells.toList(),
      exclusionZoneEnabled: _exclusionEnabled,
    );

    if (_excludedCells.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Nenhuma área excluída'),
          content: const Text('Pinte ao menos uma área com o dedo para testar a rejeição de eventos.'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }

    // Pick first excluded cell as target
    final excludedIndex = _excludedCells.first;
    final cellRect = ExclusionGrid.cellToNormalizedRect(excludedIndex);
    final insideBox = BoundingBox(
      label: 'Pessoa (Na Exclusão)',
      confidence: 0.95,
      left: cellRect.left,
      top: cellRect.top,
      width: cellRect.width,
      height: cellRect.height,
    );

    final resultInside = AiVisionAgentService.instance.testDetectionWithConfidence(
      camera: tempCam,
      simulatedConfidence: 0.95,
      label: 'Pessoa na Área Excluída',
      type: CameraEventType.person,
      customBox: insideBox,
    );

    displayInfoBar(
      context,
      duration: const Duration(seconds: 5),
      builder: (context, close) => InfoBar(
        title: Text(resultInside == null ? '✔ Teste Aprovado: Evento Descartado' : 'Aviso'),
        content: Text(
          resultInside == null
              ? 'A IA detectou uma pessoa na área pintada, mas o evento foi DESCARTADO com sucesso (sem notificação).'
              : 'O evento foi gerado (verifique se a célula está marcada).',
        ),
        severity: resultInside == null ? InfoBarSeverity.success : InfoBarSeverity.error,
        onClose: close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_excludedCells.length / ExclusionGrid.totalCells) * 100;

    return SafeArea(
      child: ScaffoldPage(
        header: PageHeader(
          title: Row(
            children: [
              IconButton(
                icon: const Icon(FluentIcons.back, size: 16),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zona de Exclusão: ${widget.camera.name}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Pinte com o dedo as áreas onde detecções de IA serão ignoradas',
                      style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _saveExclusionZone,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(FluentIcons.save, size: 13),
                    const SizedBox(width: 6),
                    Text('Salvar', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Interactive Canvas with 16:9 Aspect Ratio
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _excludedCells.isNotEmpty ? const Color(0xB3FF3B30) : BCamTheme.darkBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _handleTouch(d.localPosition),
                        onPanUpdate: (d) => _handleTouch(d.localPosition),
                        onTapDown: (d) => _handleTouch(d.localPosition),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Live Camera Stream Background
                            LivePlayerView(
                              camera: widget.camera,
                              autoPlay: true,
                              isMiniature: false,
                            ),

                            // 2. Painted Exclusion Mask Overlay
                            CustomPaint(
                              painter: ExclusionMaskPainter(
                                excludedCells: _excludedCells,
                                showGridLines: true,
                              ),
                            ),

                            // 3. Top Floating HUD Indicator
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _excludedCells.isNotEmpty ? const Color(0xFFFF3B30) : const Color(0x3DFFFFFF),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _excludedCells.isNotEmpty ? FluentIcons.blocked2 : FluentIcons.clear,
                                      size: 11,
                                      color: _excludedCells.isNotEmpty ? const Color(0xFFFF3B30) : const Color(0xB3FFFFFF),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ÁREA EXCLUÍDA: ${percent.toStringAsFixed(0)}% (${_excludedCells.length}/144)',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Interactive Painting Toolbar
              Card(
                backgroundColor: BCamTheme.darkSurface,
                borderColor: BCamTheme.darkBorder,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Tool Selection (Pincel vs Borracha) & Enable Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Button(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  _currentTool == MaskTool.paint ? const Color(0xD9FF3B30) : BCamTheme.darkCard,
                                ),
                              ),
                              onPressed: () => setState(() => _currentTool = MaskTool.paint),
                              child: Row(
                                children: [
                                  const Icon(FluentIcons.edit, size: 13),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pincel (Excluir)',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: _currentTool == MaskTool.paint ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Button(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  _currentTool == MaskTool.erase ? BCamTheme.accentBlue : BCamTheme.darkCard,
                                ),
                              ),
                              onPressed: () => setState(() => _currentTool = MaskTool.erase),
                              child: Row(
                                children: [
                                  const Icon(FluentIcons.erase_tool, size: 13),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Borracha',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: _currentTool == MaskTool.erase ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Exclusion Master Toggle
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ativa',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            ToggleSwitch(
                              checked: _exclusionEnabled,
                              onChanged: (val) => setState(() => _exclusionEnabled = val),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Row 2: Brush Size (Fino, Médio, Grosso)
                    Row(
                      children: [
                        Text(
                          'Espessura do Dedo:',
                          style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        ...[
                          (1, 'Fino (1x1)'),
                          (2, 'Médio (2x2)'),
                          (3, 'Largo (3x3)'),
                        ].map((item) {
                          final isSelected = _brushSize == item.$1;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Button(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  isSelected ? BCamTheme.darkBorder : Colors.transparent,
                                ),
                              ),
                              onPressed: () => setState(() => _brushSize = item.$1),
                              child: Text(
                                item.$2,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  color: isSelected ? Colors.white : BCamTheme.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Row 3: Action Buttons (Limpar, Inverter, Testar)
                    Row(
                      children: [
                        Expanded(
                          child: Button(
                            onPressed: _clearAll,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(FluentIcons.clear, size: 12),
                                const SizedBox(width: 4),
                                const Text('Limpar', style: TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Button(
                            onPressed: _invertSelection,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(FluentIcons.switch_widget, size: 12),
                                const SizedBox(width: 4),
                                const Text('Inverter', style: TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: Button(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(BCamTheme.darkCard),
                            ),
                            onPressed: _testExclusionDetection,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(FluentIcons.test_beaker, size: 12, color: BCamTheme.accentLightBlue),
                                const SizedBox(width: 6),
                                Text(
                                  'Testar Rejeição IA',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: BCamTheme.accentLightBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Educational Guideline Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BCamTheme.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: BCamTheme.accentBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(FluentIcons.info, size: 16, color: BCamTheme.accentLightBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Como funciona: Ao pintar com o dedo sobre calçadas públicas, janelas de vizinhos ou '
                        'vegetação com vento, o agente de IA ignorará qualquer movimento ou pessoa nessas áreas '
                        'vermelhas. Nenhum evento ou notificação será disparado.',
                        style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
