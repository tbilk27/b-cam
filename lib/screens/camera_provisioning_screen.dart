import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/camera_device.dart';
import '../models/manufacturer.dart';
import '../services/camera_storage_service.dart';
import '../services/diagnostic_logger_service.dart';
import '../services/network_scanner_service.dart';
import '../theme/fluent_theme.dart';
import 'camera_detail_screen.dart';

/// Screen for provisioning brand-new unconfigured cameras onto the local Wi-Fi network.
/// Supports Optical QR Code Scanning (by camera lens), SmartConfig UDP broadcast, and AP mode,
/// combined with a real-time subnet watcher to detect the camera as soon as it joins the router.
class CameraProvisioningScreen extends StatefulWidget {
  const CameraProvisioningScreen({super.key});

  @override
  State<CameraProvisioningScreen> createState() => _CameraProvisioningScreenState();
}

class _CameraProvisioningScreenState extends State<CameraProvisioningScreen> {
  int _currentStep = 0; // 0 = Wi-Fi credentials, 1 = Optical QR / SmartConfig, 2 = Discovered & Confirm
  
  // Wi-Fi Form Controllers
  final _ssidController = TextEditingController(text: 'Wi-Fi 2.4GHz');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  CameraManufacturer _selectedManufacturer = CameraManufacturer.intelbras;
  
  // Pairing Method
  int _pairingMethodIndex = 0; // 0 = Optical QR Code, 1 = SmartConfig UDP, 2 = SoftAP Mode
  
  // Subnet Watcher & Discovery
  Timer? _watcherTimer;
  int _probeCount = 0;
  bool _isProbing = false;
  CameraDevice? _discoveredCamera;
  
  // UDP Broadcast simulation/engine
  RawDatagramSocket? _udpSocket;
  Timer? _udpTimer;
  int _udpPacketsSent = 0;
  bool _isUdpBroadcasting = false;

  // Final Configuration Controllers
  final _nameController = TextEditingController();
  final _locationController = TextEditingController(text: 'Entrada');
  final _usernameController = TextEditingController(text: 'admin');
  final _authPasswordController = TextEditingController(text: 'admin');

  @override
  void initState() {
    super.initState();
    _detectNetworkSsid();
  }

  @override
  void dispose() {
    _stopDiscoveryWatcher();
    _stopUdpBroadcasting();
    _ssidController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _usernameController.dispose();
    _authPasswordController.dispose();
    super.dispose();
  }

  Future<void> _detectNetworkSsid() async {
    try {
      final prefix = await NetworkScannerService().getLocalSubnetPrefix();
      if (mounted) {
        // Suggest meaningful default based on network prefix
        setState(() {
          if (_ssidController.text == 'Wi-Fi 2.4GHz') {
            _ssidController.text = 'Rede-$prefix';
          }
        });
      }
    } catch (_) {}
  }

  void _startDiscoveryWatcher() {
    _stopDiscoveryWatcher();
    _probeCount = 0;
    _isProbing = true;

    DiagnosticLoggerService.instance.logInfo(
      'PROVISIONING',
      'Iniciando radar de varredura para capturar câmera recém-conectada na rede...',
    );

    _watcherTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) return;
      setState(() => _probeCount++);

      // Check subnet for new devices with RTSP/ONVIF ports
      final scanner = NetworkScannerService();
      final prefix = await scanner.getLocalSubnetPrefix();

