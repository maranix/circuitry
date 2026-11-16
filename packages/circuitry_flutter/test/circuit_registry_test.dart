import 'dart:convert';
import 'dart:developer' as developer;

import 'package:circuitry_flutter/circuitry_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

enum TestTag { global, feature, dev, prod }

final class DatabaseConfig {
  final String url;
  const DatabaseConfig(this.url);
}

final class DatabaseService {
  final DatabaseConfig config;
  DatabaseService(this.config);
}

final class AuthService {
  final DatabaseService db;
  AuthService(this.db);
}

final class LazyLoggingService {
  final String prefix;
  const LazyLoggingService(this.prefix);
}

void main() {
  setUp(() {
    CircuitRegistry.instance.clear();
  });

  tearDown(() {
    CircuitRegistry.instance.clear();
  });

  group('CircuitRegistry Core Operations', () {
    test(
      'registers and retrieves CircuitEntry by id and circuit instance',
      () async {
        final circuit = await Circuit.build([
          Wire(() => const DatabaseConfig('sqlite://app.db')),
        ]);

        final id = CircuitRegistry.instance.register(
          circuit,
          tag: TestTag.global,
        );

        expect(id, isNotNull);
        expect(CircuitRegistry.instance.count, equals(1));
        expect(CircuitRegistry.instance.isEmpty, isFalse);
        expect(CircuitRegistry.instance.isNotEmpty, isTrue);

        final entry = CircuitRegistry.instance.getCircuitById(id!);
        expect(entry, isNotNull);
        expect(entry!.id, equals(id));
        expect(identical(entry.circuit, circuit), isTrue);
        expect(entry.tag, equals(TestTag.global));
        expect(entry.state, isA<CircuitReady>());

        // Retrieval via operator [] and getEntry
        expect(CircuitRegistry.instance[id], equals(entry));
        expect(CircuitRegistry.instance.getEntry(circuit), equals(entry));

        await circuit.dispose();
      },
    );

    test('unregisters Circuit instance cleanly', () async {
      final circuit = await Circuit.build([
        Wire(() => const DatabaseConfig('sqlite://app.db')),
      ]);

      final id = CircuitRegistry.instance.register(circuit);
      expect(CircuitRegistry.instance.count, equals(1));

      CircuitRegistry.instance.unregister(circuit);
      expect(CircuitRegistry.instance.count, equals(0));
      expect(CircuitRegistry.instance.getCircuitById(id!), isNull);
      expect(CircuitRegistry.instance.getEntry(circuit), isNull);

      await circuit.dispose();
    });

    test(
      're-registering the same Circuit preserves id and updates tag/state',
      () async {
        final circuit = await Circuit.build([
          Wire(() => const DatabaseConfig('sqlite://app.db')),
        ]);

        final id1 = CircuitRegistry.instance.register(
          circuit,
          tag: TestTag.dev,
          state: const CircuitState.building(),
        );

        expect(
          CircuitRegistry.instance.getCircuitById(id1!)!.tag,
          equals(TestTag.dev),
        );
        expect(
          CircuitRegistry.instance.getCircuitById(id1)!.state,
          isA<CircuitBuilding>(),
        );

        final id2 = CircuitRegistry.instance.register(
          circuit,
          tag: TestTag.prod,
          state: CircuitState.ready(circuit),
        );

        expect(id2, equals(id1));
        expect(CircuitRegistry.instance.count, equals(1));
        final updated = CircuitRegistry.instance.getCircuitById(id1)!;
        expect(updated.tag, equals(TestTag.prod));
        expect(updated.state, isA<CircuitReady>());

        await circuit.dispose();
      },
    );

    test(
      'updateState modifies lifecycle state of registered Circuit',
      () async {
        final circuit = await Circuit.build([
          Wire(() => const DatabaseConfig('sqlite://app.db')),
        ]);

        final id = CircuitRegistry.instance.register(
          circuit,
          state: const CircuitState.building(),
        );

        CircuitRegistry.instance.updateState(
          circuit,
          CircuitState.ready(circuit),
        );
        expect(CircuitRegistry.instance[id!]!.state, isA<CircuitReady>());

        final error = Exception('Failed during operation');
        CircuitRegistry.instance.updateState(
          circuit,
          CircuitState.failure(error),
        );
        expect(CircuitRegistry.instance[id]!.state, isA<CircuitFailure>());

        await circuit.dispose();
      },
    );

    test('CircuitEntry.toJson produces expected debug metadata', () async {
      final circuit = await Circuit.build([
        Wire(() => const DatabaseConfig('sqlite://app.db')),
        Wire.takes<DatabaseConfig>().to(DatabaseService.new),
      ]);

      final id = CircuitRegistry.instance.register(
        circuit,
        tag: TestTag.feature,
        state: CircuitState.ready(circuit),
      );

      final json = CircuitRegistry.instance[id!]!.toJson();
      expect(json['id'], equals(id));
      expect(json['tag'], equals('feature'));
      expect(json['state'], equals('ready'));
      expect(json['isDisposed'], isFalse);
      expect(json['wireCount'], equals(2));

      await circuit.dispose();
      expect(CircuitRegistry.instance[id]!.toJson()['isDisposed'], isTrue);
    });
  });

  group('CircuitProvider Lifecycle Integration with CircuitRegistry', () {
    testWidgets(
      'CircuitProvider registers circuit on completion and unregisters on unmount',
      (tester) async {
        expect(CircuitRegistry.instance.count, equals(0));

        await tester.pumpWidget(
          CircuitProvider(
            tag: TestTag.global,
            wires: [
              Wire(() => const DatabaseConfig('sqlite://test.db')),
              Wire.takes<DatabaseConfig>().to(DatabaseService.new),
            ],
            builder: (context, state) => switch (state) {
              CircuitReady() => const Text(
                'Ready',
                textDirection: TextDirection.ltr,
              ),
              _ => const Text('Building', textDirection: TextDirection.ltr),
            },
          ),
        );

        // Async compilation in flight
        expect(find.text('Building'), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.text('Ready'), findsOneWidget);

        // Circuit must now be registered in CircuitRegistry
        expect(CircuitRegistry.instance.count, equals(1));
        final entry = CircuitRegistry.instance.circuits.values.first;
        expect(entry.tag, equals(TestTag.global));
        expect(entry.state, isA<CircuitReady>());
        expect(entry.circuit.isDisposed, isFalse);

        // Unmount the widget tree
        await tester.pumpWidget(const SizedBox());
        expect(CircuitRegistry.instance.count, equals(0));
      },
    );

    testWidgets(
      'CircuitProvider.value registers on mount and unregisters on unmount',
      (tester) async {
        final circuit = await Circuit.build([
          Wire(() => const DatabaseConfig('sqlite://test.db')),
        ]);

        expect(CircuitRegistry.instance.count, equals(0));

        await tester.pumpWidget(
          CircuitProvider.value(
            tag: TestTag.feature,
            value: circuit,
            child: const Text('ValueReady', textDirection: TextDirection.ltr),
          ),
        );

        expect(find.text('ValueReady'), findsOneWidget);
        expect(CircuitRegistry.instance.count, equals(1));
        final entry = CircuitRegistry.instance.getEntry(circuit);
        expect(entry, isNotNull);
        expect(entry!.tag, equals(TestTag.feature));
        expect(entry.state, isA<CircuitReady>());

        // Unmount
        await tester.pumpWidget(const SizedBox());
        expect(CircuitRegistry.instance.count, equals(0));

        await circuit.dispose();
      },
    );

    testWidgets(
      'CircuitProvider didUpdateWidget unregisters old circuit and registers new circuit',
      (tester) async {
        final wiresA = [Wire(() => const DatabaseConfig('sqlite://a.db'))];
        final wiresB = [Wire(() => const DatabaseConfig('sqlite://b.db'))];

        await tester.pumpWidget(
          CircuitProvider(
            tag: TestTag.dev,
            wires: wiresA,
            builder: (context, state) => switch (state) {
              CircuitReady() => const Text(
                'Ready A',
                textDirection: TextDirection.ltr,
              ),
              _ => const Text('Loading', textDirection: TextDirection.ltr),
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ready A'), findsOneWidget);

        final entryA = CircuitRegistry.instance.circuits.values.first;
        final circuitA = entryA.circuit;

        // Update wires list
        await tester.pumpWidget(
          CircuitProvider(
            tag: TestTag.dev,
            wires: wiresB,
            builder: (context, state) => switch (state) {
              CircuitReady() => const Text(
                'Ready B',
                textDirection: TextDirection.ltr,
              ),
              _ => const Text('Loading', textDirection: TextDirection.ltr),
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ready B'), findsOneWidget);

        expect(CircuitRegistry.instance.count, equals(1));
        final entryB = CircuitRegistry.instance.circuits.values.first;
        expect(identical(entryB.circuit, circuitA), isFalse);
        expect(circuitA.isDisposed, isTrue);
        expect(entryB.circuit.isDisposed, isFalse);
      },
    );

    testWidgets(
      'CircuitProvider.value didUpdateWidget updates registered entry when value changes',
      (tester) async {
        final circuit1 = await Circuit.build([
          Wire(() => const DatabaseConfig('sqlite://1.db')),
        ]);
        final circuit2 = await Circuit.build([
          Wire(() => const DatabaseConfig('sqlite://2.db')),
        ]);

        await tester.pumpWidget(
          CircuitProvider.value(
            tag: TestTag.dev,
            value: circuit1,
            child: const Text('Child', textDirection: TextDirection.ltr),
          ),
        );

        expect(CircuitRegistry.instance.getEntry(circuit1), isNotNull);
        expect(CircuitRegistry.instance.getEntry(circuit2), isNull);

        await tester.pumpWidget(
          CircuitProvider.value(
            tag: TestTag.prod,
            value: circuit2,
            child: const Text('Child', textDirection: TextDirection.ltr),
          ),
        );

        expect(CircuitRegistry.instance.getEntry(circuit1), isNull);
        final entry2 = CircuitRegistry.instance.getEntry(circuit2);
        expect(entry2, isNotNull);
        expect(entry2!.tag, equals(TestTag.prod));

        await tester.pumpWidget(const SizedBox());
        await circuit1.dispose();
        await circuit2.dispose();
      },
    );
  });

  group('VM Service Extensions Query and Mutation', () {
    test(
      'ext.circuitry.getCircuits returns list of registered circuits',
      () async {
        final circuit1 = await Circuit.build([
          Wire(() => const DatabaseConfig('sqlite://1.db')),
        ]);
        final circuit2 = await Circuit.build([
          Wire(() => const DatabaseConfig('sqlite://2.db')),
          Wire.takes<DatabaseConfig>().to(DatabaseService.new),
        ]);

        final id1 = CircuitRegistry.instance.register(
          circuit1,
          tag: TestTag.dev,
        );
        final id2 = CircuitRegistry.instance.register(
          circuit2,
          tag: TestTag.prod,
        );

        final response = await handleCircuitryServiceExtension(
          getCircuitsExtension,
          const {},
        );

        expect(response.errorCode, isNull);
        final data = jsonDecode(response.result!) as Map<String, Object?>;
        expect(data['type'], equals('CircuitList'));

        final list = (data['circuits'] as List<dynamic>)
            .cast<Map<String, Object?>>();
        expect(list.length, equals(2));

        final first = list.firstWhere((c) => c['id'] == id1);
        expect(first['tag'], equals('dev'));
        expect(first['state'], equals('ready'));
        expect(first['wireCount'], equals(1));

        final second = list.firstWhere((c) => c['id'] == id2);
        expect(second['tag'], equals('prod'));
        expect(second['state'], equals('ready'));
        expect(second['wireCount'], equals(2));

        await circuit1.dispose();
        await circuit2.dispose();
      },
    );

    test('ext.circuitry.getCircuitGraph returns DAG graph json', () async {
      final circuit = await Circuit.build([
        Wire(() => const DatabaseConfig('sqlite://graph.db')),
        Wire.takes<DatabaseConfig>().to(DatabaseService.new),
      ]);

      final id = CircuitRegistry.instance.register(
        circuit,
        tag: TestTag.feature,
      );

      // Missing id parameter returns invalidParams
      final missingResp = await handleCircuitryServiceExtension(
        getCircuitGraphExtension,
        const {},
      );
      expect(
        missingResp.errorCode,
        equals(developer.ServiceExtensionResponse.invalidParams),
      );

      // Unknown id returns extensionError
      final unknownResp = await handleCircuitryServiceExtension(
        getCircuitGraphExtension,
        {'id': 'circuit_9999'},
      );
      expect(
        unknownResp.errorCode,
        equals(developer.ServiceExtensionResponse.extensionError),
      );

      // Valid id returns circuit.inspect().toJson()
      final validResp = await handleCircuitryServiceExtension(
        getCircuitGraphExtension,
        {'id': id!},
      );
      expect(validResp.errorCode, isNull);
      final graphData = jsonDecode(validResp.result!) as Map<String, Object?>;
      expect(graphData.containsKey('wires'), isTrue);
      expect(graphData.containsKey('waves'), isTrue);
      expect(graphData.containsKey('maxWaveLevel'), isTrue);

      final wires = graphData['wires'] as List<dynamic>;
      expect(wires.length, equals(2));

      await circuit.dispose();
    });

    test(
      'ext.circuitry.forceResolveWire resolves lazy synchronous wire',
      () async {
        var lazyCreated = false;
        final circuit = await Circuit.build([
          Wire(() => const DatabaseConfig('sqlite://lazy.db')),
          Wire(() {
            lazyCreated = true;
            return const LazyLoggingService('[LAZY]');
          }),
        ]);

        final id = CircuitRegistry.instance.register(circuit);

        // Verify wire is initially uninitialized
        expect(circuit.isInitialized<LazyLoggingService>(), isFalse);
        expect(lazyCreated, isFalse);

        // Force resolve via service extension
        final resolveResp = await handleCircuitryServiceExtension(
          forceResolveWireExtension,
          {'id': id!, 'key': 'LazyLoggingService'},
        );

        expect(resolveResp.errorCode, isNull);
        final resultData =
            jsonDecode(resolveResp.result!) as Map<String, Object?>;
        expect(resultData['success'], equals(true));
        expect(resultData['resolved'], equals(true));
        expect(resultData['instanceType'], equals('LazyLoggingService'));

        // Wire is now initialized
        expect(circuit.isInitialized<LazyLoggingService>(), isTrue);
        expect(lazyCreated, isTrue);
        final logger = circuit.get<LazyLoggingService>();
        expect(logger.prefix, equals('[LAZY]'));

        await circuit.dispose();
      },
    );

    test('ext.circuitry.forceResolveWire resolves tagged wire', () async {
      final circuit = await Circuit.build([
        Wire.tag(
          () => const DatabaseConfig('sqlite://dev.db'),
          tag: TestTag.dev,
        ),
      ]);

      final id = CircuitRegistry.instance.register(circuit);

      expect(
        circuit.isInitializedTagged<DatabaseConfig, TestTag>(TestTag.dev),
        isFalse,
      );

      // Force resolve by composite key "DatabaseConfig#dev"
      final resolveResp = await handleCircuitryServiceExtension(
        forceResolveWireExtension,
        {'id': id!, 'key': 'DatabaseConfig#dev'},
      );

      expect(resolveResp.errorCode, isNull);
      final resultData =
          jsonDecode(resolveResp.result!) as Map<String, Object?>;
      expect(resultData['success'], equals(true));
      expect(
        circuit.isInitializedTagged<DatabaseConfig, TestTag>(TestTag.dev),
        isTrue,
      );

      await circuit.dispose();
    });

    test('ext.circuitry.forceResolveWire validates error conditions', () async {
      final circuit = await Circuit.build([
        Wire(() => const DatabaseConfig('sqlite://errors.db')),
      ]);
      final id = CircuitRegistry.instance.register(circuit);

      // Missing id
      final r1 = await handleCircuitryServiceExtension(
        forceResolveWireExtension,
        {'key': 'DatabaseConfig'},
      );
      expect(
        r1.errorCode,
        equals(developer.ServiceExtensionResponse.invalidParams),
      );

      // Missing key
      final r2 = await handleCircuitryServiceExtension(
        forceResolveWireExtension,
        {'id': id!},
      );
      expect(
        r2.errorCode,
        equals(developer.ServiceExtensionResponse.invalidParams),
      );

      // Non-existent wire key
      final r3 = await handleCircuitryServiceExtension(
        forceResolveWireExtension,
        {'id': id, 'key': 'NonExistentService'},
      );
      expect(
        r3.errorCode,
        equals(developer.ServiceExtensionResponse.extensionError),
      );

      // Disposed circuit
      await circuit.dispose();
      final r4 = await handleCircuitryServiceExtension(
        forceResolveWireExtension,
        {'id': id, 'key': 'DatabaseConfig'},
      );
      expect(
        r4.errorCode,
        equals(developer.ServiceExtensionResponse.extensionError),
      );
    });
  });
}
