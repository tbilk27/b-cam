import 'package:fluent_ui/fluent_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/camera_storage_service.dart';
import 'theme/fluent_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

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
