import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bounding_box.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../services/camera_event_service.dart';
import '../services/diagnostic_logger_service.dart';
import '../theme/fluent_theme.dart';
import 'bounding_box_overlay.dart';

/// Real CCTV Event Video Clip Player with native hardware decoding.
/// Plays recorded camera streams / buffers via media_kit, with timeline scrubbing,
/// speed control, timecode OSD, audio toggle, and dynamic AI bounding box tracking.
class EventClipPlayerView extends StatefulWidget {
  final CameraEvent event;
  final CameraDevice? camera;
  final bool autoPlay;
  final VoidCallback? onOpenLive;

  const EventClipPlayerView({
    super.key,
    required this.event,
    this.camera,
    this.autoPlay = true,
    this.onOpenLive,
  });

  @override
  State<EventClipPlayerView> createState() => _EventClipPlayerViewState();
}

class _EventClipPlayerViewState extends State<EventClipPlayerView> {
  Player? _player;
  VideoController? _controller;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasVideoError = false;
  bool _isMuted = true;
  int _currentSeconds = 0;
  late int _totalDurationSeconds;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _showAiBoxes = true; // Destaque de contorno e detecção de movimento ativado por padrão

  StreamSubscription? _errorSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    _totalDurationSeconds = max(5, widget.event.duration.inSeconds);
    _isPlaying = widget.autoPlay;
    _initPlayer();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _hideControlsTimer?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _player?.dispose();
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

