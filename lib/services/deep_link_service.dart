import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import '../models/camera_event.dart';
import '../screens/event_detail_screen.dart';
import 'camera_event_service.dart';
import 'diagnostic_logger_service.dart';

class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._internal();

  DeepLinkService._internal();

  static const MethodChannel _channel = MethodChannel('com.bcam.bcam/deeplink');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? _pendingDeepLink;
  String? get pendingDeepLink => _pendingDeepLink;

  void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final url = call.arguments as String?;
        if (url != null && url.isNotEmpty) {
          handleDeepLink(url);
        }
      }
    });

    _channel.invokeMethod<String>('getInitialDeepLink').then((url) {
      if (url != null && url.isNotEmpty) {
        handleDeepLink(url);
      }
    }).catchError((_) {});
  }

  void setPendingDeepLink(String? url) {
    _pendingDeepLink = url;
  }

  /// Processa e roteia uma URL de Deeplink (ex: bcam://event/evt-74-1 ou https://b-cam.app/event/evt-74-1)
  bool handleDeepLink(String url) {
    DiagnosticLoggerService.instance.logInfo(
      'DEEPLINK',
      'Recebida requisição de Deeplink: "$url"',
    );

    try {
      final uri = Uri.parse(url);
      String? eventId;

      if (uri.scheme == 'bcam') {
        // Formato: bcam://event/evt-123 ou bcam://event?id=evt-123
        if (uri.host == 'event') {
          if (uri.pathSegments.isNotEmpty) {
            eventId = uri.pathSegments.first;
          } else if (uri.queryParameters.containsKey('id')) {
            eventId = uri.queryParameters['id'];
          }
        }
      } else if (uri.scheme == 'http' || uri.scheme == 'https') {
        // Formato: https://b-cam.app/event/evt-123
        if (uri.pathSegments.contains('event')) {
          final index = uri.pathSegments.indexOf('event');
          if (index + 1 < uri.pathSegments.length) {
            eventId = uri.pathSegments[index + 1];
          }
        }
      } else if (url.startsWith('evt-')) {
        eventId = url;
      }

      if (eventId == null || eventId.isEmpty) {
        DiagnosticLoggerService.instance.logWarn(
          'DEEPLINK',
          'Não foi possível extrair eventId válido do Deeplink: "$url"',
        );
        return false;
      }

      final event = CameraEventService.instance.getEventById(eventId);
      if (event == null) {
        DiagnosticLoggerService.instance.logWarn(
          'DEEPLINK',
          'Evento com ID "$eventId" não encontrado no catálogo local.',
        );
        return false;
      }

      _navigateToEventDetail(event);
      _pendingDeepLink = null;
      return true;
    } catch (e, stack) {
      DiagnosticLoggerService.instance.logError(
        'DEEPLINK',
        'Falha ao processar Deeplink "$url": $e',
        stackTrace: stack,
      );
      return false;
    }
  }

  void _navigateToEventDetail(CameraEvent event) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pendingDeepLink = event.deepLinkUrl ?? 'bcam://event/${event.id}';
      return;
    }

    nav.push(
      FluentPageRoute(
        builder: (context) => EventDetailScreen(event: event),
      ),
    );

    DiagnosticLoggerService.instance.logInfo(
      'DEEPLINK',
      '✔ Navegação direta executada para o clipe do evento "${event.id}" (${event.type.label})',
    );
  }
}
