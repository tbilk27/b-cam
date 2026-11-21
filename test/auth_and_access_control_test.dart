import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/manufacturer.dart';
import 'package:bcam/services/auth_service.dart';
import 'package:bcam/services/camera_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Access Control & Gmail Domain Validation Tests', () {
    test('Strict Gmail Domain Validation: Only @gmail.com is allowed', () {
      expect(AuthService.isValidGmail('teste@gmail.com'), isTrue);
      expect(AuthService.isValidGmail('USER.NAME@GMAIL.COM'), isTrue);
      expect(AuthService.isValidGmail('tbilk27@gmail.com'), isTrue);

      // Rejected domains
      expect(AuthService.isValidGmail('teste@hotmail.com'), isFalse);
      expect(AuthService.isValidGmail('teste@yahoo.com'), isFalse);
      expect(AuthService.isValidGmail('teste@outlook.com'), isFalse);
      expect(AuthService.isValidGmail('teste@nexeoo.com'), isFalse);
      expect(AuthService.isValidGmail('teste@bilk.com.br'), isFalse);
      expect(AuthService.isValidGmail('invalid-email'), isFalse);
    });

    test('UserProfile JSON serialization and copyWith', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: '12345',
        email: 'tbilk27@gmail.com',
        displayName: 'Tiago Bilk',
        photoUrl: 'https://lh3.googleusercontent.com/photo.jpg',
        createdAt: now,
        isBiometricEnabled: true,
        hasCompletedFirstAccess: true,
      );

      final json = profile.toJson();
      expect(json['id'], equals('12345'));
      expect(json['email'], equals('tbilk27@gmail.com'));
      expect(json['isBiometricEnabled'], isTrue);
      expect(json['hasCompletedFirstAccess'], isTrue);

      final restored = UserProfile.fromJson(json);
      expect(restored.id, equals(profile.id));
      expect(restored.email, equals(profile.email));
      expect(restored.isBiometricEnabled, isTrue);
      expect(restored.hasCompletedFirstAccess, isTrue);

      final updated = profile.copyWith(isBiometricEnabled: false);
      expect(updated.isBiometricEnabled, isFalse);
      expect(updated.email, equals(profile.email));
    });

    test('CameraDevice ownerEmail binding and serialization', () {
      final camera = CameraDevice(
        id: 'cam-01',
        name: 'Portão Principal',
        ip: '192.168.3.22',
        ownerEmail: 'tbilk27@gmail.com',
      );

      expect(camera.ownerEmail, equals('tbilk27@gmail.com'));

      final json = camera.toJson();
      expect(json['ownerEmail'], equals('tbilk27@gmail.com'));

      final restored = CameraDevice.fromJson(json);
      expect(restored.ownerEmail, equals('tbilk27@gmail.com'));

      final copy = camera.copyWith(ownerEmail: 'outro@gmail.com');
      expect(copy.ownerEmail, equals('outro@gmail.com'));
    });

    test('CameraStorageService associates cameras to specific user email', () async {
      final storage = CameraStorageService();

      final cam1 = CameraDevice(
        id: 'cam-01',
        name: 'Garagem',
        ip: '192.168.3.23',
        manufacturer: CameraManufacturer.yoosee,
      );
      final cam2 = CameraDevice(
        id: 'cam-02',
        name: 'Entrada',
        ip: '192.168.3.74',
        manufacturer: CameraManufacturer.intelbras,
      );

      await storage.addCamera(cam1);
      await storage.addCamera(cam2);

      expect(storage.cameras.length, equals(2));

      // Associate all cameras to tbilk27@gmail.com
      await storage.associateCamerasToUser('tbilk27@gmail.com');

      final userCams = storage.getCamerasForUser('tbilk27@gmail.com');
      expect(userCams.length, equals(2));
      expect(userCams.first.ownerEmail, equals('tbilk27@gmail.com'));
      expect(userCams.last.ownerEmail, equals('tbilk27@gmail.com'));
    });
  });
}
