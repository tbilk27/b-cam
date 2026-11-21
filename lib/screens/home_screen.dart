import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../models/manufacturer.dart';
import '../models/scan_result.dart';
import '../services/ai_vision_agent_service.dart';
import '../services/auth_service.dart';
import '../services/camera_event_service.dart';
import '../services/camera_storage_service.dart';
import '../services/diagnostic_logger_service.dart';
import '../services/firebase_notification_service.dart';
import '../services/network_scanner_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/b_cam_logo.dart';
import '../widgets/camera_snapshot_poster.dart';
import '../widgets/event_playback_dialog.dart';
import 'camera_detail_screen.dart';
import 'camera_provisioning_screen.dart';
import 'commission_screen.dart';
import 'diagnostics_screen.dart';
import 'fullscreen_camera_viewer.dart';
import 'multi_grid_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Navigation: Instagram-style Tab Index (0: Feed, 1: Radar, 2: [+], 3: Timeline, 4: Telemetry)
  int _currentTabIndex = 0;

  // Filters for Camera Feed (Tab 0)
  String _selectedFilter = 'TODAS';
  int _refreshKey = 0;
  StreamSubscription<PushNotificationPayload>? _notificationSub;

  // Radar / Network Scanner (Tab 1)
  final _scannerService = NetworkScannerService();
  StreamSubscription<ScanProgress>? _scanSub;
  final List<ScanResult> _radarDiscovered = [];
  bool _isRadarScanning = false;
  double _radarProgress = 0.0;
  String _radarSubnet = '192.168.3';

  @override
  void initState() {
    super.initState();
    _initScannerSubnet();
    _notificationSub = FirebaseNotificationService.instance.onNotificationReceived.listen((payload) {
      if (!mounted) return;
      displayInfoBar(
        context,
        duration: const Duration(seconds: 7),
        builder: (context, close) => InfoBar(
          title: Text(payload.title),
          content: Text(payload.body),
          action: FilledButton(
            onPressed: () {
              close();
              FirebaseNotificationService.instance.onNotificationTapped(payload);
            },
            child: const Text('Ver Vídeo'),
          ),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _initScannerSubnet() async {
    try {
      final prefix = await _scannerService.getLocalSubnetPrefix();
      if (mounted) setState(() => _radarSubnet = prefix);
    } catch (_) {}
  }

  void _startRadarScan() {
    if (_isRadarScanning) return;
    setState(() {
      _isRadarScanning = true;
      _radarDiscovered.clear();
      _radarProgress = 0.0;
    });

    _scanSub?.cancel();
    _scanSub = _scannerService.scanSubnet(subnetPrefix: _radarSubnet).listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _radarProgress = progress.progress;
          _radarDiscovered.clear();
          _radarDiscovered.addAll(progress.foundCameras);
        });
      },
      onDone: () {
        if (mounted) setState(() => _isRadarScanning = false);
      },
      onError: (_) {
        if (mounted) setState(() => _isRadarScanning = false);
      },
    );
  }

  void _showAddCameraActionSheet() {
    showDialog(
      context: context,
      builder: (ctx) {
        return ContentDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: BCamTheme.accentBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(FluentIcons.add, size: 18, color: BCamTheme.accentLightBlue),
              ),
              const SizedBox(width: 10),
              Text(
                'Adicionar Câmera',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Como você deseja adicionar o novo dispositivo ao b-cam?',
                style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
              ),
              const SizedBox(height: 14),

              // Option 1: Brand New Camera Provisioning (Wi-Fi QR Code / SmartConfig)
              _buildAddActionOption(
                icon: FluentIcons.q_r_code,
                color: BCamTheme.statusOnlineGlow,
                title: 'Câmera Nova (Sem Wi-Fi)',
                subtitle: 'Envie rede e senha via QR Code para a lente ou SmartConfig',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    FluentPageRoute(builder: (_) => const CameraProvisioningScreen()),
                  );
                },
              ),

              const SizedBox(height: 10),

              // Option 2: Manual Commissioning
              _buildAddActionOption(
                icon: FluentIcons.edit,
                color: BCamTheme.accentLightBlue,
                title: 'Comissionar Manualmente',
                subtitle: 'Informe endereço IP, porta RTSP (554), ONVIF e senha',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    FluentPageRoute(builder: (_) => const CommissionScreen()),
                  );
                },
              ),

              const SizedBox(height: 10),

              // Option 3: Wi-Fi Subnet Scan
              _buildAddActionOption(
                icon: FluentIcons.network_device_scanning,
                color: const Color(0xFFFF9500),
                title: 'Varredura da Rede Wi-Fi',
                subtitle: 'Procurar câmeras ativas conectadas no roteador',
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _currentTabIndex = 1);
                  _startRadarScan();
                },
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddActionOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BCamTheme.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(FluentIcons.chevron_right, size: 12, color: BCamTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xFF0F0F13),
        child: Column(
          children: [
            // Instagram-Style Top App Header (Always at top)
            _buildInstagramTopHeader(),

            // Dynamic Body Content
            Expanded(
              child: _buildCurrentTab(),
            ),

            // Instagram-Style Fixed Command Bar (Permanently docked at the bottom)
            _buildInstagramBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTabIndex) {
      case 0:
        return _buildCameraFeedTab();
      case 1:
        return _buildRadarScannerTab();
      case 3:
        return _buildEventsTimelineTab();
      case 4:
        return _buildDiagnosticsTab();
      default:
        return _buildCameraFeedTab();
    }
  }

  // ===========================================================================
  // INSTAGRAM-STYLE TOP HEADER
  // ===========================================================================
  Widget _buildInstagramTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        border: Border(bottom: BorderSide(color: BCamTheme.darkBorder, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Brand Wordmark / Logo • Powered by Bilk Sistemas
          const BCamLogo(size: 26, showText: true, showPoweredBy: true),

          // Right: Action Command Icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Matrix 2x2 View Shortcut
              IconButton(
                icon: const Icon(FluentIcons.view_dashboard, size: 16),
                onPressed: () {
                  Navigator.of(context).push(
                    FluentPageRoute(builder: (_) => const MultiGridScreen()),
                  );
                },
              ),
              const SizedBox(width: 4),

              // Wi-Fi Online Status Pill
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _currentTabIndex = 4);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BCamTheme.darkSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: BCamTheme.statusOnlineGlow,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ONLINE',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: BCamTheme.statusOnlineGlow,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Refresh Feed
              IconButton(
                icon: const Icon(FluentIcons.refresh, size: 14),
                onPressed: () {
                  setState(() => _refreshKey++);
                  DiagnosticLoggerService.instance.logInfo(
                    'HOME',
                    'Reconexão manual geral de todas as câmeras disparada (#$_refreshKey).',
                  );
                },
              ),
              const SizedBox(width: 4),

              // User Profile & Referral Shortcut (Google Account & WhatsApp Share)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).push(
                    FluentPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0078D4).withValues(alpha: 0.25),
                    border: Border.all(color: const Color(0xFF4DA6FF), width: 1.2),
                  ),
                  child: Center(
                    child: Consumer<AuthService>(
                      builder: (context, auth, _) {
                        final user = auth.currentUser;
                        final initial = (user != null && user.displayName.isNotEmpty)
                            ? user.displayName[0].toUpperCase()
                            : 'G';
                        return Text(
                          initial,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 0: INSTAGRAM-STYLE CAMERA FEED
  // ===========================================================================
  Widget _buildCameraFeedTab() {
    final storage = context.watch<CameraStorageService>();
    final allCameras = storage.cameras;

    List<CameraDevice> filteredCameras;
    if (_selectedFilter == 'FAVORITAS') {
      filteredCameras = storage.favoriteCameras;
    } else if (_selectedFilter == 'DESATIVADAS') {
      filteredCameras = storage.disabledCameras;
    } else if (_selectedFilter != 'TODAS') {
      filteredCameras = allCameras.where((c) => c.location.toUpperCase() == _selectedFilter).toList();
    } else {
      filteredCameras = allCameras;
    }

    final uniqueLocations = allCameras.map((c) => c.location.toUpperCase()).toSet().toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Filter Pills Bar (Instagram story style bubbles)
          Container(
            height: 42,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _buildFilterPill('TODAS', allCameras.length),
                _buildFilterPill('FAVORITAS', storage.favoriteCameras.length),
                if (storage.disabledCameras.isNotEmpty)
                  _buildFilterPill('DESATIVADAS', storage.disabledCameras.length),
                ...uniqueLocations.map((loc) {
                  final count = allCameras.where((c) => c.location.toUpperCase() == loc).length;
                  return _buildFilterPill(loc, count);
                }),
              ],
            ),
          ),

          // Camera Cards Feed
          if (filteredCameras.isEmpty)
            _buildEmptyCameraFeed(allCameras.isEmpty)
          else
            ...filteredCameras.map((camera) {
              return _buildCameraFeedCard(camera, storage);
            }),
        ],
      );
  }

  Widget _buildCameraFeedCard(CameraDevice camera, CameraStorageService storage) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF15151B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row of the Post
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: (camera.isEnabled && camera.isOnline)
                            ? BCamTheme.statusOnlineGlow
                            : (camera.isEnabled ? BCamTheme.statusOffline : BCamTheme.statusWarning),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.name,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        Text(
                          '${camera.location} • ${camera.ip}',
                          style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Prominent Online / Offline Status Badge
                    _buildCameraOnlineIconBadge(camera),
                    IconButton(
                      icon: const Icon(FluentIcons.more_vertical, size: 14),
                      onPressed: () => _showCameraOptions(context, camera),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lightweight Snapshot Poster (Last Accessed Image & Resource Optimization)
          // Live RTSP playback starts smoothly when the user enters the camera.
          CameraSnapshotPoster(
            camera: camera,
            onTap: () {
              Navigator.of(context).push(
                FluentPageRoute(builder: (_) => CameraDetailScreen(camera: camera)),
              );
            },
            onDoubleTap: () {
              final all = storage.cameras;
              final idx = all.indexOf(camera);
              Navigator.of(context).push(
                FluentPageRoute(
                  builder: (_) => FullscreenCameraViewer(
                    cameras: all,
                    initialIndex: idx >= 0 ? idx : 0,
                  ),
                ),
              );
            },
          ),

          // Instagram-Style Quick Action Bar below Video
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Favorite Toggle
                    IconButton(
                      icon: Icon(
                        camera.isFavorite ? FluentIcons.heart_fill : FluentIcons.heart,
                        size: 18,
                        color: camera.isFavorite ? const Color(0xFFFF3B30) : BCamTheme.textSecondary,
                      ),
                      onPressed: () => storage.toggleFavorite(camera.id),
                    ),
                    const SizedBox(width: 8),

                    // Open Details & Timeline
                    IconButton(
                      icon: const Icon(FluentIcons.timeline_progress, size: 18, color: BCamTheme.accentLightBlue),
                      onPressed: () {
                        Navigator.of(context).push(
                          FluentPageRoute(builder: (_) => CameraDetailScreen(camera: camera)),
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // Test AI Vision Detection
                    IconButton(
                      icon: const Icon(FluentIcons.robot, size: 18, color: BCamTheme.accentLightBlue),
                      onPressed: () {
                        final evt = AiVisionAgentService.instance.testDetectionWithConfidence(
                          camera: camera,
                          simulatedConfidence: 0.94,
                          label: 'Pessoa',
                          type: CameraEventType.person,
                        );
                        displayInfoBar(
                          context,
                          duration: const Duration(seconds: 3),
                          builder: (c, close) => InfoBar(
                            title: const Text('Visão Computacional IA'),
                            content: Text(
                              evt != null
                                  ? 'Objeto contornado na live: Pessoa (94% de assertividade)'
                                  : 'Detecção descartada pelo limiar ou zona de exclusão.',
                            ),
                            severity: InfoBarSeverity.success,
                            onClose: close,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Fullscreen Button
                IconButton(
                  icon: const Icon(FluentIcons.full_screen, size: 16),
                  onPressed: () {
                    final all = storage.cameras;
                    final idx = all.indexOf(camera);
                    Navigator.of(context).push(
                      FluentPageRoute(
                        builder: (_) => FullscreenCameraViewer(
                          cameras: all,
                          initialIndex: idx >= 0 ? idx : 0,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCameraFeed(bool hasNoCameras) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BCamTheme.darkSurface,
                border: Border.all(color: BCamTheme.darkBorder, width: 1),
              ),
              child: const Icon(FluentIcons.video, size: 30, color: BCamTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              hasNoCameras
                  ? 'Nenhuma Câmera Adicionada'
                  : 'Nenhuma câmera nesta categoria',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              hasNoCameras
                  ? 'Toque no botão central (+) para provisionar uma câmera nova ou buscar na sua rede Wi-Fi!'
                  : 'Selecione a categoria "TODAS" para ver todo o parque de câmeras.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11.5, color: BCamTheme.textSecondary, height: 1.3),
            ),
            const SizedBox(height: 18),
            if (hasNoCameras)
              FilledButton(
                onPressed: _showAddCameraActionSheet,
                child: const Text('Adicionar Câmera Agora'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOnlineIconBadge(CameraDevice camera) {
    if (!camera.isEnabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: BCamTheme.statusWarning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BCamTheme.statusWarning.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.clear_night, size: 10, color: BCamTheme.statusWarning),
            const SizedBox(width: 4),
            Text(
              'SUSPENSA',
              style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: BCamTheme.statusWarning),
            ),
          ],
        ),
      );
    }

    if (camera.isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFF00C853).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.6), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF00E676),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(FluentIcons.wifi, size: 10, color: Color(0xFF00E676)),
            const SizedBox(width: 4),
            Text(
              'ONLINE',
              style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF00E676), letterSpacing: 0.5),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.plug_disconnected, size: 10, color: Color(0xFFFF3B30)),
          const SizedBox(width: 4),
          Text(
            'OFFLINE',
            style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFFFF3B30)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, int count) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? BCamTheme.accentBlue : BCamTheme.darkSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? BCamTheme.accentLightBlue : BCamTheme.darkBorder,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : BCamTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : BCamTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: RADAR / VARREDURA DA REDE WI-FI
  // ===========================================================================
  Widget _buildRadarScannerTab() {
    final storage = context.watch<CameraStorageService>();
    final uncommissionedDiscovered = storage.filterUnregistered(_radarDiscovered);
    final alreadyCount = _radarDiscovered.length - uncommissionedDiscovered.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BCamTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(FluentIcons.network_device_scanning, size: 18, color: BCamTheme.accentLightBlue),
                      const SizedBox(width: 8),
                      Text(
                        'Radar de Câmeras na Rede',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                  if (_isRadarScanning)
                    const SizedBox(width: 16, height: 16, child: ProgressRing()),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Sub-rede monitorada: $_radarSubnet.1 – $_radarSubnet.254 (Portas RTSP 554, ONVIF 80/8080/8899, Intelbras 37777)',
                style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              if (_isRadarScanning)
                ProgressBar(value: _radarProgress * 100),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _isRadarScanning ? null : _startRadarScan,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isRadarScanning ? FluentIcons.sync : FluentIcons.search, size: 14),
                    const SizedBox(width: 6),
                    Text(_isRadarScanning ? 'Varrendo Sub-rede...' : 'Iniciar Varredura Completa'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Novos Dispositivos (${uncommissionedDiscovered.length})',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: BCamTheme.textPrimary),
        ),
        const SizedBox(height: 8),

        if (uncommissionedDiscovered.isEmpty && !_isRadarScanning)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    _radarDiscovered.isNotEmpty ? FluentIcons.check_mark : FluentIcons.search,
                    size: 32,
                    color: _radarDiscovered.isNotEmpty ? BCamTheme.statusOnlineGlow : BCamTheme.textTertiary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _radarDiscovered.isNotEmpty
                        ? 'Todas as ${_radarDiscovered.length} câmeras detectadas na rede já foram cadastradas no b-cam.'
                        : 'Nenhum dispositivo encontrado ainda.\nToque em "Iniciar Varredura Completa".',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                  ),
                  if (alreadyCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '($alreadyCount câmera(s) já cadastradas e ocultadas da lista)',
                        style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
          )
        else
          ...uncommissionedDiscovered.map((res) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF15151A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: res.detectedManufacturer.brandColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(FluentIcons.security_camera, size: 18, color: res.detectedManufacturer.brandColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${res.detectedManufacturer.displayName} (${res.ip}:554)',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        Text(
                          'Portas: ${res.openPorts.join(", ")} • Fonte: ${res.detectionSource}',
                          style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _showQuickAddCameraDialog(res),
                    child: const Text('Adicionar'),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showQuickAddCameraDialog(ScanResult res) {
    final nameCtrl = TextEditingController(text: '${res.detectedManufacturer.displayName} (${res.ip.split(".").last})');
    final userCtrl = TextEditingController(text: 'admin');
    final passCtrl = TextEditingController(
      text: res.detectedManufacturer == CameraManufacturer.intelbras ? 'Zs29364835' : (res.detectedManufacturer == CameraManufacturer.yoosee ? 'Compras10@' : ''),
    );
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return ContentDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: res.detectedManufacturer.brandColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(FluentIcons.security_camera, size: 18, color: res.detectedManufacturer.brandColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Adicionar: ${res.detectedManufacturer.displayName}',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IP: ${res.ip} • Portas: ${res.openPorts.join(", ")}',
                    style: GoogleFonts.robotoMono(fontSize: 11, color: BCamTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nome da Câmera',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: nameCtrl,
                    placeholder: 'Ex: Câmera Frente, Corredor...',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 40,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Usuário',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            TextBox(
                              controller: userCtrl,
                              placeholder: 'admin',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 60,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Senha RTSP',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            TextBox(
                              controller: passCtrl,
                              obscureText: obscure,
                              placeholder: 'Senha da câmera',
                              suffix: IconButton(
                                icon: Icon(obscure ? FluentIcons.view : FluentIcons.hide, size: 14),
                                onPressed: () => setDialogState(() => obscure = !obscure),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Atalhos rápidos da rede local:',
                    style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textTertiary),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Button(
                        onPressed: () => setDialogState(() => passCtrl.text = 'Zs29364835'),
                        child: Text('Zs29364835', style: GoogleFonts.robotoMono(fontSize: 10.5)),
                      ),
                      Button(
                        onPressed: () => setDialogState(() => passCtrl.text = 'Compras10@'),
                        child: Text('Compras10@', style: GoogleFonts.robotoMono(fontSize: 10.5)),
                      ),
                      Button(
                        onPressed: () => setDialogState(() => passCtrl.text = 'compras10'),
                        child: Text('compras10', style: GoogleFonts.robotoMono(fontSize: 10.5)),
                      ),
                      Button(
                        onPressed: () => setDialogState(() => passCtrl.text = 'admin'),
                        child: Text('admin', style: GoogleFonts.robotoMono(fontSize: 10.5)),
                      ),
                      Button(
                        onPressed: () => setDialogState(() => passCtrl.text = '123456'),
                        child: Text('123456', style: GoogleFonts.robotoMono(fontSize: 10.5)),
                      ),
                      Button(
                        onPressed: () => setDialogState(() => passCtrl.text = ''),
                        child: Text('(sem senha)', style: GoogleFonts.robotoMono(fontSize: 10.5)),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                Button(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                Button(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      FluentPageRoute(builder: (_) => CommissionScreen(scanResult: res)),
                    );
                  },
                  child: const Text('Avançado...'),
                ),
                FilledButton(
                  onPressed: () async {
                    final camName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : res.suggestedName;
                    final username = userCtrl.text.trim().isNotEmpty ? userCtrl.text.trim() : 'admin';
                    final password = passCtrl.text.trim();

                    final newCamera = CameraDevice(
                      id: 'cam_${DateTime.now().millisecondsSinceEpoch}',
                      name: camName,
                      ip: res.ip,
                      rtspPort: 554,
                      username: username,
                      password: password,
                      channel: 1,
                      manufacturer: res.detectedManufacturer,
                      location: 'Geral',
                      isEnabled: true,
                      aiDetectionEnabled: true,
                      aiMinConfidence: 0.65,
                      macAddress: res.macAddress,
                    );

                    Navigator.of(ctx).pop();
                    await context.read<CameraStorageService>().addCamera(newCamera);

                    if (mounted) {
                      displayInfoBar(
                        context,
                        builder: (c, close) => InfoBar(
                          title: const Text('Câmera Adicionada'),
                          content: Text('"$camName" adicionada com sucesso.'),
                          severity: InfoBarSeverity.success,
                          onClose: close,
                        ),
                      );
                      setState(() => _currentTabIndex = 0);
                    }
                  },
                  child: const Text('Salvar e Conectar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // TAB 3: LINHA DO TEMPO GLOBAL DE EVENTOS DE SEGURANÇA
  // ===========================================================================
  Widget _buildEventsTimelineTab() {
    final eventService = context.watch<CameraEventService>();
    final storage = context.watch<CameraStorageService>();
    final allEvents = eventService.events;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Eventos de Segurança IA (${allEvents.length})',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            Button(
              onPressed: () {
                final cameras = storage.cameras;
                if (cameras.isNotEmpty) {
                  AiVisionAgentService.instance.testDetectionWithConfidence(
                    camera: cameras.first,
                    simulatedConfidence: 0.94,
                    label: 'Pessoa',
                    type: CameraEventType.person,
                  );
                }
              },
              child: const Text('Simular Evento IA'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (allEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  const Icon(FluentIcons.clear_night, size: 36, color: BCamTheme.textSecondary),
                  const SizedBox(height: 10),
                  Text(
                    'Nenhum evento registrado ainda.',
                    style: GoogleFonts.inter(fontSize: 13, color: BCamTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'O agente de IA analisa os fluxos em tempo real e lista as ocorrências aqui.',
                    style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textTertiary),
                  ),
                ],
              ),
            ),
          )
        else
          ...allEvents.map((event) {
            final cam = storage.cameras.firstWhere(
              (c) => c.id == event.cameraId,
              orElse: () => CameraDevice(
                id: event.cameraId,
                name: 'Câmera',
                ip: '192.168.3.74',
                rtspPort: 554,
                username: 'admin',
                password: '',
                channel: 1,
                manufacturer: CameraManufacturer.intelbras,
                location: 'Local',
              ),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF15151B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: BCamTheme.accentBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      event.type == CameraEventType.person
                          ? FluentIcons.contact
                          : (event.type == CameraEventType.vehicle ? FluentIcons.car : FluentIcons.running),
                      size: 20,
                      color: BCamTheme.accentLightBlue,
                    ),
                  ),
                ),
                title: Text(
                  event.type.label,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cam.name} • ${DateFormat("HH:mm:ss (dd/MM)").format(event.timestamp)}',
                      style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Assertividade IA: ${(event.confidence * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w600, color: BCamTheme.statusOnlineGlow),
                    ),
                  ],
                ),
                trailing: const Icon(FluentIcons.play, size: 14, color: BCamTheme.accentLightBlue),
                onPressed: () {
                  EventPlaybackDialog.show(context, event, cam);
                },
              ),
            );
          }),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: TELEMETRIA, DIAGNÓSTICOS & ATUALIZAÇÃO OTA
  // ===========================================================================
  Widget _buildDiagnosticsTab() {
    return const DiagnosticsScreen();
  }

  // ===========================================================================
  // INSTAGRAM-STYLE FIXED COMMAND BAR (RODAPÉ)
  // ===========================================================================
  Widget _buildInstagramBottomBar() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        border: Border(top: BorderSide(color: BCamTheme.darkBorder, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 0. Home / Câmeras (Instagram Feed)
          _buildInstagramNavItem(
            index: 0,
            icon: FluentIcons.home,
            activeIcon: FluentIcons.home_solid,
            label: 'Início',
          ),

          // 1. Radar / Varredura (Instagram Explore / Search)
          _buildInstagramNavItem(
            index: 1,
            icon: FluentIcons.network_device_scanning,
            activeIcon: FluentIcons.network_device_scanning,
            label: 'Radar',
          ),

          // 2. Central Add Button (+) (Instagram New Post Button)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showAddCameraActionSheet,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: BCamTheme.accentBlue,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: BCamTheme.accentBlue.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(FluentIcons.add, size: 20, color: Colors.white),
              ),
            ),
          ),

          // 3. Security Events Timeline (Instagram Activity / Heart)
          _buildInstagramNavItem(
            index: 3,
            icon: FluentIcons.timeline_progress,
            activeIcon: FluentIcons.timeline_delivery,
            label: 'Eventos',
          ),

          // 4. Telemetry & Settings (Instagram Profile / Gear)
          _buildInstagramNavItem(
            index: 4,
            icon: FluentIcons.diagnostic,
            activeIcon: FluentIcons.diagnostic,
            label: 'Sistema',
          ),
        ],
      ),
    );
  }

  Widget _buildInstagramNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentTabIndex == index;
    final color = isSelected ? Colors.white : const Color(0xFF8E8E93);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _currentTabIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 20,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Camera Options Dialog
  void _showCameraOptions(BuildContext context, CameraDevice camera) {
    showDialog(
      context: context,
      builder: (ctx) {
        return ContentDialog(
          title: Text(camera.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('IP: ${camera.ip}:${camera.rtspPort}'),
              Text('Fabricante: ${camera.manufacturer.displayName}'),
              if (camera.macAddress != null) Text('MAC: ${camera.macAddress}'),
              const SizedBox(height: 12),
              Text(
                'URL Stream (Ofuscada):\n${camera.maskedStreamUrl}',
                style: GoogleFonts.robotoMono(fontSize: 10, color: BCamTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  FluentPageRoute(builder: (_) => CameraDetailScreen(camera: camera)),
                );
              },
              child: const Text('Abrir Detalhes'),
            ),
            Button(
              onPressed: () {
                context.read<CameraStorageService>().toggleCameraEnabled(camera.id);
                Navigator.of(ctx).pop();
              },
              child: Text(
                camera.isEnabled ? 'Desativar Câmera' : 'Ativar Câmera',
                style: GoogleFonts.inter(
                  color: camera.isEnabled ? BCamTheme.statusWarning : BCamTheme.statusOnlineGlow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Button(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  FluentPageRoute(builder: (_) => CommissionScreen(existingCamera: camera)),
                );
              },
              child: const Text('Editar'),
            ),
            FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(BCamTheme.statusOffline),
              ),
              onPressed: () {
                context.read<CameraStorageService>().removeCamera(camera.id);
                Navigator.of(ctx).pop();
              },
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
  }
}
