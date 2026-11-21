import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bcam/models/camera_device.dart';
import 'package:bcam/models/manufacturer.dart';
import 'package:bcam/screens/camera_detail_screen.dart';
import 'package:bcam/services/camera_storage_service.dart';
import 'package:bcam/widgets/vertical_event_timeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCamera = CameraDevice(
    id: 'cam-ic5-test',
    name: 'Intelbras iC5 Quintal',
    ip: '192.168.3.22',
    rtspPort: 554,
    webPort: 80,
    manufacturer: CameraManufacturer.intelbrasIC,
    username: 'admin',
    password: 'compras10',
    channel: 1,
    subType: 0,
    location: 'Quintal / Varanda',
  );

  Widget createTestWidget(Widget child, {Size size = const Size(1080, 2400)}) {
    return FluentApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: ChangeNotifierProvider(
          create: (_) => CameraStorageService(),
          child: child,
        ),
      ),
    );
  }

  group('CameraDetailScreen and VerticalEventTimeline Tests', () {
    testWidgets('VerticalEventTimeline renders Sub-Header, < Hoje >, and Zoom buttons', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          ScaffoldPage(
            content: VerticalEventTimeline(camera: testCamera),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Sub-Header elements
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Histórico de Gravações'), findsOneWidget);
      expect(find.byIcon(FluentIcons.filter), findsOneWidget);

      // Check Zoom buttons
      expect(find.byIcon(FluentIcons.add), findsOneWidget);
      expect(find.byIcon(FluentIcons.remove), findsOneWidget);
    });

    testWidgets('CameraDetailScreen renders portrait layout with Video, Timeline, and Menu no Rodapé', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          CameraDetailScreen(camera: testCamera),
          size: const Size(400, 800), // Portrait
        ),
      );
      await tester.pumpAndSettle();

      // Verify camera name and live status in top overlay
      expect(find.text('Intelbras iC5 Quintal'), findsOneWidget);
      expect(find.textContaining('AO VIVO'), findsOneWidget);

      // Verify bottom surveillance rodapé items
      expect(find.text('Fotografar'), findsOneWidget);
      expect(find.text('Gravação'), findsOneWidget);
      expect(find.text('Definição'), findsOneWidget);
      expect(find.text('Suspensão'), findsOneWidget);
      expect(find.text('Zona Exclusão'), findsOneWidget);
      expect(find.text('PTZ Virtual'), findsNothing);
    });

    testWidgets('CameraDetailScreen renders responsive dual-pane layout in landscape mode', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          CameraDetailScreen(camera: testCamera),
          size: const Size(800, 400), // Landscape (width > height)
        ),
      );
      await tester.pumpAndSettle();

      // Verify dual pane: video header + timeline + menu all fit cleanly without overflow
      expect(find.text('Intelbras iC5 Quintal'), findsOneWidget);
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Foto'), findsOneWidget);
    });
  });
}
