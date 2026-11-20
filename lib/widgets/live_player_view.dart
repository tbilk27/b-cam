import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/camera_device.dart';
import '../theme/fluent_theme.dart';

class LivePlayerView extends StatefulWidget {
  final CameraDevice camera;
  final bool autoPlay;
  final bool showPtzOverlay;
  final bool isMiniature;

  const LivePlayerView({
    super.key,
    required this.camera,
    this.autoPlay = true,
    this.showPtzOverlay = false,
    this.isMiniature = false,
  });

  @override
  State<LivePlayerView> createState() => _LivePlayerViewState();
}

class _LivePlayerViewState extends State<LivePlayerView> {
  late final Player _player;
  late final VideoController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isMuted = true;
  Timer? _clockTimer;
  String _currentTime = '';
  StreamSubscription? _errorSub;
  StreamSubscription? _bufferingSub;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _startHudClock();
  }

  void _startHudClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
        });
      }
    });
    _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
  }

  void _initPlayer() {
    try {
      _player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 1024 * 1024 * 4, // 4MB low latency buffer
        ),
      );
      _controller = VideoController(_player);

      _errorSub = _player.stream.error.listen((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = error;
            _isLoading = false;
          });
        }
      });

      _bufferingSub = _player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _isLoading = buffering;
          });
        }
      });

      if (widget.autoPlay) {
        _playStream();
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _playStream() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final url = widget.camera.streamUrl;
      await _player.setVolume(widget.isMiniature ? 0 : 100);

      // Fine-tune RTSP transport per manufacturer: Yoosee requires UDP, Intelbras/Dahua/Hikvision excel on TCP
      try {
        if (widget.camera.manufacturer.id == 'yoosee') {
          await (_player.platform as dynamic).setProperty('rtsp-transport', 'udp');
          await (_player.platform as dynamic).setProperty('demuxer-lavf-o', 'rtsp_transport=udp');
        } else {
          await (_player.platform as dynamic).setProperty('rtsp-transport', 'tcp');
        }
      } catch (e) {
        debugPrint('Note: setProperty rtsp-transport: $e');
      }

      await _player.open(
        Media(
          url,
          httpHeaders: {
            'User-Agent': 'b-cam/1.0',
          },
        ),
        play: true,
      );

      // Auto resolve loading after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_hasError) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant LivePlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.streamUrl != widget.camera.streamUrl) {
      _playStream();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _errorSub?.cancel();
    _bufferingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12),
        borderRadius: BorderRadius.circular(widget.isMiniature ? 8 : 12),
        border: Border.all(
          color: _hasError
              ? BCamTheme.statusOffline.withValues(alpha: 0.5)
              : BCamTheme.darkBorder,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Canvas
          Video(
            controller: _controller,
            fit: BoxFit.cover,
            controls: NoVideoControls,
          ),

          // 2. Subtle Vignette Effect
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.25,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),

          // 3. Grid Crosshair markings in corners (Sober Surveillance HUD)
          if (!widget.isMiniature)
            IgnorePointer(
              child: CustomPaint(
                painter: _HudCrosshairPainter(),
              ),
            ),

          // 4. Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: widget.isMiniature
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BCamTheme.accentLightBlue,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: BCamTheme.accentLightBlue,
                              backgroundColor: Color(0xFF2A2A30),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'CONECTANDO AO FLUXO...',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: BCamTheme.textSecondary,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

          // 5. Error & Fallback display
          if (_hasError)
            Container(
              color: const Color(0xFF19161B),
              padding: EdgeInsets.all(widget.isMiniature ? 6 : 16),
              child: Center(
                child: widget.isMiniature
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videocam_off_rounded,
                            color: BCamTheme.statusOffline,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'OFFLINE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: BCamTheme.statusOffline,
                            ),
                          ),
                          Text(
                            '${widget.camera.ip}:${widget.camera.rtspPort}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 8.5,
                              color: BCamTheme.textTertiary,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videocam_off_rounded,
                            color: BCamTheme.statusOffline,
                            size: 38,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'FLUXO INDISPONÍVEL',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: BCamTheme.statusOffline,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'IP: ${widget.camera.ip}:${widget.camera.rtspPort}',
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: BCamTheme.textSecondary,
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: BCamTheme.textTertiary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BCamTheme.darkSurface,
                              foregroundColor: BCamTheme.textPrimary,
                              side: const BorderSide(color: BCamTheme.darkBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: _playStream,
                            icon: const Icon(Icons.refresh, size: 14),
                            label: Text(
                              'Reconectar',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

          // 6. Top HUD Bar (REC indicator & Timestamp)
          Positioned(
            top: 8,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Live indicator badge
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _hasError ? BCamTheme.statusOffline : BCamTheme.statusOnlineGlow,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_hasError ? BCamTheme.statusOffline : BCamTheme.statusOnlineGlow)
                                .withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _hasError ? 'OFFLINE' : 'LIVE',
                      style: GoogleFonts.inter(
                        fontSize: widget.isMiniature ? 9 : 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                // HUD Timestamp
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12, width: 0.8),
                  ),
                  child: Text(
                    _currentTime,
                    style: GoogleFonts.robotoMono(
                      fontSize: widget.isMiniature ? 9 : 10.5,
                      fontWeight: FontWeight.w600,
                      color: BCamTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 7. Bottom HUD Bar (Brand, Channel, Controls)
          Positioned(
            bottom: 8,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: widget.camera.manufacturer.brandColor.withValues(alpha: 0.7),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${widget.camera.manufacturer.displayName} • CH${widget.camera.channel}',
                      style: GoogleFonts.inter(
                        fontSize: widget.isMiniature ? 9 : 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!widget.isMiniature)
                  Row(
                    children: [
                      // Audio Mute toggle
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(5),
                          minimumSize: const Size(28, 28),
                        ),
                        icon: Icon(
                          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: _isMuted ? Colors.white54 : BCamTheme.accentLightBlue,
                          size: 15,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            _player.setVolume(_isMuted ? 0 : 100);
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      // Reload
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(5),
                          minimumSize: const Size(28, 28),
                        ),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 15),
                        onPressed: _playStream,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HudCrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const cornerLen = 10.0;
    const padding = 6.0;

    // Top-Left
    canvas.drawLine(const Offset(padding, padding + cornerLen), const Offset(padding, padding), paint);
    canvas.drawLine(const Offset(padding, padding), const Offset(padding + cornerLen, padding), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width - padding - cornerLen, padding), Offset(size.width - padding, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerLen), paint);

    // Bottom-Left
    canvas.drawLine(Offset(padding, size.height - padding - cornerLen), Offset(padding, size.height - padding), paint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLen, size.height - padding), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - padding - cornerLen, size.height - padding), Offset(size.width - padding, size.height - padding), paint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding - cornerLen), Offset(size.width - padding, size.height - padding), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
