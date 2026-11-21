import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/camera_device.dart';
import '../models/scan_result.dart';
import '../services/camera_storage_service.dart';
import '../services/network_scanner_service.dart';
import '../theme/fluent_theme.dart';
import 'commission_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final NetworkScannerService _scanner = NetworkScannerService();
  StreamSubscription<ScanProgress>? _scanSub;

  late TextEditingController _subnetController;
  bool _isScanning = false;
  double _progress = 0.0;
  String _currentIp = '';
  final List<ScanResult> _discoveredCameras = [];

  @override
  void initState() {
    super.initState();
    _subnetController = TextEditingController(text: '192.168.3');
    _detectSubnetAndStart();
  }

  Future<void> _detectSubnetAndStart() async {
    final prefix = await _scanner.getLocalSubnetPrefix();
    if (mounted) {
      setState(() {
        _subnetController.text = prefix;
      });
      _startScan();
    }
  }

  void _startScan() {
    _scanSub?.cancel();
    setState(() {
      _isScanning = true;
      _progress = 0.0;
      _discoveredCameras.clear();
    });

    final prefix = _subnetController.text.trim();
    _scanSub = _scanner.scanSubnet(subnetPrefix: prefix).listen(
      (progressData) {
        if (mounted) {
          setState(() {
            _progress = progressData.progress;
            _currentIp = progressData.currentIp;
            _discoveredCameras.clear();
            _discoveredCameras.addAll(progressData.foundCameras);
            _isScanning = !progressData.isDone;
          });
        }
      },
      onDone: () async {
        if (mounted) {
          final healedCount = await context.read<CameraStorageService>().autoReconcileDevices(_discoveredCameras);
          if (mounted) {
            setState(() {
              _isScanning = false;
              _progress = 1.0;
            });
            if (healedCount > 0) {
              displayInfoBar(
                context,
                builder: (context, close) => InfoBar(
                  title: const Text('Auto-cura DHCP'),
                  content: Text('$healedCount câmera(s) re-vinculadas pelo endereço MAC!'),
                  severity: InfoBarSeverity.success,
                  onClose: close,
                ),
              );
            }
          }
        }
      },
    );
  }

  void _stopScan() {
    _scanner.cancelScan();
    _scanSub?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _subnetController.dispose();
    super.dispose();
  }

  Future<void> _commissionAllDiscovered(List<ScanResult> uncommissioned) async {
    final storage = context.read<CameraStorageService>();
    int count = 0;

    for (final scan in uncommissioned) {
      final device = CameraDevice(
        id: const Uuid().v4(),
        name: scan.suggestedName,
        ip: scan.ip,
        rtspPort: scan.openPorts.contains(554) ? 554 : scan.detectedManufacturer.defaultRtspPort,
        webPort: scan.detectedManufacturer.defaultWebPort,
        manufacturer: scan.detectedManufacturer,
        username: 'admin',
        password: '',
        channel: 1,
        subType: 0,
        location: 'Rede Local',
        macAddress: scan.macAddress,
      );
      await storage.addCamera(device);
      count++;
    }

    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Câmeras Comissionadas'),
          content: Text('$count nova(s) câmera(s) adicionadas com sucesso!'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<CameraStorageService>();
    final uncommissionedCameras = storage.filterUnregistered(_discoveredCameras);
    final alreadyCount = _discoveredCameras.length - uncommissionedCameras.length;

    return SafeArea(
      child: ScaffoldPage.scrollable(
      header: PageHeader(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(FluentIcons.back, size: 16),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Varredura Wi-Fi',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isScanning)
              FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(BCamTheme.statusOffline),
                ),
                onPressed: _stopScan,
                child: const Text('Parar'),
              )
            else
              FilledButton(
                onPressed: _startScan,
                child: const Text('Escanear Novamente'),
              ),
          ],
        ),
      ),
      children: [
        // Subnet Configuration Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            backgroundColor: BCamTheme.darkSurface,
            borderColor: BCamTheme.darkBorder,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faixa de IP Sub-rede',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          TextBox(
                            controller: _subnetController,
                            placeholder: 'Ex: 192.168.3',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Button(
                        onPressed: _isScanning ? null : _startScan,
                        child: const Text('Definir'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ProgressBar(value: (_progress * 100).clamp(0, 100)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isScanning
                          ? 'Sondando: $_currentIp'
                          : 'Varredura Concluída',
                      style: GoogleFonts.robotoMono(fontSize: 11, color: BCamTheme.textSecondary),
                    ),
                    Text(
                      '${(_progress * 100).toInt()}% • ${uncommissionedCameras.length} novas detectadas',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: BCamTheme.accentLightBlue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Discovered Header & Bulk Action
        if (uncommissionedCameras.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Novas Câmeras Encontradas (${uncommissionedCameras.length})',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Button(
                  onPressed: () => _commissionAllDiscovered(uncommissionedCameras),
                  child: const Text('Comissionar Todas'),
                ),
              ],
            ),
          ),

        // Discovered Camera Cards (Only unregistered cameras)
        if (uncommissionedCameras.isEmpty && !_isScanning)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    _discoveredCameras.isNotEmpty ? FluentIcons.check_mark : FluentIcons.wifi,
                    size: 40,
                    color: _discoveredCameras.isNotEmpty ? BCamTheme.statusOnlineGlow : BCamTheme.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _discoveredCameras.isNotEmpty
                        ? 'Todas as ${_discoveredCameras.length} câmeras detectadas nesta sub-rede já foram cadastradas no b-cam.'
                        : 'Nenhuma câmera identificada na sub-rede ${_subnetController.text}.1 - 254',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: BCamTheme.textSecondary),
                  ),
                  if (alreadyCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '($alreadyCount câmera(s) já configuradas e ocultadas da lista)',
                        style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
          )
        else
          ...uncommissionedCameras.map((scan) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Card(
                backgroundColor: BCamTheme.darkSurface,
                borderColor: BCamTheme.darkBorder,
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scan.detectedManufacturer.brandColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scan.detectedManufacturer.brandColor, width: 0.8),
                      ),
                      child: const Center(
                        child: Icon(FluentIcons.video, size: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                scan.detectedManufacturer.displayName,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: BCamTheme.statusOnline.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: BCamTheme.statusOnlineGlow, width: 0.8),
                                ),
                                child: Text(
                                  'ONLINE',
                                  style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: BCamTheme.statusOnlineGlow),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'IP: ${scan.ip}  •  Portas: ${scan.openPorts.join(', ')}',
                            style: GoogleFonts.robotoMono(fontSize: 11, color: BCamTheme.textSecondary),
                          ),
                          if (scan.macAddress != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'MAC: ${scan.macAddress} (ID Permanente)',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 10,
                                  color: BCamTheme.accentLightBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Text(
                            'Origem: ${scan.detectionSource} (${(scan.confidence * 100).toInt()}% precisão)',
                            style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          FluentPageRoute(
                            builder: (_) => CommissionScreen(scanResult: scan),
                          ),
                        );
                      },
                      child: const Text('Comissionar'),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    ),
    );
  }
}
