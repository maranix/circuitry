import 'package:circuitry_flutter_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CircuitryExampleApp compiles and renders HomeScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CircuitryExampleApp());

    // Initially in building state
    expect(find.text('Compiling dependency graph...'), findsOneWidget);

    // Advance simulated time past the 300ms delayed async wire
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Verify ready screen rendered
    expect(find.text('Circuitry Flutter Example'), findsOneWidget);
    expect(find.text('Version: 0.1.0'), findsOneWidget);
    expect(
      find.text('Active Database: db://production.cluster'),
      findsOneWidget,
    );
  });
}
