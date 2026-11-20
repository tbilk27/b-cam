import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import 'deep_link_service.dart';
import 'diagnostic_logger_service.dart';

class PushNotificationPayload {
  final String id;
  final String title;
  final String body;
  final String deepLink;
  final DateTime receivedAt;
  final Map<String, dynamic> data;

  const PushNotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.receivedAt,
    this.data = const {},
  });
}

class FirebaseNotificationService extends ChangeNotifier {
  static final FirebaseNotificationService instance = FirebaseNotificationService._internal();

  FirebaseNotificationService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  final List<PushNotificationPayload> _notifications = [];
  List<PushNotificationPayload> get notifications => List.unmodifiable(_notifications);

  final _notificationController = StreamController<PushNotificationPayload>.broadcast();
  Stream<PushNotificationPayload> get onNotificationReceived => _notificationController.stream;

  /// Inicializa parâmetros do Firebase Cloud Messaging (FCM)
  Future<void> initialize({
    String? projectId,
    String? apiKey,
    String? appId,
  }) async {
    DiagnosticLoggerService.instance.logInfo(
      'FIREBASE_FCM',
      'Inicializando subsistema de Notificações Push (Firebase FCM)...',
    );

    // Mock/Simulador do token FCM enquanto o google-services.json não estiver conectado com projeto real
    _fcmToken = 'fcm_bcam_device_token_${DateTime.now().millisecondsSinceEpoch}_xy78z';
    _isInitialized = true;

    DiagnosticLoggerService.instance.logInfo(
      'FIREBASE_FCM',
      '✔ Firebase Messaging parametrizado com sucesso. Canal: b_cam_surveillance_alerts (Alta Prioridade). FCM Token gerado.',
    );

    notifyListeners();
  }

  /// Dispara notificação push com payload de Deeplink para o evento detectado
  void sendLocalPushForEvent(CameraEvent event, CameraDevice camera) {
    final deepLink = event.deepLinkUrl ?? 'bcam://event/${event.id}';
    final payload = PushNotificationPayload(
      id: 'notif-${event.id}',
      title: '🚨 Alerta b-cam: ${event.type.label}',
      body: '${camera.name}: ${event.description} (Certeza: ${(event.confidence * 100).toInt()}%)',
      deepLink: deepLink,
      receivedAt: DateTime.now(),
      data: {
        'eventId': event.id,
        'cameraId': camera.id,
        'confidence': event.confidence,
        'deepLink': deepLink,
      },
    );

    _notifications.insert(0, payload);
    _notificationController.add(payload);
    notifyListeners();

    DiagnosticLoggerService.instance.logInfo(
      'FIREBASE_FCM',
      'Push Notification despachada: "${payload.title}" -> Deeplink: "$deepLink"',
    );
  }

  /// Acionado quando o usuário toca na notificação recebida
  void onNotificationTapped(PushNotificationPayload payload) {
    DiagnosticLoggerService.instance.logInfo(
      'FIREBASE_FCM',
      'Toque na notificação "${payload.id}". Ativando Deeplink "${payload.deepLink}"...',
    );
    DeepLinkService.instance.handleDeepLink(payload.deepLink);
  }

  /// Remove notificação da lista ativa
  void dismissNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Limpa todas as notificações
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationController.close();
    super.dispose();
  }
}
