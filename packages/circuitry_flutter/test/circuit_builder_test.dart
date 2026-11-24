import 'package:circuitry_flutter/circuitry_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

enum Environment { dev, prod }

enum TestScope { root, feature }

final class const Config(final String env);
final class const DatabaseService(final String host);
final class const AuthService(final String token);

void main() {
  group('CircuitBuilder Widget', () {
    testWidgets('resolves untagged dependency from nearest CircuitProvider', (
      tester,
    ) async {
      final circuit = await Circuit.build([
        Wire(() => const Config('test')),
        Wire(() => const DatabaseService('localhost:5432')),
      ]);

      await tester.pumpWidget(
        CircuitProvider.value(
          value: circuit,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitBuilder<DatabaseService>(
              builder: (context, db) => Text('Database: ${db.host}'),
            ),
          ),
        ),
      );

      expect(find.text('Database: localhost:5432'), findsOneWidget);
      await circuit.dispose();
    });

    testWidgets(
      'resolves tagged wire using CircuitBuilder.tagged constructor',
      (tester) async {
        final circuit = await Circuit.build([
          Wire.tag(
            () => const DatabaseService('dev.internal'),
            tag: Environment.dev,
          ),
          Wire.tag(
            () => const DatabaseService('prod.internal'),
            tag: Environment.prod,
          ),
        ]);

        await tester.pumpWidget(
          CircuitProvider.value(
            value: circuit,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: CircuitBuilder<DatabaseService>.tagged(
                tag: Environment.prod,
                builder: (context, db) => Text('Active DB: ${db.host}'),
              ),
            ),
          ),
        );

        expect(find.text('Active DB: prod.internal'), findsOneWidget);
        await circuit.dispose();
      },
    );

    testWidgets(
      'resolves untagged dependency from ancestor tagged circuit via circuitTag',
      (tester) async {
        final rootCircuit = await Circuit.build([
          Wire(() => const AuthService('root-secret-token')),
        ]);
        final featureCircuit = await Circuit.build([
          Wire(() => const Config('feature-env')),
        ]);

        await tester.pumpWidget(
          CircuitProvider.value(
            tag: TestScope.root,
            value: rootCircuit,
            child: CircuitProvider.value(
              tag: TestScope.feature,
              value: featureCircuit,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    CircuitBuilder<Config>(
                      builder: (context, cfg) => Text('Config: ${cfg.env}'),
                    ),
                    CircuitBuilder<AuthService>(
                      circuitTag: TestScope.root,
                      builder: (context, auth) => Text('Auth: ${auth.token}'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Config: feature-env'), findsOneWidget);
        expect(find.text('Auth: root-secret-token'), findsOneWidget);

        await featureCircuit.dispose();
        await rootCircuit.dispose();
      },
    );

    testWidgets(
      'resolves tagged wire from ancestor tagged circuit via tagged constructor with circuitTag',
      (tester) async {
        final rootCircuit = await Circuit.build([
          Wire.tag(
            () => const DatabaseService('root.prod.db'),
            tag: Environment.prod,
          ),
        ]);
        final featureCircuit = await Circuit.build([
          Wire(() => const Config('nested')),
        ]);

        await tester.pumpWidget(
          CircuitProvider.value(
            tag: TestScope.root,
            value: rootCircuit,
            child: CircuitProvider.value(
              value: featureCircuit,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: CircuitBuilder<DatabaseService>.tagged(
                  tag: Environment.prod,
                  circuitTag: TestScope.root,
                  builder: (context, db) => Text('Root DB: ${db.host}'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Root DB: root.prod.db'), findsOneWidget);

        await featureCircuit.dispose();
        await rootCircuit.dispose();
      },
    );

    testWidgets(
      'throws StateError when no matching CircuitProvider encloses the builder',
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitBuilder<Config>(
              builder: (context, cfg) => Text(cfg.env),
            ),
          ),
        );

        expect(tester.takeException(), isA<StateError>());
      },
    );
  });
}
