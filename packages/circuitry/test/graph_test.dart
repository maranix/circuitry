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
    });
  });
}
