import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/camera_device.dart';
import '../theme/gta_colors.dart';

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
        color: Colors.black,
        borderRadius: BorderRadius.circular(widget.isMiniature ? 12 : 20),
        border: Border.all(
          color: _hasError
              ? GtaColors.statusOffline.withOpacity(0.5)
              : GtaColors.borderSubtle,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: GtaColors.neonPink.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
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

          // 2. Scanline & Vignette Effect Overlay (Vice City Surveillance Style)
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),
          ),

          // 3. Grid Crosshair markings in corners (Surveillance HUD)
          if (!widget.isMiniature)
            IgnorePointer(
              child: CustomPaint(
                painter: _HudCrosshairPainter(),
              ),
            ),

          // 4. Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.65),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: GtaColors.neonPink,
                        backgroundColor: GtaColors.bgSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'CONECTANDO AO FLUXO...',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        color: GtaColors.electricCyan,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Error & Fallback display
          if (_hasError)
            Container(
              color: const Color(0xEE120A16),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_rounded,
                      color: GtaColors.statusOffline,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'FLUXO INDISPONÍVEL',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: GtaColors.statusOffline,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IP: ${widget.camera.ip}:${widget.camera.rtspPort}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.rajdhani(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GtaColors.neonPink.withOpacity(0.2),
                        foregroundColor: GtaColors.neonPink,
                        side: const BorderSide(color: GtaColors.neonPink),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      onPressed: _playStream,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(
                        'RECONECTAR',
                        style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6. Top HUD Bar (Camera Name, REC indicator, Clock)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Live indicator badge
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _hasError ? GtaColors.statusOffline : GtaColors.statusOnline,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _hasError
                                ? GtaColors.statusOffline.withOpacity(0.8)
                                : GtaColors.statusOnline.withOpacity(0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _hasError ? 'OFFLINE' : 'REC • LIVE',
                      style: GoogleFonts.orbitron(
                        fontSize: widget.isMiniature ? 9 : 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                // HUD Timestamp
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GtaColors.borderSubtle, width: 0.8),
                  ),
                  child: Text(
                    _currentTime,
                    style: GoogleFonts.orbitron(
                      fontSize: widget.isMiniature ? 9 : 11,
                      fontWeight: FontWeight.bold,
                      color: GtaColors.electricCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 7. Bottom HUD Bar (Brand, Channel, Resolution)
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.camera.manufacturer.brandColor.withOpacity(0.6),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${widget.camera.manufacturer.displayName.toUpperCase()} • CH${widget.camera.channel}',
                      style: GoogleFonts.rajdhani(
                        fontSize: widget.isMiniature ? 10 : 12,
                        fontWeight: FontWeight.w800,
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
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(32, 32),
                        ),
                        icon: Icon(
                          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: _isMuted ? Colors.white54 : GtaColors.electricCyan,
                          size: 16,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            _player.setVolume(_isMuted ? 0 : 100);
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      // Reload
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(32, 32),
                        ),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 16),
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
      ..color = GtaColors.electricCyan.withOpacity(0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const cornerLen = 14.0;
    const padding = 8.0;

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
