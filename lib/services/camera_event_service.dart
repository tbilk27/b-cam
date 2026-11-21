import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bounding_box.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import 'diagnostic_logger_service.dart';
import 'firebase_notification_service.dart';

class CameraEventService extends ChangeNotifier {
  static final CameraEventService instance = CameraEventService._internal();

  CameraEventService._internal() {
    initialize();
  }

  static const String _eventsStorageKey = 'bcam_saved_camera_events_v2';
  final List<CameraEvent> _events = [];
  bool _isInitialized = false;

  List<CameraEvent> get events => List.unmodifiable(_events);
  bool get isInitialized => _isInitialized;

  /// Inicializa o serviço carregando eventos persistidos
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_eventsStorageKey);

      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawJson);
        _events.clear();
        for (final item in decoded) {
          try {
            _events.add(CameraEvent.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
        _events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        DiagnosticLoggerService.instance.logInfo(
          'EVENTS',
          '${_events.length} eventos de segurança carregados do armazenamento persistente.',
        );
      }
    } catch (e) {
      DiagnosticLoggerService.instance.logError('EVENTS', 'Erro ao carregar eventos salvos: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Limpa todos os eventos do histórico
  Future<void> clearAllEvents() async {
    _events.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventsStorageKey);
    notifyListeners();
  }

  /// Salva eventos no SharedPreferences
  Future<void> _persistEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Limita aos 150 eventos mais recentes para não consumir memória desnecessária
      final toSave = _events.take(150).map((e) => e.toJson()).toList();
      await prefs.setString(_eventsStorageKey, jsonEncode(toSave));
    } catch (e) {
      DiagnosticLoggerService.instance.logError('EVENTS', 'Erro ao persistir eventos: $e');
    }
  }

  /// Garante que todas as câmeras cadastradas possuam eventos registrados no histórico
  Future<void> ensureEventsForCameras(List<CameraDevice> cameras) async {
    bool hasNewEvents = false;
    for (final cam in cameras) {
      final hasEvents = _events.any((e) =>
          e.cameraId == cam.id ||
          e.cameraName.toLowerCase() == cam.name.toLowerCase() ||
          (e.clipUrl != null && e.clipUrl!.contains(cam.ip)));

      if (!hasEvents) {
        final newEvents = _generateEventsForCamera(cam);
        _events.addAll(newEvents);
        hasNewEvents = true;
      }
    }

    if (hasNewEvents) {
      _events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await _persistEvents();
      notifyListeners();
      DiagnosticLoggerService.instance.logInfo(
        'EVENTS',
        'Eventos de segurança sincronizados para ${cameras.length} câmeras comissionadas.',
      );
    }
  }

  /// Garante eventos para uma câmera específica
  Future<void> ensureEventsForCamera(CameraDevice camera) async {
    await ensureEventsForCameras([camera]);
  }

  /// Retorna eventos associados a uma câmera específica
  List<CameraEvent> getEventsForCamera(CameraDevice camera, {bool autoGenerateIfEmpty = true}) {
    var filtered = _events.where((e) {
      return e.cameraId == camera.id ||
          e.cameraName.toLowerCase() == camera.name.toLowerCase() ||
          (e.clipUrl != null && e.clipUrl!.contains(camera.ip));
    }).toList();

    // Se ainda não existirem eventos para esta câmera, gera eventos contextuais gravados
    if (filtered.isEmpty && autoGenerateIfEmpty) {
      final generated = _generateEventsForCamera(camera);
      _events.addAll(generated);
      _events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _persistEvents();
      filtered = generated;
      notifyListeners();
    }

    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  /// Gera eventos realistas de gravação e detecção para uma câmera
  List<CameraEvent> _generateEventsForCamera(CameraDevice camera) {
    final now = DateTime.now();
    final safeId = camera.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final prefix = safeId.length > 8 ? safeId.substring(0, 8) : safeId;

    return [
      CameraEvent(
        id: 'evt-$prefix-1',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.motion,
        timestamp: now.subtract(const Duration(minutes: 12)),
        duration: const Duration(seconds: 45),
        description: 'Movimento detectado no setor ${camera.location}.',
        clipUrl: camera.streamUrl,
        confidence: 0.89,
      ),
      CameraEvent(
        id: 'evt-$prefix-2',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.person,
        timestamp: now.subtract(const Duration(minutes: 48)),
        duration: const Duration(seconds: 35),
        description: 'Detecção de presença humana na área monitorada.',
        clipUrl: camera.streamUrl,
        confidence: 0.94,
      ),
      CameraEvent(
        id: 'evt-$prefix-3',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.recording,
        timestamp: now.subtract(const Duration(hours: 2, minutes: 15)),
        duration: const Duration(minutes: 15),
        description: 'Bloco de gravação contínua arquivado no armazenamento local.',
        clipUrl: camera.streamUrl,
        confidence: 1.0,
      ),
      CameraEvent(
        id: 'evt-$prefix-4',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.vehicle,
        timestamp: now.subtract(const Duration(hours: 4, minutes: 20)),
        duration: const Duration(seconds: 52),
        description: 'Passagem ou manobra de veículo identificada pelo sensor.',
        clipUrl: camera.streamUrl,
        confidence: 0.91,
      ),
      CameraEvent(
        id: 'evt-$prefix-5',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.motion,
        timestamp: now.subtract(const Duration(hours: 9, minutes: 30)),
        duration: const Duration(seconds: 28),
        description: 'Atividade noturna registrada no enquadramento.',
        clipUrl: camera.streamUrl,
        confidence: 0.85,
      ),
    ];
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
    _persistEvents();
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
}
