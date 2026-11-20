import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/fluent_theme.dart';

class BCamLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool compact;

  const BCamLogo({
    super.key,
    this.size = 36,
    this.showText = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BCamTheme.darkSurface,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: BCamTheme.darkBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Image.asset(
          'assets/images/b_cam_icon.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(
              FluentIcons.video,
              size: size * 0.55,
              color: BCamTheme.accentLightBlue,
            ),
          ),
        ),
      ),
    );

    if (!showText) return iconWidget;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'b-cam',
                  style: GoogleFonts.inter(
                    fontSize: compact ? 16 : 20,
                    fontWeight: FontWeight.w800,
                    color: BCamTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: BCamTheme.accentBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: BCamTheme.accentBlue.withValues(alpha: 0.6), width: 0.8),
                  ),
                  child: Text(
                    'PRO',
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: BCamTheme.accentLightBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            if (!compact)
              Text(
                'SURVEILLANCE RADAR',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: BCamTheme.textSecondary,
                  letterSpacing: 1.4,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
