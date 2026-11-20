import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/models/bounding_box.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/camera_event.dart';
import 'package:bcam/services/camera_event_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Vision & Bounding Boxes Tests', () {
    test('BoundingBox correctly maps normalized coordinates to canvas Rect', () {
      const box = BoundingBox(
        label: 'Pessoa',
        confidence: 0.95,
        left: 0.2,
        top: 0.3,
        width: 0.4,
        height: 0.5,
      );

      final rect = box.toRect(const Size(1000, 500));
      expect(rect.left, 200.0);
      expect(rect.top, 150.0);
      expect(rect.width, 400.0);
      expect(rect.height, 250.0);
    });

    test('BoundingBox resolves correct theme colors based on object class', () {
      const personBox = BoundingBox(label: 'Pessoa', confidence: 0.9, left: 0, top: 0, width: 0, height: 0);
      const carBox = BoundingBox(label: 'Veículo Detectado', confidence: 0.9, left: 0, top: 0, width: 0, height: 0);
      const motionBox = BoundingBox(label: 'Movimento Suspeito', confidence: 0.9, left: 0, top: 0, width: 0, height: 0);

      expect(personBox.displayColor.toARGB32(), 0xFF0078D4);
      expect(carBox.displayColor.toARGB32(), 0xFFFFB900);
      expect(motionBox.displayColor.toARGB32(), 0xFF00CC6A);
    });

    test('Confidence Threshold Rule: Rejects events below camera minConfidence', () {
      final camera = CameraDevice(
        id: 'cam-test-thresh',
        name: 'Câmera Teste Limiar',
        ip: '192.168.3.99',
        aiDetectionEnabled: true,
        aiMinConfidence: 0.25, // 25% threshold
      );

      final lowConfidenceEvent = CameraEvent(
        id: 'evt-low-1',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.person,
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 10),
        description: 'Detecção com baixa certeza (possível sombra)',
        confidence: 0.18, // 18% < 25%
      );

      final result = CameraEventService.instance.registerEvent(lowConfidenceEvent, camera: camera);
      expect(result, isFalse, reason: 'Eventos abaixo de 25% de certeza devem ser descartados');
      expect(CameraEventService.instance.getEventById('evt-low-1'), isNull);
    });

    test('Confidence Threshold Rule: Accepts events at or above camera minConfidence', () {
      final camera = CameraDevice(
        id: 'cam-test-thresh-2',
        name: 'Câmera Teste Aceite',
        ip: '192.168.3.99',
        aiDetectionEnabled: true,
        aiMinConfidence: 0.25, // 25% threshold
      );

      final highConfidenceEvent = CameraEvent(
        id: 'evt-high-1',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.person,
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 15),
        description: 'Pessoa confirmada no portão',
        confidence: 0.92, // 92% >= 25%
        boundingBoxes: const [
          BoundingBox(label: 'Pessoa', confidence: 0.92, left: 0.3, top: 0.2, width: 0.2, height: 0.5),
        ],
      );

      final result = CameraEventService.instance.registerEvent(highConfidenceEvent, camera: camera);
      expect(result, isTrue, reason: 'Eventos acima de 25% de certeza devem ser aceitos');
      expect(CameraEventService.instance.getEventById('evt-high-1'), isNotNull);
    });
  });
}
