import 'dart:convert';
import 'dart:developer' as developer;

import 'package:circuitry/circuitry.dart';
import 'package:test/test.dart';

final class Config {
  final String host;
  const Config(this.host);
}

final class Logger {
  const Logger();
}

final class ApiService {
  final Config config;
  final Logger logger;
  const ApiService(this.config, this.logger);
}

final class AsyncService {
  final String data;
  const AsyncService(this.data);
}

void main() {
  setUp(() {
    CircuitRegistry.instance.clear();
  });

  tearDown(() {
    CircuitRegistry.instance.clear();
  });

  group('CircuitRegistry Core Tracking', () {
    test(
      'automatically registers circuit on Circuit.build in debug mode',
      () async {
        final circuit = await Circuit.build([
          Wire(() => const Config('localhost')),
          Wire(Logger.new),
        ]);

        final descriptors = CircuitRegistry.instance.descriptors;
        expect(descriptors.length, 1);
        expect(descriptors.first.id, 'circuit_0');
        expect(descriptors.first.tag, isNull);
        expect(descriptors.first.wireCount, 2);
        expect(descriptors.first.initializedWireCount, 0);
        expect(descriptors.first.isDisposed, isFalse);

        await circuit.dispose();
        expect(CircuitRegistry.instance.descriptors, isEmpty);
      },
    );

    test(
      'captures optional tag during Circuit.build and supports setTag',
      () async {
        final circuit = await Circuit.build([
          Wire(() => const Config('localhost')),
        ], tag: 'global');

        final id = CircuitRegistry.instance.getId(circuit);
        expect(id, 'circuit_0');
        expect(CircuitRegistry.instance.getTag(id!), 'global');

        CircuitRegistry.instance.setTag(circuit, 'custom_scope');
        expect(CircuitRegistry.instance.getTag(id), 'custom_scope');

        await circuit.dispose();
      },
    );

    test('updates initializedWireCount when lazy wires resolve', () async {
      final circuit = await Circuit.build([
        Wire(() => const Config('localhost')),
        Wire(Logger.new),
        Wire.takes<Config>().takes<Logger>().to(
          (deps) => ApiService(deps.$1, deps.$2),
        ),
      ]);

      final id = CircuitRegistry.instance.getId(circuit)!;
      var descriptor = CircuitRegistry.instance.descriptors.firstWhere(
        (d) => d.id == id,
      );
      expect(descriptor.initializedWireCount, 0);

      circuit.get<Config>();
      descriptor = CircuitRegistry.instance.descriptors.firstWhere(
        (d) => d.id == id,
      );
      expect(descriptor.initializedWireCount, 1);

      circuit.get<ApiService>();
      descriptor = CircuitRegistry.instance.descriptors.firstWhere(
        (d) => d.id == id,
      );
      expect(descriptor.initializedWireCount, 3);

      await circuit.dispose();
    });

    test('assigns sequential monotonic IDs to multiple circuits', () async {
      final circuit1 = await Circuit.build([Wire(() => const Config('1'))]);
      final circuit2 = await Circuit.build([Wire(() => const Config('2'))]);

      expect(CircuitRegistry.instance.getId(circuit1), 'circuit_0');
      expect(CircuitRegistry.instance.getId(circuit2), 'circuit_1');
      expect(CircuitRegistry.instance.descriptors.length, 2);

      await circuit1.dispose();
      expect(CircuitRegistry.instance.descriptors.length, 1);
      expect(CircuitRegistry.instance.descriptors.first.id, 'circuit_1');

      await circuit2.dispose();
      expect(CircuitRegistry.instance.descriptors, isEmpty);
    });
  });

  group('VM Service Extension Handlers', () {
    test(
      'handleGetCircuits returns valid JSON with circuit descriptors',
      () async {
        final responseEmpty = await CircuitRegistry.instance.handleGetCircuits(
          'ext.circuitry.getCircuits',
          const {},
        );
        final jsonEmpty =
            jsonDecode(responseEmpty.result!) as Map<String, dynamic>;
        expect(jsonEmpty['circuits'], isEmpty);

        final circuit = await Circuit.build([
          Wire(() => const Config('db.internal')),
          AsyncWire(() async => const AsyncService('async-data')),
        ], tag: 'core');

        final response = await CircuitRegistry.instance.handleGetCircuits(
          'ext.circuitry.getCircuits',
          const {},
        );
        final json = jsonDecode(response.result!) as Map<String, dynamic>;
        final circuits = json['circuits'] as List<dynamic>;
        expect(circuits.length, 1);

        final first = circuits.first as Map<String, dynamic>;
        expect(first['id'], 'circuit_0');
        expect(first['tag'], 'core');
        expect(first['wireCount'], 2);
        expect(
          first['initializedWireCount'],
          1,
        ); // AsyncService initialized during build
        expect(first['isDisposed'], isFalse);

        await circuit.dispose();
      },
    );

    test(
      'handleGetCircuitGraph returns invalidParams when id is missing',
      () async {
        final response = await CircuitRegistry.instance.handleGetCircuitGraph(
          'ext.circuitry.getCircuitGraph',
          const {},
        );
        expect(
          response.errorCode,
          developer.ServiceExtensionResponse.invalidParams,
        );
        expect(response.errorDetail, contains('Missing required parameter'));
      },
    );

    test(
      'handleGetCircuitGraph returns extensionError when circuit is not found',
      () async {
        final response = await CircuitRegistry.instance.handleGetCircuitGraph(
          'ext.circuitry.getCircuitGraph',
          const {'id': 'non_existent'},
        );
        expect(
          response.errorCode,
          developer.ServiceExtensionResponse.extensionError,
        );
        expect(response.errorDetail, contains('not found in registry'));
      },
    );

    test('handleGetCircuitGraph returns complete serialized DAG schema and live status', () async {
      final circuit = await Circuit.build([
        Wire(() => const Config('db.internal')),
        Wire(Logger.new),
        Wire.takes<Config>().takes<Logger>().to(
          (deps) => ApiService(deps.$1, deps.$2),
        ),
      ], tag: 'service_layer');

      final id = CircuitRegistry.instance.getId(circuit)!;
      final responseBefore = await CircuitRegistry.instance
          .handleGetCircuitGraph('ext.circuitry.getCircuitGraph', {
            'circuitId': id,
          });
      expect(responseBefore.errorCode, isNull);

      final jsonBefore =
          jsonDecode(responseBefore.result!) as Map<String, dynamic>;
      expect(jsonBefore['id'], id);
      expect(jsonBefore['tag'], 'service_layer');
      expect(jsonBefore['wireCount'], 3);
      expect(jsonBefore['maxWaveLevel'], 1);

      final wiresBefore = jsonBefore['wires'] as List<dynamic>;
      expect(wiresBefore.length, 3);
      for (final wire in wiresBefore) {
        expect((wire as Map<String, dynamic>)['isInitialized'], isFalse);
      }

      // Read ApiService to resolve dependencies
      circuit.get<ApiService>();

      final responseAfter = await CircuitRegistry.instance
          .handleGetCircuitGraph('ext.circuitry.getCircuitGraph', {'id': id});
      final jsonAfter =
          jsonDecode(responseAfter.result!) as Map<String, dynamic>;
      final wiresAfter = jsonAfter['wires'] as List<dynamic>;
      for (final wire in wiresAfter) {
        expect((wire as Map<String, dynamic>)['isInitialized'], isTrue);
      }

      await circuit.dispose();
    });
  });

  group('CircuitDescriptor Value Semantics', () {
    test('supports equality and toJson formatting', () {
      const desc1 = CircuitDescriptor(
        id: 'circuit_0',
        tag: 'auth',
        wireCount: 5,
        initializedWireCount: 2,
        maxLevel: 1,
        isDisposed: false,
      );
      const desc2 = CircuitDescriptor(
        id: 'circuit_0',
        tag: 'auth',
        wireCount: 5,
        initializedWireCount: 2,
        maxLevel: 1,
        isDisposed: false,
      );
      const descDifferent = CircuitDescriptor(
        id: 'circuit_1',
        tag: 'auth',
        wireCount: 5,
        initializedWireCount: 2,
        maxLevel: 1,
        isDisposed: false,
      );

      expect(desc1, equals(desc2));
      expect(desc1.hashCode, equals(desc2.hashCode));
      expect(desc1, isNot(equals(descDifferent)));

      final json = desc1.toJson();
      expect(json['id'], 'circuit_0');
      expect(json['tag'], 'auth');
      expect(json['wireCount'], 5);
      expect(json['initializedWireCount'], 2);
      expect(json['maxLevel'], 1);
      expect(json['isDisposed'], isFalse);
    });
  });
}
