import 'package:flutter/material.dart';
import '../theme/gta_colors.dart';

class GtaNeonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? glowColor;
  final Color? borderColor;
  final double borderRadius;
  final bool isSelected;

  const GtaNeonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.glowColor,
    this.borderColor,
    this.borderRadius = 16,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlow = glowColor ?? (isSelected ? GtaColors.neonPink : Colors.transparent);
    final effectiveBorder = borderColor ?? (isSelected ? GtaColors.neonPink : GtaColors.borderSubtle);

    return Container(
      decoration: BoxDecoration(
        color: GtaColors.bgCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: effectiveBorder,
          width: isSelected ? 1.8 : 1.2,
        ),
        boxShadow: [
          if (isSelected || glowColor != null)
            BoxShadow(
              color: effectiveGlow.withOpacity(0.25),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: GtaColors.neonPink.withOpacity(0.15),
          highlightColor: GtaColors.electricCyan.withOpacity(0.08),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
