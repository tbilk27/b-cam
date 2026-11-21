import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/camera_event.dart';
import 'package:bcam/models/manufacturer.dart';
import 'package:bcam/services/camera_event_service.dart';

void main() {
  group('CameraEvent and CameraEventService Tests', () {
    test('CameraEvent model formats timestamps and durations properly', () {
      final now = DateTime(2026, 11, 20, 16, 42, 10);
      final event = CameraEvent(
        id: 'evt-test-1',
        cameraId: 'cam-intelbras-frente-74',
        cameraName: 'Intelbras Frente da Casa',
        type: CameraEventType.person,
        timestamp: now,
        duration: const Duration(seconds: 45),
        description: 'Pessoa detectada na calçada.',
        confidence: 0.95,
      );

      expect(event.timeFormatted, '16:42:10');
      expect(event.dateFormatted, '20/11');
      expect(event.durationFormatted, '45s');
      expect(event.confidence, 0.95);
      expect(event.type.label, 'Pessoa Detectada');
    });

    test('CameraEventService retrieves events for a given camera', () {
      final service = CameraEventService.instance;
      final cam74 = CameraDevice(
        id: 'cam-intelbras-frente-74',
        name: 'Intelbras Frente da Casa',
        ip: '192.168.3.74',
        manufacturer: CameraManufacturer.intelbras,
        username: 'admin',
        location: 'Frente / Portão',
      );

      service.registerEvent(
        CameraEvent(
          id: 'evt-test-101',
          cameraId: cam74.id,
          cameraName: cam74.name,
          type: CameraEventType.person,
          timestamp: DateTime.now(),
          duration: const Duration(seconds: 40),
          description: 'Pessoa detectada',
          confidence: 0.95,
        ),
        camera: cam74,
      );

      final events = service.getEventsForCamera(cam74);
      expect(events.isNotEmpty, true);
      expect(events.any((e) => e.type == CameraEventType.person), true);
    });

    test('CameraEventService returns clean empty timeline for unseeded cameras when autoGenerate is disabled', () {
      final service = CameraEventService.instance;
      final camNew = CameraDevice(
        id: 'cam-unseeded-99',
        name: 'Câmera Nova Teste',
        ip: '192.168.3.99',
        manufacturer: CameraManufacturer.genericOnvif,
        username: 'admin',
        location: 'Garagem',
      );

      final events = service.getEventsForCamera(camNew, autoGenerateIfEmpty: false);
      expect(events.isEmpty, true);
    });

    test('CameraEventService provisions recorded events for camera when requested', () {
      final service = CameraEventService.instance;
      final camNew = CameraDevice(
        id: 'cam-auto-88',
        name: 'Câmera Frente Teste',
        ip: '192.168.3.88',
        manufacturer: CameraManufacturer.intelbras,
        username: 'admin',
        location: 'Frente',
      );

      final events = service.getEventsForCamera(camNew, autoGenerateIfEmpty: true);
      expect(events.isNotEmpty, true);
      expect(events.length, greaterThanOrEqualTo(4));
    });

    test('CameraEventService registers manual and AI snapshot evidence events properly', () {
      final service = CameraEventService.instance;
      final cam = CameraDevice(
        id: 'cam-manual-rec',
        name: 'Área Gourmet',
        ip: '192.168.3.24',
        manufacturer: CameraManufacturer.yoosee,
        username: 'admin',
        location: 'Gourmet',
        aiDetectionEnabled: false, // AI disabled, but manual recording must still register
      );

      final recEvent = CameraEvent(
        id: 'rec-test-1',
        cameraId: cam.id,
        cameraName: cam.name,
        type: CameraEventType.recording,
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 15),
        description: 'Gravação manual de teste arquivada localmente.',
        clipUrl: '/data/user/0/com.nexeoo.bcam/app_flutter/snapshots/snap_test.jpg',
        confidence: 1.0,
      );

      final accepted = service.registerEvent(recEvent, camera: cam, forceAccept: true);
      expect(accepted, isTrue);

      final camEvents = service.getEventsForCamera(cam);
      expect(camEvents.any((e) => e.id == 'rec-test-1'), isTrue);
      expect(camEvents.firstWhere((e) => e.id == 'rec-test-1').clipUrl, contains('snap_test.jpg'));
    });
  });
}
