import 'package:flutter/foundation.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';

class CameraEventService extends ChangeNotifier {
  static final CameraEventService instance = CameraEventService._internal();

  CameraEventService._internal() {
    _seedInitialEvents();
  }

  final List<CameraEvent> _events = [];
  List<CameraEvent> get events => List.unmodifiable(_events);

  void _seedInitialEvents() {
    final now = DateTime.now();

    _events.clear();
    _events.addAll([
      // Intelbras Frente (.74)
      CameraEvent(
        id: 'evt-74-1',
        cameraId: 'cam-intelbras-frente-74',
        cameraName: 'Intelbras Frente da Casa',
        type: CameraEventType.person,
        timestamp: now.subtract(const Duration(minutes: 6)),
        duration: const Duration(seconds: 42),
        description: 'Pessoa detectada na calçada em frente ao portão principal.',
        confidence: 0.96,
      ),
      CameraEvent(
        id: 'evt-74-2',
        cameraId: 'cam-intelbras-frente-74',
        cameraName: 'Intelbras Frente da Casa',
        type: CameraEventType.vehicle,
        timestamp: now.subtract(const Duration(minutes: 24)),
        duration: const Duration(seconds: 55),
        description: 'Veículo identificado estacionando na entrada.',
        confidence: 0.92,
      ),
      CameraEvent(
        id: 'evt-74-3',
        cameraId: 'cam-intelbras-frente-74',
        cameraName: 'Intelbras Frente da Casa',
        type: CameraEventType.motion,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 12)),
        duration: const Duration(seconds: 28),
        description: 'Movimento detectado no campo de visão.',
        confidence: 0.88,
      ),
      CameraEvent(
        id: 'evt-74-4',
        cameraId: 'cam-intelbras-frente-74',
        cameraName: 'Intelbras Frente da Casa',
        type: CameraEventType.recording,
        timestamp: now.subtract(const Duration(hours: 2)),
        duration: const Duration(minutes: 15),
        description: 'Bloco de gravação contínua NVR arquivado.',
      ),

      // Yoosee Corredor & Jardim (.23)
      CameraEvent(
        id: 'evt-23-1',
        cameraId: 'cam-yoosee-corredor-23',
        cameraName: 'Yoosee Corredor & Jardim',
        type: CameraEventType.motion,
        timestamp: now.subtract(const Duration(minutes: 15)),
        duration: const Duration(seconds: 35),
        description: 'Atividade no corredor lateral perto do jardim.',
        confidence: 0.85,
      ),
      CameraEvent(
        id: 'evt-23-2',
        cameraId: 'cam-yoosee-corredor-23',
        cameraName: 'Yoosee Corredor & Jardim',
        type: CameraEventType.person,
        timestamp: now.subtract(const Duration(minutes: 48)),
        duration: const Duration(seconds: 40),
        description: 'Detecção de presença humana na área do jardim.',
        confidence: 0.91,
      ),
      CameraEvent(
        id: 'evt-23-3',
        cameraId: 'cam-yoosee-corredor-23',
        cameraName: 'Yoosee Corredor & Jardim',
        type: CameraEventType.alarm,
        timestamp: now.subtract(const Duration(hours: 3)),
        duration: const Duration(seconds: 15),
        description: 'Sensibilidade de movimento excedeu limite de alarme.',
        confidence: 0.98,
        isFlagged: true,
      ),

      // Yoosee Área Gourmet (.24)
      CameraEvent(
        id: 'evt-24-1',
        cameraId: 'cam-yoosee-gourmet-24',
        cameraName: 'Yoosee Área Gourmet',
        type: CameraEventType.motion,
        timestamp: now.subtract(const Duration(minutes: 18)),
        duration: const Duration(seconds: 50),
        description: 'Movimento registrado nos fundos da churrasqueira.',
        confidence: 0.89,
      ),
      CameraEvent(
        id: 'evt-24-2',
        cameraId: 'cam-yoosee-gourmet-24',
        cameraName: 'Yoosee Área Gourmet',
        type: CameraEventType.person,
        timestamp: now.subtract(const Duration(hours: 1, minutes: 40)),
        duration: const Duration(seconds: 64),
        description: 'Pessoa caminhando pela varanda gourmet.',
        confidence: 0.94,
      ),

      // Intelbras Mibo (.22)
      CameraEvent(
        id: 'evt-22-1',
        cameraId: 'cam-intelbras-mibo-22',
        cameraName: 'Intelbras Mibo',
        type: CameraEventType.person,
        timestamp: now.subtract(const Duration(minutes: 32)),
        duration: const Duration(seconds: 30),
        description: 'Detecção de presença na sala de estar.',
        confidence: 0.95,
      ),
      CameraEvent(
        id: 'evt-22-2',
        cameraId: 'cam-intelbras-mibo-22',
        cameraName: 'Intelbras Mibo',
        type: CameraEventType.motion,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 10)),
        duration: const Duration(seconds: 22),
        description: 'Mudança de iluminação / sensor PIR acionado.',
        confidence: 0.80,
      ),
    ]);

    _events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<CameraEvent> getEventsForCamera(CameraDevice camera) {
    // Match by ID or by IP address
    final filtered = _events.where((e) {
      return e.cameraId == camera.id ||
          e.cameraName.toLowerCase().contains(camera.name.toLowerCase()) ||
          e.description.contains(camera.ip);
    }).toList();

    // If specific events don't exist for a camera yet, dynamically generate contextual events
    if (filtered.isEmpty) {
      final now = DateTime.now();
      return [
        CameraEvent(
          id: 'evt-dyn-${camera.id}-1',
          cameraId: camera.id,
          cameraName: camera.name,
          type: CameraEventType.motion,
          timestamp: now.subtract(const Duration(minutes: 8)),
          duration: const Duration(seconds: 25),
          description: 'Movimento registrado na área de ${camera.location}.',
          confidence: 0.88,
        ),
        CameraEvent(
          id: 'evt-dyn-${camera.id}-2',
          cameraId: camera.id,
          cameraName: camera.name,
          type: CameraEventType.person,
          timestamp: now.subtract(const Duration(minutes: 35)),
          duration: const Duration(seconds: 40),
          description: 'Pessoa detectada no enquadramento.',
          confidence: 0.93,
        ),
        CameraEvent(
          id: 'evt-dyn-${camera.id}-3',
          cameraId: camera.id,
          cameraName: camera.name,
          type: CameraEventType.recording,
          timestamp: now.subtract(const Duration(hours: 1)),
          duration: const Duration(minutes: 10),
          description: 'Gravação contínua registrada.',
        ),
      ];
    }

    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  void addRealtimeEvent(CameraEvent event) {
    _events.insert(0, event);
    notifyListeners();
  }
}
