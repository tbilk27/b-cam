import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../services/camera_storage_service.dart';
import '../services/diagnostic_logger_service.dart';
import '../services/firebase_notification_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/b_cam_logo.dart';
import '../widgets/live_player_view.dart';
import 'camera_detail_screen.dart';
import 'commission_screen.dart';
import 'diagnostics_screen.dart';
import 'fullscreen_camera_viewer.dart';
import 'multi_grid_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'TODAS';
  int _refreshKey = 0;
  StreamSubscription<PushNotificationPayload>? _notificationSub;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<CameraStorageService>();
    final allCameras = storage.cameras;

    List<CameraDevice> filteredCameras;
    if (_selectedFilter == 'FAVORITAS') {
      filteredCameras = storage.favoriteCameras;
    } else if (_selectedFilter != 'TODAS') {
      filteredCameras = allCameras.where((c) => c.location.toUpperCase() == _selectedFilter).toList();
    } else {
      filteredCameras = allCameras;
    }

    final uniqueLocations = allCameras.map((c) => c.location.toUpperCase()).toSet().toList();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      child: ScaffoldPage.scrollable(
      header: PageHeader(
        title: BCamLogo(size: isLandscape ? 26 : 32, showText: true),
        commandBar: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).push(
              FluentPageRoute(builder: (_) => const DiagnosticsScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: BCamTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.diagnostic, size: 14, color: BCamTheme.accentLightBlue),
                const SizedBox(width: 6),
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
                  'WI-FI ONLINE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: BCamTheme.statusOnlineGlow,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      children: [
        // Action Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      FluentPageRoute(builder: (_) => const ScanScreen()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FluentIcons.wifi, size: 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Varredura',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 4,
                child: Button(
                  onPressed: () {
                    Navigator.of(context).push(
                      FluentPageRoute(builder: (_) => const MultiGridScreen()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FluentIcons.view_dashboard, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Matriz 2x2',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(FluentIcons.refresh, size: 14),
                onPressed: () {
                  setState(() {
                    _refreshKey++;
                  });
                  DiagnosticLoggerService.instance.logInfo(
                    'HOME',
                    'Reconexão manual geral de todas as câmeras disparada (#$_refreshKey).',
                  );
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(FluentIcons.add, size: 14),
                onPressed: () {
                  Navigator.of(context).push(
                    FluentPageRoute(builder: (_) => const CommissionScreen()),
                  );
                },
              ),
            ],
          ),
        ),

        // Filter Pills
        Container(
          height: 38,
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterPill('TODAS', allCameras.length),
              _buildFilterPill('FAVORITAS', storage.favoriteCameras.length),
              ...uniqueLocations.map((loc) {
                final count = allCameras.where((c) => c.location.toUpperCase() == loc).length;
                return _buildFilterPill(loc, count);
              }),
            ],
          ),
        ),

        // Section Title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Câmeras Comissionadas (${filteredCameras.length})',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BCamTheme.textPrimary,
                ),
              ),
              Text(
                'RTSP / ONVIF',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BCamTheme.accentLightBlue,
                ),
              ),
            ],
          ),
        ),

        // Camera Feed Cards or Empty State
        if (filteredCameras.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              backgroundColor: BCamTheme.darkSurface,
              borderColor: BCamTheme.darkBorder,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.video, size: 40, color: BCamTheme.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    allCameras.isEmpty
                        ? 'Nenhuma câmera comissionada ainda.\nExecute uma varredura para detectar as câmeras ativas da sua rede Wi-Fi!'
                        : 'Nenhuma câmera nesta categoria.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: BCamTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        FluentPageRoute(builder: (_) => const ScanScreen()),
                      );
                    },
                    child: const Text('Iniciar Varredura Wi-Fi'),
                  ),
                ],
              ),
            ),
          )
        else if (isLandscape)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: filteredCameras.map((camera) {
                    return SizedBox(
                      width: itemWidth,
                      child: _buildCameraCard(context, camera, storage, isLandscape: true),
                    );
                  }).toList(),
                );
              },
            ),
          )
        else
          ...filteredCameras.map((camera) {
            return _buildCameraCard(context, camera, storage, isLandscape: false);
          }),
        const SizedBox(height: 24),
      ],
    ),
    );
  }

  Widget _buildCameraCard(
    BuildContext context,
    CameraDevice camera,
    CameraStorageService storage, {
    required bool isLandscape,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 0 : 16,
        vertical: isLandscape ? 0 : 8,
      ),
      child: Card(
        backgroundColor: BCamTheme.darkSurface,
        borderColor: BCamTheme.darkBorder,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Video Player
            AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    FluentPageRoute(
                      builder: (_) => CameraDetailScreen(camera: camera),
                    ),
                  );
                },
                onDoubleTap: () {
                  final allCameras = storage.cameras;
                  final idx = allCameras.indexOf(camera);
                  Navigator.of(context).push(
                    FluentPageRoute(
                      builder: (_) => FullscreenCameraViewer(
                        cameras: allCameras,
                        initialIndex: idx >= 0 ? idx : 0,
                      ),
                    ),
                  );
                },
                child: LivePlayerView(
                  key: ValueKey('${camera.id}_${camera.streamUrl}_$_refreshKey'),
                  camera: camera,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Camera Information Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Manufacturer Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: camera.manufacturer.brandColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: camera.manufacturer.brandColor.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    camera.manufacturer.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.of(context).push(
                        FluentPageRoute(
                          builder: (_) => CameraDetailScreen(camera: camera),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.name,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: BCamTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${camera.ip}  •  ${camera.location}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: BCamTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (camera.macAddress != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'MAC: ${camera.macAddress}',
                              style: GoogleFonts.robotoMono(
                                fontSize: 9.5,
                                color: BCamTheme.accentLightBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                IconButton(
                  icon: Icon(
                    camera.isFavorite ? FluentIcons.favorite_star_fill : FluentIcons.favorite_star,
                    size: 15,
                    color: camera.isFavorite ? BCamTheme.statusWarning : BCamTheme.textTertiary,
                  ),
                  onPressed: () {
                    storage.toggleFavorite(camera.id);
                  },
                ),
                IconButton(
                  icon: const Icon(FluentIcons.more, size: 15, color: BCamTheme.textSecondary),
                  onPressed: () {
                    _showCameraOptions(context, camera);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, int count) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? BCamTheme.accentBlue : BCamTheme.darkSurface,
            borderRadius: BorderRadius.circular(16),
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
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : BCamTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : BCamTheme.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
