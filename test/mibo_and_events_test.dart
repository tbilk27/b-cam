import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/camera_event.dart';
import 'package:bcam/models/manufacturer.dart';
import 'package:bcam/services/camera_event_service.dart';
import 'package:bcam/services/camera_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Intelbras Mibo & Credentials Tests', () {
    test('isMibo correctly identifies Intelbras Mibo iM and iC cameras', () {
      final miboIm = CameraDevice(
        id: 'cam-mibo-1',
        name: 'Mibo iM3',
        ip: '192.168.3.22',
        manufacturer: CameraManufacturer.intelbrasMibo,
      );
      final miboIc = CameraDevice(
        id: 'cam-mibo-2',
        name: 'Mibo iC5',
        ip: '192.168.3.25',
        manufacturer: CameraManufacturer.intelbrasIC,
      );
      final dahua = CameraDevice(
        id: 'cam-dahua',
        name: 'Dahua',
        ip: '192.168.3.74',
        manufacturer: CameraManufacturer.dahua,
      );

      expect(miboIm.isMibo, isTrue);
      expect(miboIc.isMibo, isTrue);
      expect(dahua.isMibo, isFalse);
    });

    test('Mibo RTSP endpoints match technical matrix for iM and iC', () {
      final miboIm = CameraDevice(
        id: 'cam-im',
        name: 'iM4',
        ip: '192.168.3.22',
        manufacturer: CameraManufacturer.intelbrasMibo,
        username: 'admin',
        password: 'TESTCODE',
      );
      final miboIc = CameraDevice(
        id: 'cam-ic',
        name: 'iC3',
        ip: '192.168.3.25',
        manufacturer: CameraManufacturer.intelbrasIC,
        username: 'admin',
        password: 'TESTCODE',
      );

      expect(miboIm.streamUrl, contains('/cam/realmonitor?channel=1&subtype=0'));
      expect(miboIc.streamUrl, contains('/h264/ch1/main/av_stream'));
    });
  });

  group('Camera Events & Decoupling Tests', () {
    test('Different cameras receive unique, uncorrelated event schedules', () {
      final cam1 = CameraDevice(
        id: 'cam-101',
        name: 'Portão',
        ip: '192.168.3.10',
        manufacturer: CameraManufacturer.intelbrasMibo,
      );
      final cam2 = CameraDevice(
        id: 'cam-202',
        name: 'Fundos',
        ip: '192.168.3.20',
        manufacturer: CameraManufacturer.yoosee,
      );

      final service = CameraEventService.instance;
      final events1 = service.getEventsForCamera(cam1, autoGenerateIfEmpty: true);
      final events2 = service.getEventsForCamera(cam2, autoGenerateIfEmpty: true);

      expect(events1, isNotEmpty);
      expect(events2, isNotEmpty);

      // Timestamps must not be identical across cameras
      final times1 = events1.map((e) => e.timestamp.minute).toList();
      final times2 = events2.map((e) => e.timestamp.minute).toList();
      expect(times1, isNot(equals(times2)));

      // Event videos must have bounding boxes for outlines
      final motionEvent1 = events1.firstWhere((e) => e.type == CameraEventType.motion);
      expect(motionEvent1.boundingBoxes, isNotEmpty);
      expect(motionEvent1.boundingBoxes.first.label, contains('Movimento'));
    });

    test('playbackUrlForEvent never falls back to live streamUrl', () {
      final cam = CameraDevice(
        id: 'cam-303',
        name: 'Garagem',
        ip: '192.168.3.30',
        manufacturer: CameraManufacturer.intelbras,
      );
      final event = CameraEvent(
        id: 'evt-test-1',
        cameraId: cam.id,
        cameraName: cam.name,
        type: CameraEventType.motion,
        timestamp: DateTime(2026, 11, 21, 10, 0),
        duration: const Duration(seconds: 30),
        description: 'Test',
      );

      final pbUrl = cam.playbackUrlForEvent(event);
      expect(pbUrl, isNot(equals(cam.streamUrl)));
      expect(pbUrl, contains('playback'));
    });

    test('getEventsForCamera returns empty list by default if camera has no events', () {
      final camEmpty = CameraDevice(
        id: 'cam-empty-area-festas',
        name: 'Área de Festas',
        ip: '192.168.3.24',
        manufacturer: CameraManufacturer.yoosee,
      );

      final service = CameraEventService.instance;
      final events = service.getEventsForCamera(camEmpty);
      expect(events, isEmpty);
    });

    test('Yoosee playbackUrlForEvent returns null without recorded clip (never plays live feed)', () {
      final camYoosee = CameraDevice(
        id: 'cam-yoosee-test',
        name: 'Área de Festas',
        ip: '192.168.3.24',
        manufacturer: CameraManufacturer.yoosee,
      );
      final event = CameraEvent(
        id: 'evt-test-yoosee',
        cameraId: camYoosee.id,
        cameraName: camYoosee.name,
        type: CameraEventType.motion,
        timestamp: DateTime(2026, 11, 21, 8, 27),
        duration: const Duration(seconds: 45),
        description: 'Movimento detectado',
      );

      final pbUrl = camYoosee.playbackUrlForEvent(event);
      expect(pbUrl, isNull, reason: 'Câmeras sem RTSP VCR não devem retornar streamUrl como playback');
    });

    test('ensureEventsForCamera does not inject synthetic initial events', () async {
      final camEmpty = CameraDevice(
        id: 'cam-empty-no-init',
        name: 'Portão Lateral',
        ip: '192.168.3.99',
        manufacturer: CameraManufacturer.genericOnvif,
      );

      final service = CameraEventService.instance;
      await service.ensureEventsForCamera(camEmpty);
      final events = service.getEventsForCamera(camEmpty);
      expect(events, isEmpty);
    });
  });

  group('Cloud Relay & Outside Network Routing Tests', () {
    test('CameraDevice resolves Cloud Relay URL when forced or in remote mode', () {
      final cam = CameraDevice(
        id: 'cam-cloud-1',
        name: 'Área de Festas',
        ip: '192.168.3.24',
        manufacturer: CameraManufacturer.yoosee,
      );

      final localUrl = cam.getEffectiveStreamUrl(forceCloud: false);
      final cloudUrl = cam.getEffectiveStreamUrl(forceCloud: true);

      expect(localUrl, contains('192.168.3.24'));
      expect(cloudUrl, contains('cloud.bilkcam.web.app'));
      expect(cloudUrl, contains('8554'));
    });
  });

  group('Drag and Drop Camera Reordering Tests', () {
    test('reorderCameras moves camera up and down and updates persisted list', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = CameraStorageService();
      await storage.loadCameras();

      final c1 = CameraDevice(id: 'c1', name: 'Camera 1', ip: '192.168.3.1');
      final c2 = CameraDevice(id: 'c2', name: 'Camera 2', ip: '192.168.3.2');
      final c3 = CameraDevice(id: 'c3', name: 'Camera 3', ip: '192.168.3.3');

      await storage.addCamera(c3);
      await storage.addCamera(c2);
      await storage.addCamera(c1);

      // Current order: c1, c2, c3
      expect(storage.cameras[0].id, 'c1');
      expect(storage.cameras[1].id, 'c2');
      expect(storage.cameras[2].id, 'c3');

      // Drag c3 to top (index 2 to index 0)
      await storage.reorderCameras(2, 0);
      expect(storage.cameras[0].id, 'c3');
      expect(storage.cameras[1].id, 'c1');
      expect(storage.cameras[2].id, 'c2');

      // Drag c3 down (index 0 to index 2)
      await storage.reorderCameras(0, 2);
      expect(storage.cameras[0].id, 'c1');
      expect(storage.cameras[1].id, 'c3');
      expect(storage.cameras[2].id, 'c2');
    });
  });
}
