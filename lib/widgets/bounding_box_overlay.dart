import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bounding_box.dart';

class BoundingBoxOverlay extends StatelessWidget {
  final Widget child;
  final List<BoundingBox> boundingBoxes;
  final double minConfidenceThreshold;
  final bool showLabels;
  final Function(BoundingBox)? onBoxTap;

  const BoundingBoxOverlay({
    super.key,
    required this.child,
    required this.boundingBoxes,
    this.minConfidenceThreshold = 0.25,
    this.showLabels = true,
    this.onBoxTap,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out detections below the configured confidence threshold
    final visibleBoxes = boundingBoxes
        .where((b) => b.confidence >= minConfidenceThreshold)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth;
        final canvasHeight = constraints.maxHeight;

        return Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            if (canvasWidth > 0 && canvasHeight > 0)
              ...visibleBoxes.map((box) {
                final rect = box.toRect(Size(canvasWidth, canvasHeight));
                final color = box.displayColor;

                return Positioned(
                  left: rect.left.clamp(0.0, canvasWidth - 10),
                  top: rect.top.clamp(0.0, canvasHeight - 10),
                  width: rect.width.clamp(10.0, canvasWidth - rect.left),
                  height: rect.height.clamp(10.0, canvasHeight - rect.top),
                  child: IgnorePointer(
                    ignoring: onBoxTap == null,
                    child: GestureDetector(
                      onTap: () => onBoxTap?.call(box),
                      child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: color,
                          width: 2.0,
                        ),
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Surveillance Corner Reticles
                          Positioned(
                            top: -2,
                            left: -2,
                            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
                          ),
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
                          ),
                          Positioned(
                            bottom: -2,
                            left: -2,
                            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1))),
                          ),

                          // Header Label Tag Pill with Assertiveness Percentage
                          if (showLabels)
                            Positioned(
                              top: rect.top < 26 ? 4 : -24,
                              left: (rect.left + 150 > canvasWidth) ? null : 0,
                              right: (rect.left + 150 > canvasWidth) ? 0 : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xF018181D),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: color, width: 1.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getIconForLabel(box.label),
                                      size: 11,
                                      color: color,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      box.label,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.28),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.6),
                                      ),
                                      child: Text(
                                        box.assertivenessFormatted,
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  IconData _getIconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('pess') || lower.contains('humano') || lower.contains('person')) {
      return FluentIcons.contact;
    } else if (lower.contains('veí') || lower.contains('car') || lower.contains('moto')) {
      return FluentIcons.car;
    } else if (lower.contains('anim') || lower.contains('pet')) {
      return FluentIcons.heart;
    } else if (lower.contains('alarm') || lower.contains('intrus')) {
      return FluentIcons.warning;
    }
    return FluentIcons.running;
  }
}
