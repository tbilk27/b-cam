import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/camera_device.dart';
import '../models/scan_result.dart';
import '../services/camera_storage_service.dart';
import '../services/network_scanner_service.dart';
import '../theme/gta_colors.dart';
import '../widgets/gta_button.dart';
import '../widgets/gta_neon_card.dart';
import '../widgets/radar_pulse.dart';
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
      onDone: () {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _progress = 1.0;
          });
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

  Future<void> _commissionAll() async {
    if (_discoveredCameras.isEmpty) return;

    final storage = context.read<CameraStorageService>();
    int addedCount = 0;

    for (final scan in _discoveredCameras) {
      final dev = CameraDevice(
        id: const Uuid().v4(),
        name: scan.suggestedName,
        ip: scan.ip,
        rtspPort: 554,
        webPort: 80,
        manufacturer: scan.detectedManufacturer,
        username: scan.detectedManufacturer.defaultUser,
        password: '',
        channel: 1,
        subType: 0,
        location: 'Rede Local',
        macAddress: scan.macAddress,
      );
      await storage.addCamera(dev);
      addedCount++;
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
            '$addedCount câmeras comissionadas com sucesso!',
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
  void dispose() {
    _scanSub?.cancel();
    _scanner.cancelScan();
    _subnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RADAR DE VIGILÂNCIA WI-FI'),
        actions: [
          if (_discoveredCameras.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.playlist_add_check_rounded, color: GtaColors.statusOnline),
              label: Text(
                'COMISSIONAR TODAS',
                style: GoogleFonts.orbitron(fontSize: 10, color: GtaColors.statusOnline, fontWeight: FontWeight.bold),
              ),
              onPressed: _commissionAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Subnet control & Scan status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: GtaColors.bgSurface,
              border: Border(bottom: BorderSide(color: GtaColors.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_tethering_rounded, color: GtaColors.electricCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Sub-rede: ',
                        style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      SizedBox(
                        width: 110,
                        height: 36,
                        child: TextField(
                          controller: _subnetController,
                          style: GoogleFonts.robotoMono(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      Text(
                        '.0/24',
                        style: GoogleFonts.robotoMono(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: _isScanning ? GtaColors.statusOffline.withOpacity(0.2) : GtaColors.neonPink.withOpacity(0.2),
                    side: BorderSide(color: _isScanning ? GtaColors.statusOffline : GtaColors.neonPink),
                  ),
                  icon: Icon(
                    _isScanning ? Icons.stop_rounded : Icons.search_rounded,
                    color: _isScanning ? GtaColors.statusOffline : GtaColors.neonPink,
                  ),
                  onPressed: _isScanning ? _stopScan : _startScan,
                ),
              ],
            ),
          ),

          // Radar visualizer and live telemetry
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                RadarPulse(
                  size: 190,
                  isScanning: _isScanning,
                  discoveredDevices: _discoveredCameras,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isScanning ? 'VARRENDO: $_currentIp' : 'VARREDURA CONCLUÍDA',
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isScanning ? GtaColors.electricCyan : GtaColors.statusOnline,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: GoogleFonts.orbitron(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: GtaColors.neonPink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 6,
                          backgroundColor: GtaColors.bgCard,
                          valueColor: const AlwaysStoppedAnimation<Color>(GtaColors.neonPink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Discovered header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CÂMERAS ENCONTRADAS (${_discoveredCameras.length})',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                if (_discoveredCameras.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: GtaColors.statusOnline.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: GtaColors.statusOnline),
                    ),
                    child: Text(
                      'PRONTAS PARA COMISSIONAMENTO',
                      style: GoogleFonts.rajdhani(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: GtaColors.statusOnline,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Discovered camera list
          Expanded(
            child: _discoveredCameras.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          size: 48,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isScanning ? 'Procurando câmeras na rede...' : 'Nenhuma câmera detectada na faixa.',
                          style: GoogleFonts.rajdhani(
                            fontSize: 14,
                            color: Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: _discoveredCameras.length,
                    itemBuilder: (context, index) {
                      final scan = _discoveredCameras[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GtaNeonCard(
                          borderColor: scan.detectedManufacturer.brandColor.withOpacity(0.6),
                          glowColor: scan.detectedManufacturer.brandColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Brand Icon Badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: scan.detectedManufacturer.brandColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: scan.detectedManufacturer.brandColor),
                                    ),
                                    child: const Icon(Icons.videocam_rounded, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              scan.detectedManufacturer.displayName.toUpperCase(),
                                              style: GoogleFonts.orbitron(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: GtaColors.statusOnline.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: GtaColors.statusOnline, width: 0.8),
                                              ),
                                              child: Text(
                                                'ONLINE',
                                                style: GoogleFonts.orbitron(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: GtaColors.statusOnline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'IP: ${scan.ip}  •  Portas: ${scan.openPorts.join(', ')}',
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 12,
                                            color: GtaColors.electricCyan,
                                          ),
                                        ),
                                        Text(
                                          'Detecção: ${scan.detectionSource}',
                                          style: GoogleFonts.rajdhani(
                                            fontSize: 12,
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GtaButton(
                                    height: 38,
                                    label: 'COMISSIONAR',
                                    icon: Icons.add_link_rounded,
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => CommissionScreen(scanResult: scan),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
