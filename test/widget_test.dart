import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:bcam/main.dart';

void main() {
  testWidgets('b-cam app launches smoke test with FluentApp', (WidgetTester tester) async {
    await tester.pumpWidget(const BCamApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FluentApp), findsOneWidget);
    expect(find.text('b-cam'), findsOneWidget);
    expect(find.text('SURVEILLANCE RADAR'), findsOneWidget);
    expect(find.text('Bilk Sistemas'), findsOneWidget);

    // Conclui a sequência de inicialização
    await tester.pump(const Duration(seconds: 3));
  });
}
