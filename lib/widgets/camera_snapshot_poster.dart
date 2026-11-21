import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/camera_device.dart';
import '../theme/fluent_theme.dart';

/// High-efficiency snapshot poster displayed on the HomeScreen.
/// Instead of running an active RTSP decoding session (which drains CPU, GPU,
/// battery and network bandwidth), it shows the last accessed frame/snapshot
/// and prominently displays the camera's ONLINE / OFFLINE status.
class CameraSnapshotPoster extends StatelessWidget {
  final CameraDevice camera;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const CameraSnapshotPoster({
    super.key,
    required this.camera,
    required this.onTap,
    this.onDoubleTap,
  });

  String _formatLastAccessed(DateTime? dt) {
    if (dt == null) {
      return 'Último acesso: Recente';
    }
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final timeStr = DateFormat('HH:mm').format(dt);
    if (isToday) {
      return 'Último acesso: Hoje às $timeStr';
    }
    return 'Último acesso: ${DateFormat('dd/MM HH:mm').format(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D11),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Snapshot Image or Simulated CCTV Canvas
              _buildBackgroundSnapshot(),

              // 2. Subtle CCTV Scanlines
              _buildCctvScanlines(),

              // 3. Overlays & Badges (Visual only, non-blocking for gestures)
              IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Native Camera Watermark & Timestamp (OSD)
                    _buildCctvOsdTimestamp(),

                    // Top Status Overlay Bar (Online Status + Last Accessed Badge)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Prominent Online Status Badge
                          _buildOnlineStatusBadge(),

                          // Last Accessed Timestamp Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(FluentIcons.clock, size: 10, color: BCamTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  _formatLastAccessed(camera.lastAccessed ?? camera.lastSeen),
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center Action Indicator ("▶ AO VIVO • Toque para Abrir")
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: BCamTheme.accentLightBlue.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: BCamTheme.accentBlue.withValues(alpha: 0.25),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: BCamTheme.accentBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(FluentIcons.play, size: 10, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AO VIVO AO ENTRAR',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Energy/Resource Optimization Tag
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(FluentIcons.power_button, size: 9, color: Color(0xFF00E676)),
                            const SizedBox(width: 4),
                            Text(
                              'MODO ECONÔMICO',
                              style: GoogleFonts.robotoMono(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00E676),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundSnapshot() {
    if (camera.lastSnapshotPath != null && File(camera.lastSnapshotPath!).existsSync()) {
      return Image.file(
        File(camera.lastSnapshotPath!),
        fit: BoxFit.cover,
      );
    }

    // High-tech procedural surveillance scene representation
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF13131A),
            Color(0xFF0A0A0F),
            Color(0xFF141722),
          ],
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.12,
          child: Icon(
            FluentIcons.video,
            size: 64,
            color: BCamTheme.accentLightBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildCctvScanlines() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.5, 1.0],
            colors: [
              Colors.black.withValues(alpha: 0.25),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.45),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCctvOsdTimestamp() {
    final displayTime = camera.lastAccessed != null
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(camera.lastAccessed!)
        : DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

    return Positioned(
      bottom: 8,
      left: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${camera.name.toUpperCase()} • CH${camera.channel}',
            style: GoogleFonts.robotoMono(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            displayTime,
            style: GoogleFonts.robotoMono(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.75),
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineStatusBadge() {
    if (!camera.isEnabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xCC7F7F7F),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.clear_night, size: 9, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'SUSPENSA',
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (camera.isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xCC00C853),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C853).withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'ONLINE • Wi-Fi',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xCCFF3B30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FluentIcons.plug_disconnected, size: 9, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'OFFLINE',
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
