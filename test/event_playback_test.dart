import 'package:bcam/models/bounding_box.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/camera_event.dart';
import 'package:bcam/widgets/event_clip_player_view.dart';
import 'package:fluent_ui/fluent_ui.dart';
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
  });
}
