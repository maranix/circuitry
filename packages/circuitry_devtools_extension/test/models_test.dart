import 'package:circuitry_devtools_extension/src/models/circuit_graph_data.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_status.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_summary.dart';
import 'package:circuitry_devtools_extension/src/models/wire_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitSummary Model', () {
    test('parses from JSON and supports value equality', () {
      final json = <String, Object?>{
        'id': 'circuit_0',
        'debugTag': 'AppScope.global',
        'wireCount': 6,
        'initializedWireCount': 2,
        'maxLevel': 2,
        'isDisposed': false,
        'status': 'ready',
      };

      final CircuitSummary summary = .fromJson(json);
      expect(summary.id, 'circuit_0');
      expect(summary.debugTag, 'AppScope.global');
      expect(summary.wireCount, 6);
      expect(summary.initializedWireCount, 2);
      expect(summary.uninitializedWireCount, 4);
      expect(summary.maxLevel, 2);
      expect(summary.isDisposed, isFalse);
      expect(summary.status, CircuitLifecycleStatus.ready);

      final copy = summary.copyWith(initializedWireCount: 3);
      expect(copy.initializedWireCount, 3);
      expect(copy.uninitializedWireCount, 3);
      expect(copy == summary, isFalse);
    });
  });

  group('WireNode Model', () {
    test('extracts typeName and tag from formatted key', () {
      const nodeUntagged = WireNode(
        key: 'UserService',
        dependencies: ['Database'],
        isAsync: false,
        topologicalLevel: 1,
        isInitialized: true,
      );
      expect(nodeUntagged.typeName, 'UserService');
      expect(nodeUntagged.tag, isNull);
      expect(nodeUntagged.isUnresolvedLazy, isFalse);

      const nodeTagged = WireNode(
        key: 'Database#primary',
        dependencies: [],
        isAsync: true,
        topologicalLevel: 0,
        isInitialized: false,
      );
      expect(nodeTagged.typeName, 'Database');
      expect(nodeTagged.tag, 'primary');
      expect(nodeTagged.isUnresolvedLazy, isFalse);

      const nodeLazy = WireNode(
        key: 'OrderNotifier',
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        isInitialized: false,
      );
      expect(nodeLazy.isUnresolvedLazy, isTrue);
    });

    test('parses from and converts to JSON', () {
      final json = <String, Object?>{
        'key': 'AnalyticsService#prod',
        'dependencies': ['Logger'],
        'isAsync': false,
        'topologicalLevel': 1,
        'isInitialized': true,
        'isResolving': false,
        'hasFailed': false,
        'durationMs': 12,
      };

      final WireNode node = .fromJson(json);
      expect(node.key, 'AnalyticsService#prod');
      expect(node.dependencies, ['Logger']);
      expect(node.isAsync, isFalse);
      expect(node.topologicalLevel, 1);
      expect(node.isInitialized, isTrue);
      expect(node.durationMs, 12);

      final outJson = node.toJson();
      expect(outJson['key'], 'AnalyticsService#prod');
      expect(outJson['durationMs'], 12);
    });
  });

  group('CircuitGraphData DAG Analysis', () {
    late CircuitGraphData graph;

    setUp(() {
      final wires = <WireNode>[
        const WireNode(
          key: 'A',
          dependencies: [],
          isAsync: false,
          topologicalLevel: 0,
          isInitialized: true,
          durationMs: 10,
        ),
        const WireNode(
          key: 'B',
          dependencies: ['A'],
          isAsync: true,
          topologicalLevel: 1,
          isInitialized: true,
          durationMs: 100,
        ),
        const WireNode(
          key: 'C',
          dependencies: ['A'],
          isAsync: false,
          topologicalLevel: 1,
          isInitialized: false,
          durationMs: 20,
        ),
        const WireNode(
          key: 'D',
          dependencies: ['B', 'C'],
          isAsync: false,
          topologicalLevel: 2,
          isInitialized: false,
          durationMs: 15,
        ),
      ];

      graph = CircuitGraphData(
        id: 'circuit_0',
        debugTag: 'AppScope.global',
        isDisposed: false,
        wireCount: 4,
        wires: wires,
        waves: {
          0: [wires[0]],
          1: [wires[1], wires[2]],
          2: [wires[3]],
        },
        maxWaveLevel: 2,
        topologicalOrder: ['A', 'B', 'C', 'D'],
      );
    });

    test('computes direct and transitive dependencies', () {
      expect(graph.dependenciesOf('A'), isEmpty);
      expect(graph.dependenciesOf('B'), {'A'});
      expect(graph.dependenciesOf('D', transitive: false), {'B', 'C'});
      expect(graph.dependenciesOf('D', transitive: true), {'A', 'B', 'C'});
    });

    test('computes direct and transitive dependents', () {
      expect(graph.dependentsOf('A', transitive: false), {'B', 'C'});
      expect(graph.dependentsOf('A', transitive: true), {'B', 'C', 'D'});
      expect(graph.dependentsOf('B', transitive: false), {'D'});
      expect(graph.dependentsOf('D'), isEmpty);
    });

    test('computes critical path via cumulative latency', () {
      final criticalPath = graph.computeCriticalPath();
      // Path A (10) -> B (100) -> D (15) is longer than A (10) -> C (20) -> D (15)
      expect(criticalPath, containsAll(['A', 'B', 'D']));
    });

    test('exports valid Mermaid flowchart with wave subgraphs', () {
      final mermaid = graph.toMermaid();
      expect(mermaid, startsWith('flowchart TD'));
      expect(mermaid, contains('subgraph wave_0 ["Wave 0"]'));
      expect(mermaid, contains('subgraph wave_1 ["Wave 1"]'));
      expect(mermaid, contains('subgraph wave_2 ["Wave 2"]'));
      expect(mermaid, contains('wire_A --> wire_B'));
      expect(mermaid, contains('wire_B --> wire_D'));
      expect(mermaid, contains('wire_C --> wire_D'));
      expect(mermaid, contains('classDef initialized'));
    });

    test('exports valid SVG markup with nodes and spline paths', () {
      final svg = graph.toSvg();
      expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg"'));
      expect(svg, contains('viewBox='));
      expect(svg, contains('<path d='));
      expect(svg, contains('<rect'));
      expect(svg, contains('A'));
      expect(svg, contains('B'));
      expect(svg, endsWith('</svg>\n'));
    });
  });
}
