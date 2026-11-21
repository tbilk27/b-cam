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
          var cam = CameraDevice.fromJson(item as Map<String, dynamic>);
          // Filter out false positive Mac computer (192.168.3.62 AirPlay port 5000)
          if (cam.ip == '192.168.3.62' && cam.manufacturer == CameraManufacturer.yoosee) {
            needsSave = true;
            continue;
          }
          // Self-heal known local cameras configured with default or typo passwords and attach MAC
          if (cam.ip == '192.168.3.74' || cam.matchesMac('98:2A:0A:89:56:62')) {
            final isDefaultPass = cam.password == 'admin' || cam.password.isEmpty;
            if (isDefaultPass || cam.macAddress == null || cam.ip != '192.168.3.74') {
              cam = cam.copyWith(
                ip: '192.168.3.74',
                password: isDefaultPass ? 'Zs29364835' : cam.password,
                manufacturer: CameraManufacturer.intelbras,
                macAddress: cam.macAddress ?? '98:2A:0A:89:56:62',
              );
              needsSave = true;
            }
          } else if (cam.ip == '192.168.3.23' || cam.matchesMac('98:03:CF:DC:00:0A')) {
            final isWrongPass = cam.password == 'admin' || cam.password.isEmpty || cam.password.toLowerCase() == 'compras10';
            if (isWrongPass || cam.macAddress == null || cam.ip != '192.168.3.23') {
              cam = cam.copyWith(
                ip: '192.168.3.23',
                password: isWrongPass ? 'Compras10@' : cam.password,
                manufacturer: CameraManufacturer.yoosee,
                macAddress: cam.macAddress ?? '98:03:CF:DC:00:0A',
              );
              needsSave = true;
            }
          } else if (cam.ip == '192.168.3.24' || cam.matchesMac('98:03:CF:DB:FD:5A')) {
            final isWrongPass = cam.password == 'admin' || cam.password.isEmpty || cam.password.toLowerCase() == 'compras10';
            if (isWrongPass || cam.macAddress == null || cam.ip != '192.168.3.24') {
              cam = cam.copyWith(
                ip: '192.168.3.24',
                password: isWrongPass ? 'Compras10@' : cam.password,
                manufacturer: CameraManufacturer.yoosee,
                macAddress: cam.macAddress ?? '98:03:CF:DB:FD:5A',
              );
              needsSave = true;
            }
          } else if (cam.ip == '192.168.3.22' && cam.macAddress == null) {
            cam = cam.copyWith(macAddress: '18:0D:2C:5D:96:FE');
            needsSave = true;
          }

          // Global self-heal for Yoosee cameras with wrong password casing/special char
          if (cam.manufacturer == CameraManufacturer.yoosee && cam.password.toLowerCase() == 'compras10') {
            cam = cam.copyWith(password: 'Compras10@');
            needsSave = true;
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

  /// Reordena as câmeras persistindo a nova ordem definida pelo usuário via arrastar e soltar
  Future<void> reorderCameras(int oldIndex, int newIndex, {List<CameraDevice>? currentList}) async {
    final list = currentList ?? _cameras;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex > list.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final movedCamera = list[oldIndex];
    final realOldIdx = _cameras.indexWhere((c) => c.id == movedCamera.id);
    if (realOldIdx == -1) return;

    _cameras.removeAt(realOldIdx);

    int realNewIdx;
    if (newIndex >= list.length) {
      realNewIdx = _cameras.length;
    } else {
      final targetCamera = list[newIndex];
      realNewIdx = _cameras.indexWhere((c) => c.id == targetCamera.id);
      if (realNewIdx == -1) realNewIdx = _cameras.length;
    }

    _cameras.insert(realNewIdx, movedCamera);
    await _persist();
    notifyListeners();
    DiagnosticLoggerService.instance.logInfo(
      'STORAGE',
      'Ordem das câmeras atualizada pelo usuário via arrastar e soltar ("${movedCamera.name}" de $realOldIdx para $realNewIdx).',
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

  /// Automatically reconcile all cameras discovered in a scan by their MAC Address or heuristic match
  Future<int> autoReconcileDevices(List<ScanResult> discovered) async {
    int healedCount = 0;
    for (final scan in discovered) {
      bool reconciled = false;

      // 1. Reconciliação direta por endereço MAC
      if (scan.macAddress != null) {
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
          reconciled = true;
        } else {
          // Se a câmera tem o mesmo IP mas não tinha MAC registrado, associa o MAC
          final sameIpIdx = _cameras.indexWhere((c) => c.ip == scan.ip);
          if (sameIpIdx != -1 && _cameras[sameIpIdx].macAddress == null) {
            _cameras[sameIpIdx] = _cameras[sameIpIdx].copyWith(macAddress: scan.macAddress);
            healedCount++;
            reconciled = true;
          }
        }
      }

      // 2. Reconciliação heurística: se não reconciliou por MAC e não há câmera no IP descoberto,
      // busca câmera do mesmo fabricante que precise de atualização de IP
      if (!reconciled && !_cameras.any((c) => c.ip == scan.ip)) {
        final matchingCameras = _cameras.where((c) =>
          c.manufacturer == scan.detectedManufacturer ||
          (c.isMibo && scan.detectedManufacturer == CameraManufacturer.intelbrasMibo)
        ).toList();

        if (matchingCameras.length == 1) {
          final target = matchingCameras.first;

          // Proteção crítica: NÃO reatribuir se o IP atual do dispositivo alvo também foi encontrado na varredura
          if (discovered.any((s) => s.ip == target.ip)) {
            continue;
          }

          // Proteção crítica: Se ambos têm MAC address e são diferentes, não reatribuir (são dispositivos físicos distintos)
          if (target.macAddress != null && scan.macAddress != null && !target.matchesMac(scan.macAddress)) {
            continue;
          }

          final targetIdx = _cameras.indexWhere((c) => c.id == target.id);
          if (targetIdx != -1 && target.ip != scan.ip) {
            DiagnosticLoggerService.instance.logInfo(
              'DHCP_RECONCILE',
              'Auto-reconciliação heurística (${scan.detectedManufacturer.displayName}): Câmera "${target.name}" atualizou IP de ${target.ip} para ${scan.ip}',
            );
            _cameras[targetIdx] = target.copyWith(
              ip: scan.ip,
              macAddress: scan.macAddress ?? target.macAddress,
              isOnline: true,
              lastSeen: DateTime.now(),
            );
            healedCount++;
          }
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
