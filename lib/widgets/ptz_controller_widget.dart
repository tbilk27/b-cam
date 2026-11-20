import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/camera_device.dart';
import '../services/diagnostic_logger_service.dart';
import '../theme/fluent_theme.dart';

class PtzControllerWidget extends StatelessWidget {
  final CameraDevice camera;
  final bool isOverlay; // true when floating over video in landscape, false when below video in portrait
  final VoidCallback? onClose;

  const PtzControllerWidget({
    super.key,
    required this.camera,
    this.isOverlay = false,
    this.onClose,
  });

  void _sendPtz(BuildContext context, String action) {
    DiagnosticLoggerService.instance.logInfo(
      'PTZ',
      'Comando PTZ "$action" enviado para "${camera.name}" (${camera.ip}:${camera.rtspPort})',
      details: 'Protocolo: ONVIF PTZ ContinuousMove / RelativeMove ($action)',
    );

    displayInfoBar(
      context,
      duration: const Duration(milliseconds: 1400),
      builder: (context, close) => InfoBar(
        title: Text('PTZ: $action'),
        content: Text('Comando $action enviado para ${camera.ip}'),
        severity: InfoBarSeverity.info,
        onClose: close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isOverlay) {
      // Landscape Floating Overlay Style
      return Container(
        width: 170,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xD9121216),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BCamTheme.accentLightBlue.withValues(alpha: 0.6), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(FluentIcons.game, size: 12, color: BCamTheme.accentLightBlue),
                    const SizedBox(width: 4),
                    Text(
                      'PTZ VIRTUAL',
                      style: GoogleFonts.robotoMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 10, color: Color(0xB3FFFFFF)),
                    onPressed: onClose,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _buildDpad(context, size: 120),
            const SizedBox(height: 6),
            _buildZoomRow(context, compact: true),
          ],
        ),
      );
    }

    // Portrait Below-the-Image Style
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161C),
        border: Border(
          top: BorderSide(color: BCamTheme.darkBorder, width: 0.8),
          bottom: BorderSide(color: BCamTheme.darkBorder, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: BCamTheme.accentBlue.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(FluentIcons.game, size: 15, color: BCamTheme.accentLightBlue),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Controles Pan / Tilt / Zoom',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        'Mova a câmera e ajuste o enquadramento ótico',
                        style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BCamTheme.statusOnlineGlow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: BCamTheme.statusOnlineGlow.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'ONVIF PTZ',
                  style: GoogleFonts.robotoMono(fontSize: 9.5, fontWeight: FontWeight.w700, color: BCamTheme.statusOnlineGlow),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDpad(context, size: 145),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildZoomRow(context, compact: false),
                  const SizedBox(height: 12),
                  _buildPresetButton(context, 'Portão'),
                  const SizedBox(height: 6),
                  _buildPresetButton(context, 'Entrada'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDpad(BuildContext context, {required double size}) {
    final btnSize = size * 0.28;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle guide
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1F1F26),
              border: Border.all(color: BCamTheme.darkBorder, width: 1.2),
            ),
          ),
          // UP
          Positioned(
            top: 2,
            child: _buildArrowButton(
              context,
              icon: FluentIcons.chevron_up,
              tooltip: 'Subir',
              size: btnSize,
              onTap: () => _sendPtz(context, 'Subir (Tilt Up)'),
            ),
          ),
          // DOWN
          Positioned(
            bottom: 2,
            child: _buildArrowButton(
              context,
              icon: FluentIcons.chevron_down,
              tooltip: 'Descer',
              size: btnSize,
              onTap: () => _sendPtz(context, 'Descer (Tilt Down)'),
            ),
          ),
          // LEFT
          Positioned(
            left: 2,
            child: _buildArrowButton(
              context,
              icon: FluentIcons.chevron_left,
              tooltip: 'Esquerda',
              size: btnSize,
              onTap: () => _sendPtz(context, 'Esquerda (Pan Left)'),
            ),
          ),
          // RIGHT
          Positioned(
            right: 2,
            child: _buildArrowButton(
              context,
              icon: FluentIcons.chevron_right,
              tooltip: 'Direita',
              size: btnSize,
              onTap: () => _sendPtz(context, 'Direita (Pan Right)'),
            ),
          ),
          // CENTER / HOME
          _buildCenterButton(context, size: btnSize),
        ],
      ),
    );
  }

  Widget _buildArrowButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required double size,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B36),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3F3F4E), width: 0.8),
          ),
          child: Center(
            child: Icon(icon, size: size * 0.55, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context, {required double size}) {
    return Tooltip(
      message: 'Posição Central (Home)',
      child: GestureDetector(
        onTap: () => _sendPtz(context, 'Centro / Posição Home'),
        child: Container(
          width: size * 0.85,
          height: size * 0.85,
          decoration: BoxDecoration(
            color: BCamTheme.accentBlue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: BCamTheme.accentBlue.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
          child: const Center(
            child: Icon(FluentIcons.sync, size: 13, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomRow(BuildContext context, {required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _sendPtz(context, 'Zoom In (+)'),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 6),
            decoration: BoxDecoration(
              color: const Color(0xFF262630),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: BCamTheme.darkBorder),
            ),
            child: Row(
              children: [
                const Icon(FluentIcons.add, size: 12, color: BCamTheme.accentLightBlue),
                const SizedBox(width: 4),
                Text('Zoom +', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _sendPtz(context, 'Zoom Out (-)'),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 6),
            decoration: BoxDecoration(
              color: const Color(0xFF262630),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: BCamTheme.darkBorder),
            ),
            child: Row(
              children: [
                const Icon(FluentIcons.remove, size: 12, color: BCamTheme.accentLightBlue),
                const SizedBox(width: 4),
                Text('Zoom -', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetButton(BuildContext context, String preset) {
    return GestureDetector(
      onTap: () => _sendPtz(context, 'Preset: $preset'),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF22222A),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: BCamTheme.darkBorder),
        ),
        child: Center(
          child: Text(
            'Preset: $preset',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: BCamTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}
