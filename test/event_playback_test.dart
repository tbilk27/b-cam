import 'package:bcam/models/bounding_box.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/camera_event.dart';
import 'package:bcam/services/camera_event_service.dart';
import 'package:bcam/widgets/event_clip_player_view.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventClipPlayerView & Video Playback Tests', () {
    testWidgets('Renders EventClipPlayerView with timecode and controls', (tester) async {
      final camera = CameraDevice(
        id: 'cam-event-test-1',
        name: 'Intelbras Teste',
        ip: '192.168.3.74',
        aiDetectionEnabled: true,
      );

      final event = CameraEvent(
        id: 'evt-test-999',
        cameraId: camera.id,
        cameraName: camera.name,
        type: CameraEventType.vehicle,
        timestamp: DateTime(2026, 11, 20, 16, 23, 38),
        duration: const Duration(seconds: 55),
        description: 'Veículo identificado estacionando na entrada.',
        confidence: 0.92,
        boundingBoxes: const [
          BoundingBox(
            label: 'Veículo',
            confidence: 0.92,
            left: 0.2,
            top: 0.4,
            width: 0.3,
            height: 0.3,
            colorHex: '#FFB900',
          ),
        ],
      );

      await tester.pumpWidget(
        FluentApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: EventClipPlayerView(
              event: event,
              camera: camera,
              autoPlay: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify camera name OSD watermark and play state badge
      expect(find.text('INTELBRAS TESTE'), findsOneWidget);
      expect(find.text('PAUSADO'), findsOneWidget);

      // Verify timecode OSD rendering
      expect(find.textContaining('20/11'), findsOneWidget);
      expect(find.textContaining('16:23:38'), findsOneWidget);

      // Verify Scrubber Slider exists
      expect(find.byType(Slider), findsOneWidget);

      // Tap Play/Pause Button
      final playBtn = find.byIcon(FluentIcons.play);
      expect(playBtn, findsWidgets);

      await tester.tap(playBtn.first);
      await tester.pump();

      // State switches to PLAY
      expect(find.text('PLAY • NVR/SD'), findsOneWidget);

      // Tap Pause to safely cancel periodic playback timer
      final pauseBtn = find.byIcon(FluentIcons.pause);
      if (pauseBtn.evaluate().isNotEmpty) {
        await tester.tap(pauseBtn.first);
        await tester.pump();
      }

      // Tear down widget tree cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    test('CameraEventService shareEventViaWhatsApp invokes platform channel with correct payload', () async {
      String? sentMethod;
      dynamic sentArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.nexeoo.bcam/deeplink'),
        (MethodCall call) async {
          sentMethod = call.method;
          sentArgs = call.arguments;
          return true;
        },
      );

      final event = CameraEvent(
        id: 'evt-wa-123',
        cameraId: 'cam-74',
        cameraName: 'Intelbras Frente',
        type: CameraEventType.person,
        timestamp: DateTime(2026, 11, 21, 10, 30, 0),
        duration: const Duration(seconds: 45),
        description: 'Pessoa identificada no portão.',
        confidence: 0.95,
      );

      final camera = CameraDevice(
        id: 'cam-74',
        name: 'Intelbras Frente',
        ip: '192.168.3.74',
        lastSnapshotPath: '/tmp/test_snap.jpg',
      );

      final service = CameraEventService.instance;
      final success = await service.shareEventViaWhatsApp(
        event,
        camera: camera,
      );

      expect(success, isTrue);
      expect(sentMethod, 'shareEventViaWhatsApp');
      expect(sentArgs['filePath'], '/tmp/test_snap.jpg');
      expect(sentArgs['message'], contains('Alerta de Vigilância b-cam PRO'));
      expect(sentArgs['message'], contains('Intelbras Frente'));
      expect(sentArgs['message'], contains('Pessoa Detectada'));
      expect(sentArgs['message'], contains('95%'));
      expect(sentArgs['message'], contains('https://bcam.nexeoo.com/event/evt-wa-123'));
    });
  });
}
