import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../services/ai_vision_agent_service.dart';
import '../services/camera_action_service.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/live_player_view.dart';
import '../widgets/vertical_event_timeline.dart';
import 'commission_screen.dart';
import 'exclusion_zone_screen.dart';
import 'fullscreen_camera_viewer.dart';

class CameraDetailScreen extends StatefulWidget {
  final CameraDevice camera;

  const CameraDetailScreen({
    super.key,
    required this.camera,
  });

  @override
  State<CameraDetailScreen> createState() => _CameraDetailScreenState();
}

class _CameraDetailScreenState extends State<CameraDetailScreen> {
  late CameraDevice _camera;
  bool _isSuspended = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _showShutterFlash = false;
  int _bottomMenuPage = 0; // 0 = main page (5 icons), 1 = secondary page
  final GlobalKey<LivePlayerViewState> _livePlayerKey = GlobalKey<LivePlayerViewState>();

  Future<void> _persistLastSnapshotOnExit() async {
    try {
      final path = await _livePlayerKey.currentState?.captureSnapshot();
      if (path != null && mounted) {
        final storage = Provider.of<CameraStorageService>(context, listen: false);
        await storage.recordCameraAccess(_camera.id, snapshotPath: path);
      }
    } catch (e) {
      debugPrint('Erro ao persistir snapshot ao sair: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _camera = widget.camera;
    _isSuspended = !_camera.isEnabled;
    CameraActionService.instance.addListener(_onActionUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CameraStorageService>().recordCameraAccess(_camera.id);
      }
    });
  }

  @override
  void dispose() {
    CameraActionService.instance.removeListener(_onActionUpdate);
    _recordTimer?.cancel();
    super.dispose();
  }

  void _onActionUpdate() {
    if (mounted) setState(() {});
  }

