import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/camera_storage_service.dart';
import 'theme/app_theme.dart';

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
      child: MaterialApp(
        title: 'b-cam • Vigilância Inteligente',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
