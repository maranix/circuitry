import 'dart:async';

import 'package:circuitry_devtools_extension/src/models/circuit_graph_data.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_status.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_summary.dart';
import 'package:circuitry_devtools_extension/src/models/wire_node.dart';
import 'package:circuitry_devtools_extension/src/services/circuitry_service_client.dart';

/// In-memory mock implementation of [CircuitryServiceClient] for unit tests,
/// widget tests, and offline UI development.
final class MockCircuitryServiceClient implements CircuitryServiceClient {
  MockCircuitryServiceClient({
    List<CircuitSummary>? initialCircuits,
    Map<String, CircuitGraphData>? initialGraphs,
  }) : _eventController = StreamController<Map<String, Object?>>.broadcast() {
    if (initialCircuits != null) {
      _circuits.addAll(initialCircuits);
    } else {
      _populateDefaultMockData();
    }

    if (initialGraphs != null) {
      _graphs.addAll(initialGraphs);
    }
  }

  final StreamController<Map<String, Object?>> _eventController;
  final List<CircuitSummary> _circuits = [];
  final Map<String, CircuitGraphData> _graphs = {};

  @override
  Stream<Map<String, Object?>> get onCircuitryEvent => _eventController.stream;

  void emitEvent(Map<String, Object?> event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  @override
  Future<List<CircuitSummary>> getCircuits() async =>
      List.unmodifiable(_circuits);

  @override
  Future<CircuitGraphData> getCircuitGraph(String circuitId) async {
    final graph = _graphs[circuitId];
    if (graph == null) {
      throw StateError('Circuit "$circuitId" not found in mock service.');
    }
    return graph;
  }

  @override
  Future<bool> forceResolveWire(String circuitId, String wireKey) async {
    final graph = _graphs[circuitId];
    if (graph == null) return false;

    final targetNode = graph.findNode(wireKey);
    if (targetNode == null) return false;

    // Mutate node to initialized
    final updatedWires = graph.wires.map((w) {
      if (w.key == wireKey) {
        return w.copyWith(isInitialized: true);
      }
      return w;
    }).toList();

    final updatedWaves = <int, List<WireNode>>{};
    for (final entry in graph.waves.entries) {
      updatedWaves[entry.key] = entry.value.map((w) {
        if (w.key == wireKey) {
          return w.copyWith(isInitialized: true);
        }
        return w;
      }).toList();
    }

    _graphs[circuitId] = CircuitGraphData(
      id: graph.id,
      debugTag: graph.debugTag,
      isDisposed: graph.isDisposed,
      wireCount: graph.wireCount,
      wires: updatedWires,
      waves: updatedWaves,
      maxWaveLevel: graph.maxWaveLevel,
      topologicalOrder: graph.topologicalOrder,
    );

    // Update circuit summary count
    final circuitIndex = _circuits.indexWhere((c) => c.id == circuitId);
    if (circuitIndex != -1) {
      final summary = _circuits[circuitIndex];
      _circuits[circuitIndex] = summary.copyWith(
        initializedWireCount: summary.initializedWireCount + 1,
      );
    }

    emitEvent({
      'type': 'wire_resolved',
      'circuitId': circuitId,
      'key': wireKey,
      'isAsync': targetNode.isAsync,
    });

    return true;
  }

  @override
  void dispose() {
    _eventController.close();
  }

  void _populateDefaultMockData() {
    _circuits.add(
      const CircuitSummary(
        id: 'circuit_0',
        debugTag: 'AppScope.global',
        wireCount: 6,
        initializedWireCount: 3,
        maxLevel: 2,
        isDisposed: false,
        status: CircuitLifecycleStatus.ready,
      ),
    );

    final wires0 = <WireNode>[
      const WireNode(
        key: 'AppConfig',
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        isInitialized: true,
        durationMs: 4,
      ),
      const WireNode(
        key: 'DatabaseConnection',
        dependencies: ['AppConfig'],
        isAsync: true,
        topologicalLevel: 1,
        isInitialized: true,
        durationMs: 142,
      ),
      const WireNode(
        key: 'LoggerService',
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        isInitialized: true,
        durationMs: 2,
      ),
      const WireNode(
        key: 'AuthRepository',
        dependencies: ['DatabaseConnection'],
        isAsync: true,
        topologicalLevel: 2,
        isInitialized: false,
        durationMs: 85,
      ),
      const WireNode(
        key: 'AnalyticsService#prod',
        dependencies: ['LoggerService'],
        isAsync: false,
        topologicalLevel: 1,
        isInitialized: false,
      ),
      const WireNode(
        key: 'UserFacade',
        dependencies: ['AuthRepository', 'AnalyticsService#prod'],
        isAsync: false,
        topologicalLevel: 3,
        isInitialized: false,
      ),
    ];

    final waves0 = <int, List<WireNode>>{
      0: [wires0[0], wires0[2]],
      1: [wires0[1], wires0[4]],
      2: [wires0[3]],
      3: [wires0[5]],
    };

    _graphs['circuit_0'] = CircuitGraphData(
      id: 'circuit_0',
      debugTag: 'AppScope.global',
      isDisposed: false,
      wireCount: 6,
      wires: wires0,
      waves: waves0,
      maxWaveLevel: 3,
      topologicalOrder: [
        'AppConfig',
        'LoggerService',
        'DatabaseConnection',
        'AnalyticsService#prod',
        'AuthRepository',
        'UserFacade',
      ],
    );

    _circuits.add(
      const CircuitSummary(
        id: 'circuit_1',
        debugTag: 'FeatureScope.orders',
        wireCount: 3,
        initializedWireCount: 1,
        maxLevel: 1,
        isDisposed: false,
        status: CircuitLifecycleStatus.ready,
      ),
    );

    final wires1 = <WireNode>[
      const WireNode(
        key: 'OrderConfig',
        dependencies: [],
        isAsync: false,
        topologicalLevel: 0,
        isInitialized: true,
      ),
      const WireNode(
        key: 'OrderApiClient',
        dependencies: ['OrderConfig'],
        isAsync: true,
        topologicalLevel: 1,
        isInitialized: false,
      ),
      const WireNode(
        key: 'OrderBloc',
        dependencies: ['OrderApiClient'],
        isAsync: false,
        topologicalLevel: 2,
        isInitialized: false,
      ),
    ];

    _graphs['circuit_1'] = CircuitGraphData(
      id: 'circuit_1',
      debugTag: 'FeatureScope.orders',
      isDisposed: false,
      wireCount: 3,
      wires: wires1,
      waves: {
        0: [wires1[0]],
        1: [wires1[1]],
        2: [wires1[2]],
      },
      maxWaveLevel: 2,
      topologicalOrder: ['OrderConfig', 'OrderApiClient', 'OrderBloc'],
    );
  }
}