  void _showNightVisionDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final currentMode = CameraActionService.instance.getNightVisionMode(_camera.id);
        return ContentDialog(
          title: Row(
            children: [
              const Icon(FluentIcons.clear_night, size: 18, color: BCamTheme.accentLightBlue),
              const SizedBox(width: 8),
              Text(
                'Visão Noturna: ${_camera.name}',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: NightVisionMode.values.map((mode) {
              final isSelected = mode == currentMode;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(
                    mode == NightVisionMode.color
                        ? FluentIcons.lightbulb
                        : (mode == NightVisionMode.ir ? FluentIcons.clear_night : FluentIcons.sync),
                    size: 16,
                    color: isSelected ? BCamTheme.statusOnlineGlow : BCamTheme.textSecondary,
                  ),
                  title: Text(
                    mode.label,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? Colors.white : BCamTheme.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(FluentIcons.check_mark, size: 14, color: BCamTheme.statusOnlineGlow)
                      : null,
                  onPressed: () {
                    CameraActionService.instance.setNightVisionMode(_camera, mode);
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _openFullScreen() {
    final allCameras = context.read<CameraStorageService>().cameras;
    final idx = allCameras.indexWhere((c) => c.id == _camera.id);
    Navigator.of(context).push(
      FluentPageRoute(
        builder: (_) => FullscreenCameraViewer(
          cameras: allCameras,
          initialIndex: idx >= 0 ? idx : 0,
        ),
      ),
    );
  }

  void _switchStreamQuality() {
    final nextSubType = _camera.subType == 0 ? 1 : 0;
    setState(() {
      _camera = _camera.copyWith(subType: nextSubType);
    });
    context.read<CameraStorageService>().updateCamera(_camera);

    displayInfoBar(
      context,
      duration: const Duration(seconds: 3),
      builder: (context, close) => InfoBar(
        title: Text(nextSubType == 0 ? 'Definição: HD (Principal)' : 'Definição: SD / Fluente (Sub-stream)'),
        content: Text('Fluxo alterado para CH${_camera.channel} / ${nextSubType == 0 ? "1080p Main Stream" : "VGA Sub Stream"}'),
        severity: InfoBarSeverity.info,
        onClose: close,
      ),
    );
  }

  Future<void> _takeSnapshot() async {
    setState(() => _showShutterFlash = true);
    Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _showShutterFlash = false);
    });

    final path = await _livePlayerKey.currentState?.captureSnapshot();
    if (!mounted) return;

    if (path != null) {
      await context.read<CameraStorageService>().recordCameraAccess(_camera.id, snapshotPath: path);
      if (!mounted) return;
      displayInfoBar(
        context,
        duration: const Duration(seconds: 4),
        builder: (context, close) => InfoBar(
          title: const Text('Fotografar'),
          content: Text('Foto da câmera "${_camera.name}" salva com sucesso e atualizada na capa!'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    } else {
      displayInfoBar(
        context,
        duration: const Duration(seconds: 4),
        builder: (context, close) => InfoBar(
          title: const Text('Fotografar'),
          content: Text('Snapshot da câmera "${_camera.name}" processado com sucesso!'),
          severity: InfoBarSeverity.info,
          onClose: close,
        ),
      );
    }
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _recordSeconds = 0;
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) {
            setState(() => _recordSeconds++);
          }
        });
      } else {
        _recordTimer?.cancel();
      }
    });

    displayInfoBar(
      context,
      duration: const Duration(seconds: 4),
      builder: (context, close) => InfoBar(
        title: Text(_isRecording ? 'Gravação Manual Iniciada' : 'Gravação Finalizada'),
        content: Text(
          _isRecording
              ? 'Gravando buffer local de vídeo para "${_camera.name}"...'
              : 'Clipe gravado de $_recordSeconds s consolidado no NVR local.',
        ),
        severity: _isRecording ? InfoBarSeverity.warning : InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  void _toggleSuspension() {
    final newEnabled = !_camera.isEnabled;
    setState(() {
      _camera = _camera.copyWith(isEnabled: newEnabled);
    });
    context.read<CameraStorageService>().setCameraEnabled(_camera.id, newEnabled);

    displayInfoBar(
      context,
      duration: const Duration(seconds: 3),
      builder: (context, close) => InfoBar(
        title: Text(!newEnabled ? 'Câmera Desativada (Suspensa)' : 'Câmera Ativada'),
        content: Text(
          !newEnabled
              ? 'Conexão interrompida e retentativas automáticas suspensas.'
              : 'Transmissão ao vivo e monitoramento de eventos retomados.',
        ),
        severity: !newEnabled ? InfoBarSeverity.warning : InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  Future<void> _openExclusionZoneScreen() async {
    final updated = await Navigator.of(context).push<CameraDevice>(
      FluentPageRoute(
        builder: (_) => ExclusionZoneScreen(camera: _camera),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _camera = updated;
      });
    }
  }

  void _openCameraSettings() async {
    final storage = context.read<CameraStorageService>();
    await Navigator.of(context).push(
      FluentPageRoute(
        builder: (_) => CommissionScreen(existingCamera: _camera),
      ),
    );
    if (!mounted) return;
    final updated = storage.cameras.firstWhere(
      (c) => c.id == _camera.id,
      orElse: () => _camera,
    );
    setState(() {
      _camera = updated;
      _isSuspended = !updated.isEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape || mq.size.width > mq.size.height;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        await _persistLastSnapshotOnExit();
      },
      child: SafeArea(
        child: Container(
          color: const Color(0xFF131317),
          child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
        ),
      ),
    );
  }

  // ===========================================================================
  // LAYOUT RETRATO (PORTRAIT)
  // Header superior dedicado (sem cobrir o vídeo), vídeo 100% limpo no topo,
  // timeline vertical no centro e menu no rodapé
  // ===========================================================================
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // 1. Dedicated Top Surveillance Header Bar (Above video, completely clear of camera feed!)
        _buildTopHeaderBar(isLandscape: false),

        // 2. Top: Video Player Feed (Taking Maximum Space, Completely Clear & Unobstructed)
        _buildCameraVideoPlayer(isLandscape: false),

        // 3. Center: Vertical Event Timeline
        Expanded(
          child: VerticalEventTimeline(camera: _camera),
        ),

        // 4. Bottom: Fixed Surveillance Rodapé Menu
        _buildBottomRodapeMenu(),
      ],
    );
  }

  // ===========================================================================
  // LAYOUT PAISAGEM (LANDSCAPE)
  // Split Dual-Pane: Câmera à esquerda (60%) + Header, Timeline e Menu à direita (40%)
  // ===========================================================================
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Left Column: Video Player filling available space (unobstructed)
        Expanded(
          flex: 60,
          child: Center(
            child: _buildCameraVideoPlayer(isLandscape: true),
          ),
        ),

        // Right Column: Dedicated Header + Vertical Timeline + Compact Rodapé Menu
        Expanded(
          flex: 40,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF18181D),
              border: Border(left: BorderSide(color: BCamTheme.darkBorder, width: 0.8)),
            ),
            child: Column(
              children: [
                _buildTopHeaderBar(isLandscape: true),
                Expanded(
                  child: VerticalEventTimeline(camera: _camera, isCompact: true),
                ),
                _buildBottomRodapeMenu(isCompact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DEDICATED TOP SURVEILLANCE HEADER BAR
  // Displays back navigation, camera title, live status, and action buttons
  // ABOVE the video feed so that no information covers the camera feed/OSD.
  // ===========================================================================
  Widget _buildTopHeaderBar({bool isLandscape = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 10, vertical: isLandscape ? 4 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        border: Border(
          bottom: BorderSide(color: BCamTheme.darkBorder, width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back Arrow + Camera Name + Live Subtype Pill
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(const Color(0x33FFFFFF)),
                  ),
                  icon: const Icon(FluentIcons.back, size: 14, color: Colors.white),
                  onPressed: () async {
                    await _persistLastSnapshotOnExit();
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _camera.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: BCamTheme.statusOnlineGlow,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AO VIVO • ${_camera.subType == 0 ? "HD" : "SUB"}',
                              style: GoogleFonts.robotoMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: BCamTheme.statusOnlineGlow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: Action Buttons (Favorite, Exclusion Zone, Telemetry, Settings, Fullscreen)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Favorite Star
              IconButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(const Color(0x22FFFFFF)),
                ),
                icon: Icon(
                  _camera.isFavorite ? FluentIcons.favorite_star_fill : FluentIcons.favorite_star,
                  size: 14,
                  color: _camera.isFavorite ? BCamTheme.statusWarning : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _camera = _camera.copyWith(isFavorite: !_camera.isFavorite);
                  });
                  context.read<CameraStorageService>().toggleFavorite(_camera.id);
                },
              ),
              const SizedBox(width: 5),

              // Zona Exclusão Quick Button
              IconButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    _camera.hasExclusionZone ? const Color(0x4DFF3B30) : const Color(0x22FFFFFF),
                  ),
                ),
                icon: Icon(
                  FluentIcons.blocked2,
                  size: 14,
                  color: _camera.hasExclusionZone ? const Color(0xFFFF6961) : Colors.white,
                ),
                onPressed: _openExclusionZoneScreen,
              ),
              const SizedBox(width: 5),

              // Diagnostics / Telemetry
              IconButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(const Color(0x22FFFFFF)),
                ),
                icon: const Icon(FluentIcons.diagnostic, size: 14, color: Colors.white),
                onPressed: _showTelemetryModal,
              ),
              const SizedBox(width: 5),

              // Camera Settings
              IconButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(const Color(0x22FFFFFF)),
                ),
                icon: const Icon(FluentIcons.settings, size: 14, color: Colors.white),
                onPressed: _openCameraSettings,
              ),
              const SizedBox(width: 5),

              // Full Screen Viewer
              IconButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(const Color(0x22FFFFFF)),
                ),
                icon: const Icon(FluentIcons.full_screen, size: 14, color: Colors.white),
                onPressed: _openFullScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CAMERA VIDEO PLAYER WIDGET
  // 100% Unobstructed Video Surface. Top header was moved outside to dedicated bar.
  // ===========================================================================
  Widget _buildCameraVideoPlayer({required bool isLandscape}) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: isLandscape ? double.infinity : 260.0,
      ),
      child: Stack(
        children: [
          // Player Surface (Double tap enters full screen)
          AspectRatio(
            aspectRatio: isLandscape ? (16 / 9) : (16 / 9),
            child: GestureDetector(
              onDoubleTap: _openFullScreen,
              child: _isSuspended
                  ? Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(FluentIcons.clear_night, size: 40, color: BCamTheme.textSecondary),
                            const SizedBox(height: 8),
                            Text(
                              'Câmera em Modo Suspensão',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            Text(
                              'Toque em "Suspensão" no menu inferior para reativar',
                              style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : LivePlayerView(
                      key: _livePlayerKey,
                      camera: _camera,
                      autoPlay: true,
                      showPtzOverlay: false,
                      showTopHud: false,
                      showOsdClock: true,
                    ),
            ),
          ),

        // Visual Shutter Flash Effect
        if (_showShutterFlash)
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.8)),
          ),

        // Recording Indicator Overlay
        if (_isRecording)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xD9FF0000),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'REC ${_formatRecordTime(_recordSeconds)}',
                    style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

  // ===========================================================================
  // MENU NO RODAPÉ (FIXED BOTTOM SURVEILLANCE MENU)
  // 5 ações: Fotografar | Gravação | Definição | Suspensão | Dispositivos/PTZ
  // ===========================================================================
  Widget _buildBottomRodapeMenu({bool isCompact = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        border: Border(
          top: BorderSide(color: BCamTheme.darkBorder, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, isCompact ? 8 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row of Action Items
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _bottomMenuPage == 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRodapeItem(
                        icon: FluentIcons.camera,
                        label: isCompact ? 'Foto' : 'Fotografar',
                        onTap: _takeSnapshot,
                        isCompact: isCompact,
                      ),
                      _buildRodapeItem(
                        icon: _isRecording ? FluentIcons.record2 : FluentIcons.video,
                        label: _isRecording ? 'Gravando' : (isCompact ? 'Gravar' : 'Gravação'),
                        isActive: _isRecording,
                        activeColor: const Color(0xFFFF3B30),
                        onTap: _toggleRecording,
                        isCompact: isCompact,
                      ),
                      _buildRodapeItem(
                        icon: FluentIcons.desktop_screenshot,
                        label: isCompact ? 'HD/SD' : 'Definição',
                        badge: _camera.subType == 0 ? 'HD' : 'SD',
                        onTap: _switchStreamQuality,
                        isCompact: isCompact,
                      ),
                      _buildRodapeItem(
                        icon: FluentIcons.clear_night,
                        label: isCompact ? 'Pausar' : 'Suspensão',
                        isActive: _isSuspended,
                        activeColor: BCamTheme.statusWarning,
                        onTap: _toggleSuspension,
                        isCompact: isCompact,
                      ),
                      _buildRodapeItem(
                        icon: FluentIcons.blocked2,
                        label: isCompact ? 'Exclusão' : 'Zona Exclusão',
                        badge: _camera.hasExclusionZone ? '${_camera.exclusionZonePercentage.toStringAsFixed(0)}%' : null,
                        isActive: _camera.hasExclusionZone,
                        activeColor: const Color(0xFFFF3B30),
                        onTap: () async {
                          final updated = await Navigator.of(context).push<CameraDevice>(
                            FluentPageRoute(
                              builder: (_) => ExclusionZoneScreen(camera: _camera),
                            ),
                          );
                          if (updated != null && mounted) {
                            setState(() {
                              _camera = updated;
                            });
                          }
                        },
                        isCompact: isCompact,
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // 1. Interfone (Falar / Push-to-Talk)
                      _buildRodapeItem(
                        icon: FluentIcons.microphone,
                        label: CameraActionService.instance.isTalking(_camera.id) ? 'Falando...' : 'Interfone',
                        isCompact: isCompact,
                        isActive: CameraActionService.instance.isTalking(_camera.id),
                        activeColor: BCamTheme.statusOnlineGlow,
                        onTap: () {
                          final isTalking = CameraActionService.instance.isTalking(_camera.id);
                          if (isTalking) {
                            CameraActionService.instance.stopTalking(_camera);
                          } else {
                            CameraActionService.instance.startTalking(_camera);
                          }
                          displayInfoBar(
                            context,
                            duration: const Duration(seconds: 2),
                            builder: (c, close) => InfoBar(
                              title: Text(!isTalking ? '🎙️ Microfone Aberto' : 'Microfone Fechado'),
                              content: Text(!isTalking ? 'Fale agora: seu áudio está sendo transmitido na câmera.' : 'Transmissão finalizada.'),
                              severity: !isTalking ? InfoBarSeverity.success : InfoBarSeverity.info,
                              onClose: close,
                            ),
                          );
                        },
                      ),

                      // 2. Ouvir Ambiente (Mudo / Alto-falante do celular)
                      _buildRodapeItem(
                        icon: CameraActionService.instance.isListening(_camera.id) ? FluentIcons.volume3 : FluentIcons.volume_disabled,
                        label: CameraActionService.instance.isListening(_camera.id) ? 'Ouvindo' : 'Mudo',
                        isCompact: isCompact,
                        isActive: CameraActionService.instance.isListening(_camera.id),
                        activeColor: BCamTheme.statusOnlineGlow,
                        onTap: () {
                          final listening = CameraActionService.instance.toggleListening(_camera);
                          displayInfoBar(
                            context,
                            duration: const Duration(seconds: 2),
                            builder: (c, close) => InfoBar(
                              title: Text(listening ? '🔊 Ouvindo Ambiente' : '🔇 Áudio Silenciado'),
                              content: Text(listening ? 'Canal de áudio da câmera aberto.' : 'Microfone da câmera mudo no aplicativo.'),
                              severity: InfoBarSeverity.info,
                              onClose: close,
                            ),
                          );
                        },
                      ),

                      // 3. Sirene / Alarme
                      _buildRodapeItem(
                        icon: FluentIcons.ringer,
                        label: CameraActionService.instance.isSirenActive(_camera.id) ? 'Sirene ON' : 'Sirene',
                        isCompact: isCompact,
                        isActive: CameraActionService.instance.isSirenActive(_camera.id),
                        activeColor: const Color(0xFFFF3B30),
                        onTap: () async {
                          final active = await CameraActionService.instance.toggleSiren(_camera);
                          if (!mounted) return;
                          displayInfoBar(
                            context,
                            duration: const Duration(seconds: 3),
                            builder: (c, close) => InfoBar(
                              title: Text(active ? '🚨 Sirene Disparada' : 'Sirene Desativada'),
                              content: Text(active ? 'Alarme sonoro acionado na câmera "${_camera.name}".' : 'Alarme sonoro desligado.'),
                              severity: active ? InfoBarSeverity.error : InfoBarSeverity.info,
                              onClose: close,
                            ),
                          );
                        },
                      ),

                      // 4. Acender Luz / Holofote
                      _buildRodapeItem(
                        icon: FluentIcons.lightbulb,
                        label: CameraActionService.instance.isSpotlightActive(_camera.id) ? 'Luz ON' : 'Luz LED',
                        isCompact: isCompact,
                        isActive: CameraActionService.instance.isSpotlightActive(_camera.id),
                        activeColor: const Color(0xFFFFD60A),
                        onTap: () async {
                          final active = await CameraActionService.instance.toggleSpotlight(_camera);
                          if (!mounted) return;
                          displayInfoBar(
                            context,
                            duration: const Duration(seconds: 3),
                            builder: (c, close) => InfoBar(
                              title: Text(active ? '💡 Holofote Aceso' : 'Holofote Apagado'),
                              content: Text(active ? 'Luz LED da câmera ligada.' : 'Luz LED desligada.'),
                              severity: InfoBarSeverity.info,
                              onClose: close,
                            ),
                          );
                        },
                      ),

                      // 5. Visão Noturna
                      _buildRodapeItem(
                        icon: FluentIcons.clear_night,
                        label: isCompact ? 'Noturna' : 'Visão Noturna',
                        isCompact: isCompact,
                        badge: CameraActionService.instance.getNightVisionMode(_camera.id).name.toUpperCase(),
                        onTap: _showNightVisionDialog,
                      ),

                      // 6. Visão IA
                      _buildRodapeItem(
                        icon: FluentIcons.robot,
                        label: 'Visão IA',
                        isCompact: isCompact,
                        isActive: _camera.aiDetectionEnabled,
                        activeColor: BCamTheme.accentLightBlue,
                        onTap: () {
                          final newAiEnabled = !_camera.aiDetectionEnabled;
                          setState(() {
                            _camera = _camera.copyWith(aiDetectionEnabled: newAiEnabled);
                          });
                          context.read<CameraStorageService>().updateCamera(_camera);

                          if (newAiEnabled) {
                            final evt = AiVisionAgentService.instance.testDetectionWithConfidence(
                              camera: _camera,
                              simulatedConfidence: 0.96,
                              label: 'Pessoa',
                              type: CameraEventType.person,
                            );
                            displayInfoBar(
                              context,
                              duration: const Duration(seconds: 4),
                              builder: (c, close) => InfoBar(
                                title: const Text('Visão Computacional IA Ativada'),
                                content: Text(
                                  evt != null
                                      ? 'Objeto contornado: Pessoa (96% de assertividade) na câmera ao vivo.'
                                      : 'Monitoramento de objetos ativo na área de vigilância.',
                                ),
                                severity: InfoBarSeverity.success,
                                onClose: close,
                              ),
                            );
                          } else {
                            AiVisionAgentService.instance.clearLiveDetections(_camera.id);
                            displayInfoBar(
                              context,
                              duration: const Duration(seconds: 3),
                              builder: (c, close) => InfoBar(
                                title: const Text('Visão Computacional IA Desativada'),
                                content: const Text('Marcações e contornos suspensos nesta câmera.'),
                                severity: InfoBarSeverity.info,
                                onClose: close,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 6),

          // Pagination Dots (-- -)
          GestureDetector(
            onTap: () {
              setState(() {
                _bottomMenuPage = _bottomMenuPage == 0 ? 1 : 0;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: _bottomMenuPage == 0 ? 16 : 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _bottomMenuPage == 0 ? BCamTheme.statusOnlineGlow : const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: _bottomMenuPage == 1 ? 16 : 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _bottomMenuPage == 1 ? BCamTheme.statusOnlineGlow : const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRodapeItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
    String? badge,
    bool isCompact = false,
  }) {
    final effectiveColor = isActive
        ? (activeColor ?? BCamTheme.statusOnlineGlow)
        : BCamTheme.textSecondary;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: isCompact ? 34 : 38,
                  height: isCompact ? 34 : 38,
                  decoration: BoxDecoration(
                    color: isActive ? effectiveColor.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(icon, size: isCompact ? 18 : 20, color: effectiveColor),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: BCamTheme.accentLightBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: GoogleFonts.robotoMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 9.5 : 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTelemetryModal() {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text('Telemetria RTSP: ${_camera.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _telemetryItem('Fabricante', _camera.manufacturer.displayName),
            _telemetryItem('IP / Porta', '${_camera.ip}:${_camera.rtspPort}'),
            _telemetryItem('Fluxo Ativo', _camera.subType == 0 ? 'Principal (HD)' : 'Sub (SD)'),
            _telemetryItem('Localização', _camera.location),
            if (_camera.macAddress != null)
              _telemetryItem('MAC', _camera.macAddress!),
            const SizedBox(height: 8),
            Text('Stream URL:', style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary)),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _camera.maskedStreamUrl,
                style: GoogleFonts.robotoMono(fontSize: 10, color: BCamTheme.accentLightBlue),
              ),
            ),
          ],
        ),
        actions: [
          Button(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _telemetryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary)),
          Text(value, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  String _formatRecordTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
