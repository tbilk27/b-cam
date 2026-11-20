import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/camera_device.dart';
import '../models/manufacturer.dart';
import '../models/scan_result.dart';
import '../services/camera_storage_service.dart';
import '../theme/gta_colors.dart';
import '../widgets/gta_button.dart';
import '../widgets/gta_neon_card.dart';
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
    );
  }

  void _applyQuickCredential(String user, String pass) {
    setState(() {
      _userController.text = user;
      _passController.text = pass;
    });
  }

  Future<void> _saveCamera() async {
    if (!_formKey.currentState!.validate()) return;

    final device = _buildTempDevice();
    final storage = context.read<CameraStorageService>();

    if (widget.existingCamera != null) {
      await storage.updateCamera(device);
    } else {
      await storage.addCamera(device);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GtaColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: GtaColors.statusOnline),
          ),
          content: Text(
            'Câmera "${device.name}" salva com sucesso!',
            style: GoogleFonts.rajdhani(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewDevice = _buildTempDevice();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingCamera != null ? 'EDITAR CÂMERA' : 'COMISSIONAR CÂMERA'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Auto-detected Banner if from Scan
            if (widget.scanResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: GtaColors.neonCyanPinkGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DETECTADA AUTOMATICAMENTE',
                            style: GoogleFonts.orbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Origem: ${widget.scanResult!.detectionSource}',
                            style: GoogleFonts.rajdhani(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Live Test Stream Card
            if (_testingStream) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TESTE EM TEMPO REAL',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: GtaColors.electricCyan,
                          letterSpacing: 1.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white60),
                        onPressed: () => setState(() => _testingStream = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: LivePlayerView(camera: previewDevice),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],

            // 1. Manufacturer selection
            Text(
              'FABRICANTE / PROTOCOLO',
              style: GoogleFonts.orbitron(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: GtaColors.neonPink,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: CameraManufacturer.values.map((m) {
                  final isSelected = m == _selectedManufacturer;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(m.displayName),
                      labelStyle: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      selectedColor: m.brandColor,
                      backgroundColor: GtaColors.bgCard,
                      side: BorderSide(
                        color: isSelected ? Colors.white : GtaColors.borderSubtle,
                        width: isSelected ? 1.5 : 1,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedManufacturer = m;
                            _userController.text = m.defaultUser;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Camera Name & Location
            GtaNeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IDENTIFICAÇÃO',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: GtaColors.electricCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Câmera',
                      prefixIcon: Icon(Icons.videocam_rounded),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Localização / Zona',
                      prefixIcon: Icon(Icons.place_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _commonLocations.map((loc) {
                      return ActionChip(
                        label: Text(loc, style: GoogleFonts.rajdhani(fontSize: 12)),
                        backgroundColor: GtaColors.bgSurface,
                        side: const BorderSide(color: GtaColors.borderSubtle),
                        onPressed: () => setState(() => _locationController.text = loc),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Network & Connection
            GtaNeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REDE & COMUNICAÇÃO',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: GtaColors.electricCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _ipController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Endereço IP',
                            prefixIcon: Icon(Icons.lan_rounded),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Informe o IP' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _rtspPortController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Porta',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _channelController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Canal NVR / Cam',
                            prefixIcon: Icon(Icons.grid_view_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedSubType,
                          decoration: const InputDecoration(labelText: 'Qualidade Fluxo'),
                          dropdownColor: GtaColors.bgCard,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Principal (HD/4K)')),
                            DropdownMenuItem(value: 1, child: Text('Sub (Fluente)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSubType = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Credentials & Auto-Testing Helpers
            GtaNeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUTENTICAÇÃO & CREDENCIAIS',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: GtaColors.electricCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: 'Usuário',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha (Deixe em branco se não houver)',
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Credenciais comuns do fabricante:',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      color: Colors.white60,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: Text('admin / admin', style: GoogleFonts.rajdhani(fontSize: 11)),
                        backgroundColor: GtaColors.bgSurface,
                        side: const BorderSide(color: GtaColors.borderSubtle),
                        onPressed: () => _applyQuickCredential('admin', 'admin'),
                      ),
                      ActionChip(
                        label: Text('admin / 123456', style: GoogleFonts.rajdhani(fontSize: 11)),
                        backgroundColor: GtaColors.bgSurface,
                        side: const BorderSide(color: GtaColors.borderSubtle),
                        onPressed: () => _applyQuickCredential('admin', '123456'),
                      ),
                      ActionChip(
                        label: Text('admin / admin123', style: GoogleFonts.rajdhani(fontSize: 11)),
                        backgroundColor: GtaColors.bgSurface,
                        side: const BorderSide(color: GtaColors.borderSubtle),
                        onPressed: () => _applyQuickCredential('admin', 'admin123'),
                      ),
                      ActionChip(
                        label: Text('admin / (sem senha)', style: GoogleFonts.rajdhani(fontSize: 11)),
                        backgroundColor: GtaColors.bgSurface,
                        side: const BorderSide(color: GtaColors.borderSubtle),
                        onPressed: () => _applyQuickCredential('admin', ''),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. RTSP URL Preview / Manual Override
            GtaNeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'URL DO FLUXO RTSP GERADA',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: GtaColors.sunsetOrange,
                          letterSpacing: 1.2,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isManualCustomUrl = !_isManualCustomUrl;
                            if (_isManualCustomUrl && _customUrlController.text.isEmpty) {
                              _customUrlController.text = previewDevice.streamUrl;
                            }
                          });
                        },
                        child: Text(
                          _isManualCustomUrl ? 'USAR AUTO' : 'CUSTOMIZAR',
                          style: GoogleFonts.orbitron(fontSize: 10, color: GtaColors.electricCyan),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_isManualCustomUrl)
                    TextFormField(
                      controller: _customUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL RTSP Customizada',
                        hintText: 'rtsp://usuario:senha@ip:porta/caminho',
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GtaColors.borderSubtle),
                      ),
                      child: Text(
                        previewDevice.maskedStreamUrl,
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          color: GtaColors.electricCyan,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons: Test Live & Save
            Row(
              children: [
                Expanded(
                  child: GtaButton(
                    label: _testingStream ? 'RECARREGAR TESTE' : 'TESTAR FLUXO',
                    icon: Icons.play_circle_outline_rounded,
                    outlined: true,
                    onPressed: () {
                      setState(() {
                        _testingStream = true;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GtaButton(
                    label: widget.existingCamera != null ? 'SALVAR ALTERAÇÕES' : 'COMISSIONAR',
                    icon: Icons.check_circle_rounded,
                    onPressed: _saveCamera,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
