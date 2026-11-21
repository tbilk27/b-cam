import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/camera_event.dart';
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

    test('Intelbras iC5 (Hikvision/EZVIZ based) URL generator', () {
      final url = CameraManufacturer.intelbrasIC.buildRtspUrl(
        ip: '192.168.3.22',
        port: 554,
        user: 'admin',
        password: 'compras10',
        channel: 1,
        subType: 0,
      );
      expect(url, 'rtsp://admin:compras10@192.168.3.22:554/h264/ch1/main/av_stream');
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

    test('Remote Host and Port resolution works for 3G/4G outside access', () {
      final cam = CameraDevice(
        id: 'test-remote',
        name: 'Intelbras Remota',
        ip: '192.168.3.74',
        rtspPort: 554,
        remoteHost: 'cameras.nexeoo.com',
        remoteRtspPort: 8554,
        remoteAccessMode: 'remote',
        manufacturer: CameraManufacturer.intelbras,
        username: 'admin',
        password: 'pass',
      );

      expect(cam.streamUrl, contains('cameras.nexeoo.com:8554'));
      expect(cam.maskedStreamUrl, contains('cameras.nexeoo.com:8554'));

      final json = cam.toJson();
      final fromJson = CameraDevice.fromJson(json);
      expect(fromJson.remoteHost, 'cameras.nexeoo.com');
      expect(fromJson.remoteRtspPort, 8554);
      expect(fromJson.remoteAccessMode, 'remote');
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

  group('Playback RTSP URL and Notification Event Filtering tests', () {
    test('playbackUrlForEvent builds correct RTSP playback URL for Intelbras DVR/NVR', () {
      final cam = CameraDevice(
        id: 'cam-intelbras',
        name: 'Entrada',
        ip: '192.168.3.74',
        rtspPort: 554,
        manufacturer: CameraManufacturer.intelbras,
        username: 'admin',
        password: 'password123',
        channel: 1,
      );

      final event = CameraEvent(
        id: 'evt-1',
        cameraId: cam.id,
        cameraName: cam.name,
        type: CameraEventType.person,
        timestamp: DateTime(2026, 11, 21, 8, 30, 0),
        duration: const Duration(seconds: 45),
        description: 'Pessoa na entrada',
      );

      final playbackUrl = cam.playbackUrlForEvent(event);
      expect(playbackUrl, contains('/cam/playback?channel=1&starttime=2026_11_21_08_30_00&endtime=2026_11_21_08_30_45'));
      expect(playbackUrl, contains('admin:password123@192.168.3.74:554'));
    });

    test('isNotificationEnabledFor correctly respects filtered categories', () {
      final cam = CameraDevice(
        id: 'cam-filtered',
        name: 'Garagem',
        ip: '192.168.3.23',
        pushNotificationsEnabled: true,
        notificationEventTypes: ['person', 'vehicle'], // only person and vehicle
      );

      expect(cam.isNotificationEnabledFor(CameraEventType.person), isTrue);
      expect(cam.isNotificationEnabledFor(CameraEventType.vehicle), isTrue);
      expect(cam.isNotificationEnabledFor(CameraEventType.motion), isFalse);
      expect(cam.isNotificationEnabledFor(CameraEventType.alarm), isFalse);

      final camDisabled = cam.copyWith(pushNotificationsEnabled: false);
      expect(camDisabled.isNotificationEnabledFor(CameraEventType.person), isFalse);
    });
  });
}
