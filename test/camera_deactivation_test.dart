import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/manufacturer.dart';
import 'package:bcam/services/camera_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Deactivation & Suspension Tests', () {
    test('CameraDevice default isEnabled is true', () {
      final cam = CameraDevice(
        id: 'cam-1',
        name: 'Cam 1',
        ip: '192.168.3.22',
        manufacturer: CameraManufacturer.intelbrasIC,
      );

      expect(cam.isEnabled, isTrue);
    });

    test('CameraDevice json serialization preserves isEnabled state', () {
      final camDisabled = CameraDevice(
        id: 'cam-mibo-22',
        name: 'Intelbras iC5',
        ip: '192.168.3.22',
        isEnabled: false,
        manufacturer: CameraManufacturer.intelbrasIC,
      );

      final json = camDisabled.toJson();
      expect(json['isEnabled'], isFalse);

      final restored = CameraDevice.fromJson(json);
      expect(restored.isEnabled, isFalse);
      expect(restored.name, 'Intelbras iC5');
      expect(restored.ip, '192.168.3.22');
    });

    test('CameraDevice copyWith toggles isEnabled cleanly', () {
      final cam = CameraDevice(
        id: 'cam-yoosee-23',
        name: 'Yoosee Corredor',
        ip: '192.168.3.23',
        isEnabled: true,
      );

      final disabled = cam.copyWith(isEnabled: false);
      expect(disabled.isEnabled, isFalse);
      expect(disabled.id, cam.id);
      expect(disabled.ip, cam.ip);

      final reEnabled = disabled.copyWith(isEnabled: true);
      expect(reEnabled.isEnabled, isTrue);
    });

    test('CameraStorageService toggles and manages disabled cameras', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = CameraStorageService();
      await storage.loadCameras();

      // Ensure initial state
      expect(storage.cameras.isNotEmpty, isTrue);
      final initialCount = storage.cameras.length;
      final targetCam = storage.cameras.first;

      // Deactivate camera
      await storage.setCameraEnabled(targetCam.id, false);
      expect(storage.disabledCameras.length, 1);
      expect(storage.disabledCameras.first.id, targetCam.id);
      expect(storage.enabledCameras.length, initialCount - 1);

      // Toggle back to active
      await storage.toggleCameraEnabled(targetCam.id);
      expect(storage.disabledCameras.isEmpty, isTrue);
      expect(storage.enabledCameras.length, initialCount);
      expect(storage.cameras.firstWhere((c) => c.id == targetCam.id).isEnabled, isTrue);
    });
  });
}
