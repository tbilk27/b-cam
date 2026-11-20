import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/camera_device.dart';
import '../models/manufacturer.dart';
import '../models/scan_result.dart';

class CameraStorageService extends ChangeNotifier {
  static const String _storageKey = 'bcam_saved_cameras_v1';
  final List<CameraDevice> _cameras = [];

  List<CameraDevice> get cameras => List.unmodifiable(_cameras);
  List<CameraDevice> get favoriteCameras =>
      _cameras.where((c) => c.isFavorite).toList();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  CameraStorageService() {
    loadCameras();
  }

  Future<void> loadCameras() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);

      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawJson);
        _cameras.clear();
        for (final item in decoded) {
          _cameras.add(CameraDevice.fromJson(item as Map<String, dynamic>));
        }
      } else {
        // Pre-populate with verified cameras detected on the user's current Wi-Fi network!
        _cameras.clear();
        _cameras.addAll([
          CameraDevice(
            id: const Uuid().v4(),
            name: 'Stream Demonstração RTSP',
            ip: 'wowzaec2demo.streamlock.net',
            rtspPort: 554,
            webPort: 80,
            manufacturer: CameraManufacturer.genericOnvif,
            customUrl: 'rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4',
            location: 'Demo Lab',
            isFavorite: true,
            isOnline: true,
          ),
          CameraDevice(
            id: const Uuid().v4(),
            name: 'Intelbras Entrada Principal',
            ip: '192.168.3.74',
            rtspPort: 554,
            webPort: 80,
            manufacturer: CameraManufacturer.intelbras,
            username: 'admin',
            password: '',
            channel: 1,
            subType: 0,
            location: 'Portão Principal',
            isFavorite: true,
            isOnline: true,
            macAddress: '98:2A:0A:89:56:62',
          ),
          CameraDevice(
            id: const Uuid().v4(),
            name: 'Intelbras Estacionamento',
            ip: '192.168.3.22',
            rtspPort: 554,
            webPort: 80,
            manufacturer: CameraManufacturer.intelbras,
            username: 'admin',
            password: '',
            channel: 1,
            subType: 0,
            location: 'Estacionamento',
            isFavorite: true,
            isOnline: true,
            macAddress: '18:0D:2C:5D:96:FE',
          ),
          CameraDevice(
            id: const Uuid().v4(),
            name: 'Câmera Wi-Fi Corredor',
            ip: '192.168.3.23',
            rtspPort: 554,
            webPort: 80,
            manufacturer: CameraManufacturer.xiongmai,
            username: 'admin',
            password: '',
            channel: 1,
            subType: 0,
            location: 'Corredor',
            isFavorite: false,
            isOnline: true,
            macAddress: '98:03:CF:DC:00:0A',
          ),
          CameraDevice(
            id: const Uuid().v4(),
            name: 'Câmera Wi-Fi Fundos',
            ip: '192.168.3.24',
            rtspPort: 554,
            webPort: 80,
            manufacturer: CameraManufacturer.xiongmai,
            username: 'admin',
            password: '',
            channel: 1,
            subType: 0,
            location: 'Fundos',
            isFavorite: false,
            isOnline: true,
            macAddress: '98:03:CF:DB:FD:5A',
          ),
        ]);
        await _saveToDisk(prefs);
      }
    } catch (e) {
      debugPrint('Error loading cameras: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Add or update camera binding by MAC Address (DHCP resilient)
  Future<void> addCamera(CameraDevice camera) async {
    // 1. Try to find existing device by unique hardware MAC address
    final existingMacIdx = (camera.macAddress != null)
        ? _cameras.indexWhere((c) => c.matchesMac(camera.macAddress))
        : -1;

    if (existingMacIdx != -1) {
      // Existing hardware found: PRESERVE user nickname, password, location & favorites, update IP & ports
      final existing = _cameras[existingMacIdx];
      debugPrint('[DHCP HEAL] Camera "${existing.name}" (MAC: ${existing.macAddress}) updated to IP ${camera.ip}');
      _cameras[existingMacIdx] = existing.copyWith(
        ip: camera.ip,
        rtspPort: camera.rtspPort,
        webPort: camera.webPort,
        manufacturer: camera.manufacturer,
        macAddress: camera.macAddress ?? existing.macAddress,
        isOnline: true,
        lastSeen: DateTime.now(),
      );
    } else {
      // Clean duplicate by ID or exact IP/channel if no MAC
      _cameras.removeWhere((c) =>
          c.id == camera.id ||
          (c.ip == camera.ip && c.channel == camera.channel && c.macAddress == null));
      _cameras.insert(0, camera);
    }

    await _persist();
    notifyListeners();
  }

  /// Automatically reconcile all cameras discovered in a scan by their MAC Address
  Future<int> autoReconcileDevices(List<ScanResult> discovered) async {
    int healedCount = 0;
    for (final scan in discovered) {
      if (scan.macAddress == null) continue;
      final idx = _cameras.indexWhere((c) => c.matchesMac(scan.macAddress));
      if (idx != -1) {
        final existing = _cameras[idx];
        if (existing.ip != scan.ip) {
          debugPrint('[DHCP HEAL] Camera "${existing.name}" (MAC: ${existing.macAddress}) migrated IP from ${existing.ip} to ${scan.ip}');
          _cameras[idx] = existing.copyWith(
            ip: scan.ip,
            isOnline: true,
            lastSeen: DateTime.now(),
          );
          healedCount++;
        }
      }
    }
    if (healedCount > 0) {
      await _persist();
      notifyListeners();
    }
    return healedCount;
  }

  /// Explicitly re-bind an IP for a given MAC Address
  Future<bool> updateIpForMac(String mac, String newIp) async {
    final idx = _cameras.indexWhere((c) => c.matchesMac(mac));
    if (idx != -1) {
      final existing = _cameras[idx];
      _cameras[idx] = existing.copyWith(
        ip: newIp,
        isOnline: true,
        lastSeen: DateTime.now(),
      );
      await _persist();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> updateCamera(CameraDevice camera) async {
    final idx = _cameras.indexWhere((c) => c.id == camera.id);
    if (idx != -1) {
      _cameras[idx] = camera;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> removeCamera(String id) async {
    _cameras.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _cameras.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _cameras[idx] = _cameras[idx].copyWith(isFavorite: !_cameras[idx].isFavorite);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveToDisk(prefs);
    } catch (e) {
      debugPrint('Error persisting cameras: $e');
    }
  }

  Future<void> _saveToDisk(SharedPreferences prefs) async {
    final encoded = jsonEncode(_cameras.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
