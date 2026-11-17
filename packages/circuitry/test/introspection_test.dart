import 'package:circuitry/circuitry.dart';
import 'package:test/test.dart';

enum Environment { dev, prod }

final class ConfigService;
final class DatabaseService;
final class UserService;
final class OrderService;

void main() {
  group('WireDescriptor Specs', () {
    test('primary constructor initializes fields correctly', () {
      const descriptor = WireDescriptor(
        key: (ConfigService, null),
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        isInitialized: true,
      );

      expect(descriptor.key, equals((ConfigService, null)));
      expect(descriptor.dependencies, isEmpty);
      expect(descriptor.isAsync, isFalse);
      expect(descriptor.topologicalLevel, equals(0));
      expect(descriptor.isInitialized, isTrue);
    });

    test('toJson serializes descriptor fields into map', () {
      const descriptor = WireDescriptor(
        key: (DatabaseService, Environment.dev),
        dependencies: [(ConfigService, null)],
        isAsync: true,
        topologicalLevel: 1,
        isInitialized: false,
      );

      final json = descriptor.toJson();
      expect(json['key'], equals('DatabaseService#Environment.dev'));
      expect(json['dependencies'], equals(['ConfigService']));
      expect(json['isAsync'], isTrue);
      expect(json['topologicalLevel'], equals(1));
      expect(json['isInitialized'], isFalse);
    });

    test('copyWith creates modified clone', () {
      const original = WireDescriptor(
        key: (ConfigService, null),
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        isInitialized: false,
      );

      final modified = original.copyWith(isInitialized: true);
      expect(modified.isInitialized, isTrue);
      expect(modified.key, equals(original.key));
      expect(original.isInitialized, isFalse);
    });

    test('equality and hashCode adhere to value semantics', () {
      const desc1 = WireDescriptor(
        key: (ConfigService, null),
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        isInitialized: false,
      );
      const desc2 = WireDescriptor(
        key: (ConfigService, null),
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        isInitialized: false,
      );
      const desc3 = WireDescriptor(
        key: (ConfigService, null),
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        isInitialized: true,
      );

      expect(desc1, equals(desc2));
      expect(desc1.hashCode, equals(desc2.hashCode));
      expect(desc1, isNot(equals(desc3)));
      expect(desc1.toString(), contains('ConfigService'));
    });
  });

  group('CircuitIntrospection On-Demand Queries', () {
    test(
      'inspect() exposes descriptors and tracks live isInitialized state',
      () async {
        final circuit = await Circuit.build([
          Wire(ConfigService.new),
          AsyncWire.takes<ConfigService>().to((_) async => DatabaseService()),
          Wire.takes<DatabaseService>().to((_) => UserService()),
        ]);

        final introspectionBefore = circuit.inspect();
        final configDescBefore = introspectionBefore.wires.firstWhere(
          (w) => w.key == (ConfigService, null),
        );
        final dbDescBefore = introspectionBefore.wires.firstWhere(
          (w) => w.key == (DatabaseService, null),
        );
        final userDescBefore = introspectionBefore.wires.firstWhere(
          (w) => w.key == (UserService, null),
        );

        // Config was lazily instantiated because DatabaseService depended on it during build
        expect(configDescBefore.isInitialized, isTrue);
        expect(configDescBefore.isAsync, isFalse);
        expect(configDescBefore.topologicalLevel, equals(0));

        // DatabaseService was resolved asynchronously during build
        expect(dbDescBefore.isInitialized, isTrue);
        expect(dbDescBefore.isAsync, isTrue);
        expect(dbDescBefore.topologicalLevel, equals(1));

        // UserService has not been requested yet
        expect(userDescBefore.isInitialized, isFalse);
        expect(userDescBefore.isAsync, isFalse);
        expect(userDescBefore.topologicalLevel, equals(2));

        // Now access UserService
        circuit.get<UserService>();

        final introspectionAfter = circuit.inspect();
        final userDescAfter = introspectionAfter.wires.firstWhere(
          (w) => w.key == (UserService, null),
        );
        expect(userDescAfter.isInitialized, isTrue);
      },
    );

    test('waves groups descriptors by topological level', () async {
      final circuit = await Circuit.build([
        Wire(ConfigService.new),
        Wire.takes<ConfigService>().to((_) => DatabaseService()),
        Wire.takes<DatabaseService>().to((_) => UserService()),
      ]);

      final introspection = circuit.inspect();
      final waves = introspection.waves;

      expect(waves.length, equals(3));
      expect(waves[0]!.map((w) => w.key), equals([(ConfigService, null)]));
      expect(waves[1]!.map((w) => w.key), equals([(DatabaseService, null)]));
      expect(waves[2]!.map((w) => w.key), equals([(UserService, null)]));
      expect(introspection.maxWaveLevel, equals(2));
    });

    test(
      'topologicalOrder, dependenciesOf, and dependentsOf delegate to graph',
      () async {
        final circuit = await Circuit.build([
          Wire(ConfigService.new),
          Wire.takes<ConfigService>().to((_) => DatabaseService()),
          Wire.takes<DatabaseService>().to((_) => UserService()),
        ]);

        final introspection = circuit.inspect();

        expect(
          introspection.topologicalOrder,
          equals([
            (ConfigService, null),
            (DatabaseService, null),
            (UserService, null),
          ]),
        );

        expect(
          introspection.dependenciesOf((UserService, null), transitive: true),
          equals({(DatabaseService, null), (ConfigService, null)}),
        );

        expect(
          introspection.dependentsOf((ConfigService, null), transitive: true),
          equals({(DatabaseService, null), (UserService, null)}),
        );
      },
    );

    test('handles empty circuit edge case', () async {
      final circuit = await Circuit.build([]);
      final introspection = circuit.inspect();

      expect(introspection.wires, isEmpty);
      expect(introspection.waves, isEmpty);
      expect(introspection.maxWaveLevel, equals(0));
      expect(introspection.topologicalOrder, isEmpty);
    });
  });
}
