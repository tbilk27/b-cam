import 'manufacturer.dart';

class ScanResult {
  final String ip;
  final String? macAddress;
  final List<int> openPorts;
  final CameraManufacturer detectedManufacturer;
  final double confidence;
  final String detectionSource;
  final String? banner;
  final String suggestedName;
  final String suggestedRtspUrl;
  final DateTime discoveredAt;

  ScanResult({
    required this.ip,
    this.macAddress,
    required this.openPorts,
    required this.detectedManufacturer,
    this.confidence = 0.8,
    required this.detectionSource,
    this.banner,
    required this.suggestedName,
    required this.suggestedRtspUrl,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  bool get hasRtsp => openPorts.contains(554) || openPorts.contains(8554);
  bool get hasWeb => openPorts.contains(80) || openPorts.contains(8080) || openPorts.contains(443);
  bool get hasIntelbrasDahua => openPorts.contains(37777);
  bool get hasHikvision => openPorts.contains(8000);
  bool get hasXm => openPorts.contains(34567);
}
