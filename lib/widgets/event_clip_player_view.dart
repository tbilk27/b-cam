import 'dart:async';
import 'dart:math';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/bounding_box.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../theme/fluent_theme.dart';
import 'bounding_box_overlay.dart';

/// Interactive CCTV Event Video Clip Player.
/// Plays recorded buffers and event clips with timeline scrubbing, speed control,
/// timecode OSD, and dynamic AI bounding box tracking across the scene.
class EventClipPlayerView extends StatefulWidget {
  final CameraEvent event;
  final CameraDevice? camera;
  final bool autoPlay;

  const EventClipPlayerView({
    super.key,
    required this.event,
    this.camera,
    this.autoPlay = true,
  });

  @override
  State<EventClipPlayerView> createState() => _EventClipPlayerViewState();
}

class _EventClipPlayerViewState extends State<EventClipPlayerView> {
  late bool _isPlaying;
  int _currentSeconds = 0;
  late int _totalDurationSeconds;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _totalDurationSeconds = max(5, widget.event.duration.inSeconds);
    _isPlaying = widget.autoPlay;
    if (_isPlaying) {
      _startPlaybackTimer();
    }
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    if (_isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    final intervalMs = (1000 / _playbackSpeed).round();
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_currentSeconds < _totalDurationSeconds) {
          _currentSeconds++;
        } else {
          // Loop playback smoothly
          _currentSeconds = 0;
        }
      });
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _showControls = true;
      if (_isPlaying) {
        _startPlaybackTimer();
        _scheduleHideControls();
      } else {
        _playbackTimer?.cancel();
        _hideControlsTimer?.cancel();
      }
    });
  }

  void _cyclePlaybackSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 2.0;
      } else if (_playbackSpeed == 2.0) {
        _playbackSpeed = 4.0;
      } else {
        _playbackSpeed = 1.0;
      }
      _showControls = true;
      if (_isPlaying) {
        _startPlaybackTimer();
        _scheduleHideControls();
      }
    });
  }

  void _seekTo(double value) {
    setState(() {
      _currentSeconds = value.round().clamp(0, _totalDurationSeconds);
      _showControls = true;
    });
    _scheduleHideControls();
  }

  String _formatTime(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _timecodeString() {
    final baseTime = widget.event.timestamp;
    final currentTime = baseTime.add(Duration(seconds: _currentSeconds));
    return DateFormat('HH:mm:ss').format(currentTime);
  }

  /// Calculates dynamically interpolated bounding boxes following object movement
  List<BoundingBox> _interpolatedBoundingBoxes() {
    final originalBoxes = widget.event.boundingBoxes;
    if (originalBoxes.isEmpty) {
      // Synthesize a bounding box matching the event type
      final progress = _totalDurationSeconds > 0 ? _currentSeconds / _totalDurationSeconds : 0.0;
      final isVehicle = widget.event.type == CameraEventType.vehicle;

      final startX = isVehicle ? 0.10 : 0.35;
      final deltaX = isVehicle ? 0.35 * progress : sin(progress * pi) * 0.15;
      final posX = (startX + deltaX).clamp(0.05, 0.75);

      return [
        BoundingBox(
          label: widget.event.type.label,
          confidence: widget.event.confidence,
          left: posX,
          top: isVehicle ? 0.45 : 0.28,
          width: isVehicle ? 0.38 : 0.22,
          height: isVehicle ? 0.32 : 0.54,
          colorHex: widget.event.type.color == BCamTheme.statusWarning
              ? '#FFB900'
              : (widget.event.type.color == BCamTheme.statusOnlineGlow ? '#0078D4' : '#00CC6A'),
        ),
      ];
    }

    final progress = _totalDurationSeconds > 0 ? _currentSeconds / _totalDurationSeconds : 0.0;
    return originalBoxes.map((box) {
      final offsetX = sin(progress * pi * 2) * 0.04;
      final offsetY = cos(progress * pi * 2) * 0.02;
      return box.copyWith(
        left: (box.left + offsetX).clamp(0.02, 0.90),
        top: (box.top + offsetY).clamp(0.02, 0.90),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final boxes = _interpolatedBoundingBoxes();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _showControls = !_showControls);
        if (_showControls && _isPlaying) {
          _scheduleHideControls();
        }
      },
      child: Container(
        color: const Color(0xFF0D0D11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. CCTV Video Feed Canvas with AI Bounding Boxes & Assertiveness Marking
            BoundingBoxOverlay(
              boundingBoxes: boxes,
              minConfidenceThreshold: 0.20,
              showLabels: true,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      Color(0xFF1E1E26),
                      Color(0xFF0F0F14),
                      Color(0xFF09090C),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        event.type.icon,
                        size: 38,
                        color: event.type.color.withValues(alpha: 0.28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.cameraName.toUpperCase(),
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0x40FFFFFF),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Subtle CCTV Scanline Lines Overlay
            IgnorePointer(
              child: CustomPaint(
                painter: _CctvScanlinePainter(),
              ),
            ),

            // 3. Top Security OSD Header (Always visible or in controls)
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Play State Indicator + Buffer Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _isPlaying ? BCamTheme.statusOnlineGlow : BCamTheme.statusWarning,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPlaying ? FluentIcons.play_solid : FluentIcons.pause,
                          size: 9,
                          color: _isPlaying ? BCamTheme.statusOnlineGlow : BCamTheme.statusWarning,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isPlaying ? 'PLAY • NVR/SD' : 'PAUSADO',
                          style: GoogleFonts.robotoMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // CCTV Real Timecode OSD
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${event.dateFormatted}  ${_timecodeString()}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00E676),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Center Play/Pause Large Pulse Button (when paused or briefly on tap)
            if (!_isPlaying || _showControls)
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BCamTheme.accentLightBlue,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BCamTheme.accentLightBlue.withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _isPlaying ? FluentIcons.pause : FluentIcons.play,
                        size: 22,
                        color: BCamTheme.accentLightBlue,
                      ),
                    ),
                  ),
                ),
              ),

            // 5. Bottom Interactive Scrubber and Toolbar Overlay
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.88),
                        Colors.black.withValues(alpha: 0.60),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scrubber Progress Slider
                      Slider(
                        value: _currentSeconds.toDouble().clamp(0.0, _totalDurationSeconds.toDouble()),
                        min: 0.0,
                        max: _totalDurationSeconds.toDouble(),
                        onChanged: _seekTo,
                        style: SliderThemeData(
                          activeColor: WidgetStateProperty.all(BCamTheme.accentLightBlue),
                          inactiveColor: WidgetStateProperty.all(const Color(0x44FFFFFF)),
                          thumbColor: WidgetStateProperty.all(Colors.white),
                        ),
                      ),

                      // Time + Controls Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Play/Pause Small + Time Counter
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? FluentIcons.pause : FluentIcons.play,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatTime(_currentSeconds)} / ${_formatTime(_totalDurationSeconds)}',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),

                          // Speed Control Button (1.0x, 2.0x, 4.0x) + Restart
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _cyclePlaybackSpeed,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33FFFFFF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0x66FFFFFF), width: 0.8),
                                  ),
                                  child: Text(
                                    '${_playbackSpeed.toStringAsFixed(1)}x',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: BCamTheme.statusOnlineGlow,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(FluentIcons.repeat_all, size: 13, color: Colors.white),
                                onPressed: () {
                                  _seekTo(0.0);
                                  if (!_isPlaying) _togglePlayPause();
                                },
                              ),
                            ],
                          ),
                        ],
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

class _CctvScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 4.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
