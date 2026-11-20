import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/camera_storage_service.dart';
import 'services/diagnostic_logger_service.dart';
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
      ],
      child: FluentApp(
        title: 'b-cam • Vigilância Inteligente',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: BCamTheme.darkTheme(),
        theme: BCamTheme.darkTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
