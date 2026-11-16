// ignore_for_file: deprecated_member_use

import 'package:circuitry_devtools_extension/circuitry_devtools_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitNavigator', () {
    testWidgets('renders empty state when circuits list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CircuitNavigator(circuits: [])),
        ),
      );

      expect(find.text('Circuits'), findsOneWidget);
      expect(find.text('No active circuits detected'), findsOneWidget);
    });

    testWidgets('renders list of circuits with state badges and tags', (
      tester,
    ) async {
      final circuits = [
        const CircuitSummary(
          id: 'circuit_root',
          tag: 'main',
          state: 'ready',
          wireCount: 5,
        ),
        const CircuitSummary(
          id: 'circuit_auth',
          tag: 'auth_feature',
          state: 'building',
          wireCount: 2,
        ),
        const CircuitSummary(
          id: 'circuit_failed',
          state: 'failure',
          wireCount: 1,
        ),
      ];

      CircuitSummary? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircuitNavigator(
              circuits: circuits,
              selectedCircuitId: 'circuit_root',
              onSelect: (c) => selected = c,
            ),
          ),
        ),
      );

      expect(find.text('circuit_root'), findsOneWidget);
      expect(find.text('circuit_auth'), findsOneWidget);
      expect(find.text('circuit_failed'), findsOneWidget);

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Building'), findsOneWidget);
      expect(find.text('Failure'), findsOneWidget);

      expect(find.text('tag: main'), findsOneWidget);
      expect(find.text('tag: auth_feature'), findsOneWidget);

      expect(find.text('5 wires'), findsOneWidget);
      expect(find.text('2 wires'), findsOneWidget);
      expect(find.text('1 wire'), findsOneWidget);

      // Tap on circuit_auth
      await tester.tap(find.text('circuit_auth'));
      await tester.pump();

      expect(selected?.id, equals('circuit_auth'));
    });

    testWidgets('filters circuits matching search text', (tester) async {
      final circuits = [
        const CircuitSummary(id: 'circuit_alpha', state: 'ready', wireCount: 3),
        const CircuitSummary(id: 'circuit_beta', state: 'ready', wireCount: 2),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CircuitNavigator(circuits: circuits)),
        ),
      );

      expect(find.text('circuit_alpha'), findsOneWidget);
      expect(find.text('circuit_beta'), findsOneWidget);

      // Enter search term
      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pump();

      expect(find.text('circuit_alpha'), findsNothing);
      expect(find.text('circuit_beta'), findsOneWidget);
    });
  });

  group('DagCanvas', () {
    testWidgets('renders placeholder when graph has no nodes', (tester) async {
      final emptyGraph = LayoutGraph(
        nodes: const [],
        edges: const [],
        totalWidth: 0,
        totalHeight: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DagCanvas(graph: emptyGraph)),
        ),
      );

      expect(find.text('No wires registered in this circuit.'), findsOneWidget);
    });

    testWidgets('renders wave headers, nodes, and interactive controls', (
      tester,
    ) async {
      final nodes = [
        LayoutNode(
          id: 'Logger',
          keyLabel: 'Logger',
          waveLevel: 0,
          status: 'resolved',
          x: 20,
          y: 60,
        ),
        LayoutNode(
          id: 'ApiClient',
          keyLabel: 'ApiClient',
          waveLevel: 1,
          status: 'unresolvedLazy',
          x: 260,
          y: 60,
        ),
        LayoutNode(
          id: 'Database',
          keyLabel: 'Database',
          waveLevel: 1,
          status: 'resolving',
          x: 260,
          y: 160,
        ),
        LayoutNode(
          id: 'PaymentGateway',
          keyLabel: 'PaymentGateway',
          waveLevel: 2,
          status: 'failed',
          x: 500,
          y: 60,
        ),
      ];

      final edges = [
        LayoutEdge(
          fromId: 'Logger',
          toId: 'ApiClient',
          waypoints: const [
            LayoutPoint(180, 90),
            LayoutPoint(220, 90),
            LayoutPoint(220, 90),
            LayoutPoint(260, 90),
          ],
        ),
        LayoutEdge(
          fromId: 'ApiClient',
          toId: 'PaymentGateway',
          waypoints: const [
            LayoutPoint(420, 90),
            LayoutPoint(460, 90),
            LayoutPoint(460, 90),
            LayoutPoint(500, 90),
          ],
        ),
      ];

      final graph = LayoutGraph(
        nodes: nodes,
        edges: edges,
        totalWidth: 700,
        totalHeight: 300,
      );

      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DagCanvas(
              graph: graph,
              selectedNodeId: 'Logger',
              onNodeSelected: (id) => selected = id,
            ),
          ),
        ),
      );

      // Verify zoom controls are present
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);

      // Tap reset view
      await tester.tap(find.byIcon(Icons.center_focus_strong));
      await tester.pump();

      // Tap on node position
      await tester.tapAt(const Offset(30, 80));
      await tester.pump();

      expect(selected, equals('Logger'));
    });
  });

  group('WireDrawer', () {
    testWidgets('renders empty placeholder when no wire is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: WireDrawer(wire: null))),
      );

      expect(find.text('Wire Inspector'), findsOneWidget);
      expect(find.text('No Wire Selected'), findsOneWidget);
    });

    testWidgets('renders wire metadata, properties, and dependencies', (
      tester,
    ) async {
      const wire = WireModel(
        key: 'UserService(tag: primary)',
        typeName: 'UserService',
        tag: 'primary',
        dependencies: ['Database', 'Logger'],
        dependents: ['AuthController'],
        isAsync: true,
        waveLevel: 2,
        status: 'resolved',
        resolutionDuration: Duration(milliseconds: 15),
        isCriticalPath: true,
      );

      String? focusedWire;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WireDrawer(wire: wire, onSelectWire: (w) => focusedWire = w),
          ),
        ),
      );

      expect(find.text('UserService'), findsOneWidget);
      expect(find.text('primary'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Wave 2'), findsOneWidget);
      expect(find.text('Asynchronous'), findsOneWidget);
      expect(find.text('15.00 ms'), findsOneWidget);
      expect(find.text('Critical Path Node'), findsOneWidget);

      expect(find.text('Dependencies (2)'), findsOneWidget);
      expect(find.text('Database'), findsOneWidget);
      expect(find.text('Logger'), findsOneWidget);

      expect(find.text('Dependents (1)'), findsOneWidget);
      expect(find.text('AuthController'), findsOneWidget);

      // Click on dependency
      await tester.tap(find.text('Database'));
      await tester.pump();

      expect(focusedWire, equals('Database'));
    });

    testWidgets('renders Force Initialize button for unresolvedLazy wires', (
      tester,
    ) async {
      const lazyWire = WireModel(
        key: 'AnalyticsService',
        typeName: 'AnalyticsService',
        isAsync: false,
        waveLevel: 1,
        status: 'unresolvedLazy',
      );

      String? forceInitKey;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WireDrawer(
              wire: lazyWire,
              onForceInitialize: (k) => forceInitKey = k,
            ),
          ),
        ),
      );

      expect(find.text('Unresolved Lazy'), findsOneWidget);
      expect(find.text('Force Initialize'), findsOneWidget);

      await tester.tap(find.text('Force Initialize'));
      await tester.pump();

      expect(forceInitKey, equals('AnalyticsService'));
    });
  });

  group('WaveProfiler', () {
    testWidgets('renders empty message when wires are empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WaveProfiler(wires: [])),
        ),
      );

      expect(
        find.text('No wires available for wave profiling.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders wave sections, Gantt bars, and critical path metrics',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        const wires = [
          WireModel(
            key: 'Config',
            typeName: 'Config',
            isAsync: false,
            waveLevel: 0,
            status: 'resolved',
            resolutionDuration: Duration(milliseconds: 2),
            isCriticalPath: true,
          ),
          WireModel(
            key: 'Database',
            typeName: 'Database',
            dependencies: ['Config'],
            isAsync: true,
            waveLevel: 1,
            status: 'resolved',
            resolutionDuration: Duration(milliseconds: 10),
            isCriticalPath: true,
          ),
          WireModel(
            key: 'Cache',
            typeName: 'Cache',
            dependencies: ['Config'],
            isAsync: false,
            waveLevel: 1,
            status: 'resolved',
            resolutionDuration: Duration(milliseconds: 1),
            isCriticalPath: false,
          ),
        ];

        String? selectedWire;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WaveProfiler(
                wires: wires,
                criticalPath: const ['Config', 'Database'],
                totalDuration: const Duration(milliseconds: 12),
                onSelectWire: (w) => selectedWire = w,
              ),
            ),
          ),
        );

        expect(find.text('Wave Profiler & Critical Path'), findsOneWidget);
        expect(find.text('2 Waves'), findsOneWidget);
        expect(find.text('Critical Path: 2 nodes'), findsOneWidget);

        expect(find.text('Wave 0'), findsOneWidget);
        expect(find.text('Wave 1'), findsOneWidget);

        expect(find.text('Config'), findsOneWidget);
        expect(find.text('Database'), findsOneWidget);
        expect(find.text('Cache'), findsOneWidget);

        // Tap on Database bar
        await tester.tap(find.text('Database'));
        await tester.pump();

        expect(selectedWire, equals('Database'));

        // Toggle critical path switch
        await tester.ensureVisible(find.byType(Switch));
        await tester.tap(find.byType(Switch));
        await tester.pump();

        // Now Cache (not on critical path) should be filtered out
        expect(find.text('Cache'), findsNothing);
        expect(find.text('Database'), findsOneWidget);
      },
    );
  });

  group('CircuitryDashboard', () {
    testWidgets(
      'integrates CircuitNavigator, DagCanvas, WireDrawer, and WaveProfiler',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockClient = MockCircuitryClient();

        await tester.pumpWidget(
          MaterialApp(home: CircuitryDashboard(client: mockClient)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify dashboard title
        expect(find.text('Circuitry DAG Inspector'), findsOneWidget);

        // Verify CircuitNavigator on left
        expect(find.text('Circuits'), findsOneWidget);
        expect(find.text('circuit_app_root'), findsAtLeast(1));

        // Verify DagCanvas in center
        expect(find.byType(DagCanvas), findsOneWidget);

        // Verify WaveProfiler at bottom
        expect(find.byType(WaveProfiler), findsOneWidget);
        expect(find.text('Wave Profiler & Critical Path'), findsOneWidget);

        // Verify WireDrawer on right
        expect(find.byType(WireDrawer), findsOneWidget);
        expect(find.text('Wire Inspector'), findsOneWidget);

        // Select a circuit in CircuitNavigator
        await tester.tap(find.text('circuit_auth_feature'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('circuit_auth_feature'), findsAtLeast(1));
      },
    );
  });
}
