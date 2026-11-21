import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSharing = false;

  Future<void> _handleShareWhatsApp() async {
    setState(() => _isSharing = true);
    final auth = AuthService.instance;

    final success = await auth.shareReferralViaWhatsApp();

    if (mounted) {
      setState(() => _isSharing = false);
      if (success) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('WhatsApp Aberto'),
            content: const Text('Selecione o contato no WhatsApp para enviar o link de download do b-cam PRO.'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Sair da Conta Google'),
        content: const Text(
          'Deseja realmente sair da sua conta Google? Será necessário realizar a autenticação novamente para acessar as câmeras.',
        ),
        actions: [
          Button(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFFD83B01)),
            ),
            child: const Text('Sair'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          FluentPageRoute(builder: (_) => const AuthScreen(autoPromptBiometrics: false)),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final storage = context.watch<CameraStorageService>();
    final userCameras = user != null ? storage.getCamerasForUser(user.email) : <dynamic>[];

    return Container(
      color: BCamTheme.darkBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF14141B),
                border: Border(bottom: BorderSide(color: BCamTheme.darkBorder, width: 0.8)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(FluentIcons.back, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Perfil do Usuário',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2D1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E6F38)),
                    ),
                    child: Text(
                      'CONTA GOOGLE',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF4AE37B)),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User Identity Header Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0078D4).withValues(alpha: 0.2),
                              border: Border.all(color: const Color(0xFF0078D4), width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                (user?.displayName.isNotEmpty ?? false)
                                    ? user!.displayName[0].toUpperCase()
                                    : 'G',
                                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? 'Usuário b-cam',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ?? 'usuario@gmail.com',
                                  style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F1E2E),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '✔ Domínio Verificado @gmail.com',
                                    style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF4DA6FF)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // WHATSAPP RECOMMENDATION CARD (Requisito 4)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF102619),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E6F38), width: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(FluentIcons.send, size: 16, color: Color(0xFF25D366)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Indicar o b-cam via WhatsApp',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Compartilhe o app com amigos ou clientes',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFFA1D9B5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Envie uma recomendação com o link de download direto do b-cam PRO para qualquer pessoa no seu WhatsApp.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFFD1F2DE),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF091A11),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF174726)),
                            ),
                            child: Row(
                              children: [
                                const Icon(FluentIcons.link, size: 12, color: Color(0xFF25D366)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'https://bcam.nexeoo.com',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF25D366),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(const Color(0xFF25D366)),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(vertical: 12),
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            onPressed: _isSharing ? null : _handleShareWhatsApp,
                            child: _isSharing
                                ? const SizedBox(width: 18, height: 18, child: ProgressRing(strokeWidth: 2))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(FluentIcons.send, size: 14, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Enviar Indicação pelo WhatsApp',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // BIOMETRICS ACCESS CARD (Requisito 5)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0078D4).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(FluentIcons.fingerprint, size: 16, color: Color(0xFF4DA6FF)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Acesso por Biometria',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      auth.isBiometricsAvailable
                                          ? 'Sensor biométrico disponível no dispositivo'
                                          : 'Dispositivo sem biometria compatível',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: BCamTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (auth.isBiometricsAvailable)
                                ToggleSwitch(
                                  checked: user?.isBiometricEnabled ?? false,
                                  onChanged: (val) => auth.setBiometricsEnabled(val),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Quando ativado, você poderá entrar no b-cam com sua impressão digital ou reconhecimento facial sem precisar digitar senhas.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: BCamTheme.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Associated Cameras Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(FluentIcons.video, size: 16, color: Color(0xFF4DA6FF)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Câmeras Associadas',
                                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1E2E),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${userCameras.length} ativas',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4DA6FF)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Estas câmeras estão vinculadas à sua conta Google e salvas com segurança no seu dispositivo.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: BCamTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sair da Conta (Logout)
                    Button(
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
                      ),
                      onPressed: _handleLogout,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(FluentIcons.sign_out, size: 14, color: Color(0xFFFF6B6B)),
                          const SizedBox(width: 8),
                          Text(
                            'Sair da Conta Google',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFFFF6B6B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
