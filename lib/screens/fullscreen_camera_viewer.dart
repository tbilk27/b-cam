import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../theme/fluent_theme.dart';
import '../widgets/live_player_view.dart';
import '../widgets/vertical_event_timeline.dart';

class FullscreenCameraViewer extends StatefulWidget {
  final List<CameraDevice> cameras;
  final int initialIndex;

  const FullscreenCameraViewer({
    super.key,
    required this.cameras,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenCameraViewer> createState() => _FullscreenCameraViewerState();
}

class _FullscreenCameraViewerState extends State<FullscreenCameraViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showHud = true;
  Timer? _hudHideTimer;
  bool _showTimelineSheet = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _startHudTimer();
  }

  void _startHudTimer() {
    _hudHideTimer?.cancel();
    _hudHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_showTimelineSheet) {
        setState(() {
          _showHud = false;
        });
      }
    });
  }

  void _toggleHud() {
    setState(() {
      _showHud = !_showHud;
    });
    if (_showHud) {
      _startHudTimer();
    } else {
      _hudHideTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _hudHideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar'),
          ),
        ),
      );
    }

    final currentCamera = widget.cameras[_currentIndex];

    return PopScope(
      canPop: !_showTimelineSheet,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showTimelineSheet) {
          setState(() => _showTimelineSheet = false);
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Horizontal PageView for Swiping between Cameras in Full Screen
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleHud,
              // Double-tap exits full screen back to normal view
              onDoubleTap: () {
                Navigator.of(context).pop();
              },
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.horizontal,
                physics: const PageScrollPhysics(),
                itemCount: widget.cameras.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  _startHudTimer();
                },
                itemBuilder: (context, index) {
                  final camera = widget.cameras[index];
                  return Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: LivePlayerView(
                        key: ValueKey('fullscreen_${camera.id}_${camera.streamUrl}'),
                        camera: camera,
                        autoPlay: true,
                        showPtzOverlay: false,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 2. Fullscreen HUD Overlay (Top App Bar & Controls)
            AnimatedOpacity(
              opacity: _showHud ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showHud,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back / Exit Fullscreen Button
                            Row(
                              children: [
                                IconButton(
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(const Color(0x73000000)),
                                  ),
                                  icon: const Icon(FluentIcons.back, size: 16, color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentCamera.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${currentCamera.manufacturer.displayName} • ${currentCamera.ip}',
                                      style: GoogleFonts.robotoMono(
                                        fontSize: 11,
                                        color: BCamTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Camera Paging Index & Exit Hint
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: BCamTheme.darkSurface.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: BCamTheme.darkBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(FluentIcons.view_dashboard, size: 12, color: BCamTheme.accentLightBlue),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_currentIndex + 1} / ${widget.cameras.length}',
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(const Color(0x73000000)),
                                  ),
                                  icon: const Icon(FluentIcons.full_screen, size: 16, color: BCamTheme.accentLightBlue),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Gesture Hint Pill (Centered Floating Guide)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x8A000000),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x1FFFFFFF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(FluentIcons.touch, size: 13, color: BCamTheme.accentLightBlue),
                            const SizedBox(width: 6),
                            Text(
                              'Arraste para trocar de câmera • Duplo toque para sair',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xB3FFFFFF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom HUD Toolbar (Timeline Trigger, Snapshot, Info)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Vertical Timeline Trigger Button
                            FilledButton(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  _showTimelineSheet ? BCamTheme.accentBlue : BCamTheme.darkSurface,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showTimelineSheet = !_showTimelineSheet;
                                });
                                _hudHideTimer?.cancel();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(FluentIcons.timeline_progress, size: 15),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Linha do Tempo',
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),

                            // Camera switcher dots
                            Row(
                              children: List.generate(widget.cameras.length, (idx) {
                                final isSelected = idx == _currentIndex;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: isSelected ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isSelected ? BCamTheme.accentLightBlue : const Color(0x3DFFFFFF),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),

                            // Exit Button
                            Button(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(FluentIcons.chrome_restore, size: 13),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Reduzir',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
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
              ),
            ),

            // 3. Sliding Bottom Sheet / Drawer for Vertical Timeline
            if (_showTimelineSheet)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.58,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141418),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border.all(color: BCamTheme.darkBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag Handle & Close Bar
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4, left: 16, right: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0x3DFFFFFF),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(FluentIcons.chrome_close, size: 14, color: Color(0xB3FFFFFF)),
                              onPressed: () {
                                setState(() {
                                  _showTimelineSheet = false;
                                });
                                _startHudTimer();
                              },
                            ),
                          ],
                        ),
                      ),

                      // Vertical Timeline inside Sheet
                      Expanded(
                        child: SingleChildScrollView(
                          child: VerticalEventTimeline(
                            camera: currentCamera,
                            onEventTap: (CameraEvent event) {
                              displayInfoBar(
                                context,
                                builder: (context, close) => InfoBar(
                                  title: Text('Evento: ${event.type.label}'),
                                  content: Text('Carregando clipe gravado às ${event.timeFormatted}...'),
                                  severity: InfoBarSeverity.info,
                                  onClose: close,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
