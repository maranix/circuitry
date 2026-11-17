import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_status.dart';
import 'package:circuitry_devtools_extension/src/services/mock_circuitry_service_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitryDevToolsController State Operations', () {
    late MockCircuitryServiceClient client;
    late CircuitryDevToolsController controller;

    setUp(() {
      client = MockCircuitryServiceClient();
      controller = CircuitryDevToolsController(client);
    });

    tearDown(() {
      controller.dispose();
      client.dispose();
    });

    test('initializes and auto-selects first circuit', () async {
      await controller.init();

      expect(controller.circuits.length, 2);
      expect(controller.selectedCircuitId, 'circuit_0');
      expect(controller.graphData, isNotNull);
      expect(controller.graphData!.id, 'circuit_0');
      expect(controller.graphData!.wires.length, 6);
      expect(controller.selectedWire, isNull);
    });

    test('selects another circuit and updates DAG graph data', () async {
      await controller.init();

      await controller.selectCircuit('circuit_1');
      expect(controller.selectedCircuitId, 'circuit_1');
      expect(controller.selectedCircuit?.debugTag, 'FeatureScope.orders');
      expect(controller.graphData?.wires.length, 3);
    });

    test('manages wire selection and dependency illumination sets', () async {
      await controller.init();

      controller.selectWireByKey('UserFacade');
      expect(controller.selectedWire, isNotNull);
      expect(controller.selectedWire!.key, 'UserFacade');

      // Upstream dependencies of UserFacade: AuthRepository, AnalyticsService#prod, DatabaseConnection, AppConfig, LoggerService
      final deps = controller.highlightedDependencies;
      expect(
        deps,
        containsAll([
          'AuthRepository',
          'AnalyticsService#prod',
          'DatabaseConnection',
          'AppConfig',
          'LoggerService',
        ]),
      );

      // Dependents of UserFacade: none (leaf)
      expect(controller.highlightedDependents, isEmpty);

      // Deselect by toggling same node
      controller.selectWire(controller.selectedWire);
      expect(controller.selectedWire, isNull);
      expect(controller.highlightedDependencies, isEmpty);
    });

    test('manages search query and filter toggles', () async {
      await controller.init();

      controller.setSearchQuery('auth');
      expect(controller.searchQuery, 'auth');

      expect(controller.showUnresolvedOnly, isFalse);
      controller.toggleUnresolvedOnly();
      expect(controller.showUnresolvedOnly, isTrue);

      expect(controller.showAsyncOnly, isFalse);
      controller.toggleAsyncOnly();
      expect(controller.showAsyncOnly, isTrue);

      expect(controller.highlightCriticalPath, isFalse);
      controller.toggleCriticalPath();
      expect(controller.highlightCriticalPath, isTrue);
      expect(controller.criticalPath.isNotEmpty, isTrue);

      expect(controller.isWaterfallView, isFalse);
      controller.setWaterfallView(true);
      expect(controller.isWaterfallView, isTrue);
    });

    test('forceResolveWire updates node status and circuit initialized counter in-place', () async {
      await controller.init();

      // AnalyticsService#prod is uninitialized lazy in circuit_0
      final initialNode = controller.graphData!.findNode(
        'AnalyticsService#prod',
      )!;
      expect(initialNode.isInitialized, isFalse);
      final initialResolvedCount =
          controller.selectedCircuit!.initializedWireCount;

      controller.selectWire(initialNode);

      final success = await controller.forceResolveWire(
        'AnalyticsService#prod',
      );
      expect(success, isTrue);

      // Node should now be initialized
      final updatedNode = controller.graphData!.findNode(
        'AnalyticsService#prod',
      )!;
      expect(updatedNode.isInitialized, isTrue);
      expect(controller.selectedWire?.isInitialized, isTrue);
      expect(
        controller.selectedCircuit!.initializedWireCount,
        initialResolvedCount + 1,
      );
    });

    test('reacts to real-time extension stream events', () async {
      await controller.init();

      // Emit circuit_building event for new circuit
      client.emitEvent({
        'type': 'circuit_building',
        'circuitId': 'circuit_new',
        'debugTag': 'FeatureScope.payment',
      });
      await pumpEventQueue();

      final newSummary = controller.circuits.firstWhere(
        (c) => c.id == 'circuit_new',
      );
      expect(newSummary.debugTag, 'FeatureScope.payment');
      expect(newSummary.status, CircuitLifecycleStatus.building);

      // Emit circuit_failed event
      client.emitEvent({
        'type': 'circuit_failed',
        'circuitId': 'circuit_new',
        'error': 'Connection refused',
      });
      await pumpEventQueue();
      expect(
        controller.circuits.firstWhere((c) => c.id == 'circuit_new').status,
        CircuitLifecycleStatus.failed,
      );

      // Emit circuit_disposed event
      client.emitEvent({'type': 'circuit_disposed', 'circuitId': 'circuit_0'});
      await pumpEventQueue();
      expect(
        controller.circuits.firstWhere((c) => c.id == 'circuit_0').isDisposed,
        isTrue,
      );
      expect(
        controller.circuits.firstWhere((c) => c.id == 'circuit_0').status,
        CircuitLifecycleStatus.disposed,
      );
    });
  });
}
