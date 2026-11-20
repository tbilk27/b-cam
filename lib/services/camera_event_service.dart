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
        sceneInterpretation: 'Indivíduo vestido com camisa escura caminhando pela calçada em direção ao portão social.',
        boundingBoxes: const [
          BoundingBox(
            label: 'Pessoa',
            confidence: 0.96,
            left: 0.45,
            top: 0.32,
            width: 0.18,
            height: 0.52,
            colorHex: '#0078D4',
          ),
        ],
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
        sceneInterpretation: 'Automóvel prata executando manobra de estacionamento na guia rebaixada.',
        boundingBoxes: const [
          BoundingBox(
            label: 'Veículo',
            confidence: 0.92,
            left: 0.18,
            top: 0.48,
            width: 0.42,
            height: 0.34,
            colorHex: '#FFB900',
          ),
        ],
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
        sceneInterpretation: 'Oscilação expressiva de vegetação e passagem de pedestre periférico.',
        boundingBoxes: const [
          BoundingBox(
            label: 'Movimento',
            confidence: 0.88,
            left: 0.65,
            top: 0.35,
            width: 0.25,
            height: 0.40,
            colorHex: '#00CC6A',
          ),
        ],
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
        sceneInterpretation: 'Movimentação no corredor residencial lateral.',
        boundingBoxes: const [
          BoundingBox(
            label: 'Movimento',
            confidence: 0.85,
            left: 0.30,
            top: 0.40,
            width: 0.35,
            height: 0.45,
            colorHex: '#00CC6A',
          ),
        ],
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
        sceneInterpretation: 'Presença identificada junto aos canteiros do jardim residencial.',
        boundingBoxes: const [
          BoundingBox(
            label: 'Pessoa',
            confidence: 0.91,
            left: 0.38,
            top: 0.26,
            width: 0.22,
            height: 0.60,
            colorHex: '#0078D4',
          ),
        ],
      ),

      // Yoosee Área Gourmet (.24)
      CameraEvent(
        id: 'evt-24-1',
        cameraId: 'cam-yoosee-gourmet-24',
        cameraName: 'Yoosee Área Gourmet',
        type: CameraEventType.motion,
        timestamp: now.subtract(const Duration(minutes: 18)),
        duration: const Duration(seconds: 22),
        description: 'Movimento na área externa gourmet.',
        confidence: 0.89,
        sceneInterpretation: 'Atividade na bancada da área de churrasqueira.',
        boundingBoxes: const [
          BoundingBox(
            label: 'Movimento',
            confidence: 0.89,
            left: 0.20,
            top: 0.30,
            width: 0.45,
            height: 0.50,
            colorHex: '#00CC6A',
          ),
        ],
      ),
    ]);
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

    // Filtra as bounding boxes internas também pelo limiar
    final validBoxes = event.boundingBoxes
        .where((b) => b.confidence >= camera.aiMinConfidence)
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
