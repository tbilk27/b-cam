import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:bcam/main.dart';
import 'package:bcam/widgets/b_cam_logo.dart';

void main() {
  testWidgets('b-cam app launches smoke test with FluentApp', (WidgetTester tester) async {
    await tester.pumpWidget(const BCamApp());
    await tester.pumpAndSettle();

    expect(find.byType(FluentApp), findsOneWidget);
    expect(find.byType(BCamLogo), findsOneWidget);
    expect(find.text('b-cam'), findsOneWidget);
  });
}
