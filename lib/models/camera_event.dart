import 'package:fluent_ui/fluent_ui.dart';
import '../theme/fluent_theme.dart';

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
  final double confidence; // e.g. 0.94 (94%)
  final bool isFlagged;

  const CameraEvent({
    required this.id,
    required this.cameraId,
    required this.cameraName,
    required this.type,
    required this.timestamp,
    required this.duration,
    required this.description,
    this.clipUrl,
    this.confidence = 1.0,
    this.isFlagged = false,
  });

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
    'confidence': confidence,
    'isFlagged': isFlagged,
  };
}
