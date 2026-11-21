import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/splash_screen.dart';
import 'services/ai_vision_agent_service.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'services/camera_event_service.dart';
import 'services/camera_storage_service.dart';
import 'services/deep_link_service.dart';
import 'services/diagnostic_logger_service.dart';
import 'services/firebase_notification_service.dart';
import 'theme/fluent_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Initialize Diagnostic Logger
  final logger = DiagnosticLoggerService.instance;
  logger.logInfo('APP', '=== Inicializando b-cam (Sessão de Depuração Ativa) ===');

  // Intercept Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.logError(
      'FLUTTER_CORE',
      details.exceptionAsString(),
      stackTrace: details.stack,
      details: details.context?.toString(),
    );
  };

  // Intercept uncaught asynchronous platform errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logger.logError(
      'ASYNC_CORE',
      error.toString(),
      stackTrace: stack,
    );
    return true;
  };

  // Prevent screen from turning off or locking while app is active
  try {
    WakelockPlus.enable();
    logger.logInfo('SYSTEM', '✔ Wakelock ativado: bloqueio de tela desativado enquanto o app estiver aberto.');
  } catch (e) {
    logger.logWarn('SYSTEM', 'Falha ao ativar Wakelock: $e');
  }

  // Initialize DeepLink Router
  DeepLinkService.instance.initialize();

  runApp(const BCamApp());
}

class BCamApp extends StatelessWidget {
  final CameraStorageService? storageService;

  const BCamApp({super.key, this.storageService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => storageService ?? CameraStorageService()),
        ChangeNotifierProvider.value(value: DiagnosticLoggerService.instance),
        ChangeNotifierProvider.value(value: AuthService.instance),
        ChangeNotifierProvider.value(value: CameraEventService.instance),
        ChangeNotifierProvider.value(value: FirebaseNotificationService.instance),
        ChangeNotifierProvider.value(value: AppUpdateService.instance),
        ChangeNotifierProvider.value(value: AiVisionAgentService.instance),
      ],
      child: FluentApp(
        title: 'b-cam • Vigilância Inteligente',
        navigatorKey: DeepLinkService.instance.navigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: BCamTheme.darkTheme(),
        theme: BCamTheme.darkTheme(),
        home: const SplashScreen(),
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: mediaQuery.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
