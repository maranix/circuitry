import 'package:circuitry_devtools_extension/circuitry_devtools_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SugiyamaLayout', () {
    const layout = SugiyamaLayout(
      columnWidth: 260.0,
      verticalMargin: 40.0,
      paddingX: 20.0,
      paddingY: 30.0,
    );

    test('empty graph produces empty layout graph with zero bounds', () {
      final graph = layout.execute(<LayoutNode>[], <LayoutEdge>[]);

      expect(graph.nodes, isEmpty);
      expect(graph.edges, isEmpty);
      expect(graph.totalWidth, equals(0.0));
      expect(graph.totalHeight, equals(0.0));
    });

    test('nodes in different waves have increasing X coordinates (wave column alignment)', () {
      final nodes = <LayoutNode>[
        LayoutNode(id: 'root_logger', keyLabel: 'Logger', waveLevel: 0),
        LayoutNode(id: 'root_config', keyLabel: 'Config', waveLevel: 0),
        LayoutNode(id: 'service_db', keyLabel: 'Database', waveLevel: 1),
        LayoutNode(id: 'service_api', keyLabel: 'ApiClient', waveLevel: 1),
        LayoutNode(id: 'consumer_user', keyLabel: 'UserService', waveLevel: 2),
        LayoutNode(
          id: 'consumer_orders',
          keyLabel: 'OrdersService',
          waveLevel: 2,
        ),
        LayoutNode(
          id: 'ui_controller',
          keyLabel: 'AppController',
          waveLevel: 3,
        ),
      ];

      final edges = <LayoutEdge>[
        LayoutEdge(fromId: 'root_config', toId: 'service_db'),
        LayoutEdge(fromId: 'root_logger', toId: 'service_api'),
        LayoutEdge(fromId: 'service_db', toId: 'consumer_user'),
        LayoutEdge(fromId: 'service_api', toId: 'consumer_orders'),
        LayoutEdge(fromId: 'consumer_user', toId: 'ui_controller'),
      ];

      final graph = layout.execute(nodes, edges);

      // Verify wave column alignment: all nodes in the same wave must share identical X
      final wave0Nodes = graph.nodes.where((n) => n.waveLevel == 0).toList();
      final wave1Nodes = graph.nodes.where((n) => n.waveLevel == 1).toList();
      final wave2Nodes = graph.nodes.where((n) => n.waveLevel == 2).toList();
      final wave3Nodes = graph.nodes.where((n) => n.waveLevel == 3).toList();

      expect(wave0Nodes.length, equals(2));
      expect(wave1Nodes.length, equals(2));
      expect(wave2Nodes.length, equals(2));
      expect(wave3Nodes.length, equals(1));

      // Exact mathematical column placement: paddingX + waveLevel * columnWidth
      for (final n in wave0Nodes) {
        expect(n.x, equals(20.0 + (0 * 260.0)));
      }
      for (final n in wave1Nodes) {
        expect(n.x, equals(20.0 + (1 * 260.0)));
      }
      for (final n in wave2Nodes) {
        expect(n.x, equals(20.0 + (2 * 260.0)));
      }
      for (final n in wave3Nodes) {
        expect(n.x, equals(20.0 + (3 * 260.0)));
      }

      // Verify strictly increasing X coordinates across topological progression
      expect(wave0Nodes.first.x, lessThan(wave1Nodes.first.x));
      expect(wave1Nodes.first.x, lessThan(wave2Nodes.first.x));
      expect(wave2Nodes.first.x, lessThan(wave3Nodes.first.x));
    });

    test('nodes in same wave are vertically separated without overlap', () {
      final nodes = <LayoutNode>[
        LayoutNode(
          id: 'w0_a',
          keyLabel: 'A',
          waveLevel: 0,
          width: 180.0,
          height: 60.0,
        ),
        LayoutNode(
          id: 'w0_b',
          keyLabel: 'B',
          waveLevel: 0,
          width: 180.0,
          height: 80.0, // Different custom height
        ),
        LayoutNode(
          id: 'w0_c',
          keyLabel: 'C',
          waveLevel: 0,
          width: 180.0,
          height: 50.0,
        ),
        LayoutNode(
          id: 'w0_d',
          keyLabel: 'D',
          waveLevel: 0,
          width: 180.0,
          height: 70.0,
        ),
      ];

      final graph = layout.execute(nodes, <LayoutEdge>[]);

      final sortedByY = List<LayoutNode>.of(graph.nodes)
        ..sort((a, b) => a.y.compareTo(b.y));

      for (int i = 0; i < sortedByY.length - 1; i++) {
        final current = sortedByY[i];
        final next = sortedByY[i + 1];

        // The top of the next node must be separated by at least verticalMargin
        final gap = next.y - (current.y + current.height);
        expect(
          gap,
          greaterThanOrEqualTo(layout.verticalMargin),
          reason: 'Node ${next.id} must not overlap node ${current.id}',
        );

        // Bounding box intersection check (should strictly be false)
        final overlaps = current.y < next.bottom && current.bottom > next.y;
        expect(overlaps, isFalse);
      }
    });

    test('edges have valid cubic Bézier waypoints', () {
      final nodeA = LayoutNode(
        id: 'node_a',
        keyLabel: 'Source',
        waveLevel: 0,
        width: 160.0,
        height: 60.0,
      );
      final nodeB = LayoutNode(
        id: 'node_b',
        keyLabel: 'Target',
        waveLevel: 1,
        width: 160.0,
        height: 80.0,
      );

      final edge = LayoutEdge(fromId: 'node_a', toId: 'node_b');

      final graph = layout.execute(
        <LayoutNode>[nodeA, nodeB],
        <LayoutEdge>[edge],
      );

      expect(graph.edges.length, equals(1));
      final routedEdge = graph.edges.first;

      // Must have exactly 4 cubic Bézier waypoints: [start, cp1, cp2, end]
      expect(routedEdge.waypoints.length, equals(4));

      final start = routedEdge.start!;
      final cp1 = routedEdge.controlPoint1!;
      final cp2 = routedEdge.controlPoint2!;
      final end = routedEdge.end!;

      final resolvedA = graph.findNode('node_a')!;
      final resolvedB = graph.findNode('node_b')!;

      // 1. Start point must sit at right-center of source node
      expect(start.x, equals(resolvedA.right));
      expect(start.y, equals(resolvedA.centerY));

      // 2. End point must sit at left-center of target node
      expect(end.x, equals(resolvedB.x));
      expect(end.y, equals(resolvedB.centerY));

      // 3. Control point 1 must have horizontal tangent from start
      expect(cp1.y, equals(start.y));
      expect(cp1.x, greaterThan(start.x));

      // 4. Control point 2 must have horizontal tangent entering target
      expect(cp2.y, equals(end.y));
      expect(cp2.x, lessThan(end.x));

      // 5. Waypoints must progress horizontally from start to end
      expect(start.x, lessThanOrEqualTo(cp1.x));
      expect(cp1.x, lessThanOrEqualTo(end.x));
      expect(cp2.x, greaterThanOrEqualTo(start.x));
    });

    test('barycentric ordering reduces edge crossings', () {
      // Classic crossing setup:
      // Wave 0: A (index 0), B (index 1)
      // Wave 1: C (index 0), D (index 1)
      // Edges: A -> D (crosses down), B -> C (crosses up)
      final nodeA = LayoutNode(id: 'A', keyLabel: 'A', waveLevel: 0);
      final nodeB = LayoutNode(id: 'B', keyLabel: 'B', waveLevel: 0);
      final nodeC = LayoutNode(id: 'C', keyLabel: 'C', waveLevel: 1);
      final nodeD = LayoutNode(id: 'D', keyLabel: 'D', waveLevel: 1);

      final edges = <LayoutEdge>[
        LayoutEdge(fromId: 'A', toId: 'D'),
        LayoutEdge(fromId: 'B', toId: 'C'),
      ];

      // Initial crossings count with original order:
      // Edge (A->D) and Edge (B->C) cross!
      final initialCrossings = SugiyamaLayout.countEdgeCrossings(<LayoutNode>[
        nodeA,
        nodeB,
        nodeC,
        nodeD,
      ], edges);
      expect(initialCrossings, equals(1));

      // Execute layout with barycentric crossing reduction
      final graph = layout.execute(<LayoutNode>[
        nodeA,
        nodeB,
        nodeC,
        nodeD,
      ], edges);

      final wave1Nodes = graph.nodes.where((n) => n.waveLevel == 1).toList()
        ..sort((a, b) => a.y.compareTo(b.y));

      // Barycenter of D connected to A (index 0) = 0.0
      // Barycenter of C connected to B (index 1) = 1.0
      // Therefore D must now be ordered above C!
      expect(wave1Nodes.first.id, equals('D'));
      expect(wave1Nodes.last.id, equals('C'));

      // In the new layout, A -> D and B -> C run in parallel: crossings = 0!
      final finalCrossings = SugiyamaLayout.countEdgeCrossings(
        graph.nodes,
        edges,
      );
      expect(finalCrossings, equals(0));
      expect(finalCrossings, lessThan(initialCrossings));
    });

    test('barycentric ordering handles complex multi-layer graphs and reduces crossings', () {
      // Multi-layer crossing setup:
      // Wave 0: N0, N1, N2
      // Wave 1: N3, N4, N5
      // Reverse crossing edges
      final nodes = <LayoutNode>[
        LayoutNode(id: 'N0', keyLabel: 'N0', waveLevel: 0),
        LayoutNode(id: 'N1', keyLabel: 'N1', waveLevel: 0),
        LayoutNode(id: 'N2', keyLabel: 'N2', waveLevel: 0),
        LayoutNode(id: 'N3', keyLabel: 'N3', waveLevel: 1),
        LayoutNode(id: 'N4', keyLabel: 'N4', waveLevel: 1),
        LayoutNode(id: 'N5', keyLabel: 'N5', waveLevel: 1),
      ];

      final edges = <LayoutEdge>[
        LayoutEdge(fromId: 'N0', toId: 'N5'), // 0 -> 2
        LayoutEdge(fromId: 'N1', toId: 'N4'), // 1 -> 1
        LayoutEdge(fromId: 'N2', toId: 'N3'), // 2 -> 0
      ];

      final initialCrossings = SugiyamaLayout.countEdgeCrossings(nodes, edges);
      // Inverted 3-edge permutation has 3 crossings
      expect(initialCrossings, equals(3));

      final graph = layout.execute(nodes, edges);
      final finalCrossings = SugiyamaLayout.countEdgeCrossings(
        graph.nodes,
        edges,
      );

      expect(finalCrossings, equals(0));
      expect(finalCrossings, lessThan(initialCrossings));
    });

    test('calculates canvas bounding box dimensions correctly', () {
      final nodes = <LayoutNode>[
        LayoutNode(
          id: 'w0',
          keyLabel: 'W0',
          waveLevel: 0,
          width: 160.0,
          height: 60.0,
        ),
        LayoutNode(
          id: 'w1',
          keyLabel: 'W1',
          waveLevel: 1,
          width: 160.0,
          height: 60.0,
        ),
      ];

      final graph = layout.execute(nodes, <LayoutEdge>[]);

      // Wave 0: x = 20, right = 180
      // Wave 1: x = 20 + 260 = 280, right = 440
      // totalWidth = maxRight + paddingX = 440 + 20 = 460
      expect(graph.totalWidth, equals(460.0));

      // Both nodes at y = 30, bottom = 90
      // totalHeight = maxBottom + paddingY = 90 + 30 = 120
      expect(graph.totalHeight, equals(120.0));
    });

    test(
      'tolerates edges with missing or invalid node references gracefully',
      () {
        final node = LayoutNode(id: 'valid', keyLabel: 'Valid', waveLevel: 0);
        final edge = LayoutEdge(fromId: 'valid', toId: 'non_existent');

        final graph = layout.execute(<LayoutNode>[node], <LayoutEdge>[edge]);

        expect(graph.edges.length, equals(1));
        expect(graph.edges.first.waypoints, isEmpty);
      },
    );

    test('provides positional and convenience constructors for all models', () {
      const point = LayoutPoint(10.0, 20.0);
      expect(point.x, equals(10.0));
      expect(point.y, equals(20.0));
      expect(point.toString(), equals('LayoutPoint(10.0, 20.0)'));

      final node = LayoutNode.positional(
        'id1',
        'Label',
        0,
        150.0,
        50.0,
        10.0,
        20.0,
        'failed',
      );
      expect(node.id, equals('id1'));
      expect(node.status, equals('failed'));
      expect(node.centerX, equals(85.0));
      expect(node.centerY, equals(45.0));

      final edge = LayoutEdge.positional('id1', 'id2', <LayoutPoint>[point]);
      expect(edge.fromId, equals('id1'));
      expect(edge.start, equals(point));

      final graph = LayoutGraph.positional(
        <LayoutNode>[node],
        <LayoutEdge>[edge],
        500.0,
        400.0,
      );
      expect(graph.findNode('id1'), equals(node));
      expect(graph.findNode('missing'), isNull);
    });
  });
}
