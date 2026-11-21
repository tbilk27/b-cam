import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/manufacturer.dart';
import 'package:bcam/models/scan_result.dart';
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

      // Fresh install starts clean with 0 cameras
      expect(storage.cameras.isEmpty, isTrue);

      // Add a camera for testing
      await storage.addCamera(CameraDevice(
        id: 'cam-test-1',
        name: 'Câmera Teste',
        ip: '192.168.3.100',
        isEnabled: true,
      ));

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

  group('Scan Filter Unregistered Tests', () {
    test('filterUnregistered excludes already commissioned cameras by IP and MAC', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = CameraStorageService();
      await storage.loadCameras();

      await storage.addCamera(CameraDevice(
        id: 'cam-74',
        name: 'Portão',
        ip: '192.168.3.74',
        macAddress: '98:2A:0A:89:56:62',
      ));

      final scanResults = <ScanResult>[
        ScanResult(
          ip: '192.168.3.74', // matches IP of cam-74
          openPorts: [554],
          detectedManufacturer: CameraManufacturer.intelbras,
          detectionSource: 'Port 554',
          suggestedName: 'Intelbras Portão',
          suggestedRtspUrl: 'rtsp://192.168.3.74:554/cam/realmonitor',
          confidence: 0.9,
          macAddress: '98:2A:0A:89:56:62',
        ),
        ScanResult(
          ip: '192.168.3.23', // new camera
          openPorts: [554],
          detectedManufacturer: CameraManufacturer.yoosee,
          detectionSource: 'Port 5000',
          suggestedName: 'Yoosee Garagem',
          suggestedRtspUrl: 'rtsp://192.168.3.23:554/onvif1',
          confidence: 0.85,
          macAddress: '98:03:CF:DC:00:0A',
        ),
      ];

      expect(storage.isCameraAlreadyAdded(scanResults[0]), isTrue);
      expect(storage.isCameraAlreadyAdded(scanResults[1]), isFalse);

      final unreg = storage.filterUnregistered(scanResults);
      expect(unreg.length, 1);
      expect(unreg.first.ip, '192.168.3.23');
    });

    test('autoReconcileDevices does not hijack existing online camera IP heuristically', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = CameraStorageService();
      await storage.loadCameras();

      // Commission camera at .23
      await storage.addCamera(CameraDevice(
        id: 'yoosee-23',
        name: 'Yoosee 23',
        ip: '192.168.3.23',
        manufacturer: CameraManufacturer.yoosee,
        macAddress: '98:03:CF:DC:00:0A',
      ));

      // Scan discovers BOTH .23 and a new Yoosee at .24
      final scanResults = <ScanResult>[
        ScanResult(
          ip: '192.168.3.23',
          openPorts: [554],
          detectedManufacturer: CameraManufacturer.yoosee,
          detectionSource: 'Port 5000',
          suggestedName: 'Yoosee 23',
          suggestedRtspUrl: 'rtsp://192.168.3.23:554/onvif1',
          macAddress: '98:03:CF:DC:00:0A',
        ),
        ScanResult(
          ip: '192.168.3.24',
          openPorts: [554],
          detectedManufacturer: CameraManufacturer.yoosee,
          detectionSource: 'Port 5000',
          suggestedName: 'Yoosee 24',
          suggestedRtspUrl: 'rtsp://192.168.3.24:554/onvif1',
          macAddress: '98:03:CF:DB:FD:5A',
        ),
      ];

      await storage.autoReconcileDevices(scanResults);

      // Verify that yoosee-23 kept its IP 192.168.3.23 and was NOT hijacked to .24
      final cam23 = storage.cameras.firstWhere((c) => c.id == 'yoosee-23');
      expect(cam23.ip, '192.168.3.23');
    });

    test('loadCameras self-heals Yoosee password to Compras10@', () async {
      // Setup SharedPreferences with an existing Yoosee camera having lowercase password 'compras10'
      final savedJson = '[{"id":"yoosee-test","name":"Yoosee","ip":"192.168.3.23","rtspPort":554,"manufacturer":"yoosee","username":"admin","password":"compras10"}]';
      SharedPreferences.setMockInitialValues({'bcam_saved_cameras_v2': savedJson});

      final storage = CameraStorageService();
      await storage.loadCameras();

      final cam = storage.cameras.firstWhere((c) => c.ip == '192.168.3.23');
      expect(cam.password, 'Compras10@');
      expect(cam.macAddress, '98:03:CF:DC:00:0A');
    });
  });
}
