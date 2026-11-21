import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/camera_event_service.dart';
import '../services/camera_storage_service.dart';
import '../services/deep_link_service.dart';
import '../services/diagnostic_logger_service.dart';
import '../services/firebase_notification_service.dart';
import '../theme/fluent_theme.dart';
import 'auth_screen.dart';
import 'first_access_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  String _statusText = 'Inicializando subsistemas de vigilância...';
  double _progressValue = 15.0;

  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _runStartupSequence();
  }

  Future<void> _runStartupSequence() async {
    DiagnosticLoggerService.instance.logInfo('SPLASH', 'Iniciando inicialização ultrarrápida b-cam...');

    final storage = Provider.of<CameraStorageService>(context, listen: false);

    // Inicialização concorrente dos subsistemas para máxima agilidade de abertura
    await Future.wait([
      storage.loadCameras(),
      AuthService.instance.initialize(),
      CameraEventService.instance.initialize(),
      FirebaseNotificationService.instance.initialize(),
      Future.delayed(const Duration(milliseconds: 250)),
    ]);

    // Assegura histórico de eventos para as câmeras cadastradas
    if (storage.cameras.isNotEmpty) {
      await CameraEventService.instance.ensureEventsForCameras(storage.cameras);
    }

    if (!mounted || _disposed) return;
    setState(() {
      _statusText = 'Sistema pronto para monitoramento.';
      _progressValue = 100.0;
    });

    final auth = AuthService.instance;
    final user = auth.currentUser;

    Widget nextScreen;
    if (user == null) {
      nextScreen = const AuthScreen(autoPromptBiometrics: false);
    } else if (user.isBiometricEnabled && auth.isBiometricsAvailable) {
      nextScreen = const AuthScreen(autoPromptBiometrics: true);
    } else if (!user.hasCompletedFirstAccess) {
      nextScreen = const FirstAccessScreen();
    } else {
      nextScreen = const HomeScreen();
    }

    // Roteamento para a tela apropriada (Auth, Primeiro Acesso ou Home)
    Navigator.of(context).pushReplacement(
      FluentPageRoute(
        builder: (context) => nextScreen,
      ),
    );

    // Se houver um Deeplink pendente, ativa a navegação direta
    final pendingLink = DeepLinkService.instance.pendingDeepLink;
    if (pendingLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DeepLinkService.instance.handleDeepLink(pendingLink);
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BCamTheme.darkBackground,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Logo Oficial Neon b-cam SURVEILLANCE RADAR com Respiração e Rim Glow
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: _glowAnimation.value * 0.30),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: const Color(0xFFFF007F).withValues(alpha: _glowAnimation.value * 0.22),
                            blurRadius: 36,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 1024 / 571,
                          child: Image.asset(
                            'assets/images/b_cam_neon_logo.jpg',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(FluentIcons.video, size: 64, color: BCamTheme.accentLightBlue),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 44),

              // Barra de Progresso e Status
              SizedBox(
                width: 220,
                child: Column(
                  children: [
                    ProgressBar(
                      value: _progressValue,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: BCamTheme.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Rodapé de Versão, Domínio e Copyright Corporativo
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'v1.26.0 • Build 29 • Inteligência Artificial & Visão Computacional',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        color: BCamTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Powered by ',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: BCamTheme.textSecondary,
                          ),
                        ),
                        Text(
                          'Bilk Sistemas',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: BCamTheme.accentLightBlue,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
