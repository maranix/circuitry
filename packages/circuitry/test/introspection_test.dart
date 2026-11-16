import 'dart:convert';

import 'package:circuitry/circuitry.dart';
import 'package:test/test.dart';

enum TestEnv { dev, prod }

final class Config {
  final String name;
  Config(this.name);
}

final class Database {
  final Config config;
  Database(this.config);
}

final class Repository {
  final Database database;
  Repository(this.database);
}

final class ServiceA {
  ServiceA();
}

final class ServiceB {
  final ServiceA a;
  ServiceB(this.a);
}

final class ServiceC {
  final ServiceA a;
  ServiceC(this.a);
}

final class ServiceD {
  final ServiceB b;
  final ServiceC c;
  ServiceD(this.b, this.c);
}

final class IsolatedService {}

void main() {
  group('WireStatus', () {
    test('contains all expected lifecycle status values', () {
      expect(
        WireStatus.values,
        containsAll([
          WireStatus.unresolvedLazy,
          WireStatus.resolving,
          WireStatus.resolved,
          WireStatus.failed,
          WireStatus.disposed,
        ]),
      );
    });
  });

  group('WireDescriptor', () {
    test('instantiates and provides field accessors', () {
      const descriptor = WireDescriptor(
        key: (String, null),
        dependencies: [(int, null)],
        isAsync: true,
        topologicalLevel: 1,
        status: WireStatus.resolved,
        resolutionDuration: Duration(milliseconds: 15),
      );

      expect(descriptor.key, equals((String, null)));
      expect(descriptor.dependencies, equals([(int, null)]));
      expect(descriptor.isAsync, isTrue);
      expect(descriptor.topologicalLevel, equals(1));
      expect(descriptor.status, equals(WireStatus.resolved));
      expect(
        descriptor.resolutionDuration,
        equals(const Duration(milliseconds: 15)),
      );
    });

    test('toJson serializes descriptor properly', () {
      const descriptor = WireDescriptor(
        key: (String, null),
        dependencies: [(int, null)],
        isAsync: true,
        topologicalLevel: 1,
        status: WireStatus.resolved,
        resolutionDuration: Duration(milliseconds: 15),
      );

      final json = descriptor.toJson();
      expect(json['key'], equals('String'));
      expect(json['dependencies'], equals(['int']));
      expect(json['isAsync'], isTrue);
      expect(json['topologicalLevel'], equals(1));
      expect(json['status'], equals('resolved'));
      expect(json['resolutionDurationMicros'], equals(15000));
    });

    test('toJson formats tagged keys properly', () {
      const descriptor = WireDescriptor(
        key: (Config, TestEnv.prod),
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        status: WireStatus.unresolvedLazy,
      );

      final json = descriptor.toJson();
      expect(json['key'], equals('Config(tag: TestEnv.prod)'));
      expect(json['dependencies'], isEmpty);
      expect(json['status'], equals('unresolvedLazy'));
      expect(json.containsKey('resolutionDurationMicros'), isFalse);
    });

    test('copyWith creates updated descriptor clone', () {
      const descriptor = WireDescriptor(
        key: (String, null),
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        status: WireStatus.unresolvedLazy,
      );

      final updated = descriptor.copyWith(
        status: WireStatus.resolved,
        resolutionDuration: const Duration(milliseconds: 5),
      );

      expect(updated.key, equals((String, null)));
      expect(updated.status, equals(WireStatus.resolved));
      expect(
        updated.resolutionDuration,
        equals(const Duration(milliseconds: 5)),
      );
      expect(descriptor.status, equals(WireStatus.unresolvedLazy));
    });

    test('equality and hashCode match identical descriptors', () {
      const desc1 = WireDescriptor(
        key: (String, null),
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        status: WireStatus.unresolvedLazy,
      );

      const desc2 = WireDescriptor(
        key: (String, null),
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        status: WireStatus.unresolvedLazy,
      );

      expect(desc1, equals(desc2));
      expect(desc1.hashCode, equals(desc2.hashCode));
      expect(desc1.toString(), contains('WireDescriptor'));
    });
  });

  group('CircuitIntrospection.of and circuit.inspect', () {
    test(
      'both factory entrypoints return CircuitIntrospection instance',
      () async {
        final circuit = await Circuit.build([Wire(() => Config('test'))]);

        final inspectResult = circuit.inspect();
        final ofResult = CircuitIntrospection.of(circuit);

        expect(inspectResult, isA<CircuitIntrospectionImpl>());
        expect(ofResult, isA<CircuitIntrospectionImpl>());
        expect(inspectResult.wires.length, equals(1));
        expect(ofResult.wires.length, equals(1));

        await circuit.dispose();
      },
    );
  });

  group('Empty Circuit Introspection', () {
    test(
      'empty circuit introspection returns consistent empty metadata',
      () async {
        final circuit = await Circuit.build([]);
        final introspection = circuit.inspect();

        expect(introspection.wires, isEmpty);
        expect(introspection.waves, isEmpty);
        expect(introspection.maxWaveLevel, equals(0));
        expect(introspection.topologicalOrder, isEmpty);
        expect(introspection.findOrphanWires(), isEmpty);
        expect(introspection.detectCriticalPath(), isEmpty);

        final mermaid = introspection.toMermaid();
        expect(mermaid, equals('flowchart TD'));

        final dot = introspection.toDot();
        expect(dot, contains('digraph Circuit {'));
        expect(dot, contains('node [shape=box, style=filled];'));

        final json = introspection.toJson();
        expect(json['wires'], equals([]));
        expect(json['waves'], equals({}));
        expect(json['maxWaveLevel'], equals(0));
        expect(() => jsonEncode(json), returnsNormally);

        expect(
          () => introspection.statusOf((Config, null)),
          throwsA(isA<WireNotFoundException>()),
        );
        expect(
          () => introspection.dependenciesOf((Config, null)),
          throwsA(isA<WireNotFoundException>()),
        );
        expect(
          () => introspection.dependentsOf((Config, null)),
          throwsA(isA<WireNotFoundException>()),
        );

        await circuit.dispose();
      },
    );
  });

  group('Linear Dependency Chain DAG', () {
    late Circuit circuit;
    late CircuitIntrospection introspection;

    setUp(() async {
      circuit = await Circuit.build([
        Wire(() => Config('linear.db')),
        Wire.takes<Config>().to(Database.new),
        Wire.takes<Database>().to(Repository.new),
      ]);
      introspection = circuit.inspect();
    });

    tearDown(() async {
      await circuit.dispose();
    });

    test(
      'wires returns descriptors with correct topological levels and keys',
      () {
        final wires = introspection.wires;
        expect(wires.length, equals(3));

        final configWire = wires.firstWhere((w) => w.key == (Config, null));
        expect(configWire.topologicalLevel, equals(0));
        expect(configWire.dependencies, isEmpty);
        expect(configWire.isAsync, isFalse);

        final dbWire = wires.firstWhere((w) => w.key == (Database, null));
        expect(dbWire.topologicalLevel, equals(1));
        expect(dbWire.dependencies, equals([(Config, null)]));

        final repoWire = wires.firstWhere((w) => w.key == (Repository, null));
        expect(repoWire.topologicalLevel, equals(2));
        expect(repoWire.dependencies, equals([(Database, null)]));
      },
    );

    test('waves groups descriptors by topological level', () {
      final waves = introspection.waves;
      expect(waves.keys, containsAllInOrder([0, 1, 2]));
      expect(waves[0]!.map((w) => w.key), equals([(Config, null)]));
      expect(waves[1]!.map((w) => w.key), equals([(Database, null)]));
      expect(waves[2]!.map((w) => w.key), equals([(Repository, null)]));
      expect(introspection.maxWaveLevel, equals(2));
    });

    test(
      'dependenciesOf resolves direct and transitive upstream dependencies',
      () {
        expect(introspection.dependenciesOf((Config, null)), isEmpty);
        expect(
          introspection.dependenciesOf((Config, null), transitive: true),
          isEmpty,
        );

        expect(
          introspection.dependenciesOf((Database, null)),
          equals([(Config, null)]),
        );
        expect(
          introspection.dependenciesOf((Database, null), transitive: true),
          equals([(Config, null)]),
        );

        expect(
          introspection.dependenciesOf((Repository, null)),
          equals([(Database, null)]),
        );
        expect(
          introspection.dependenciesOf((Repository, null), transitive: true),
          equals([(Database, null), (Config, null)]),
        );
      },
    );

    test(
      'dependentsOf resolves direct and transitive downstream dependents',
      () {
        expect(introspection.dependentsOf((Repository, null)), isEmpty);
        expect(
          introspection.dependentsOf((Repository, null), transitive: true),
          isEmpty,
        );

        expect(
          introspection.dependentsOf((Database, null)),
          equals([(Repository, null)]),
        );
        expect(
          introspection.dependentsOf((Database, null), transitive: true),
          equals([(Repository, null)]),
        );

        expect(
          introspection.dependentsOf((Config, null)),
          equals([(Database, null)]),
        );
        expect(
          introspection.dependentsOf((Config, null), transitive: true),
          equals([(Database, null), (Repository, null)]),
        );
      },
    );

    test('topologicalOrder returns wire keys in ascending wave order', () {
      final order = introspection.topologicalOrder;
      expect(
        order,
        equals([(Config, null), (Database, null), (Repository, null)]),
      );
    });

    test('findOrphanWires detects only leaf wires with no dependents', () {
      final orphans = introspection.findOrphanWires();
      expect(orphans, equals([(Repository, null)]));
    });

    test('detectCriticalPath computes full longest path from root to leaf', () {
      final criticalPath = introspection.detectCriticalPath();
      expect(
        criticalPath,
        equals([(Config, null), (Database, null), (Repository, null)]),
      );
    });
  });

  group('Diamond DAG Introspection', () {
    late Circuit circuit;
    late CircuitIntrospection introspection;

    setUp(() async {
      circuit = await Circuit.build([
        Wire(ServiceA.new),
        Wire.takes<ServiceA>().to(ServiceB.new),
        Wire.takes<ServiceA>().to(ServiceC.new),
        Wire.takes<ServiceB>().takes<ServiceC>().to(
          (deps) => ServiceD(deps.$1, deps.$2),
        ),
      ]);
      introspection = circuit.inspect();
    });

    tearDown(() async {
      await circuit.dispose();
    });

    test('waves correctly structures diamond DAG', () {
      final waves = introspection.waves;
      expect(waves.length, equals(3));
      expect(waves[0]!.map((w) => w.key), equals([(ServiceA, null)]));
      expect(
        waves[1]!.map((w) => w.key),
        containsAll([(ServiceB, null), (ServiceC, null)]),
      );
      expect(waves[2]!.map((w) => w.key), equals([(ServiceD, null)]));
      expect(introspection.maxWaveLevel, equals(2));
    });

    test('dependenciesOf resolves transitive diamond dependencies without duplicates', () {
      final transitiveDeps = introspection.dependenciesOf((
        ServiceD,
        null,
      ), transitive: true);
      expect(
        transitiveDeps,
        containsAllInOrder([
          (ServiceB, null),
          (ServiceC, null),
          (ServiceA, null),
        ]),
      );
      expect(transitiveDeps.length, equals(3));
    });

    test(
      'dependentsOf resolves transitive diamond dependents without duplicates',
      () {
        final transitiveDownstream = introspection.dependentsOf((
          ServiceA,
          null,
        ), transitive: true);
        expect(
          transitiveDownstream,
          containsAll([(ServiceB, null), (ServiceC, null), (ServiceD, null)]),
        );
        expect(transitiveDownstream.length, equals(3));
      },
    );

    test('findOrphanWires identifies diamond sink', () {
      expect(introspection.findOrphanWires(), equals([(ServiceD, null)]));
    });

    test('detectCriticalPath returns length 3 path through diamond', () {
      final criticalPath = introspection.detectCriticalPath();
      expect(criticalPath.length, equals(3));
      expect(criticalPath.first, equals((ServiceA, null)));
      expect(criticalPath.last, equals((ServiceD, null)));
      expect(
        criticalPath[1] == (ServiceB, null) ||
            criticalPath[1] == (ServiceC, null),
        isTrue,
      );
    });
  });

  group('Disconnected Graphs and Tagged Wires', () {
    test(
      'findOrphanWires correctly finds multiple leaves and isolated wires',
      () async {
        final circuit = await Circuit.build([
          Wire(ServiceA.new),
          Wire.takes<ServiceA>().to(ServiceB.new),
          Wire(IsolatedService.new),
          Wire.tag(() => Config('prod'), tag: TestEnv.prod),
        ]);
        final introspection = circuit.inspect();

        final orphans = introspection.findOrphanWires();
        expect(
          orphans,
          containsAll([
            (ServiceB, null),
            (IsolatedService, null),
            (Config, TestEnv.prod),
          ]),
        );

        await circuit.dispose();
      },
    );
  });

  group('Runtime statusOf Lifecycle Transitions', () {
    test(
      'tracks unresolvedLazy -> resolving -> resolved -> disposed',
      () async {
        late Circuit circuit;
        late CircuitIntrospection introspection;
        var checkedResolving = false;

        final wire = Wire<ServiceA>(() {
          expect(
            introspection.statusOf((ServiceA, null)),
            equals(WireStatus.resolving),
          );
          checkedResolving = true;
          return ServiceA();
        });

        circuit = await Circuit.build([wire]);
        introspection = circuit.inspect();

        // Initially lazy and unrequested
        expect(
          introspection.statusOf((ServiceA, null)),
          equals(WireStatus.unresolvedLazy),
        );

        // Request instance, triggers factory which verifies resolving state
        final instance = circuit.get<ServiceA>();
        expect(instance, isNotNull);
        expect(checkedResolving, isTrue);

        // Now resolved and memoized
        expect(
          introspection.statusOf((ServiceA, null)),
          equals(WireStatus.resolved),
        );

        // After circuit disposal
        await circuit.dispose();
        expect(
          introspection.statusOf((ServiceA, null)),
          equals(WireStatus.disposed),
        );
      },
    );

    test('async wires are resolved after circuit build', () async {
      final circuit = await Circuit.build([
        AsyncWire<Config>(() async => Config('async-config')),
      ]);
      final introspection = circuit.inspect();

      expect(
        introspection.statusOf((Config, null)),
        equals(WireStatus.resolved),
      );

      final descriptor = introspection.wires.first;
      expect(descriptor.isAsync, isTrue);
      expect(descriptor.status, equals(WireStatus.resolved));

      await circuit.dispose();
      expect(
        introspection.statusOf((Config, null)),
        equals(WireStatus.disposed),
      );
    });
  });

  group('toMermaid Flowchart Generation', () {
    late Circuit circuit;
    late CircuitIntrospection introspection;

    setUp(() async {
      circuit = await Circuit.build([
        Wire(() => Config('cfg')),
        Wire.takes<Config>().to(Database.new),
        Wire.tag(() => Config('prod-cfg'), tag: TestEnv.prod),
      ]);
      introspection = circuit.inspect();
    });

    tearDown(() async {
      await circuit.dispose();
    });

    test('generates valid flowchart with wave subgraphs and class styling', () {
      final mermaid = introspection.toMermaid();

      expect(mermaid, startsWith('flowchart TD'));
      expect(mermaid, contains('subgraph wave_0 ["Wave 0"]'));
      expect(mermaid, contains('subgraph wave_1 ["Wave 1"]'));
      expect(mermaid, contains('classDef resolved'));
      expect(mermaid, contains('classDef unresolvedLazy'));
      expect(mermaid, contains('-->'));
      expect(mermaid, contains('Config(tag: TestEnv.prod)'));
    });

    test('supports disabling wave grouping and status styling', () {
      final flatMermaid = introspection.toMermaid(
        groupByWave: false,
        showStatus: false,
      );

      expect(flatMermaid, startsWith('flowchart TD'));
      expect(flatMermaid, isNot(contains('subgraph')));
      expect(flatMermaid, isNot(contains('classDef')));
      expect(flatMermaid, isNot(contains('class ')));
      expect(flatMermaid, contains('-->'));
    });
  });

  group('toDot Graphviz DOT Generation', () {
    late Circuit circuit;
    late CircuitIntrospection introspection;

    setUp(() async {
      circuit = await Circuit.build([
        Wire(() => Config('cfg')),
        Wire.takes<Config>().to(Database.new),
      ]);
      introspection = circuit.inspect();
    });

    tearDown(() async {
      await circuit.dispose();
    });

    test('generates valid DOT with status colors', () {
      final dot = introspection.toDot(showStatus: true);

      expect(dot, startsWith('digraph Circuit {'));
      expect(dot, contains('rankdir=TB;'));
      expect(dot, contains('node [shape=box, style=filled];'));
      expect(dot, contains('fillcolor='));
      expect(dot, contains('->'));
      expect(dot, endsWith('}'));
    });

    test('generates plain DOT without fillcolor when showStatus is false', () {
      final dot = introspection.toDot(showStatus: false);

      expect(dot, startsWith('digraph Circuit {'));
      expect(dot, isNot(contains('fillcolor=')));
      expect(dot, contains('->'));
      expect(dot, endsWith('}'));
    });
  });

  group('toJson Serialization', () {
    test('serializes structured introspection to JSON map', () async {
      final circuit = await Circuit.build([
        Wire(() => Config('cfg')),
        Wire.takes<Config>().to(Database.new),
      ]);
      final introspection = circuit.inspect();

      final json = introspection.toJson();
      expect(json['wires'], isA<List<Object?>>());
      expect(json['waves'], isA<Map<String, Object?>>());
      expect(json['maxWaveLevel'], equals(1));

      final wavesMap = json['waves'] as Map<String, Object?>;
      expect(wavesMap.containsKey('0'), isTrue);
      expect(wavesMap.containsKey('1'), isTrue);

      final encoded = jsonEncode(json);
      expect(encoded, isA<String>());
      expect(encoded, contains('"maxWaveLevel":1'));

      await circuit.dispose();
    });
  });
}
