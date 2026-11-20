import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/main.dart';

void main() {
  testWidgets('b-cam app launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BCamApp());
    expect(find.byType(BCamApp), findsOneWidget);
  });
}
