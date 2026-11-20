import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/camera_device.dart';
import '../services/camera_storage_service.dart';
import '../theme/fluent_theme.dart';
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
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: Text('Controle PTZ ($action)'),
        content: Text('Comando PTZ $action enviado para ${_camera.ip}'),
        severity: InfoBarSeverity.info,
        onClose: close,
      ),
    );
  }

  void _takeSnapshot() {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('Foto Instantânea'),
        content: const Text('Snapshot capturado e salvo no armazenamento!'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ScaffoldPage.scrollable(
      header: PageHeader(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.back, size: 16),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _camera.name,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _camera.isFavorite ? FluentIcons.favorite_star_fill : FluentIcons.favorite_star,
                size: 16,
                color: _camera.isFavorite ? BCamTheme.statusWarning : BCamTheme.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _camera = _camera.copyWith(isFavorite: !_camera.isFavorite);
                });
                context.read<CameraStorageService>().toggleFavorite(_camera.id);
              },
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(FluentIcons.edit, size: 16),
              onPressed: () async {
                final storage = context.read<CameraStorageService>();
                await Navigator.of(context).push(
                  FluentPageRoute(
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
      ),
      children: [
        // Main Video Player View
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LivePlayerView(
              camera: _camera,
              autoPlay: true,
              showPtzOverlay: true,
            ),
          ),
        ),

        // Action Toolbar (Snapshot, Stream Quality)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Button(
                  onPressed: _takeSnapshot,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FluentIcons.camera, size: 15),
                      const SizedBox(width: 6),
                      Text('Snapshot', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Button(
                  onPressed: () => _switchStreamQuality(_camera.subType == 0 ? 1 : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FluentIcons.video, size: 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _camera.subType == 0 ? 'HD Principal' : 'Sub Fluente',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Virtual PTZ Control Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            backgroundColor: BCamTheme.darkSurface,
            borderColor: BCamTheme.darkBorder,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Controle PTZ Virtual',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'ONVIF / Protocolo Nativo',
                      style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.accentLightBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Up
                        Positioned(
                          top: 0,
                          child: IconButton(
                            icon: const Icon(FluentIcons.chevron_up, size: 20),
                            onPressed: () => _triggerPtzAction('Subir (Pan Up)'),
                          ),
                        ),
                        // Down
                        Positioned(
                          bottom: 0,
                          child: IconButton(
                            icon: const Icon(FluentIcons.chevron_down, size: 20),
                            onPressed: () => _triggerPtzAction('Descer (Pan Down)'),
                          ),
                        ),
                        // Left
                        Positioned(
                          left: 0,
                          child: IconButton(
                            icon: const Icon(FluentIcons.chevron_left, size: 20),
                            onPressed: () => _triggerPtzAction('Esquerda (Pan Left)'),
                          ),
                        ),
                        // Right
                        Positioned(
                          right: 0,
                          child: IconButton(
                            icon: const Icon(FluentIcons.chevron_right, size: 20),
                            onPressed: () => _triggerPtzAction('Direita (Pan Right)'),
                          ),
                        ),
                        // Center Reset
                        Button(
                          onPressed: () {
                            setState(() => _zoomLevel = 1.0);
                            _triggerPtzAction('Posição Inicial (Home)');
                          },
                          child: const Icon(FluentIcons.sync, size: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(FluentIcons.remove, size: 16, color: BCamTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _zoomLevel,
                        min: 1.0,
                        max: 8.0,
                        onChanged: (val) {
                          setState(() => _zoomLevel = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(FluentIcons.add, size: 16, color: BCamTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      '${_zoomLevel.toStringAsFixed(1)}x',
                      style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Camera Telemetry Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            backgroundColor: BCamTheme.darkSurface,
            borderColor: BCamTheme.darkBorder,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Telemetria da Câmera',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _buildTelemetryRow('Fabricante', _camera.manufacturer.displayName),
                _buildTelemetryRow('Endereço IP', '${_camera.ip}:${_camera.rtspPort}'),
                _buildTelemetryRow('Canal / Fluxo', 'CH${_camera.channel} / ${_camera.subType == 0 ? "Principal (HD)" : "Sub (Fluente)"}'),
                _buildTelemetryRow('Localização', _camera.location),
                if (_camera.macAddress != null)
                  _buildTelemetryRow('MAC Address', _camera.macAddress!),
                const SizedBox(height: 8),
                Text(
                  'URL RTSP (Ofuscada):',
                  style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BCamTheme.darkCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: BCamTheme.darkBorder, width: 0.8),
                  ),
                  child: Text(
                    _camera.maskedStreamUrl,
                    style: GoogleFonts.robotoMono(fontSize: 10, color: BCamTheme.accentLightBlue),
                  ),
                ),
              ],
            ),
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
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: BCamTheme.textSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary)),
        ],
      ),
    );
  }
}
