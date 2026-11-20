import 'package:flutter/material.dart';
import '../models/exclusion_zone.dart';

/// CustomPainter that renders a translucent exclusion zone overlay with diagonal warning hatch pattern
class ExclusionMaskPainter extends CustomPainter {
  final Set<int> excludedCells;
  final bool showGridLines;
  final Color maskColor;
  final Color borderColor;

  ExclusionMaskPainter({
    required this.excludedCells,
    this.showGridLines = true,
    this.maskColor = const Color(0x66FF3B30), // 40% translucent warning red
    this.borderColor = const Color(0xB3FF3B30), // 70% border red
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final cellWidth = size.width / ExclusionGrid.columns;
    final cellHeight = size.height / ExclusionGrid.rows;

    final fillPaint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final hatchPaint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = const Color(0x1AFFFFFF) // very subtle 10% white grid
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Optional background grid lines
    if (showGridLines) {
      for (int c = 1; c < ExclusionGrid.columns; c++) {
        final x = c * cellWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (int r = 1; r < ExclusionGrid.rows; r++) {
        final y = r * cellHeight;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // Paint excluded cells
    for (final index in excludedCells) {
      if (index < 0 || index >= ExclusionGrid.totalCells) continue;
      final coord = ExclusionGrid.indexToCoord(index);
      final rect = Rect.fromLTWH(
        coord.x * cellWidth,
        coord.y * cellHeight,
        cellWidth,
        cellHeight,
      );

      // 1. Red fill
      canvas.drawRect(rect, fillPaint);

      // 2. Diagonal hatch line for CCTV exclusion aesthetic
      canvas.drawLine(
        Offset(rect.left, rect.bottom),
        Offset(rect.right, rect.top),
        hatchPaint,
      );

      // 3. Border outline
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ExclusionMaskPainter oldDelegate) {
    return oldDelegate.excludedCells != excludedCells ||
        oldDelegate.showGridLines != showGridLines ||
        oldDelegate.maskColor != maskColor ||
        oldDelegate.borderColor != borderColor;
  }
}
