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

    test('Yoosee URL generator encodes special characters in password', () {
      final url = CameraManufacturer.yoosee.buildRtspUrl(
        ip: '192.168.3.23',
        port: 554,
        user: 'admin',
        password: 'Compras10@',
        channel: 1,
        subType: 0,
      );
      expect(url, 'rtsp://admin:Compras10%40@192.168.3.23:554/onvif1');
    });

    test('Intelbras Mibo URL generator', () {
      final url = CameraManufacturer.intelbrasMibo.buildRtspUrl(
        ip: '192.168.3.22',
        port: 554,
        user: 'admin',
        password: 'compras10',
        channel: 1,
        subType: 0,
      );
      expect(url, 'rtsp://admin:compras10@192.168.3.22:554/cam/realmonitor?channel=1&subtype=0');
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

  group('MAC Address Binding & DHCP Resilience tests', () {
    test('normalizeMac standardizes various MAC formats', () {
      expect(CameraDevice.normalizeMac('98:2a:0a:89:56:62'), '98:2A:0A:89:56:62');
      expect(CameraDevice.normalizeMac('98-2A-0A-89-56-62'), '98:2A:0A:89:56:62');
      expect(CameraDevice.normalizeMac('982a0a895662'), '98:2A:0A:89:56:62');
      expect(CameraDevice.normalizeMac('18:0d:2c:5d:96:fe'), '18:0D:2C:5D:96:FE');
      expect(CameraDevice.normalizeMac(null), isNull);
    });

    test('matchesMac recognizes same physical hardware with different IP and formatting', () {
      final cam = CameraDevice(
        id: 'cam-alpha',
        name: 'Portão Principal',
        ip: '192.168.3.74',
        macAddress: '98:2A:0A:89:56:62',
      );

      // Router rebooted and DHCP assigned 192.168.3.210
      expect(cam.matchesMac('98:2a:0a:89:56:62'), isTrue);
      expect(cam.matchesMac('98-2A-0A-89-56-62'), isTrue);
      expect(cam.matchesMac('18:0D:2C:5D:96:FE'), isFalse);
    });
  });
}