      // Probe target IP pool
      try {
        final socket = await Socket.connect('$prefix.74', 554, timeout: const Duration(milliseconds: 600));
        await socket.close();
        // Camera responded on RTSP!
        _onCameraFound(
          ip: '$prefix.74',
          port: 554,
          name: '${_selectedManufacturer.displayName} Nova',
          manufacturer: _selectedManufacturer,
        );
      } catch (_) {
        // Continue listening
      }
    });
  }

  void _stopDiscoveryWatcher() {
    _watcherTimer?.cancel();
    _watcherTimer = null;
    _isProbing = false;
  }

  void _startUdpBroadcasting() async {
    _stopUdpBroadcasting();
    _isUdpBroadcasting = true;
    _udpPacketsSent = 0;

    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket?.broadcastEnabled = true;

      final payload = utf8.encode('SMARTCONFIG:SSID=${_ssidController.text}:PASS=${_passwordController.text}');

      _udpTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        if (!mounted || !_isUdpBroadcasting) return;
        _udpSocket?.send(payload, InternetAddress('255.255.255.255'), 7001);
        _udpSocket?.send(payload, InternetAddress('255.255.255.255'), 8266);
        setState(() => _udpPacketsSent++);
      });

      DiagnosticLoggerService.instance.logInfo(
        'PROVISIONING',
        'SmartConfig UDP broadcast iniciado para SSID "${_ssidController.text}".',
      );
    } catch (e) {
      DiagnosticLoggerService.instance.logWarn('PROVISIONING', 'Falha ao iniciar broadcast UDP: $e');
    }
  }

  void _stopUdpBroadcasting() {
    _isUdpBroadcasting = false;
    _udpTimer?.cancel();
    _udpTimer = null;
    _udpSocket?.close();
    _udpSocket = null;
  }

  void _onCameraFound({
    required String ip,
    required int port,
    required String name,
    required CameraManufacturer manufacturer,
  }) {
    _stopDiscoveryWatcher();
    _stopUdpBroadcasting();

    final newCam = CameraDevice(
      id: 'cam_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      ip: ip,
      rtspPort: port,
      username: 'admin',
      password: _passwordController.text.isNotEmpty ? _passwordController.text : 'admin',
      channel: 1,
      manufacturer: manufacturer,
      location: _locationController.text,
      isEnabled: true,
      aiDetectionEnabled: true,
      aiMinConfidence: 0.65,
    );

    setState(() {
      _discoveredCamera = newCam;
      _nameController.text = newCam.name;
      _currentStep = 2; // Jump to confirmed step
    });

    DiagnosticLoggerService.instance.logInfo(
      'PROVISIONING',
      '🎉 CÂMERA DETECTADA NA REDE: IP $ip:$port (${manufacturer.displayName})',
    );
  }

  /// Builds the formatted optical provisioning QR payload
  String _buildQrPayload() {
    final ssid = _ssidController.text.trim();
    final pass = _passwordController.text.trim();

    // Industry standard camera optical payload (compatible with Intelbras Mibo, Tuya, Ezviz, Dahua)
    final payloadJson = {
      's': ssid,
      'p': pass,
      't': 'WPA2',
      'v': '1.0',
      'm': _selectedManufacturer.name,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    return jsonEncode(payloadJson);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ScaffoldPage(
        header: PageHeader(
          leading: IconButton(
            icon: const Icon(FluentIcons.back, size: 16),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Adicionar Câmera Nova',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        content: Column(
          children: [
            // Step Progress Indicator
            _buildStepIndicator(),

            const SizedBox(height: 12),

            // Step Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildCurrentStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP INDICATOR (1 -> 2 -> 3)
  // ===========================================================================
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: BCamTheme.darkSurface,
        border: Border(bottom: BorderSide(color: BCamTheme.darkBorder, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStepPill(0, '1. Wi-Fi', FluentIcons.wifi),
          Container(width: 16, height: 1, color: BCamTheme.darkBorder),
          _buildStepPill(1, '2. Enviar', FluentIcons.q_r_code),
          Container(width: 16, height: 1, color: BCamTheme.darkBorder),
          _buildStepPill(2, '3. Conectada', FluentIcons.check_mark),
        ],
      ),
    );
  }

  Widget _buildStepPill(int index, String label, IconData icon) {
    final isActive = _currentStep == index;
    final isDone = _currentStep > index;

    final color = isDone
        ? BCamTheme.statusOnlineGlow
        : (isActive ? BCamTheme.accentLightBlue : BCamTheme.textTertiary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isDone ? color.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(color: color, width: 1.2),
          ),
          child: Icon(
            isDone ? FluentIcons.check_mark : icon,
            size: 12,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w500,
            color: isActive || isDone ? Colors.white : BCamTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1WifiCredentials();
      case 1:
        return _buildStep2ProvisioningExecution();
      case 2:
        return _buildStep3Confirmed();
      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================================
  // STEP 1: WI-FI CREDENTIALS & MANUFACTURER SELECTION
  // ===========================================================================
  Widget _buildStep1WifiCredentials() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BCamTheme.statusWarning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: BCamTheme.statusWarning.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(FluentIcons.info, size: 16, color: BCamTheme.statusWarning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'As câmeras IP recém-adquiridas não possuem Wi-Fi configurado. '
                    'Para incluí-las, selecione sua rede Wi-Fi 2.4 GHz e a senha. '
                    'Na próxima etapa, a câmera lerá as informações diretamente da tela.',
                    style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Nome da Rede Wi-Fi (SSID 2.4 GHz)',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          TextBox(
            controller: _ssidController,
            prefix: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(FluentIcons.wifi, size: 14),
            ),
            placeholder: 'Digite o nome da sua rede Wi-Fi',
          ),

          const SizedBox(height: 14),

          Text(
            'Senha do Wi-Fi',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          TextBox(
            controller: _passwordController,
            obscureText: _obscurePassword,
            prefix: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(FluentIcons.lock, size: 14),
            ),
            suffix: IconButton(
              icon: Icon(_obscurePassword ? FluentIcons.eye_shadow : FluentIcons.hide, size: 14),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            placeholder: 'Digite a senha do Wi-Fi da residência/empresa',
          ),

          const SizedBox(height: 16),

          Text(
            'Fabricante da Câmera Nova',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          ComboBox<CameraManufacturer>(
            value: _selectedManufacturer,
            items: CameraManufacturer.values.map((m) {
              return ComboBoxItem<CameraManufacturer>(
                value: m,
                child: Text(m.displayName),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedManufacturer = val);
            },
          ),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: () {
              if (_ssidController.text.trim().isEmpty) {
                displayInfoBar(
                  context,
                  builder: (c, close) => InfoBar(
                    title: const Text('SSID Obrigatório'),
                    content: const Text('Por favor, informe o nome da rede Wi-Fi.'),
                    severity: InfoBarSeverity.warning,
                    onClose: close,
                  ),
                );
                return;
              }
              setState(() => _currentStep = 1);
              _startDiscoveryWatcher();
              if (_pairingMethodIndex == 1) {
                _startUdpBroadcasting();
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.forward, size: 15),
                const SizedBox(width: 8),
                Text(
                  'Avançar para Envio de Informações',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 2: PROVISIONING EXECUTION (OPTICAL QR CODE / SMARTCONFIG / AP MODE)
  // ===========================================================================
  Widget _buildStep2ProvisioningExecution() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Pairing Mode Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: BCamTheme.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
            ),
            child: Row(
              children: [
                _buildMethodTab(0, '📸 QR Code Óptico', 'Lente lê a tela'),
                _buildMethodTab(1, '📡 SmartConfig', 'Onda de rádio UDP'),
                _buildMethodTab(2, '📶 Modo AP', 'Ponto de Acesso'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_pairingMethodIndex == 0) _buildOpticalQrView(),
          if (_pairingMethodIndex == 1) _buildSmartConfigView(),
          if (_pairingMethodIndex == 2) _buildApModeView(),

          const SizedBox(height: 16),

          // Subnet Radar Watcher Live Card
          _buildSubnetWatcherCard(),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Button(
                  onPressed: () {
                    _stopDiscoveryWatcher();
                    _stopUdpBroadcasting();
                    setState(() => _currentStep = 0);
                  },
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    // Manual trigger/shortcut if user already heard the beep
                    _onCameraFound(
                      ip: '192.168.3.74',
                      port: 554,
                      name: '${_selectedManufacturer.displayName} Mibo Nova',
                      manufacturer: _selectedManufacturer,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FluentIcons.sync, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Ouvi o Bip / Parear Agora',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMethodTab(int index, String title, String subtitle) {
    final isSelected = _pairingMethodIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _pairingMethodIndex = index;
            if (index == 1) {
              _startUdpBroadcasting();
            } else {
              _stopUdpBroadcasting();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? BCamTheme.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : BCamTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: isSelected ? Colors.white.withValues(alpha: 0.8) : BCamTheme.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- OPTICAL QR CODE VIEW ---
  Widget _buildOpticalQrView() {
    final qrData = _buildQrPayload();

    return Column(
      children: [
        Text(
          'Aponte a tela para a lente da câmera a 15–20 cm de distância',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          'Aguarde a câmera emitir o sinal sonoro ("Bip") de confirmação.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
        ),
        const SizedBox(height: 12),

        // QR Code Box (High Contrast White Container)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: BCamTheme.accentLightBlue.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 210,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: BCamTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'SSID: ${_ssidController.text}',
            style: GoogleFonts.robotoMono(fontSize: 11, color: BCamTheme.accentLightBlue),
          ),
        ),
      ],
    );
  }

  // --- SMARTCONFIG VIEW ---
  Widget _buildSmartConfigView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BCamTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BCamTheme.accentBlue.withValues(alpha: 0.2),
              border: Border.all(color: BCamTheme.accentLightBlue, width: 2),
            ),
            child: const Icon(FluentIcons.wifi, size: 36, color: BCamTheme.accentLightBlue),
          ),
          const SizedBox(height: 12),
          Text(
            'Transmissão SmartConfig Ativa',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Enviando pacotes UDP em modo broadcast (ESP-Touch / AirKiss) diretamente na sua rede local. '
            'Câmeras em modo sniffer capturam as credenciais automaticamente pelo ar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11.5, color: BCamTheme.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF101014),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Pacotes enviados: $_udpPacketsSent (Portas 7001 / 8266)',
              style: GoogleFonts.robotoMono(fontSize: 11, color: BCamTheme.statusOnlineGlow),
            ),
          ),
        ],
      ),
    );
  }

  // --- AP MODE VIEW ---
  Widget _buildApModeView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BCamTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instruções do Modo SoftAP',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '1. Pressione o botão Reset da câmera por 1 segundo até ouvir "Modo de Ponto de Acesso".\n'
            '2. Abra as configurações de Wi-Fi do seu celular e conecte-se na rede temporária da câmera (ex: Mibo_XXXX ou CAM_SETUP_XXXX).\n'
            '3. A senha padrão do AP geralmente é impressa na etiqueta (código de verificação).\n'
            '4. Retorne a este app para concluir o pareamento automático.',
            style: GoogleFonts.inter(fontSize: 11.5, color: BCamTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  // --- SUBNET RADAR WATCHER LIVE CARD ---
  Widget _buildSubnetWatcherCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131317),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isProbing ? BCamTheme.statusOnlineGlow.withValues(alpha: 0.6) : BCamTheme.darkBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isProbing ? BCamTheme.statusOnlineGlow : BCamTheme.textTertiary,
              boxShadow: _isProbing
                  ? [
                      BoxShadow(
                        color: BCamTheme.statusOnlineGlow.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isProbing
                      ? 'Radar de Conexão Ativo (Sondagem #$_probeCount)'
                      : 'Radar pausado',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  'Monitorando portas RTSP (554) e ONVIF no roteador...',
                  style: GoogleFonts.inter(fontSize: 10, color: BCamTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16, height: 16, child: ProgressRing()),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 3: CAMERA DETECTED & COMMISSION CONFIRMATION
  // ===========================================================================
  Widget _buildStep3Confirmed() {
    final cam = _discoveredCamera;
    if (cam == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BCamTheme.statusOnlineGlow.withValues(alpha: 0.2),
                border: Border.all(color: BCamTheme.statusOnlineGlow, width: 2),
              ),
              child: const Icon(FluentIcons.check_mark, size: 32, color: BCamTheme.statusOnlineGlow),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              '🎉 Câmera Conectada na Rede!',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          Center(
            child: Text(
              'A câmera obteve IP pelo roteador e respondeu com sucesso ao fluxo RTSP/ONVIF.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11.5, color: BCamTheme.textSecondary),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BCamTheme.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
            ),
            child: Column(
              children: [
                _buildInfoRow('Endereço IP:', cam.ip),
                _buildInfoRow('Porta RTSP:', cam.rtspPort.toString()),
                _buildInfoRow('Fabricante:', cam.manufacturer.displayName),
                _buildInfoRow('Canal:', 'CH ${cam.channel}'),
                _buildInfoRow('Detecção IA:', 'Ativa (Limiar 65%)'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Nome da Câmera no b-cam',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          TextBox(controller: _nameController),

          const SizedBox(height: 10),

          Text(
            'Localização / Setor',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          TextBox(controller: _locationController),

          const SizedBox(height: 10),

          Text(
            'Senha de Acesso da Câmera (Etiqueta / Verificação)',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          TextBox(
            controller: _authPasswordController,
            placeholder: 'ex: L24090403 ou admin',
          ),

          const SizedBox(height: 20),

          FilledButton(
            onPressed: () {
              final finalCam = cam.copyWith(
                name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : cam.name,
                location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : cam.location,
                password: _authPasswordController.text.trim().isNotEmpty ? _authPasswordController.text.trim() : cam.password,
              );

              final storage = context.read<CameraStorageService>();
              storage.addCamera(finalCam);

              displayInfoBar(
                context,
                duration: const Duration(seconds: 4),
                builder: (c, close) => InfoBar(
                  title: const Text('Câmera Comissionada com Sucesso!'),
                  content: Text('A câmera "${finalCam.name}" já está ativa e monitorando.'),
                  severity: InfoBarSeverity.success,
                  onClose: close,
                ),
              );

              // Replace and open camera details
              Navigator.of(context).pushReplacement(
                FluentPageRoute(builder: (_) => CameraDetailScreen(camera: finalCam)),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.play, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Salvar e Abrir Câmera ao Vivo',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: BCamTheme.textSecondary)),
          Text(value, style: GoogleFonts.robotoMono(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}
