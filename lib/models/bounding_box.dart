import 'package:flutter/widgets.dart';

class BoundingBox {
  final String label;
  final double confidence; // 0.0 to 1.0
  final double left; // Normalized 0.0 to 1.0
  final double top; // Normalized 0.0 to 1.0
  final double width; // Normalized 0.0 to 1.0
  final double height; // Normalized 0.0 to 1.0
  final String? colorHex;

  const BoundingBox({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.colorHex,
  });

  /// Computes pixel rectangle for a given canvas or screen size
  Rect toRect(Size canvasSize) {
    return Rect.fromLTWH(
      left * canvasSize.width,
      top * canvasSize.height,
      width * canvasSize.width,
      height * canvasSize.height,
    );
  }

  /// Confidence expressed as integer percentage (0-100)
  int get confidencePercent => (confidence * 100).round();

  /// Formatted assertiveness string (e.g., '94%')
  String get assertivenessFormatted => '$confidencePercent%';

  /// Resolved color with fallback based on object class
  Color get displayColor {
    if (colorHex != null && colorHex!.isNotEmpty) {
      final hex = colorHex!.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
    }
    final lower = label.toLowerCase();
    if (lower.contains('pess') || lower.contains('humano') || lower.contains('person')) {
      return const Color(0xFF0078D4); // Fluent Cobalt Blue
    } else if (lower.contains('veí') || lower.contains('car') || lower.contains('moto')) {
      return const Color(0xFFFFB900); // Amber Gold
    } else if (lower.contains('movim') || lower.contains('motion')) {
      return const Color(0xFF00CC6A); // Emerald Green
    } else if (lower.contains('anim') || lower.contains('pet') || lower.contains('cachorro')) {
      return const Color(0xFF9A44FF); // Purple
    } else if (lower.contains('alarm') || lower.contains('intrus') || lower.contains('viol')) {
      return const Color(0xFFD83B01); // Red Alert
    }
    return const Color(0xFF4CC2FF); // Cyan Default
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'confidence': confidence,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'colorHex': colorHex,
  };

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      label: json['label'] as String? ?? 'Objeto Detectado',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      left: (json['left'] as num?)?.toDouble() ?? 0.0,
      top: (json['top'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      colorHex: json['colorHex'] as String?,
    );
  }

  BoundingBox copyWith({
    String? label,
    double? confidence,
    double? left,
    double? top,
    double? width,
    double? height,
    String? colorHex,
  }) {
    return BoundingBox(
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      colorHex: colorHex ?? this.colorHex,
    );
  }
}
