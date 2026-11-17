import 'package:circuitry/circuitry.dart';
import 'package:circuitry/src/graph.dart';
import 'package:test/test.dart';

enum Environment { dev, prod }

final class ConfigService;
final class DatabaseService;
final class UserService;
final class OrderService;

void main() {
  group('CircuitGraph Isolated Validation and Compilation', () {
    test('uncompiled graph throws StateError on compiled property access', () {
      final graph = CircuitGraph([Wire(ConfigService.new)]);

      expect(graph.isCompiled, isFalse);
      expect(() => graph.wireMap, throwsStateError);
      expect(() => graph.levels, throwsStateError);
      expect(() => graph.maxLevel, throwsStateError);
      expect(() => graph.wiresAtLevel(0), throwsStateError);
      expect(() => graph.asyncWiresAtLevel(0), throwsStateError);
    });

    test('validateDuplicates throws DuplicateWireException in isolation', () {
      final graph = CircuitGraph([
        Wire(ConfigService.new),
        Wire(ConfigService.new),
      ]);

      expect(
        () => graph.validateDuplicates(),
        throwsA(
          isA<DuplicateWireException>().having(
            (e) => e.key,
            'key',
            equals((ConfigService, null)),
          ),
        ),
      );
    });

    test('validateDependencies throws MissingWireException in isolation', () {
      final graph = CircuitGraph([
        Wire.takes<ConfigService>().to((_) => DatabaseService()),
      ]);

      expect(
        () => graph.validateDependencies(),
        throwsA(
          isA<MissingWireException>().having(
            (e) => e.missingKey,
            'missingKey',
            equals((ConfigService, null)),
          ),
        ),
      );
    });

    test('detectCycles throws CircularDependencyException in isolation', () {
      final graph = CircuitGraph([
        Wire.takes<UserService>().to((_) => DatabaseService()),
        Wire.takes<DatabaseService>().to((_) => UserService()),
      ]);

      expect(
        () => graph.detectCycles(),
        throwsA(
          isA<CircularDependencyException>().having(
            (e) => e.cycle,
            'cycle',
            equals([
              (DatabaseService, null),
              (UserService, null),
              (DatabaseService, null),
            ]),
          ),
        ),
      );
    });

    test('computeTopologicalLevels computes levels in isolation', () {
      final graph = CircuitGraph([
        Wire(ConfigService.new),
        Wire.takes<ConfigService>().to((_) => DatabaseService()),
        Wire.takes<DatabaseService>().to((_) => UserService()),
      ]);

      final (levels, maxLevel) = graph.computeTopologicalLevels();

      expect(levels[(ConfigService, null)], equals(0));
      expect(levels[(DatabaseService, null)], equals(1));
      expect(levels[(UserService, null)], equals(2));
      expect(maxLevel, equals(2));
    });

    test('compile runs all validations, computes levels and wave buckets', () {
      final configWire = Wire(ConfigService.new);
      final dbWire = AsyncWire.takes<ConfigService>().to(
        (_) async => DatabaseService(),
      );
      final userWire = Wire.takes<DatabaseService>().to((_) => UserService());

      final graph = CircuitGraph([configWire, dbWire, userWire]);
      expect(graph.compile(), same(graph));

      expect(graph.isCompiled, isTrue);
      expect(graph.wireMap.length, equals(3));
      expect(graph.maxLevel, equals(2));

      expect(graph.wiresAtLevel(0), equals([configWire]));
      expect(graph.wiresAtLevel(1), equals([dbWire]));
      expect(graph.wiresAtLevel(2), equals([userWire]));

      expect(graph.asyncWiresAtLevel(0), isEmpty);
      expect(graph.asyncWiresAtLevel(1), equals([dbWire]));
      expect(graph.asyncWiresAtLevel(2), isEmpty);
    });

    test('compile handles empty graph edge case', () {
      final graph = CircuitGraph([]);
      graph.compile();

      expect(graph.isCompiled, isTrue);
      expect(graph.wireMap, isEmpty);
      expect(graph.levels, isEmpty);
      expect(graph.maxLevel, equals(0));
      expect(graph.wiresAtLevel(0), isEmpty);
      expect(graph.asyncWiresAtLevel(0), isEmpty);
      expect(graph.reverseDependencies, isEmpty);
      expect(graph.topologicalOrder, isEmpty);
    });

    test('reverseDependencies precomputes direct dependents for all wires', () {
      final configWire = Wire(ConfigService.new);
      final dbWire = Wire.takes<ConfigService>().to((_) => DatabaseService());
      final userWire = Wire.takes<DatabaseService>().to((_) => UserService());
      final orderWire = Wire.takes<DatabaseService>().to((_) => OrderService());

      final graph = CircuitGraph([configWire, dbWire, userWire, orderWire])
          .compile();

      expect(
        graph.reverseDependencies[(ConfigService, null)],
        equals({(DatabaseService, null)}),
      );
      expect(
        graph.reverseDependencies[(DatabaseService, null)],
        equals({(UserService, null), (OrderService, null)}),
      );
      expect(graph.reverseDependencies[(UserService, null)], isEmpty);
      expect(graph.reverseDependencies[(OrderService, null)], isEmpty);
    });

    test('dependentsOf returns direct dependents when transitive is false', () {
      final configWire = Wire(ConfigService.new);
      final dbWire = Wire.takes<ConfigService>().to((_) => DatabaseService());
      final userWire = Wire.takes<DatabaseService>().to((_) => UserService());

      final graph = CircuitGraph([configWire, dbWire, userWire]).compile();

      expect(
        graph.dependentsOf((ConfigService, null)),
        equals({(DatabaseService, null)}),
      );
      expect(
        graph.dependentsOf((DatabaseService, null)),
        equals({(UserService, null)}),
      );
      expect(graph.dependentsOf((UserService, null)), isEmpty);
    });

    test(
      'dependentsOf returns all transitive dependents across diamond graph',
      () {
        // Config -> (Database, Cache) -> AppGateway
        final configWire = Wire(ConfigService.new);
        final dbWire = Wire.takes<ConfigService>().to((_) => DatabaseService());
        final userWire = Wire.takes<ConfigService>().to((_) => UserService());
        final orderWire = Wire.takes<DatabaseService>().takes<UserService>().to(
          (_) => OrderService(),
        );

        final graph = CircuitGraph([configWire, dbWire, userWire, orderWire])
            .compile();

        expect(
          graph.dependentsOf((ConfigService, null), transitive: true),
          equals({
            (DatabaseService, null),
            (UserService, null),
            (OrderService, null),
          }),
        );
        expect(
          graph.dependentsOf((DatabaseService, null), transitive: true),
          equals({(OrderService, null)}),
        );
        expect(
          graph.dependentsOf((OrderService, null), transitive: true),
          isEmpty,
        );
      },
    );

    test('dependenciesOf returns direct and transitive dependencies', () {
      final configWire = Wire(ConfigService.new);
      final dbWire = Wire.takes<ConfigService>().to((_) => DatabaseService());
      final userWire = Wire.takes<DatabaseService>().to((_) => UserService());

      final graph = CircuitGraph([configWire, dbWire, userWire]).compile();

      expect(graph.dependenciesOf((ConfigService, null)), isEmpty);
      expect(
        graph.dependenciesOf((DatabaseService, null)),
        equals({(ConfigService, null)}),
      );
      expect(
        graph.dependenciesOf((UserService, null)),
        equals({(DatabaseService, null)}),
      );
      expect(
        graph.dependenciesOf((UserService, null), transitive: true),
        equals({(DatabaseService, null), (ConfigService, null)}),
      );
    });

    test('topologicalOrder returns deterministic wave-sorted ordering', () {
      final configWire = Wire(ConfigService.new);
      final dbWire = Wire.takes<ConfigService>().to((_) => DatabaseService());
      final userWire = Wire.takes<DatabaseService>().to((_) => UserService());

      final graph = CircuitGraph([userWire, configWire, dbWire]).compile();

      expect(
        graph.topologicalOrder,
        equals([
          (ConfigService, null),
          (DatabaseService, null),
          (UserService, null),
        ]),
      );
    });

    test('dependentsOf and dependenciesOf throw WireNotFoundException for unknown keys', () {
      final graph = CircuitGraph([Wire(ConfigService.new)]).compile();

      expect(
        () => graph.dependentsOf((DatabaseService, null)),
        throwsA(isA<WireNotFoundException>()),
      );
      expect(
        () => graph.dependenciesOf((DatabaseService, null)),
        throwsA(isA<WireNotFoundException>()),
      );
    });

    test('dependentsOf, dependenciesOf, and topologicalOrder throw StateError when uncompiled', () {
      final graph = CircuitGraph([Wire(ConfigService.new)]);

      expect(() => graph.reverseDependencies, throwsStateError);
      expect(() => graph.topologicalOrder, throwsStateError);
      expect(() => graph.dependentsOf((ConfigService, null)), throwsStateError);
      expect(
        () => graph.dependenciesOf((ConfigService, null)),
        throwsStateError,
      );
    });
  });
}
