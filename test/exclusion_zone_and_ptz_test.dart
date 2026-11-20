import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/models/bounding_box.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/camera_event.dart';
import 'package:bcam/models/exclusion_zone.dart';
import 'package:bcam/models/manufacturer.dart';
import 'package:bcam/services/camera_action_service.dart';
import 'package:bcam/services/camera_event_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExclusionGrid & BoundingBox Math Tests', () {
    test('Calculates grid cell coordinates correctly for 16x9 grid', () {
      expect(ExclusionGrid.totalCells, equals(144));
      expect(ExclusionGrid.columns, equals(16));
      expect(ExclusionGrid.rows, equals(9));

      // Top-left cell (0, 0)
      final topLeftRect = ExclusionGrid.cellToNormalizedRect(0);
      expect(topLeftRect.left, closeTo(0.0, 0.001));
      expect(topLeftRect.top, closeTo(0.0, 0.001));
      expect(topLeftRect.width, closeTo(1 / 16, 0.001));
      expect(topLeftRect.height, closeTo(1 / 9, 0.001));

      // Coordinate to cell index
      final cell0 = ExclusionGrid.pointToCell(const Offset(0.01, 0.01), const Size(1.0, 1.0));
      expect(cell0, equals(0));

      final centerCell = ExclusionGrid.pointToCell(const Offset(0.5, 0.5), const Size(1.0, 1.0));
      expect(centerCell, isNotNull);
      expect(centerCell, isNot(-1));
    });

    test('BoundingBox overlap detection against exclusion mask', () {
      // Cell 0 is top left: left 0.0..0.0625, top 0.0..0.111
      final mask = [0];

      final boxInside = const BoundingBox(
        left: 0.01,
        top: 0.01,
        width: 0.04,
        height: 0.08,
        label: 'Pessoa',
        confidence: 0.9,
      );

      final boxOutside = const BoundingBox(
        left: 0.5,
        top: 0.5,
        width: 0.2,
        height: 0.2,
        label: 'Pessoa',
        confidence: 0.9,
      );

      expect(ExclusionGrid.isBoxExcluded(boxInside, mask), isTrue);
      expect(ExclusionGrid.isBoxExcluded(boxOutside, mask), isFalse);
    });
  });

  group('CameraDevice Exclusion Zone Integration', () {
    test('Camera correctly identifies bounding boxes inside its exclusion zone', () {
      final cameraWithMask = CameraDevice(
        id: 'cam_excl_1',
        name: 'Cam Quintal',
        ip: '192.168.3.74',
        rtspPort: 554,
        username: 'admin',
        password: 'password',
        channel: 1,
        manufacturer: CameraManufacturer.intelbras,
        location: 'Quintal',
        exclusionMask: [0, 1, 2], // First 3 cells on top row
        exclusionZoneEnabled: true,
      );

      expect(cameraWithMask.hasExclusionZone, isTrue);
      expect(cameraWithMask.exclusionZonePercentage, closeTo((3 / 144) * 100, 0.01));

      // Object in cell 0
      final boxInMask = const BoundingBox(
        left: 0.02,
        top: 0.02,
        width: 0.03,
        height: 0.05,
        label: 'Pessoa',
        confidence: 0.9,
      );
      expect(cameraWithMask.isBoxInExclusionZone(boxInMask), isTrue);

      // Object in cell 100 (bottom right quadrant)
      final boxNotInMask = const BoundingBox(
        left: 0.7,
        top: 0.7,
        width: 0.2,
        height: 0.2,
        label: 'Pessoa',
        confidence: 0.9,
      );
      expect(cameraWithMask.isBoxInExclusionZone(boxNotInMask), isFalse);
    });
  });

  group('CameraEventService Exclusion Zone Discarding', () {
    test('Events falling inside exclusion zone are completely rejected', () {
      final eventService = CameraEventService.instance;
      final initialCount = eventService.events.length;

      final camera = CameraDevice(
        id: 'cam_test_discard',
        name: 'Test Cam Discard',
        ip: '192.168.3.74',
        rtspPort: 554,
        username: 'admin',
        password: 'password',
        channel: 1,
        manufacturer: CameraManufacturer.intelbras,
        location: 'Teste',
        exclusionMask: [0, 1], // Top left cells
        exclusionZoneEnabled: true,
      );

      // Event inside excluded cells
      final eventInside = CameraEvent(
        id: 'evt_inside_1',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.person,
        duration: const Duration(seconds: 15),
        description: 'Detectada em zona desconsiderada',
        timestamp: DateTime.now(),
        confidence: 0.95,
        boundingBoxes: [
          const BoundingBox(
            left: 0.01,
            top: 0.01,
            width: 0.05,
            height: 0.05,
            label: 'Pessoa',
            confidence: 0.95,
          ),
        ],
      );

      final accepted = eventService.registerEvent(eventInside, camera: camera);
      expect(accepted, isFalse);
      expect(eventService.events.length, equals(initialCount));
    });
  });

  group('CameraActionService Hardware Commands', () {
    final camera = CameraDevice(
      id: 'cam_action_unit',
      name: 'Cam Ações Hardware',
      ip: '192.168.3.74',
      rtspPort: 554,
      username: 'admin',
      password: 'password',
      channel: 1,
      manufacturer: CameraManufacturer.intelbras,
      location: 'Garagem',
    );

    test('Toggles siren on and off', () async {
      final service = CameraActionService.instance;
      expect(service.isSirenActive(camera.id), isFalse);

      final active1 = await service.toggleSiren(camera);
      expect(active1, isTrue);
      expect(service.isSirenActive(camera.id), isTrue);

      final active2 = await service.toggleSiren(camera);
      expect(active2, isFalse);
      expect(service.isSirenActive(camera.id), isFalse);
    });

    test('Toggles spotlight on and off', () async {
      final service = CameraActionService.instance;
      expect(service.isSpotlightActive(camera.id), isFalse);

      final active1 = await service.toggleSpotlight(camera);
      expect(active1, isTrue);
      expect(service.isSpotlightActive(camera.id), isTrue);

      final active2 = await service.toggleSpotlight(camera);
      expect(active2, isFalse);
      expect(service.isSpotlightActive(camera.id), isFalse);
    });

    test('Changes night vision modes', () async {
      final service = CameraActionService.instance;
      expect(service.getNightVisionMode(camera.id), equals(NightVisionMode.auto));

      await service.setNightVisionMode(camera, NightVisionMode.color);
      expect(service.getNightVisionMode(camera.id), equals(NightVisionMode.color));

      await service.setNightVisionMode(camera, NightVisionMode.ir);
      expect(service.getNightVisionMode(camera.id), equals(NightVisionMode.ir));

      await service.setNightVisionMode(camera, NightVisionMode.off);
      expect(service.getNightVisionMode(camera.id), equals(NightVisionMode.off));
    });

    test('Controls two-way audio talk and listen', () {
      final service = CameraActionService.instance;
      expect(service.isTalking(camera.id), isFalse);

      service.startTalking(camera);
      expect(service.isTalking(camera.id), isTrue);

      service.stopTalking(camera);
      expect(service.isTalking(camera.id), isFalse);

      final listening1 = service.toggleListening(camera);
      expect(listening1, isFalse);
      expect(service.isListening(camera.id), isFalse);

      final listening2 = service.toggleListening(camera);
      expect(listening2, isTrue);
      expect(service.isListening(camera.id), isTrue);
    });
  });
}
