import 'package:fluent_ui/fluent_ui.dart';
import '../theme/fluent_theme.dart';
import 'bounding_box.dart';

enum CameraEventType {
  person(
    label: 'Pessoa Detectada',
    icon: FluentIcons.contact,
    color: BCamTheme.statusOnlineGlow,
  ),
  vehicle(
    label: 'Veículo Detectado',
    icon: FluentIcons.car,
    color: BCamTheme.statusWarning,
  ),
  motion(
    label: 'Movimento',
    icon: FluentIcons.running,
    color: BCamTheme.accentLightBlue,
  ),
  alarm(
    label: 'Alarme / Violação',
    icon: FluentIcons.warning,
    color: BCamTheme.statusOffline,
  ),
  recording(
    label: 'Gravação Contínua',
    icon: FluentIcons.video,
    color: BCamTheme.textSecondary,
  );

  final String label;
  final IconData icon;
  final Color color;

  const CameraEventType({
    required this.label,
    required this.icon,
    required this.color,
  });

  static CameraEventType fromName(String? name) {
    if (name == null) return CameraEventType.motion;
    for (final t in CameraEventType.values) {
      if (t.name.toLowerCase() == name.toLowerCase()) return t;
    }
    return CameraEventType.motion;
  }
}

class CameraEvent {
  final String id;
  final String cameraId;
  final String cameraName;
  final CameraEventType type;
  final DateTime timestamp;
  final Duration duration;
  final String description;
  final String? clipUrl;
  final String? snapshotPath;
  final double confidence; // e.g. 0.94 (94%)
  final bool isFlagged;
  final List<BoundingBox> boundingBoxes;
  final String? sceneInterpretation;
  final String? deepLinkUrl;

  const CameraEvent({
    required this.id,
    required this.cameraId,
    required this.cameraName,
    required this.type,
    required this.timestamp,
    required this.duration,
    required this.description,
    this.clipUrl,
    this.snapshotPath,
    this.confidence = 1.0,
    this.isFlagged = false,
    this.boundingBoxes = const [],
    this.sceneInterpretation,
    String? deepLinkUrl,
  }) : deepLinkUrl = deepLinkUrl ?? 'bcam://event/$id';

  /// True if event has a real recorded video clip (.mp4, .mkv, rtsp://) and not just an image
  bool get hasVideoClip =>
      clipUrl != null &&
      clipUrl!.trim().isNotEmpty &&
      !clipUrl!.toLowerCase().endsWith('.jpg') &&
      !clipUrl!.toLowerCase().endsWith('.jpeg') &&
      !clipUrl!.toLowerCase().endsWith('.png') &&
      !clipUrl!.contains('/snapshots/');

  /// Path to the evidence snapshot image captured at the moment of detection
  String? get effectiveSnapshotPath {
    if (snapshotPath != null && snapshotPath!.trim().isNotEmpty) {
      return snapshotPath!.trim();
    }
    if (clipUrl != null &&
        (clipUrl!.toLowerCase().endsWith('.jpg') ||
         clipUrl!.toLowerCase().endsWith('.jpeg') ||
         clipUrl!.toLowerCase().endsWith('.png') ||
         clipUrl!.contains('/snapshots/'))) {
      return clipUrl!.trim();
    }
    return null;
  }

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get dateFormatted {
    final d = timestamp.day.toString().padLeft(2, '0');
    final m = timestamp.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  String get durationFormatted {
    final s = duration.inSeconds;
    if (s < 60) {
      return '${s}s';
    }
    final min = duration.inMinutes;
    final remSec = s % 60;
    return '${min}m ${remSec}s';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cameraId': cameraId,
    'cameraName': cameraName,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'description': description,
    'clipUrl': clipUrl,
    'snapshotPath': effectiveSnapshotPath,
    'confidence': confidence,
    'isFlagged': isFlagged,
    'boundingBoxes': boundingBoxes.map((b) => b.toJson()).toList(),
    'sceneInterpretation': sceneInterpretation,
    'deepLinkUrl': deepLinkUrl,
  };

  factory CameraEvent.fromJson(Map<String, dynamic> json) {
    return CameraEvent(
      id: json['id'] as String,
      cameraId: json['cameraId'] as String,
      cameraName: json['cameraName'] as String,
      type: CameraEventType.fromName(json['type'] as String?),
      timestamp: DateTime.parse(json['timestamp'] as String),
      duration: Duration(seconds: (json['durationSeconds'] as num?)?.toInt() ?? 30),
      description: json['description'] as String? ?? '',
      clipUrl: json['clipUrl'] as String?,
      snapshotPath: json['snapshotPath'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      isFlagged: json['isFlagged'] as bool? ?? false,
      boundingBoxes: (json['boundingBoxes'] as List<dynamic>?)
              ?.map((e) => BoundingBox.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      sceneInterpretation: json['sceneInterpretation'] as String?,
      deepLinkUrl: json['deepLinkUrl'] as String?,
    );
  }

  CameraEvent copyWith({
    String? id,
    String? cameraId,
    String? cameraName,
    CameraEventType? type,
    DateTime? timestamp,
    Duration? duration,
    String? description,
    String? clipUrl,
    String? snapshotPath,
    double? confidence,
    bool? isFlagged,
    List<BoundingBox>? boundingBoxes,
    String? sceneInterpretation,
    String? deepLinkUrl,
  }) {
    return CameraEvent(
      id: id ?? this.id,
      cameraId: cameraId ?? this.cameraId,
      cameraName: cameraName ?? this.cameraName,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      clipUrl: clipUrl ?? this.clipUrl,
      snapshotPath: snapshotPath ?? this.snapshotPath,
      confidence: confidence ?? this.confidence,
      isFlagged: isFlagged ?? this.isFlagged,
      boundingBoxes: boundingBoxes ?? this.boundingBoxes,
      sceneInterpretation: sceneInterpretation ?? this.sceneInterpretation,
      deepLinkUrl: deepLinkUrl ?? this.deepLinkUrl,
    );
  }
}
