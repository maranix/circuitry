import 'package:circuitry_flutter_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CircuitryExampleApp renders and resolves dependency graph', (
    tester,
  ) async {
    await tester.pumpWidget(const CircuitryExampleApp());

    // Initially displays building message
    expect(find.text('Compiling dependency graph...'), findsOneWidget);

    // Advance fake timer by 350ms to complete async connection
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Verifies HomeScreen elements
    expect(find.text('Circuitry Flutter Example'), findsOneWidget);
    expect(find.text('Version: 0.1.0'), findsOneWidget);
    expect(
      find.text('Active Database: db://production.cluster'),
      findsOneWidget,
    );
  });
}
