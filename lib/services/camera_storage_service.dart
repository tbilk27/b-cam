import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/camera_device.dart';
import '../models/manufacturer.dart';

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

  Future<void> addCamera(CameraDevice camera) async {
    _cameras.removeWhere((c) => c.id == camera.id || (c.ip == camera.ip && c.channel == camera.channel));
    _cameras.insert(0, camera);
    await _persist();
    notifyListeners();
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
