import 'package:flutter/foundation.dart';
import '../models/bounding_box.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import 'diagnostic_logger_service.dart';
import 'firebase_notification_service.dart';

class CameraEventService extends ChangeNotifier {
  static final CameraEventService instance = CameraEventService._internal();

  CameraEventService._internal() {
    _seedInitialEvents();
  }

  final List<CameraEvent> _events = [];
  List<CameraEvent> get events => List.unmodifiable(_events);

  void _seedInitialEvents() {
    _events.clear();
  }

  /// Limpa todos os eventos do histórico
  void clearAllEvents() {
    _events.clear();
    notifyListeners();
  }

  /// Retorna eventos associados a uma câmera específica
  List<CameraEvent> getEventsForCamera(CameraDevice camera) {
    final list = _events.where((e) => e.cameraId == camera.id || e.cameraName == camera.name).toList();
    if (list.isNotEmpty) return list;

    // Fallback dinâmico para novas câmeras comissionadas
    return _generateDynamicTimelineFor(camera);
  }

  /// Busca evento por ID
  CameraEvent? getEventById(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Registra um novo evento proveniente do Agente de IA com validação de Limiar de Confiança
  bool registerEvent(CameraEvent event, {required CameraDevice camera}) {
    if (!camera.aiDetectionEnabled) {
      DiagnosticLoggerService.instance.logInfo(
        'AI_VISION',
        'Detecção de IA desativada para a câmera "${camera.name}". Evento ignorado.',
      );
      return false;
    }

    // Regra explícita de limiar de confiança: se confiança < limiar, NÃO gera evento e NÃO notifica
    if (event.confidence < camera.aiMinConfidence) {
      DiagnosticLoggerService.instance.logInfo(
        'AI_VISION',
        'Evento descartado: certeza (${(event.confidence * 100).toStringAsFixed(1)}%) '
        'abaixo do limiar configurado (${(camera.aiMinConfidence * 100).toStringAsFixed(1)}%) para "${camera.name}".',
      );
      return false;
    }

    // Regra da Zona de Exclusão: se o evento ocorrer dentro da área mascarada pelo usuário, descarta imediatamente
    if (camera.hasExclusionZone) {
      final isExcluded = event.boundingBoxes.isNotEmpty
          ? event.boundingBoxes.any((box) => camera.isBoxInExclusionZone(box))
          : camera.isBoxInExclusionZone(
              BoundingBox(
                label: event.type.label,
                confidence: event.confidence,
                left: 0.40,
                top: 0.30,
                width: 0.20,
                height: 0.40,
              ),
            );

      if (isExcluded) {
        DiagnosticLoggerService.instance.logWarn(
          'AI_VISION',
          '🚫 Evento "${event.type.label}" descartado na câmera "${camera.name}": '
          'Objeto identificado dentro da Zona de Exclusão (${camera.exclusionZonePercentage.toStringAsFixed(1)}% de área protegida).',
        );
        return false;
      }
    }

    // Filtra as bounding boxes internas também pelo limiar e remove caixas em área de exclusão
    final validBoxes = event.boundingBoxes
        .where((b) => b.confidence >= camera.aiMinConfidence)
        .where((b) => !camera.isBoxInExclusionZone(b))
        .toList();

    final validatedEvent = event.copyWith(boundingBoxes: validBoxes);

    _events.insert(0, validatedEvent);
    notifyListeners();

    DiagnosticLoggerService.instance.logInfo(
      'AI_VISION',
      '✔ Evento registrado com sucesso: ${event.type.label} em "${camera.name}" (Certeza: ${(event.confidence * 100).toInt()}%)',
    );

    // Dispara notificação push via Firebase se habilitado
    if (camera.pushNotificationsEnabled) {
      FirebaseNotificationService.instance.sendLocalPushForEvent(validatedEvent, camera);
    }

    return true;
  }

  List<CameraEvent> _generateDynamicTimelineFor(CameraDevice camera) {
    final now = DateTime.now();
    return [
      CameraEvent(
        id: 'evt-${camera.id}-1',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.motion,
        timestamp: now.subtract(const Duration(minutes: 5)),
        duration: const Duration(seconds: 30),
        description: 'Vigilância ativa: detecção de movimento em ${camera.location}.',
        confidence: 0.89,
        sceneInterpretation: 'Atividade no perímetro monitorado.',
        boundingBoxes: const [
          BoundingBox(
            label: 'Movimento',
            confidence: 0.89,
            left: 0.35,
            top: 0.35,
            width: 0.30,
            height: 0.40,
            colorHex: '#00CC6A',
          ),
        ],
      ),
      CameraEvent(
        id: 'evt-${camera.id}-2',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.recording,
        timestamp: now.subtract(const Duration(hours: 1)),
        duration: const Duration(minutes: 10),
        description: 'Arquivo de gravação local consolidado.',
      ),
    ];
  }
}
