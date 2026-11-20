import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../services/camera_storage_service.dart';
import '../theme/gta_colors.dart';
import '../widgets/gta_neon_card.dart';
import '../widgets/live_player_view.dart';
import 'commission_screen.dart';

class CameraDetailScreen extends StatefulWidget {
  final CameraDevice camera;

  const CameraDetailScreen({
    super.key,
    required this.camera,
  });

  @override
  State<CameraDetailScreen> createState() => _CameraDetailScreenState();
}

class _CameraDetailScreenState extends State<CameraDetailScreen> {
  late CameraDevice _camera;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _camera = widget.camera;
  }

  void _switchStreamQuality(int subType) {
    setState(() {
      _camera = _camera.copyWith(subType: subType);
    });
    context.read<CameraStorageService>().updateCamera(_camera);
  }

  void _triggerPtzAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
        backgroundColor: GtaColors.bgCard,
        content: Text(
          'PTZ $action enviado para ${_camera.ip}',
          style: GoogleFonts.orbitron(fontSize: 11, color: GtaColors.electricCyan),
        ),
      ),
    );
  }

  void _takeSnapshot() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: GtaColors.bgCard,
        content: Row(
          children: [
            const Icon(Icons.camera_alt_rounded, color: GtaColors.statusOnline),
            const SizedBox(width: 8),
            Text(
              'Foto instantânea capturada e salva!',
              style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _camera.name.toUpperCase(),
            style: GoogleFonts.orbitron(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _camera.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _camera.isFavorite ? GtaColors.sunsetYellow : Colors.white60,
            ),
            onPressed: () {
              setState(() {
                _camera = _camera.copyWith(isFavorite: !_camera.isFavorite);
              });
              context.read<CameraStorageService>().toggleFavorite(_camera.id);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: GtaColors.electricCyan),
            onPressed: () async {
              final storage = context.read<CameraStorageService>();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CommissionScreen(existingCamera: _camera),
                ),
              );
              if (!mounted) return;
              final updated = storage.cameras.firstWhere(
                    (c) => c.id == _camera.id,
                    orElse: () => _camera,
                  );
              setState(() {
                _camera = updated;
              });
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Main Video Player View
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LivePlayerView(
              camera: _camera,
              autoPlay: true,
              showPtzOverlay: true,
            ),
          ),
          const SizedBox(height: 16),

          // Action toolbar (Snapshot, Stream Quality, Audio)
          Row(
            children: [
              Expanded(
                child: GtaNeonCard(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  onTap: _takeSnapshot,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_rounded, color: GtaColors.neonPink, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'FOTO SNAPSHOT',
                        style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GtaNeonCard(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _camera.subType,
                      dropdownColor: GtaColors.bgCard,
                      isExpanded: true,
                      icon: const Icon(Icons.hd_rounded, color: GtaColors.electricCyan),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text('Stream Principal (HD)'),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Sub-Stream (Fluente)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) _switchStreamQuality(val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Virtual PTZ (Pan / Tilt / Zoom) Controller
          GtaNeonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CONTROLE PTZ VIRTUAL',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: GtaColors.neonPink,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'ONVIF / DAHUA PROTOCOL',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: GtaColors.electricCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      children: [
                        // Center Iris
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: GtaColors.bgSurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: GtaColors.neonPink),
                            ),
                            child: const Center(
                              child: Icon(Icons.circle, size: 14, color: GtaColors.neonPink),
                            ),
                          ),
                        ),
                        // UP
                        Align(
                          alignment: Alignment.topCenter,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: GtaColors.bgSurface,
                              side: const BorderSide(color: GtaColors.borderSubtle),
                            ),
                            icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                            onPressed: () => _triggerPtzAction('PARA CIMA'),
                          ),
                        ),
                        // DOWN
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: GtaColors.bgSurface,
                              side: const BorderSide(color: GtaColors.borderSubtle),
                            ),
                            icon: const Icon(Icons.arrow_downward_rounded, color: Colors.white),
                            onPressed: () => _triggerPtzAction('PARA BAIXO'),
                          ),
                        ),
                        // LEFT
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: GtaColors.bgSurface,
                              side: const BorderSide(color: GtaColors.borderSubtle),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            onPressed: () => _triggerPtzAction('ESQUERDA'),
                          ),
                        ),
                        // RIGHT
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: GtaColors.bgSurface,
                              side: const BorderSide(color: GtaColors.borderSubtle),
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                            onPressed: () => _triggerPtzAction('DIREITA'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Zoom Slider
                Row(
                  children: [
                    const Icon(Icons.zoom_out_rounded, color: Colors.white60, size: 18),
                    Expanded(
                      child: Slider(
                        value: _zoomLevel,
                        min: 1.0,
                        max: 4.0,
                        divisions: 6,
                        activeColor: GtaColors.neonPink,
                        inactiveColor: GtaColors.bgSurface,
                        label: '${_zoomLevel.toStringAsFixed(1)}x',
                        onChanged: (val) {
                          setState(() => _zoomLevel = val);
                        },
                      ),
                    ),
                    const Icon(Icons.zoom_in_rounded, color: GtaColors.neonPink, size: 22),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Telemetry & Details
          GtaNeonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TELEMETRIA DA CÂMERA',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: GtaColors.electricCyan,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTelemetryRow('Fabricante', _camera.manufacturer.displayName),
                _buildTelemetryRow('Endereço IP', '${_camera.ip}:${_camera.rtspPort}'),
                _buildTelemetryRow('Canal / Sub', 'CH${_camera.channel} / ${_camera.subType == 0 ? "Main" : "Sub"}'),
                _buildTelemetryRow('Localização', _camera.location),
                if (_camera.macAddress != null)
                  _buildTelemetryRow('MAC', _camera.macAddress!),
                const Divider(color: GtaColors.borderSubtle, height: 20),
                Text(
                  'URL RTSP (OFUSCADA):',
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _camera.maskedStreamUrl,
                  style: GoogleFonts.robotoMono(fontSize: 11, color: GtaColors.sunsetOrange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.rajdhani(fontSize: 13, color: Colors.white60)),
          Text(value, style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
