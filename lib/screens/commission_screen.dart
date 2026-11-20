import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/camera_device.dart';
import '../models/camera_event.dart';
import '../models/manufacturer.dart';
import '../models/scan_result.dart';
import '../services/ai_vision_agent_service.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/live_player_view.dart';

class CommissionScreen extends StatefulWidget {
  final ScanResult? scanResult;
  final CameraDevice? existingCamera;

  const CommissionScreen({
    super.key,
    this.scanResult,
    this.existingCamera,
  });

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _rtspPortController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late TextEditingController _channelController;
  late TextEditingController _customUrlController;
  late TextEditingController _locationController;

  late CameraManufacturer _selectedManufacturer;
  int _selectedSubType = 0; // 0 = Main, 1 = Sub
  bool _testingStream = false;
  bool _isManualCustomUrl = false;

  // AI Event Recognition & Confidence Threshold Configuration
  bool _aiDetectionEnabled = true;
  double _aiMinConfidence = 0.25; // 25% default
  bool _pushNotificationsEnabled = true;

  final List<String> _commonLocations = [
    'Entrada',
    'Portão',
    'Garagem',
    'Corredor',
    'Perímetro',
    'Fundos',
    'Recepção',
    'Geral',
  ];

  @override
  void initState() {
    super.initState();
    final scan = widget.scanResult;
    final existing = widget.existingCamera;

    if (existing != null) {
      _nameController = TextEditingController(text: existing.name);
      _ipController = TextEditingController(text: existing.ip);
      _rtspPortController = TextEditingController(text: existing.rtspPort.toString());
      _userController = TextEditingController(text: existing.username);
      _passController = TextEditingController(text: existing.password);
      _channelController = TextEditingController(text: existing.channel.toString());
      _customUrlController = TextEditingController(text: existing.customUrl ?? '');
      _locationController = TextEditingController(text: existing.location);
      _selectedManufacturer = existing.manufacturer;
      _selectedSubType = existing.subType;
      _isManualCustomUrl = existing.customUrl != null && existing.customUrl!.isNotEmpty;
      _aiDetectionEnabled = existing.aiDetectionEnabled;
      _aiMinConfidence = existing.aiMinConfidence;
      _pushNotificationsEnabled = existing.pushNotificationsEnabled;
    } else if (scan != null) {
      _nameController = TextEditingController(text: scan.suggestedName);
      _ipController = TextEditingController(text: scan.ip);
      _rtspPortController = TextEditingController(text: '554');
      _userController = TextEditingController(text: scan.detectedManufacturer.defaultUser);
      _passController = TextEditingController(text: '');
      _channelController = TextEditingController(text: '1');
      _customUrlController = TextEditingController(text: '');
      _locationController = TextEditingController(text: 'Entrada');
      _selectedManufacturer = scan.detectedManufacturer;
      _selectedSubType = 0;
    } else {
      _nameController = TextEditingController(text: 'Nova Câmera');
      _ipController = TextEditingController(text: '192.168.3.');
      _rtspPortController = TextEditingController(text: '554');
      _userController = TextEditingController(text: 'admin');
      _passController = TextEditingController(text: '');
      _channelController = TextEditingController(text: '1');
      _customUrlController = TextEditingController(text: '');
      _locationController = TextEditingController(text: 'Geral');
      _selectedManufacturer = CameraManufacturer.intelbras;
      _selectedSubType = 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _rtspPortController.dispose();
    _userController.dispose();
    _passController.dispose();
    _channelController.dispose();
    _customUrlController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  CameraDevice _buildTempDevice() {
    return CameraDevice(
      id: widget.existingCamera?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      ip: _ipController.text.trim(),
      rtspPort: int.tryParse(_rtspPortController.text.trim()) ?? 554,
      webPort: 80,
      manufacturer: _selectedManufacturer,
      username: _userController.text.trim(),
      password: _passController.text.trim(),
      channel: int.tryParse(_channelController.text.trim()) ?? 1,
      subType: _selectedSubType,
      customUrl: _isManualCustomUrl ? _customUrlController.text.trim() : null,
      location: _locationController.text.trim(),
      macAddress: widget.scanResult?.macAddress ?? widget.existingCamera?.macAddress,
      aiDetectionEnabled: _aiDetectionEnabled,
      aiMinConfidence: _aiMinConfidence,
      pushNotificationsEnabled: _pushNotificationsEnabled,
    );
  }

  void _applyQuickCredential(String user, String pass) {
    setState(() {
      _userController.text = user;
      _passController.text = pass;
    });
  }

  Future<void> _saveCamera() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final device = _buildTempDevice();
    final storage = context.read<CameraStorageService>();

    if (widget.existingCamera != null) {
      await storage.updateCamera(device);
    } else {
      await storage.addCamera(device);
    }

    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Configuração Salva'),
          content: Text('Câmera "${device.name}" foi salva com sucesso!'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewDevice = _buildTempDevice();

    return SafeArea(
      child: ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.back, size: 16),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Text(
              widget.existingCamera != null ? 'Editar Câmera' : 'Comissionar Câmera',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      content: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
              // Auto-detected Banner if from Scan
              if (widget.scanResult != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: InfoBar(
                    title: const Text('Dispositivo Detectado na Rede'),
                    content: Text(
                      'Origem: ${widget.scanResult!.detectionSource} • MAC: ${widget.scanResult!.macAddress ?? "Não resolvido"}',
                    ),
                    severity: InfoBarSeverity.info,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Live Test Stream Card
              if (_testingStream) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    backgroundColor: BCamTheme.darkSurface,
                    borderColor: BCamTheme.darkBorder,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(FluentIcons.video, size: 16, color: BCamTheme.accentLightBlue),
                                const SizedBox(width: 8),
                                Text(
                                  'Teste de Reprodução em Tempo Real',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(FluentIcons.chrome_close, size: 14),
                              onPressed: () => setState(() => _testingStream = false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: LivePlayerView(camera: previewDevice),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // 1. Manufacturer selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'FABRICANTE & PROTOCOLO',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: BCamTheme.accentLightBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: CameraManufacturer.values.map((m) {
                      final isSelected = m == _selectedManufacturer;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Button(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              isSelected ? BCamTheme.accentBlue : BCamTheme.darkCard,
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                side: BorderSide(
                                  color: isSelected ? BCamTheme.accentLightBlue : BCamTheme.darkBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedManufacturer = m;
                              _userController.text = m.defaultUser;
                            });
                          },
                          child: Text(
                            m.displayName,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? Colors.white : BCamTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Camera Name & Location
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Card(
                  backgroundColor: BCamTheme.darkSurface,
                  borderColor: BCamTheme.darkBorder,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Identificação do Dispositivo',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Nome da Câmera',
                        style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      TextFormBox(
                        controller: _nameController,
                        placeholder: 'Ex: Câmera Portão Principal',
                        validator: (v) => v == null || v.isEmpty ? 'Informe o nome da câmera' : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Local / Zona de Monitoramento',
                        style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      TextFormBox(
                        controller: _locationController,
                        placeholder: 'Ex: Entrada, Garagem, Perímetro',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _commonLocations.map((loc) {
                          return Button(
                            onPressed: () => setState(() => _locationController.text = loc),
                            child: Text(loc, style: GoogleFonts.inter(fontSize: 11)),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Network & Connection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Card(
                  backgroundColor: BCamTheme.darkSurface,
                  borderColor: BCamTheme.darkBorder,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rede & Conexão RTSP',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Endereço IP Local',
                                  style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                TextFormBox(
                                  controller: _ipController,
                                  placeholder: '192.168.3.X',
                                  validator: (v) => v == null || v.isEmpty ? 'Informe o IP' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Porta RTSP',
                                  style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                TextFormBox(
                                  controller: _rtspPortController,
                                  placeholder: '554',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Canal NVR / Câmera',
                                  style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                TextFormBox(
                                  controller: _channelController,
                                  placeholder: '1',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Qualidade do Fluxo',
                                  style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  child: ComboBox<int>(
                                    value: _selectedSubType,
                                    items: const [
                                      ComboBoxItem(value: 0, child: Text('Principal (HD/4K)')),
                                      ComboBoxItem(value: 1, child: Text('Sub (Fluente)')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedSubType = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Credentials & Auto-Testing Helpers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Card(
                  backgroundColor: BCamTheme.darkSurface,
                  borderColor: BCamTheme.darkBorder,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Autenticação de Acesso',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Nome de Usuário',
                        style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      TextFormBox(
                        controller: _userController,
                        placeholder: 'Ex: admin',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Senha do Fluxo RTSP',
                        style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      TextFormBox(
                        controller: _passController,
                        obscureText: true,
                        placeholder: 'Deixe em branco se não houver senha',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Atalhos de credenciais do ambiente:',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (_selectedManufacturer == CameraManufacturer.intelbras ||
                              _ipController.text.endsWith('.74'))
                            Button(
                              style: ButtonStyle(
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    side: const BorderSide(color: BCamTheme.accentLightBlue),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              onPressed: () => _applyQuickCredential('admin', 'Zs29364835'),
                              child: Text(
                                'admin / Zs29364835 (Frente)',
                                style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.accentLightBlue, fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (_selectedManufacturer == CameraManufacturer.yoosee ||
                              _ipController.text.endsWith('.23') ||
                              _ipController.text.endsWith('.24'))
                            Button(
                              style: ButtonStyle(
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    side: const BorderSide(color: BCamTheme.accentLightBlue),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              onPressed: () => _applyQuickCredential('admin', 'Compras10@'),
                              child: Text(
                                'admin / Compras10@ (Yoosee)',
                                style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.accentLightBlue, fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (_selectedManufacturer == CameraManufacturer.intelbrasMibo ||
                              _ipController.text.endsWith('.22'))
                            Button(
                              style: ButtonStyle(
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    side: const BorderSide(color: BCamTheme.accentLightBlue),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              onPressed: () => _applyQuickCredential('admin', 'compras10'),
                              child: Text(
                                'admin / compras10 (Mibo)',
                                style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.accentLightBlue, fontWeight: FontWeight.w600),
                              ),
                            ),
                          Button(
                            onPressed: () => _applyQuickCredential('admin', 'admin'),
                            child: Text('admin / admin', style: GoogleFonts.inter(fontSize: 11)),
                          ),
                          Button(
                            onPressed: () => _applyQuickCredential('admin', '123456'),
                            child: Text('admin / 123456', style: GoogleFonts.inter(fontSize: 11)),
                          ),
                          Button(
                            onPressed: () => _applyQuickCredential('admin', ''),
                            child: Text('admin / (vazio)', style: GoogleFonts.inter(fontSize: 11)),
                          ),
                        ],
                      ),
                      if (_selectedManufacturer == CameraManufacturer.intelbrasMibo ||
                          _ipController.text.endsWith('.22')) ...[
                        const SizedBox(height: 12),
                        const InfoBar(
                          title: Text('Dica Intelbras Mibo'),
                          content: Text(
                            'O usuário local é "admin". A senha é a da conta Mibo ("compras10") ou o Safety Code (código de verificação) da etiqueta se a criptografia estiver ativa.',
                          ),
                          severity: InfoBarSeverity.warning,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 5. RTSP URL Preview / Manual Override
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Card(
                  backgroundColor: BCamTheme.darkSurface,
                  borderColor: BCamTheme.darkBorder,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'URL do Fluxo RTSP',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                          ),
                          Button(
                            onPressed: () {
                              setState(() {
                                _isManualCustomUrl = !_isManualCustomUrl;
                                if (_isManualCustomUrl && _customUrlController.text.isEmpty) {
                                  _customUrlController.text = previewDevice.streamUrl;
                                }
                              });
                            },
                            child: Text(
                              _isManualCustomUrl ? 'Modo Automático' : 'Personalizar URL',
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isManualCustomUrl)
                        TextFormBox(
                          controller: _customUrlController,
                          placeholder: 'rtsp://usuario:senha@ip:porta/caminho',
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: BCamTheme.darkCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: BCamTheme.darkBorderSubtle),
                          ),
                          child: Text(
                            previewDevice.maskedStreamUrl,
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: BCamTheme.accentLightBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 6. Inteligência Artificial, Limiar de Certeza & Notificações Firebase
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Card(
                  backgroundColor: BCamTheme.darkSurface,
                  borderColor: BCamTheme.darkBorder,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: BCamTheme.accentBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(FluentIcons.robot, size: 16, color: BCamTheme.accentLightBlue),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Inteligência Artificial & Alertas',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Toggle Habilitar IA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mapeamento de Eventos por IA',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                              ),
                              Text(
                                'Identifica pessoas, veículos e interpreta a cena',
                                style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textSecondary),
                              ),
                            ],
                          ),
                          ToggleSwitch(
                            checked: _aiDetectionEnabled,
                            onChanged: (val) => setState(() => _aiDetectionEnabled = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Slider de Limiar de Confiança
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Limiar Mínimo de Certeza',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BCamTheme.accentBlue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: BCamTheme.accentBlue, width: 0.8),
                                ),
                                child: Text(
                                  '${(_aiMinConfidence * 100).toInt()}%',
                                  style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w700, color: BCamTheme.accentLightBlue),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Slider(
                            value: _aiMinConfidence * 100,
                            min: 10.0,
                            max: 95.0,
                            divisions: 17,
                            onChanged: (val) {
                              setState(() {
                                _aiMinConfidence = val / 100;
                              });
                            },
                          ),
                          Text(
                            '💡 Regra de Negócio: Detecções com nível de certeza abaixo de ${(_aiMinConfidence * 100).toInt()}% '
                            '(ex: sombras, ruídos ou dúvidas) não gravam eventos e nem disparam notificações.',
                            style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textTertiary, height: 1.3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Toggle Notificações Push
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notificações Push (Firebase FCM)',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                              ),
                              Text(
                                'Envia aviso imediato com Deeplink para o clipe',
                                style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textSecondary),
                              ),
                            ],
                          ),
                          ToggleSwitch(
                            checked: _pushNotificationsEnabled,
                            onChanged: (val) => setState(() => _pushNotificationsEnabled = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Botões de Simulação Rápida para Testar Limiar
                      Text(
                        'Simular Teste de Limiar do Agente de IA:',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Button(
                              onPressed: () {
                                final tempCam = _buildTempDevice();
                                final evt = AiVisionAgentService.instance.testDetectionWithConfidence(
                                  camera: tempCam,
                                  simulatedConfidence: 0.92,
                                  label: 'Pessoa',
                                  type: CameraEventType.person,
                                );
                                displayInfoBar(
                                  context,
                                  builder: (context, close) => InfoBar(
                                    title: const Text('Teste IA: 92% Certeza'),
                                    content: Text(
                                      evt != null
                                          ? 'Evento gerado e notificação push despachada (acima de ${(_aiMinConfidence * 100).toInt()}%).'
                                          : 'Evento descartado.',
                                    ),
                                    severity: InfoBarSeverity.success,
                                    onClose: close,
                                  ),
                                );
                              },
                              child: Text(
                                'Pessoa (92% • Notifica)',
                                style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.statusOnlineGlow),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Button(
                              onPressed: () {
                                final tempCam = _buildTempDevice();
                                final evt = AiVisionAgentService.instance.testDetectionWithConfidence(
                                  camera: tempCam,
                                  simulatedConfidence: 0.18,
                                  label: 'Ruído Periférico',
                                  type: CameraEventType.motion,
                                );
                                displayInfoBar(
                                  context,
                                  builder: (context, close) => InfoBar(
                                    title: const Text('Teste IA: 18% Certeza'),
                                    content: Text(
                                      evt == null
                                          ? '✔ Descartado pelo limiar de ${(_aiMinConfidence * 100).toInt()}% (nem grava, nem notifica).'
                                          : 'Evento gerado.',
                                    ),
                                    severity: InfoBarSeverity.warning,
                                    onClose: close,
                                  ),
                                );
                              },
                              child: Text(
                                'Ruído (18% • Ignora)',
                                style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.statusOffline),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons: Test Live & Save
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Button(
                        onPressed: () {
                          setState(() {
                            _testingStream = true;
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(FluentIcons.play, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              _testingStream ? 'Recarregar Teste' : 'Testar Conexão',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveCamera,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(FluentIcons.save, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              widget.existingCamera != null ? 'Salvar Alterações' : 'Comissionar Câmera',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
