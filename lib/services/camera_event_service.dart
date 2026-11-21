import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

        // Remove eventos sintéticos/fictícios legados para manter apenas dados e gravações reais
        final beforeCount = _events.length;
        _events.removeWhere((e) =>
            e.id.startsWith('evt-init-') ||
            e.id.startsWith('evt-sim-') ||
            e.id.startsWith('evt-mock-') ||
            RegExp(r'^evt-[a-zA-Z0-9]+-[1-5]$').hasMatch(e.id) ||
            e.description.contains('Área Monitorada') ||
            e.description.contains('Enquadramento inicial') ||
            e.description.contains('Bloco de gravação contínua') ||
            e.description.contains('Passagem ou manobra de veículo') ||
            e.description.contains('Atividade noturna registrada') ||
            e.description.contains('Movimento detectado no setor') ||
            e.description.contains('Detecção de presença humana na área monitorada') ||
            (e.clipUrl != null && e.clipUrl!.startsWith('rtsp://')) ||
            e.boundingBoxes.any((b) => b.label == 'Área Monitorada') ||
            e.boundingBoxes.any((b) =>
                (b.left == 0.25 && b.top == 0.25 && b.width == 0.50) ||
                (b.left == 0.32 && b.top == 0.26 && b.width == 0.36)));

        if (_events.length != beforeCount) {
          DiagnosticLoggerService.instance.logInfo(
            'EVENTS',
            'Limpeza de dados legados: ${beforeCount - _events.length} eventos sintéticos/duplicados removidos do histórico.',
          );
          await _persistEvents();
        }

        _events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        DiagnosticLoggerService.instance.logInfo(
          'EVENTS',
          '${_events.length} eventos de segurança reais carregados do armazenamento persistente.',
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

  /// Garante a sincronização de eventos para as câmeras cadastradas sem criar dados fictícios
  Future<void> ensureEventsForCameras(List<CameraDevice> cameras) async {
    // Mantém a integridade do histórico sem injetar eventos falsos
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Garante eventos para uma câmera específica mantendo integridade sem injetar dados fictícios
  Future<void> ensureEventsForCamera(CameraDevice camera) async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Retorna eventos reais associados a uma câmera específica
  List<CameraEvent> getEventsForCamera(CameraDevice camera, {bool autoGenerateIfEmpty = false}) {
    var filtered = _events.where((e) {
      return e.cameraId == camera.id ||
          (camera.name.isNotEmpty && e.cameraName.toLowerCase() == camera.name.toLowerCase()) ||
          (e.clipUrl != null && e.clipUrl!.contains(camera.ip));
    }).toList();

    // Gera eventos sintéticos APENAS se explicitamente solicitado (ex: suítes de testes de regressão)
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

  /// Gera eventos realistas de gravação e detecção exclusivos e variados para uma câmera
  List<CameraEvent> _generateEventsForCamera(CameraDevice camera) {
    final now = DateTime.now();
    final safeId = camera.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final prefix = safeId.length > 8 ? safeId.substring(0, 8) : safeId;

    // Semente única baseada na identidade física da câmera para horários e posições descorrelacionados
    final seed = (camera.id + camera.ip + (camera.macAddress ?? '') + camera.name).hashCode.abs();
    final m1 = (seed % 19) + 4; // 4 a 22 min atrás
    final m2 = ((seed ~/ 7) % 43) + 26; // 26 a 68 min atrás
    final m3 = ((seed ~/ 13) % 75) + 85; // 1h25 a 2h40 atrás
    final m4 = ((seed ~/ 19) % 150) + 210; // 3h30 a 6h00 atrás
    final m5 = ((seed ~/ 29) % 240) + 460; // 7h40 a 11h40 atrás

    final d1 = 25 + (seed % 35); // 25s a 60s
    final d2 = 20 + ((seed ~/ 3) % 40);
    final d4 = 30 + ((seed ~/ 5) % 45);
    final d5 = 18 + ((seed ~/ 7) % 30);

    return [
      CameraEvent(
        id: 'evt-$prefix-1',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.motion,
        timestamp: now.subtract(Duration(minutes: m1)),
        duration: Duration(seconds: d1),
        description: 'Movimento detectado no setor ${camera.location}.',
        confidence: 0.88 + ((seed % 10) * 0.01),
        boundingBoxes: [
          BoundingBox(
            label: 'Movimento Detectado',
            confidence: 0.88 + ((seed % 10) * 0.01),
            left: 0.20 + ((seed % 15) * 0.01),
            top: 0.28 + ((seed % 10) * 0.01),
            width: 0.46,
            height: 0.40,
          ),
        ],
      ),
      CameraEvent(
        id: 'evt-$prefix-2',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.person,
        timestamp: now.subtract(Duration(minutes: m2)),
        duration: Duration(seconds: d2),
        description: 'Detecção de presença humana na área monitorada.',
        confidence: 0.93 + ((seed % 6) * 0.01),
        boundingBoxes: [
          BoundingBox(
            label: 'Pessoa',
            confidence: 0.93 + ((seed % 6) * 0.01),
            left: 0.36 + ((seed % 12) * 0.01),
            top: 0.22,
            width: 0.26,
            height: 0.58,
          ),
        ],
      ),
      CameraEvent(
        id: 'evt-$prefix-3',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.recording,
        timestamp: now.subtract(Duration(minutes: m3)),
        duration: const Duration(minutes: 15),
        description: 'Bloco de gravação contínua arquivado no armazenamento local.',
        confidence: 1.0,
      ),
      CameraEvent(
        id: 'evt-$prefix-4',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.vehicle,
        timestamp: now.subtract(Duration(minutes: m4)),
        duration: Duration(seconds: d4),
        description: 'Passagem ou manobra de veículo identificada pelo sensor.',
        confidence: 0.91 + ((seed % 8) * 0.01),
        boundingBoxes: [
          BoundingBox(
            label: 'Veículo',
            confidence: 0.91 + ((seed % 8) * 0.01),
            left: 0.24 + ((seed % 10) * 0.01),
            top: 0.32,
            width: 0.50,
            height: 0.36,
          ),
        ],
      ),
      CameraEvent(
        id: 'evt-$prefix-5',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.motion,
        timestamp: now.subtract(Duration(minutes: m5)),
        duration: Duration(seconds: d5),
        description: 'Atividade noturna registrada no enquadramento.',
        confidence: 0.85 + ((seed % 7) * 0.01),
        boundingBoxes: [
          BoundingBox(
            label: 'Movimento Noturno',
            confidence: 0.85 + ((seed % 7) * 0.01),
            left: 0.18 + ((seed % 15) * 0.01),
            top: 0.24 + ((seed % 10) * 0.01),
            width: 0.44,
            height: 0.38,
          ),
        ],
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
  bool registerEvent(CameraEvent event, {required CameraDevice camera, bool forceAccept = false}) {
    if (!forceAccept && event.type != CameraEventType.recording) {
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
    }

    // Regra da Zona de Exclusão: se o evento ocorrer dentro da área mascarada pelo usuário, descarta imediatamente
    if (!forceAccept && camera.hasExclusionZone) {
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
    final validBoxes = forceAccept
        ? event.boundingBoxes
        : event.boundingBoxes
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

  static const MethodChannel _platformChannel = MethodChannel('com.nexeoo.bcam/deeplink');

  /// Formata e compartilha o vídeo e informações de um evento gravado via WhatsApp
  Future<bool> shareEventViaWhatsApp(
    CameraEvent event, {
    CameraDevice? camera,
    String? snapshotPath,
    String? phone,
  }) async {
    try {
      final camName = camera?.name ?? event.cameraName;
      final videoLink = event.deepLinkUrl != null && event.deepLinkUrl!.startsWith('http')
          ? event.deepLinkUrl!
          : 'https://bcam.nexeoo.com/event/${event.id}';

      final buffer = StringBuffer();
      buffer.writeln('🚨 *Alerta de Vigilância b-cam PRO*');
      buffer.writeln('');
      buffer.writeln('📹 *Câmera:* $camName');
      buffer.writeln('🔍 *Evento:* ${event.type.label}');
      buffer.writeln('🕒 *Horário:* ${event.timeFormatted} (${event.dateFormatted})');
      buffer.writeln('⚡ *Assertividade IA:* ${(event.confidence * 100).toInt()}%');
      if (event.sceneInterpretation != null && event.sceneInterpretation!.isNotEmpty) {
        buffer.writeln('📝 *Interpretação IA:* ${event.sceneInterpretation}');
      } else if (event.description.isNotEmpty) {
        buffer.writeln('📝 *Detalhes:* ${event.description}');
      }
      buffer.writeln('⏱️ *Duração do Clipe:* ${event.durationFormatted}');
      buffer.writeln('');
      buffer.writeln('▶️ *Assistir Gravação do Vídeo:*');
      buffer.writeln(videoLink);

      final message = buffer.toString();
      final effectivePath = snapshotPath ?? camera?.lastSnapshotPath;

      final result = await _platformChannel.invokeMethod<bool>('shareEventViaWhatsApp', {
        'filePath': effectivePath,
        'message': message,
        'phone': phone,
      });

      DiagnosticLoggerService.instance.logInfo(
        'EVENTS',
        'Vídeo/alerta do evento ${event.id} (${event.type.label}) compartilhado via WhatsApp.',
      );

      return result ?? true;
    } catch (e) {
      DiagnosticLoggerService.instance.logError(
        'EVENTS',
        'Erro ao compartilhar vídeo do evento via WhatsApp: $e',
      );
      return false;
    }
  }
}
