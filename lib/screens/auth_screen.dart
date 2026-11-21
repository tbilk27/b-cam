import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/b_cam_logo.dart';
import 'first_access_screen.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool autoPromptBiometrics;

  const AuthScreen({
    super.key,
    this.autoPromptBiometrics = true,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.autoPromptBiometrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndPromptBiometrics();
      });
    }
  }

  Future<void> _checkAndPromptBiometrics() async {
    final auth = AuthService.instance;
    final user = auth.currentUser;

    if (user != null && user.isBiometricEnabled && auth.isBiometricsAvailable) {
      final success = await auth.authenticateWithBiometrics();
      if (success && mounted) {
        _navigateForward(auth);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = AuthService.instance;
    final result = await auth.signInWithGoogle();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      _navigateForward(auth);
    } else if (!result.cancelled) {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Falha na autenticação com o Google.';
      });
    }
  }

  Future<void> _handleBiometricAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = AuthService.instance;
    final success = await auth.authenticateWithBiometrics();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _navigateForward(auth);
    }
  }

  void _navigateForward(AuthService auth) {
    final user = auth.currentUser;
    final isFirst = user != null && !user.hasCompletedFirstAccess;

    if (isFirst) {
      Navigator.of(context).pushReplacement(
        FluentPageRoute(builder: (_) => const FirstAccessScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        FluentPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final savedUser = auth.currentUser;
    final canUseBiometrics = savedUser != null &&
        savedUser.isBiometricEnabled &&
        auth.isBiometricsAvailable;

    return Container(
      color: BCamTheme.darkBackground,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo Canônico Central
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: BCamTheme.darkSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: BCamTheme.accentBlue.withValues(alpha: 0.35), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: BCamTheme.accentBlue.withValues(alpha: 0.2),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const BCamLogo(size: 44, showText: false),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título e Subtítulo
                  Text(
                    'b-cam PRO',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.syne(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vigilância Inteligente & Controle de Acesso',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: BCamTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Card de Autenticação
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16161E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: BCamTheme.accentBlue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                FluentIcons.lock,
                                size: 14,
                                color: BCamTheme.accentBlue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Autenticação de Segurança',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Acesso restrito para contas autorizadas',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: BCamTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Aviso de domínio @gmail.com
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1E2E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E3A5F)),
                          ),
                          child: Row(
                            children: [
                              const Icon(FluentIcons.info, size: 14, color: Color(0xFF4DA6FF)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Criação de conta e login permitidos apenas com e-mails oficiais @gmail.com',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFFC7E0F4),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Mensagem de Erro (se houver)
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1010),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF8B2525)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(FluentIcons.error_badge, size: 14, color: Color(0xFFFF6B6B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFFFFCCCC),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Opção de Desbloqueio por Biometria (se disponível para usuário salvo)
                        if (canUseBiometrics) ...[
                          FilledButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(const Color(0xFF0078D4)),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            onPressed: _isLoading ? null : _handleBiometricAuth,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(FluentIcons.fingerprint, size: 18, color: Colors.white),
                                const SizedBox(width: 10),
                                Text(
                                  'Entrar com Biometria',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              'ou',
                              style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Botão Oficial Google Sign-In
                        FilledButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(Colors.white),
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: ProgressRing(strokeWidth: 2.5),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Google "G" icon styling
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(shape: BoxShape.circle),
                                      child: Center(
                                        child: Text(
                                          'G',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF4285F4),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Continuar com o Google',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1F1F1F),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Powered by Bilk Sistemas
                  Center(
                    child: Text(
                      'Powered by Bilk Sistemas • bcam.nexeoo.com',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: BCamTheme.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
