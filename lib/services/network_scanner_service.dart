import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/manufacturer.dart';
import '../models/scan_result.dart';

class NetworkScannerService {
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Ports commonly opened on IP surveillance cameras & NVRs
  static const List<int> cameraPorts = [
    554,   // RTSP standard
    8554,  // RTSP alternate
    37777, // Intelbras / Dahua control port
    8000,  // Hikvision SDK / control port
    34567, // Xiongmai (XM) / Sofia port
    80,    // Web GUI / ONVIF HTTP
    8080,  // Web GUI alt
    8899,  // ONVIF service port
    9000,  // Reolink control port
    2020,  // Tapo control port
  ];

  /// Get local subnet prefix (e.g. "192.168.3")
  Future<String> getLocalSubnetPrefix() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          // Ignore link-local
          if (ip.startsWith('169.254.')) continue;
          
          // Android emulator typically uses 10.0.2.15, but host cameras are on 192.168.3.x
          // If in emulator, prefer 192.168.3 if reachable or default
          if (ip.startsWith('10.0.2.')) {
            return '192.168.3';
          }

          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding network interface: $e');
    }
    // Default fallback to user verified subnet
    return '192.168.3';
  }

  /// Sweep subnet looking for camera devices
  Stream<ScanProgress> scanSubnet({
    String? subnetPrefix,
    int startHost = 1,
    int endHost = 254,
    Duration portTimeout = const Duration(milliseconds: 500),
  }) async* {
    _isScanning = true;
    final prefix = subnetPrefix ?? await getLocalSubnetPrefix();
    final List<ScanResult> discovered = [];

    // Trigger ONVIF probe in parallel
    _sendOnvifWsDiscovery(prefix);

    final totalHosts = (endHost - startHost + 1);
    int scannedCount = 0;

    // Scan in chunks of 32 concurrent hosts to prevent socket exhaustion
    const chunkSize = 32;
    for (int i = startHost; i <= endHost; i += chunkSize) {
      if (!_isScanning) break;

      final chunkEnd = (i + chunkSize - 1) > endHost ? endHost : (i + chunkSize - 1);
      final futures = <Future<ScanResult?>>[];

      for (int h = i; h <= chunkEnd; h++) {
        final targetIp = '$prefix.$h';
        futures.add(_scanHost(targetIp, portTimeout));
      }

      final results = await Future.wait(futures);
      scannedCount += (chunkEnd - i + 1);

      for (final res in results) {
        if (res != null) {
          discovered.add(res);
        }
      }

      yield ScanProgress(
        progress: scannedCount / totalHosts,
        currentIp: '$prefix.$chunkEnd',
        totalScanned: scannedCount,
        totalToScan: totalHosts,
        foundCameras: List.unmodifiable(discovered),
        isDone: scannedCount >= totalHosts,
      );
    }

    _isScanning = false;
    yield ScanProgress(
      progress: 1.0,
      currentIp: '$prefix.$endHost',
      totalScanned: totalHosts,
      totalToScan: totalHosts,
      foundCameras: List.unmodifiable(discovered),
      isDone: true,
    );
  }

  /// Stop ongoing scan
  void cancelScan() {
    _isScanning = false;
  }

  /// Scan an individual host on candidate ports
  Future<ScanResult?> _scanHost(String ip, Duration timeout) async {
    final openPorts = <int>[];

    // Check high-priority camera ports first
    for (final port in cameraPorts) {
      try {
        final socket = await Socket.connect(ip, port, timeout: timeout);
        socket.destroy();
        openPorts.add(port);
      } catch (_) {
        // Closed or filtered
      }
    }

    // If no typical camera port is open, this is not a camera
    if (openPorts.isEmpty) return null;

    // Any device with RTSP (554), Dahua/Intelbras (37777), Hikvision (8000), XM (34567)
    final isCameraCandidate = openPorts.contains(554) ||
        openPorts.contains(8554) ||
        openPorts.contains(37777) ||
        openPorts.contains(8000) ||
        openPorts.contains(34567) ||
        openPorts.contains(9000) ||
        openPorts.contains(2020);

    if (!isCameraCandidate) {
      // If only port 80 is open, it might just be a router or printer
      return null;
    }

    // Heuristic manufacturer identification
    CameraManufacturer manufacturer = CameraManufacturer.genericOnvif;
    String detectionSource = 'Porta RTSP 554 Aberta';
    double confidence = 0.75;
    String? banner;

    if (openPorts.contains(37777)) {
      manufacturer = CameraManufacturer.intelbras;
      detectionSource = 'Porta Dahua/Intelbras 37777';
      confidence = 0.95;
    } else if (openPorts.contains(8000)) {
      manufacturer = CameraManufacturer.hikvision;
      detectionSource = 'Porta Hikvision SDK 8000';
      confidence = 0.95;
    } else if (openPorts.contains(34567)) {
      manufacturer = CameraManufacturer.xiongmai;
      detectionSource = 'Porta Xiongmai/XM 34567';
      confidence = 0.90;
    } else if (openPorts.contains(2020)) {
      manufacturer = CameraManufacturer.tapo;
      detectionSource = 'Porta Tapo 2020';
      confidence = 0.90;
    } else if (openPorts.contains(9000)) {
      manufacturer = CameraManufacturer.reolink;
      detectionSource = 'Porta Reolink 9000';
      confidence = 0.85;
    } else {
      // Try fast RTSP OPTIONS query to inspect server banner
      try {
        final socket = await Socket.connect(ip, 554, timeout: const Duration(milliseconds: 600));
        socket.write('OPTIONS rtsp://$ip:554/ RTSP/1.0\r\nCSeq: 1\r\nUser-Agent: b-cam/1.0\r\n\r\n');
        final data = await socket.first.timeout(const Duration(milliseconds: 600));
        final response = utf8.decode(data, allowMalformed: true);
        socket.destroy();

        banner = response;
        if (response.contains('180d2c') || response.contains('Dahua') || response.contains('Intelbras')) {
          manufacturer = CameraManufacturer.intelbras;
          detectionSource = 'Intelbras RTSP Auth Realm';
          confidence = 0.98;
        } else if (response.contains('Hikvision') || response.contains('DS-')) {
          manufacturer = CameraManufacturer.hikvision;
          detectionSource = 'Hikvision RTSP Banner';
          confidence = 0.95;
        } else if (response.contains('USER_CMD_SET')) {
          manufacturer = CameraManufacturer.xiongmai;
          detectionSource = 'Xiongmai RTSP Extended Cmds';
          confidence = 0.90;
        }
      } catch (_) {}
    }

    // Default suggested name
    final brandName = manufacturer.displayName.split(' ').first;
    final suggestedName = '$brandName Cam (${ip.split('.').last})';
    final suggestedUrl = manufacturer.buildRtspUrl(ip: ip, port: 554);

    return ScanResult(
      ip: ip,
      openPorts: openPorts,
      detectedManufacturer: manufacturer,
      confidence: confidence,
      detectionSource: detectionSource,
      banner: banner,
      suggestedName: suggestedName,
      suggestedRtspUrl: suggestedUrl,
    );
  }

  /// Fire UDP WS-Discovery broadcast in background
  void _sendOnvifWsDiscovery(String prefix) async {
    try {
      final rawSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      rawSocket.broadcastEnabled = true;

      const uuid = 'urn:uuid:bcam-scanner-probe';
      const probeMessage =
          '<?xml version="1.0" encoding="utf-8"?>'
          '<Envelope xmlns="http://www.w3.org/2003/05/soap-envelope" '
          'xmlns:tds="http://www.onvif.org/ver10/device/wsdl">'
          '<Header>'
          '<wsa:MessageID xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing">$uuid</wsa:MessageID>'
          '<wsa:To xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing">urn:schemas-xmlsoap-org:ws:2005:04:discovery</wsa:To>'
          '<wsa:Action xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing">http://schemas.xmlsoap.org/ws/2005:04:discovery/Probe</wsa:Action>'
          '</Header>'
          '<Body><Probe xmlns="http://schemas.xmlsoap.org/ws/2005/04/discovery"><Types>tds:Device</Types></Probe></Body>'
          '</Envelope>';

      final bytes = utf8.encode(probeMessage);
      // Multicast address for WS-Discovery
      rawSocket.send(bytes, InternetAddress('239.255.255.250'), 3702);
      // Also broadcast to subnet
      rawSocket.send(bytes, InternetAddress('$prefix.255'), 3702);

      Future.delayed(const Duration(seconds: 3), () {
        rawSocket.close();
      });
    } catch (_) {}
  }
}

class ScanProgress {
  final double progress;
  final String currentIp;
  final int totalScanned;
  final int totalToScan;
  final List<ScanResult> foundCameras;
  final bool isDone;

  const ScanProgress({
    required this.progress,
    required this.currentIp,
    required this.totalScanned,
    required this.totalToScan,
    required this.foundCameras,
    required this.isDone,
  });
}
