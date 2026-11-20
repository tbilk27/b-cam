import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/services/app_update_service.dart';

void main() {
  group('App Update & Versioning Tests', () {
    test('AppVersionInfo flags update only when remote version code is strictly higher', () {
      const infoHigher = AppVersionInfo(
        currentVersionCode: 2,
        currentVersionName: '1.1.0',
        remoteVersionCode: 3,
        remoteVersionName: '1.2.0',
        apkUrl: 'http://192.168.3.62:8088/b-cam-arm64.apk',
        releaseNotes: 'Melhorias de IA',
      );
      expect(infoHigher.hasUpdate, isTrue);

      const infoEqual = AppVersionInfo(
        currentVersionCode: 2,
        currentVersionName: '1.1.0',
        remoteVersionCode: 2,
        remoteVersionName: '1.1.0',
        apkUrl: 'http://192.168.3.62:8088/b-cam-arm64.apk',
        releaseNotes: 'Mesma versão',
      );
      expect(infoEqual.hasUpdate, isFalse);
    });

    test('AppVersionInfo formats file size in MB properly', () {
      const infoWithSize = AppVersionInfo(
        currentVersionCode: 2,
        currentVersionName: '1.1.0',
        remoteVersionCode: 3,
        remoteVersionName: '1.2.0',
        apkUrl: 'http://192.168.3.62:8088/b-cam-arm64.apk',
        releaseNotes: 'Notas',
        fileSizeBytes: 143146838, // ~136.5 MB
      );
      expect(infoWithSize.fileSizeFormatted, contains('136.5 MB'));
    });
  });
}
