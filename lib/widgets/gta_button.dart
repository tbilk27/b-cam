import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/gta_colors.dart';

class GtaButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Gradient? gradient;
  final Color? glowColor;
  final double height;
  final bool outlined;

  const GtaButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.glowColor,
    this.height = 52,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ?? GtaColors.viceSunsetGradient;
    final effectiveGlow = glowColor ?? GtaColors.neonPink;

    if (outlined) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GtaColors.neonPink, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: GtaColors.neonPink.withOpacity(0.18),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(14),
            splashColor: GtaColors.neonPink.withOpacity(0.25),
            child: Center(
              child: _buildContent(GtaColors.neonPink),
            ),
          ),
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : effectiveGradient,
        color: onPressed == null ? GtaColors.borderSubtle : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: effectiveGlow.withOpacity(0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withOpacity(0.2),
          child: Center(
            child: _buildContent(Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    if (isLoading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: textColor,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
