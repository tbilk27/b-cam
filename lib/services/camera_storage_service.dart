import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/camera_device.dart';
import '../models/manufacturer.dart';
import '../models/scan_result.dart';
import 'diagnostic_logger_service.dart';

class CameraStorageService extends ChangeNotifier {
  static const String _storageKey = 'bcam_saved_cameras_v2';
  final List<CameraDevice> _cameras = [];

  List<CameraDevice> get cameras => List.unmodifiable(_cameras);
  List<CameraDevice> get favoriteCameras =>
      _cameras.where((c) => c.isFavorite).toList();
  List<CameraDevice> get enabledCameras =>
      _cameras.where((c) => c.isEnabled).toList();
  List<CameraDevice> get disabledCameras =>
      _cameras.where((c) => !c.isEnabled).toList();

  /// Verifica se um dispositivo identificado na varredura já está cadastrado/comissionado
  bool isCameraAlreadyAdded(ScanResult scan) {
    return _cameras.any((c) {
      if (scan.macAddress != null && c.macAddress != null) {
        if (c.matchesMac(scan.macAddress)) return true;
      }
      return c.ip == scan.ip;
    });
  }

  /// Filtra uma lista de varredura, retornando apenas as câmeras ainda não cadastradas
  List<ScanResult> filterUnregistered(List<ScanResult> scanResults) {
    return scanResults.where((s) => !isCameraAlreadyAdded(s)).toList();
  }

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
        bool needsSave = false;
        for (final item in decoded) {
          final cam = CameraDevice.fromJson(item as Map<String, dynamic>);
          // Filter out false positive Mac computer (192.168.3.62 AirPlay port 5000)
          if (cam.ip == '192.168.3.62' && cam.manufacturer == CameraManufacturer.yoosee) {
            needsSave = true;
            continue;
          }
          // Self-heal known local cameras configured with default 'admin' password
          if (cam.ip == '192.168.3.74' && (cam.password == 'admin' || cam.password.isEmpty)) {
            _cameras.add(cam.copyWith(
              password: 'Zs29364835',
              manufacturer: CameraManufacturer.intelbras,
            ));
            needsSave = true;
            continue;
          }
          if (cam.ip == '192.168.3.23' && (cam.password == 'admin' || cam.password.isEmpty)) {
            _cameras.add(cam.copyWith(
              password: 'Compras10@',
              manufacturer: CameraManufacturer.yoosee,
            ));
            needsSave = true;
            continue;
          }
          if (cam.ip == '192.168.3.24' && (cam.password == 'admin' || cam.password.isEmpty)) {
            _cameras.add(cam.copyWith(
              password: 'Compras10@',
              manufacturer: CameraManufacturer.yoosee,
            ));
            needsSave = true;
            continue;
          }
          _cameras.add(cam);
        }
        if (needsSave) {
          await _saveToDisk(prefs);
        }
        DiagnosticLoggerService.instance.logInfo(
          'STORAGE',
          '${_cameras.length} câmeras comissionadas carregadas do armazenamento persistente.',
        );
      } else {
        // Fresh install / clean app: start completely empty so user commissions their own cameras
        _cameras.clear();
        await _saveToDisk(prefs);
        DiagnosticLoggerService.instance.logInfo(
          'STORAGE',
          'Instalação limpa inicializada: zero câmeras pré-configuradas. Aguardando cadastro do usuário.',
        );
      }
    } catch (e) {
      debugPrint('Error loading cameras: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Remove todas as câmeras cadastradas e zera o armazenamento
  Future<void> clearAllCameras() async {
    _cameras.clear();
    final prefs = await SharedPreferences.getInstance();
    await _saveToDisk(prefs);
    notifyListeners();
    DiagnosticLoggerService.instance.logInfo(
      'STORAGE',
      'Todas as câmeras foram removidas do dispositivo.',
    );
  }

  /// Associa câmeras selecionadas (ou todas) à conta Google do usuário
  Future<void> associateCamerasToUser(String email, {List<String>? cameraIds}) async {
    bool changed = false;
    for (int i = 0; i < _cameras.length; i++) {
      if (cameraIds == null || cameraIds.contains(_cameras[i].id)) {
        _cameras[i] = _cameras[i].copyWith(ownerEmail: email);
        changed = true;
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
      DiagnosticLoggerService.instance.logInfo(
        'STORAGE',
        'Câmeras associadas à conta Google: $email',
      );
    }
  }

  /// Retorna as câmeras associadas ao e-mail do usuário logado
  List<CameraDevice> getCamerasForUser(String email) {
    return _cameras.where((c) => c.ownerEmail == null || c.ownerEmail == email).toList();
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
          DiagnosticLoggerService.instance.logInfo(
            'DHCP_RECONCILE',
            'Câmera "${existing.name}" (MAC: ${existing.macAddress}) atualizou IP de ${existing.ip} para ${scan.ip}',
          );
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

  /// Records when a camera was opened by the user, storing timestamp and optional snapshot path
  Future<void> recordCameraAccess(String cameraId, {String? snapshotPath}) async {
    final idx = _cameras.indexWhere((c) => c.id == cameraId);
    if (idx != -1) {
      final cam = _cameras[idx];
      _cameras[idx] = cam.copyWith(
        lastAccessed: DateTime.now(),
        lastSnapshotPath: snapshotPath ?? cam.lastSnapshotPath,
        lastSeen: DateTime.now(),
        isOnline: true,
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> removeCamera(String id) async {
    _cameras.removeWhere((c) => c.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _cameras.clear();
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

  Future<void> toggleCameraEnabled(String id) async {
    final idx = _cameras.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final newStatus = !_cameras[idx].isEnabled;
      _cameras[idx] = _cameras[idx].copyWith(isEnabled: newStatus);
      DiagnosticLoggerService.instance.logInfo(
        'STORAGE',
        newStatus
            ? 'Câmera "${_cameras[idx].name}" ativada. Reconexão e fluxo restaurados.'
            : 'Câmera "${_cameras[idx].name}" desativada pelo usuário. Retentativas de conexão suspensas.',
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> setCameraEnabled(String id, bool enabled) async {
    final idx = _cameras.indexWhere((c) => c.id == id);
    if (idx != -1 && _cameras[idx].isEnabled != enabled) {
      _cameras[idx] = _cameras[idx].copyWith(isEnabled: enabled);
      DiagnosticLoggerService.instance.logInfo(
        'STORAGE',
        enabled
            ? 'Câmera "${_cameras[idx].name}" ativada. Reconexão e fluxo restaurados.'
            : 'Câmera "${_cameras[idx].name}" desativada. Retentativas de conexão suspensas.',
      );
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
