import 'dart:math';
import 'package:flutter/widgets.dart';
import 'bounding_box.dart';

/// Representation and mathematical utilities for CCTV exclusion zones.
/// Uses a 16x9 grid (144 cells) corresponding to standard 16:9 camera aspect ratio.
class ExclusionGrid {
  static const int columns = 16;
  static const int rows = 9;
  static const int totalCells = columns * rows; // 144

  /// Converts a linear cell index (0..143) to column and row (x, y)
  static Point<int> indexToCoord(int index) {
    final col = index % columns;
    final row = index ~/ columns;
    return Point(col, row);
  }

  /// Converts column and row (x, y) to linear cell index (0..143)
  static int coordToIndex(int col, int row) {
    if (col < 0 || col >= columns || row < 0 || row >= rows) return -1;
    return row * columns + col;
  }

  /// Returns normalized (0.0 to 1.0) Rect for a cell index
  static Rect cellToNormalizedRect(int index) {
    final coord = indexToCoord(index);
    const cellW = 1.0 / columns;
    const cellH = 1.0 / rows;
    return Rect.fromLTWH(
      coord.x * cellW,
      coord.y * cellH,
      cellW,
      cellH,
    );
  }

  /// Converts a physical touch offset to the corresponding cell index
  static int pointToCell(Offset localPosition, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return -1;

    final normX = (localPosition.dx / canvasSize.width).clamp(0.0, 0.999);
    final normY = (localPosition.dy / canvasSize.height).clamp(0.0, 0.999);

    final col = (normX * columns).floor();
    final row = (normY * rows).floor();

    return coordToIndex(col, row);
  }

  /// Returns all cell indices covered by a brush centered at localPosition with given radius (in cells)
  static Set<int> brushCellsAt(Offset localPosition, Size canvasSize, {int brushRadius = 1}) {
    final center = pointToCell(localPosition, canvasSize);
    if (center == -1) return const {};

    final centerCoord = indexToCoord(center);
    final affected = <int>{};

    for (int dy = -brushRadius + 1; dy <= brushRadius - 1; dy++) {
      for (int dx = -brushRadius + 1; dx <= brushRadius - 1; dx++) {
        final c = centerCoord.x + dx;
        final r = centerCoord.y + dy;
        final idx = coordToIndex(c, r);
        if (idx != -1) {
          affected.add(idx);
        }
      }
    }
    return affected;
  }

  /// Evaluates whether a BoundingBox intersects with any excluded cell by at least [overlapThreshold]
  static bool isBoxExcluded(
    BoundingBox box,
    Iterable<int> excludedCells, {
    double overlapThreshold = 0.20,
  }) {
    if (excludedCells.isEmpty) return false;

    final excludedSet = excludedCells.toSet();
    final boxRect = Rect.fromLTWH(box.left, box.top, box.width, box.height);
    final boxArea = box.width * box.height;

    if (boxArea <= 0.0) {
      // Point check: check if center is in an excluded cell
      final centerCell = pointToCell(Offset(box.left + box.width / 2, box.top + box.height / 2), const Size(1.0, 1.0));
      return excludedSet.contains(centerCell);
    }

    double totalOverlapArea = 0.0;

    // Check overlap with each excluded cell
    for (final cellIndex in excludedSet) {
      final cellRect = cellToNormalizedRect(cellIndex);
      final intersect = boxRect.intersect(cellRect);

      if (intersect.width > 0 && intersect.height > 0) {
        totalOverlapArea += intersect.width * intersect.height;
      }
    }

    final overlapRatio = totalOverlapArea / boxArea;
    return overlapRatio >= overlapThreshold;
  }
}
