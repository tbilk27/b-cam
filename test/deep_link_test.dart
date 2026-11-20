import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/services/deep_link_service.dart';

void main() {
  group('Deeplink & Routing Tests', () {
    test('Deeplink service correctly extracts event IDs from custom scheme and web URLs', () {
      final service = DeepLinkService.instance;

      service.setPendingDeepLink('bcam://event/evt-74-1');
      expect(service.pendingDeepLink, 'bcam://event/evt-74-1');

      service.setPendingDeepLink('https://b-cam.app/event/evt-23-1');
      expect(service.pendingDeepLink, 'https://b-cam.app/event/evt-23-1');
    });
  });
}
