import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/manufacturer.dart';

void main() {
  group('CameraManufacturer URL generation tests', () {
    test('Intelbras default URL generator', () {
      final url = CameraManufacturer.intelbras.buildRtspUrl(
        ip: '192.168.3.74',
        port: 554,
        user: 'admin',
        password: 'password123',
        channel: 1,
        subType: 0,
      );
      expect(url, 'rtsp://admin:password123@192.168.3.74:554/cam/realmonitor?channel=1&subtype=0');
    });

    test('Hikvision default URL generator', () {
      final url = CameraManufacturer.hikvision.buildRtspUrl(
        ip: '192.168.3.50',
        port: 554,
        user: 'admin',
        password: 'password123',
        channel: 1,
        subType: 1,
      );
      expect(url, 'rtsp://admin:password123@192.168.3.50:554/Streaming/Channels/102');
    });
  });

  group('CameraDevice security and masking tests', () {
    test('maskedStreamUrl obfuscates password properly', () {
      final cam = CameraDevice(
        id: 'test-1',
        name: 'Cam Teste',
        ip: '192.168.3.22',
        rtspPort: 554,
        manufacturer: CameraManufacturer.intelbras,
        username: 'admin',
        password: 'superSecretPassword',
      );

      expect(cam.maskedStreamUrl, contains(':******@'));
      expect(cam.maskedStreamUrl, isNot(contains('superSecretPassword')));
    });

    test('customUrl override works correctly', () {
      final cam = CameraDevice(
        id: 'test-2',
        name: 'Custom Stream',
        ip: 'custom.local',
        customUrl: 'rtsp://custom:stream@custom.local:8554/live',
      );

      expect(cam.streamUrl, 'rtsp://custom:stream@custom.local:8554/live');
      expect(cam.maskedStreamUrl, 'rtsp://custom:******@custom.local:8554/live');
    });
  });
}
