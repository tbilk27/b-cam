import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/scan_result.dart';
import '../services/auth_service.dart';
import '../services/camera_storage_service.dart';
import '../services/diagnostic_logger_service.dart';
import '../services/network_scanner_service.dart';
import '../theme/fluent_theme.dart';
import 'commission_screen.dart';
import 'home_screen.dart';

class FirstAccessScreen extends StatefulWidget {
  const FirstAccessScreen({super.key});

  @override
  State<FirstAccessScreen> createState() => _FirstAccessScreenState();
}

class _FirstAccessScreenState extends State<FirstAccessScreen> {
  final Set<String> _selectedCameraIds = {};
  bool _enableBiometrics = true;
  bool _isScanning = false;
  bool _isSaving = false;

  final _scanner = NetworkScannerService();

  @override
  void initState() {
    super.initState();
    final auth = AuthService.instance;
    _enableBiometrics = auth.isBiometricsAvailable;

    // Seleciona todas as câmeras já cadastradas por padrão
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = context.read<CameraStorageService>();
      setState(() {
        for (final cam in storage.cameras) {
          _selectedCameraIds.add(cam.id);
        }
      });
    });
  }

  Future<void> _runQuickScan() async {
    setState(() => _isScanning = true);
    DiagnosticLoggerService.instance.logInfo('FIRST_ACCESS', 'Varredura rápida disparada no primeiro acesso.');

    try {
      final results = await _scanner.scanSubnet(
        subnetPrefix: '192.168.3',
        portTimeout: const Duration(milliseconds: 400),
      ).toList();
      final discovered = results.isNotEmpty ? results.last.foundCameras : <ScanResult>[];

      if (mounted) {
        final storage = context.read<CameraStorageService>();
        await storage.autoReconcileDevices(discovered);
        setState(() {
          for (final cam in storage.cameras) {
            _selectedCameraIds.add(cam.id);
          }
        });
      }
    } catch (e) {
      DiagnosticLoggerService.instance.logError('FIRST_ACCESS', 'Erro na varredura: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isSaving = true);

    final auth = AuthService.instance;
    final user = auth.currentUser;
    final storage = context.read<CameraStorageService>();

    try {
      if (user != null) {
        // 1. Associa as câmeras selecionadas ao e-mail do usuário
        await storage.associateCamerasToUser(
          user.email,
          cameraIds: _selectedCameraIds.toList(),
        );

        // 2. Salva preferência biométrica
        if (auth.isBiometricsAvailable) {
          await auth.setBiometricsEnabled(_enableBiometrics);
        }

        // 3. Marca primeiro acesso como concluído
        await auth.completeFirstAccess();
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          FluentPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      DiagnosticLoggerService.instance.logError('FIRST_ACCESS', 'Erro ao concluir primeiro acesso: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final storage = context.watch<CameraStorageService>();
    final cameras = storage.cameras;

    return Container(
      color: BCamTheme.darkBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF14141B),
                border: Border(bottom: BorderSide(color: BCamTheme.darkBorder, width: 0.8)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0078D4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(FluentIcons.contact, size: 16, color: Color(0xFF4DA6FF)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Primeiro Acesso • b-cam PRO',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2),
                        ),
                        Text(
                          user?.email ?? 'Conta Google',
                          style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2D1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E6F38)),
                    ),
                    child: Text(
                      'CONTA ATIVA',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF4AE37B)),
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo Rolável
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card Boas-vindas
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bem-vindo, ${user?.displayName ?? "Usuário"}!',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sua conta Google (${user?.email}) foi criada com sucesso. Agora associe as câmeras da sua rede para gerenciar e monitorar.',
                            style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Seção de Câmeras
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Câmeras para Associar (${_selectedCameraIds.length}/${cameras.length})',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Button(
                              onPressed: _isScanning ? null : _runQuickScan,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isScanning)
                                    const SizedBox(width: 12, height: 12, child: ProgressRing(strokeWidth: 2))
                                  else
                                    const Icon(FluentIcons.search, size: 12),
                                  const SizedBox(width: 4),
                                  Text(_isScanning ? 'Varrendo...' : 'Varrer Rede', style: GoogleFonts.inter(fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Button(
                              onPressed: () {
                                Navigator.of(context).push(
                                  FluentPageRoute(builder: (_) => const CommissionScreen()),
                                );
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(FluentIcons.add, size: 12),
                                  const SizedBox(width: 4),
                                  Text('+ Câmera', style: GoogleFonts.inter(fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (cameras.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                        ),
                        child: Column(
                          children: [
                            const Icon(FluentIcons.video, size: 28, color: BCamTheme.textSecondary),
                            const SizedBox(height: 10),
                            Text(
                              'Nenhuma câmera cadastrada ainda',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Toque em "Varrer Rede" para localizar câmeras na Wi-Fi ou cadastre uma manualmente.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 11.5, color: BCamTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ...cameras.map((cam) {
                        final isSelected = _selectedCameraIds.contains(cam.id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF16202C) : const Color(0xFF14141B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0078D4) : BCamTheme.darkBorder,
                              width: isSelected ? 1.2 : 0.8,
                            ),
                          ),
                          child: Checkbox(
                            checked: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedCameraIds.add(cam.id);
                                } else {
                                  _selectedCameraIds.remove(cam.id);
                                }
                              });
                            },
                            content: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: BCamTheme.darkSurface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      FluentIcons.video,
                                      size: 16,
                                      color: isSelected ? const Color(0xFF4DA6FF) : BCamTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cam.name,
                                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                        Text(
                                          '${cam.ip}:${cam.rtspPort} • ${cam.manufacturer.displayName}',
                                          style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 16),

                    // Configuração de Biometria (Requisito 5)
                    if (auth.isBiometricsAvailable) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16161E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0078D4).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(FluentIcons.fingerprint, size: 18, color: Color(0xFF4DA6FF)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Login por Biometria',
                                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  Text(
                                    'Desbloquear app usando digital ou rosto nos próximos acessos',
                                    style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            ToggleSwitch(
                              checked: _enableBiometrics,
                              onChanged: (val) => setState(() => _enableBiometrics = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Botão Concluir
                    FilledButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(const Color(0xFF0078D4)),
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 14),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      onPressed: _isSaving ? null : _completeOnboarding,
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: ProgressRing(strokeWidth: 2))
                          : Text(
                              'Concluir e Iniciar Monitoramento',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
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
