import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/live_player_view.dart';
import '../widgets/vertical_event_timeline.dart';
import 'commission_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _camera = widget.camera;
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    super.dispose();
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

  void _takeSnapshot() {
    setState(() => _showShutterFlash = true);
    Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _showShutterFlash = false);
    });

    displayInfoBar(
      context,
      duration: const Duration(seconds: 4),
      builder: (context, close) => InfoBar(
        title: const Text('Fotografar'),
        content: Text('Snapshot da câmera "${_camera.name}" salvo no armazenamento com sucesso!'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
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
    setState(() {
      _isSuspended = !_isSuspended;
    });

    displayInfoBar(
      context,
      duration: const Duration(seconds: 3),
      builder: (context, close) => InfoBar(
        title: Text(_isSuspended ? 'Modo Suspensão Ativado' : 'Modo Suspensão Desativado'),
        content: Text(
          _isSuspended
              ? 'Transmissão em repouso / privacidade. Sensores e alertas pausados.'
              : 'Transmissão ao vivo e vigilância de IA retomadas.',
        ),
        severity: _isSuspended ? InfoBarSeverity.warning : InfoBarSeverity.info,
        onClose: close,
      ),
    );
  }

  void _openPtzPanel() {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Row(
          children: [
            const Icon(FluentIcons.game, size: 18, color: BCamTheme.accentLightBlue),
            const SizedBox(width: 8),
            Text(
              'Controle PTZ Virtual: ${_camera.name}',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Controle panorâmico (Pan), inclinação (Tilt) e zoom digital via ONVIF/RTSP.',
              style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 0,
                    child: IconButton(
                      icon: const Icon(FluentIcons.chevron_up, size: 22),
                      onPressed: () => _ptzAction('Subir'),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(FluentIcons.chevron_down, size: 22),
                      onPressed: () => _ptzAction('Descer'),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: IconButton(
                      icon: const Icon(FluentIcons.chevron_left, size: 22),
                      onPressed: () => _ptzAction('Esquerda'),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(FluentIcons.chevron_right, size: 22),
                      onPressed: () => _ptzAction('Direita'),
                    ),
                  ),
                  Button(
                    onPressed: () => _ptzAction('Centro (Home)'),
                    child: const Icon(FluentIcons.sync, size: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _ptzAction(String direction) {
    displayInfoBar(
      context,
      duration: const Duration(seconds: 2),
      builder: (context, close) => InfoBar(
        title: Text('PTZ: $direction'),
        content: Text('Comando $direction enviado para ${_camera.ip}'),
        severity: InfoBarSeverity.info,
        onClose: close,
      ),
    );
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      child: Container(
        color: const Color(0xFF131317),
        child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
      ),
    );
  }

  // ===========================================================================
  // LAYOUT RETRATO (PORTRAIT)
  // Imagem no topo ocupando máximo de espaço, timeline vertical no centro e menu no rodapé
  // ===========================================================================
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Top: Video Player Feed (Taking Maximum Space at the Top)
        _buildCameraVideoPlayer(isLandscape: false),

        // Center: Vertical Event Timeline
        Expanded(
          child: VerticalEventTimeline(camera: _camera),
        ),

        // Bottom: Fixed Surveillance Rodapé Menu
        _buildBottomRodapeMenu(),
      ],
    );
  }

  // ===========================================================================
  // LAYOUT PAISAGEM (LANDSCAPE)
  // Split Dual-Pane: Câmera à esquerda (62% largura) + Timeline e Menu à direita (38% largura)
  // ===========================================================================
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Left Column: Video Player filling 100% available height
        Expanded(
          flex: 62,
          child: _buildCameraVideoPlayer(isLandscape: true),
        ),

        // Right Column: Sub-header + Vertical Timeline + Compact Bottom Menu
        Expanded(
          flex: 38,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF18181D),
              border: Border(left: BorderSide(color: BCamTheme.darkBorder, width: 0.8)),
            ),
            child: Column(
              children: [
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
  // CAMERA VIDEO PLAYER WIDGET
  // ===========================================================================
  Widget _buildCameraVideoPlayer({required bool isLandscape}) {
    return Stack(
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
                    key: ValueKey('live_${_camera.id}_${_camera.streamUrl}'),
                    camera: _camera,
                    autoPlay: true,
                    showPtzOverlay: false,
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
            left: 56,
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

        // Minimalist Translucent Top Floating Header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button + Camera Name
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(const Color(0x66000000)),
                      ),
                      icon: const Icon(FluentIcons.back, size: 15, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Column(
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
                        Row(
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
                      ],
                    ),
                  ],
                ),

                // Action Pills (Favorite, Settings Gear, Full Screen)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(const Color(0x66000000)),
                      ),
                      icon: Icon(
                        _camera.isFavorite ? FluentIcons.favorite_star_fill : FluentIcons.favorite_star,
                        size: 15,
                        color: _camera.isFavorite ? BCamTheme.statusWarning : Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _camera = _camera.copyWith(isFavorite: !_camera.isFavorite);
                        });
                        context.read<CameraStorageService>().toggleFavorite(_camera.id);
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(const Color(0x66000000)),
                      ),
                      icon: const Icon(FluentIcons.settings, size: 15, color: Colors.white),
                      onPressed: _openCameraSettings,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(const Color(0x66000000)),
                      ),
                      icon: const Icon(FluentIcons.full_screen, size: 15, color: Colors.white),
                      onPressed: _openFullScreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
                        icon: FluentIcons.game,
                        label: isCompact ? 'PTZ' : 'PTZ Virtual',
                        onTap: _openPtzPanel,
                        isCompact: isCompact,
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRodapeItem(
                        icon: FluentIcons.microphone,
                        label: 'Interfone',
                        isCompact: isCompact,
                        onTap: () {
                          displayInfoBar(
                            context,
                            builder: (c, close) => InfoBar(
                              title: const Text('Áudio Bidirecional'),
                              content: const Text('Transmissão de microfone aberta com a câmera.'),
                              severity: InfoBarSeverity.info,
                              onClose: close,
                            ),
                          );
                        },
                      ),
                      _buildRodapeItem(
                        icon: FluentIcons.ringer,
                        label: 'Alarme',
                        isCompact: isCompact,
                        onTap: () {
                          displayInfoBar(
                            context,
                            builder: (c, close) => InfoBar(
                              title: const Text('Disparo Manual'),
                              content: const Text('Comando de sirene enviado para a câmera.'),
                              severity: InfoBarSeverity.warning,
                              onClose: close,
                            ),
                          );
                        },
                      ),
                      _buildRodapeItem(
                        icon: FluentIcons.diagnostic,
                        label: 'Telemetria',
                        isCompact: isCompact,
                        onTap: _showTelemetryModal,
                      ),
                      _buildRodapeItem(
                        icon: FluentIcons.settings,
                        label: 'Configurar',
                        isCompact: isCompact,
                        onTap: _openCameraSettings,
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