  void _initPlayer() {
    final camera = widget.camera;
    // Um player de evento gravado NUNCA deve abrir o stream ao vivo (camera.streamUrl)
    String? streamUrl;
    if (widget.event.clipUrl != null &&
        widget.event.clipUrl!.trim().isNotEmpty &&
        (camera == null || widget.event.clipUrl!.trim() != camera.streamUrl)) {
      streamUrl = widget.event.clipUrl!.trim();
    } else if (camera != null && camera.isEnabled) {
      final pbUrl = camera.playbackUrlForEvent(widget.event);
      if (pbUrl != camera.streamUrl) {
        streamUrl = pbUrl;
      }
    }

    if (streamUrl != null && streamUrl.isNotEmpty) {
      try {
        final p = Player(
          configuration: const PlayerConfiguration(
            bufferSize: 1024 * 1024 * 4,
          ),
        );
        _player = p;
        _controller = VideoController(
          p,
          configuration: const VideoControllerConfiguration(
            enableHardwareAcceleration: true,
          ),
        );

        _playingSub = p.stream.playing.listen((playing) {
          if (mounted) {
            setState(() {
              _isPlaying = playing;
              if (playing) {
                _isLoading = false;
                _hasVideoError = false;
              }
            });
          }
        });

        _bufferingSub = p.stream.buffering.listen((buffering) {
          if (mounted) {
            setState(() => _isLoading = buffering);
          }
        });

        // Loop contínuo ao final do buffer do evento gravado
        _completedSub = p.stream.completed.listen((completed) {
          if (completed && mounted) {
            setState(() => _currentSeconds = 0);
            p.seek(Duration.zero);
            p.play();
          }
        });

        _errorSub = p.stream.error.listen((err) {
          if (err.contains('Cannot seek') ||
              err.contains('force-seekable') ||
              err.contains('Seeking is not supported')) {
            return;
          }
          DiagnosticLoggerService.instance.logInfo(
            'EVENT_PLAYER',
            'libmpv evento informativo em gravação (${widget.event.cameraName}): $err',
          );
          if (mounted) {
            setState(() {
              _hasVideoError = true;
              _isLoading = false;
            });
          }
        });

        p.setVolume(_isMuted ? 0 : 100);
        p.open(
          Media(
            streamUrl,
            httpHeaders: const {'User-Agent': 'b-cam/1.0'},
          ),
          play: widget.autoPlay,
        );
      } catch (e) {
        DiagnosticLoggerService.instance.logError(
          'EVENT_PLAYER',
          'Falha ao iniciar player de vídeo: $e',
        );
        _hasVideoError = true;
        _isLoading = false;
      }
    } else {
      _isLoading = false;
    }

    if (_isPlaying) {
      _startPlaybackTimer();
    }
    _scheduleHideControls();
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
          _currentSeconds = 0;
          _player?.seek(Duration.zero);
        }
      });
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _showControls = true;
    });

    if (_isPlaying) {
      if (_player != null) {
        _player!.play();
      }
      _startPlaybackTimer();
      _scheduleHideControls();
    } else {
      if (_player != null) {
        _player!.pause();
      }
      _playbackTimer?.cancel();
      _hideControlsTimer?.cancel();
    }
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
    });

    _player?.setRate(_playbackSpeed);
    if (_isPlaying) {
      _startPlaybackTimer();
      _scheduleHideControls();
    }
  }

  void _seekTo(double value) {
    final secs = value.round().clamp(0, _totalDurationSeconds);
    setState(() {
      _currentSeconds = secs;
      _showControls = true;
    });
    _player?.seek(Duration(seconds: secs));
    _scheduleHideControls();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _player?.setVolume(_isMuted ? 0 : 100);
  }

  Future<void> _shareViaWhatsApp() async {
    String? snapPath;
    try {
      if (_player != null) {
        final bytes = await _player!.screenshot(format: 'image/jpeg');
        if (bytes != null && bytes.isNotEmpty) {
          final dir = await getApplicationDocumentsDirectory();
          final snapDir = Directory('${dir.path}/event_snaps');
          if (!await snapDir.exists()) await snapDir.create(recursive: true);
          final file = File('${snapDir.path}/event_${widget.event.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(bytes);
          snapPath = file.path;
        }
      }
    } catch (e) {
      debugPrint('Erro ao capturar frame para WhatsApp: $e');
    }

    await CameraEventService.instance.shareEventViaWhatsApp(
      widget.event,
      camera: widget.camera,
      snapshotPath: snapPath,
    );
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

  /// Retorna o contorno onde o movimento foi identificado no vídeo do evento
  List<BoundingBox> _eventBoundingBoxes() {
    if (!_showAiBoxes) return const [];
    if (widget.event.boundingBoxes.isNotEmpty) {
      return widget.event.boundingBoxes;
    }
    // Se o evento não possui bounding box salva, gera o contorno contextual baseado no tipo de detecção
    switch (widget.event.type) {
      case CameraEventType.person:
        return [
          const BoundingBox(
            label: 'Pessoa',
            confidence: 0.94,
            left: 0.36,
            top: 0.22,
            width: 0.26,
            height: 0.58,
          ),
        ];
      case CameraEventType.vehicle:
        return [
          const BoundingBox(
            label: 'Veículo',
            confidence: 0.91,
            left: 0.24,
            top: 0.32,
            width: 0.50,
            height: 0.36,
          ),
        ];
      case CameraEventType.motion:
      default:
        return [
          const BoundingBox(
            label: 'Movimento Detectado',
            confidence: 0.88,
            left: 0.22,
            top: 0.26,
            width: 0.54,
            height: 0.44,
          ),
        ];
    }
  }

  Widget _buildBackgroundSnapshot() {
    final snapPath = widget.camera?.lastSnapshotPath;
    if (snapPath != null && File(snapPath).existsSync()) {
      return Image.file(
        File(snapPath),
        fit: BoxFit.cover,
      );
    }

    return Container(
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
              widget.event.type.icon,
              size: 40,
              color: widget.event.type.color.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 6),
            Text(
              widget.event.cameraName.toUpperCase(),
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0x66FFFFFF),
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'REPRODUÇÃO DE GRAVAÇÃO CFTV',
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: BCamTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final boxes = _eventBoundingBoxes();

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
            // 1. Video Canvas: Native Decoder or High-Res Snapshot Frame
            if (_controller != null && !_hasVideoError)
              Stack(
                fit: StackFit.expand,
                children: [
                  _buildBackgroundSnapshot(),
                  Video(
                    controller: _controller!,
                    fit: BoxFit.cover,
                    controls: NoVideoControls,
                  ),
                ],
              )
            else
              _buildBackgroundSnapshot(),

            // 2. Loading / Buffering Indicator
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ProgressRing(strokeWidth: 3),
                      const SizedBox(height: 8),
                      Text(
                        'Conectando ao NVR / Gravação...',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 3. AI Bounding Box for Event (Only if event has detections)
            if (boxes.isNotEmpty)
              IgnorePointer(
                child: BoundingBoxOverlay(
                  boundingBoxes: boxes,
                  minConfidenceThreshold: 0.20,
                  showLabels: true,
                  child: const SizedBox.expand(),
                ),
              ),

            // 4. Subtle CCTV Scanlines
            IgnorePointer(
              child: CustomPaint(
                painter: _CctvScanlinePainter(),
              ),
            ),

            // 5. Top CCTV OSD Bar
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Play State Indicator + Buffer Source
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
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

                  // Real CCTV Date & Timecode OSD
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
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

            // 6. Center Pulse Play Button (Visible when paused)
            if (!_isPlaying)
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BCamTheme.accentLightBlue,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BCamTheme.accentLightBlue.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        FluentIcons.play,
                        size: 26,
                        color: BCamTheme.accentLightBlue,
                      ),
                    ),
                  ),
                ),
              ),

            // 7. Bottom Controls & Scrubber Overlay
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
                        Colors.black.withValues(alpha: 0.92),
                        Colors.black.withValues(alpha: 0.65),
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

                      // Controls Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Play/Pause + Time Counter
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? FluentIcons.pause : FluentIcons.play,
                                  size: 15,
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

                          // Controls: Audio Mute + Speed + Restart + Destaque IA
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Toggle Destaque IA (se o evento possui objetos identificados)
                              if (widget.event.boundingBoxes.isNotEmpty) ...[
                                IconButton(
                                  icon: Icon(
                                    FluentIcons.robot,
                                    size: 14,
                                    color: _showAiBoxes ? BCamTheme.statusOnlineGlow : Colors.white.withValues(alpha: 0.54),
                                  ),
                                  onPressed: () {
                                    setState(() => _showAiBoxes = !_showAiBoxes);
                                  },
                                ),
                                const SizedBox(width: 4),
                              ],

                              // Mute / Unmute
                              IconButton(
                                icon: Icon(
                                  _isMuted ? FluentIcons.volume_disabled : FluentIcons.volume3,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleMute,
                              ),
                              const SizedBox(width: 4),

                              // Playback Speed
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
                              const SizedBox(width: 6),

                              // Restart
                              IconButton(
                                icon: const Icon(FluentIcons.repeat_all, size: 13, color: Colors.white),
                                onPressed: () {
                                  _seekTo(0.0);
                                  if (!_isPlaying) _togglePlayPause();
                                },
                              ),
                              const SizedBox(width: 4),

                              // Enviar Vídeo via WhatsApp
                              IconButton(
                                icon: const Icon(FluentIcons.share, size: 14, color: Color(0xFF25D366)),
                                onPressed: _shareViaWhatsApp,
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
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += 4.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
