import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/camera_storage_service.dart';
import '../services/deep_link_service.dart';
import '../services/diagnostic_logger_service.dart';
import '../services/firebase_notification_service.dart';
import '../theme/fluent_theme.dart';
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
    DiagnosticLoggerService.instance.logInfo('SPLASH', 'Iniciando sequência de inicialização b-cam...');

    // Etapa 1: Carregar câmeras do storage
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _disposed) return;
    setState(() {
      _statusText = 'Carregando câmeras comissionadas...';
      _progressValue = 40.0;
    });

    final storage = Provider.of<CameraStorageService>(context, listen: false);
    await storage.loadCameras();

    // Etapa 2: Inicializar parâmetros do Firebase e IA
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted || _disposed) return;
    setState(() {
      _statusText = 'Conectando ao barramento de eventos e IA...';
      _progressValue = 75.0;
    });

    await FirebaseNotificationService.instance.initialize();

    // Etapa 3: Concluir e rotear
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _disposed) return;
    setState(() {
      _statusText = 'Sistema pronto para monitoramento.';
      _progressValue = 100.0;
    });

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted || _disposed) return;

    // Roteia para HomeScreen
    Navigator.of(context).pushReplacement(
      FluentPageRoute(
        builder: (context) => const HomeScreen(),
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

              // Logo Emblema Canônico com Respiração e Rim Glow
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: BCamTheme.darkSurface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: BCamTheme.accentBlue.withValues(alpha: _glowAnimation.value),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: BCamTheme.accentBlue.withValues(alpha: _glowAnimation.value * 0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.asset(
                          'assets/images/b_cam_icon.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(FluentIcons.video, size: 48, color: BCamTheme.accentLightBlue),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Wordmark b-cam PRO
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'b-cam',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: BCamTheme.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: BCamTheme.accentBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: BCamTheme.accentBlue.withValues(alpha: 0.7), width: 1.0),
                    ),
                    child: Text(
                      'PRO',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: BCamTheme.accentLightBlue,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                'SURVEILLANCE RADAR',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BCamTheme.textSecondary,
                  letterSpacing: 2.0,
                ),
              ),

              const SizedBox(height: 48),

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

              // Rodapé de Versão e Copyright Corporativo
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'v1.2.0 • Build 3 • Inteligência Artificial & Visão Computacional',
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    color: BCamTheme.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
