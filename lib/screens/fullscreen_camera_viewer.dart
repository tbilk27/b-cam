import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../theme/fluent_theme.dart';
import '../widgets/camera_actions_bar.dart';
import '../widgets/event_playback_dialog.dart';
import '../widgets/live_player_view.dart';
import '../widgets/ptz_controller_widget.dart';
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
  bool _showPtzLandscape = true;

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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: !_showTimelineSheet,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showTimelineSheet) {
          setState(() => _showTimelineSheet = false);
        }
      },
      child: Container(
        color: Colors.black,
        child: isLandscape
            ? _buildLandscapeView(context, currentCamera)
            : _buildPortraitView(context, currentCamera),
      ),
    );
  }

  // ===========================================================================
  // LANDSCAPE LAYOUT: PTZ as an Overlay over the video
  // ===========================================================================
  Widget _buildLandscapeView(BuildContext context, CameraDevice currentCamera) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Horizontal PageView for Swiping between Cameras
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleHud,
          onDoubleTap: () => Navigator.of(context).pop(),
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.horizontal,
            physics: const PageScrollPhysics(),
            itemCount: widget.cameras.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
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

        // 2. PTZ Overlay in Landscape (Positioned on the right side)
        if (_showPtzLandscape && _showHud)
          Positioned(
            right: 20,
            bottom: 60,
            child: PtzControllerWidget(
              camera: currentCamera,
              isOverlay: true,
              onClose: () => setState(() => _showPtzLandscape = false),
            ),
          ),

        // 3. Fullscreen HUD Overlay (Top App Bar & Bottom Controls)
        AnimatedOpacity(
          opacity: _showHud ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: IgnorePointer(
            ignoring: !_showHud,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopBar(currentCamera, isLandscape: true),
                  _buildBottomBar(currentCamera, isLandscape: true),
                ],
              ),
            ),
          ),
        ),

        // 4. Sliding Bottom Sheet for Timeline
        if (_showTimelineSheet) _buildTimelineDrawer(currentCamera),
      ],
    );
  }

  // ===========================================================================
  // PORTRAIT LAYOUT: PTZ Controls placed directly BELOW the camera image
  // ===========================================================================
  Widget _buildPortraitView(BuildContext context, CameraDevice currentCamera) {
    return SafeArea(
      child: Column(
        children: [
          // Top Navigation Bar
          _buildTopBar(currentCamera, isLandscape: false),

          // 1. Camera Image at Top (Swipeable PageView)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => Navigator.of(context).pop(),
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.cameras.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final camera = widget.cameras[index];
                  return LivePlayerView(
                    key: ValueKey('fullscreen_portrait_${camera.id}_${camera.streamUrl}'),
                    camera: camera,
                    autoPlay: true,
                    showPtzOverlay: false,
                  );
                },
              ),
            ),
          ),

          // 2. PTZ Commands placed directly BELOW the image
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // Direct PTZ Controls Below Image
                      PtzControllerWidget(
                        camera: currentCamera,
                        isOverlay: false,
                      ),

                      const SizedBox(height: 12),

                      // Camera Hardware Quick Actions (Sirene, Holofote, Falar, Ouvir, Visão Noturna)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CameraActionsBar(camera: currentCamera),
                      ),

                      const SizedBox(height: 14),

                      // Bottom Action Buttons (Timeline & Camera Dots)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FilledButton(
                              onPressed: () {
                                setState(() => _showTimelineSheet = !_showTimelineSheet);
                              },
                              child: Row(
                                children: [
                                  const Icon(FluentIcons.timeline_progress, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Linha do Tempo',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: List.generate(widget.cameras.length, (idx) {
                                final isSelected = idx == _currentIndex;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: isSelected ? 16 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isSelected ? BCamTheme.accentLightBlue : const Color(0x3DFFFFFF),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Timeline Drawer overlay if open
                if (_showTimelineSheet) _buildTimelineDrawer(currentCamera),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(CameraDevice currentCamera, {required bool isLandscape}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xD9101014),
        border: Border(bottom: BorderSide(color: BCamTheme.darkBorder, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                style: ButtonStyle(backgroundColor: WidgetStateProperty.all(const Color(0x73000000))),
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
                    style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  Text(
                    '${currentCamera.manufacturer.displayName} • ${currentCamera.ip}',
                    style: GoogleFonts.robotoMono(fontSize: 10.5, color: BCamTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (isLandscape)
                IconButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      _showPtzLandscape ? BCamTheme.accentBlue.withValues(alpha: 0.4) : const Color(0x73000000),
                    ),
                  ),
                  icon: const Icon(FluentIcons.game, size: 16, color: BCamTheme.accentLightBlue),
                  onPressed: () => setState(() => _showPtzLandscape = !_showPtzLandscape),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BCamTheme.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BCamTheme.darkBorder),
                ),
                child: Text(
                  '${_currentIndex + 1}/${widget.cameras.length}',
                  style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(CameraDevice currentCamera, {required bool isLandscape}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xD9101014),
        border: Border(top: BorderSide(color: BCamTheme.darkBorder, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FilledButton(
            onPressed: () {
              setState(() => _showTimelineSheet = !_showTimelineSheet);
              _hudHideTimer?.cancel();
            },
            child: Row(
              children: [
                const Icon(FluentIcons.timeline_progress, size: 14),
                const SizedBox(width: 6),
                Text('Linha do Tempo', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
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
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: Row(
              children: [
                const Icon(FluentIcons.chrome_restore, size: 12),
                const SizedBox(width: 4),
                const Text('Reduzir', style: TextStyle(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDrawer(CameraDevice currentCamera) {
    return Positioned(
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
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(FluentIcons.timeline_progress, size: 16, color: BCamTheme.accentLightBlue),
                      const SizedBox(width: 8),
                      Text(
                        'Eventos Gravados: ${currentCamera.name}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 14, color: Color(0xB3FFFFFF)),
                    onPressed: () => setState(() => _showTimelineSheet = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: VerticalEventTimeline(
                camera: currentCamera,
                onEventTap: (CameraEvent event) {
                  EventPlaybackDialog.show(context, event, currentCamera);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
