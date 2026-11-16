import 'package:circuitry_devtools_extension/src/model/circuit_devtools_models.dart';

/// Client interface for querying Circuitry VM service extensions.
abstract interface class CircuitryClient {
  /// Fetches all active registered circuits.
  Future<List<CircuitSummary>> getCircuits();

  /// Fetches the DAG graph and introspection data for [circuitId].
  Future<CircuitGraphData?> getCircuitGraph(String circuitId);

  /// Triggers force-resolution of an unresolved lazy wire.
  Future<void> forceResolveWire(String circuitId, String wireKey);
}

/// In-memory sample client used for testing, offline previews, and development.
class MockCircuitryClient implements CircuitryClient {
  final List<CircuitSummary> _circuits;
  final Map<String, CircuitGraphData> _graphs;

  /// Creates a [MockCircuitryClient] with mock data.
  MockCircuitryClient({
    List<CircuitSummary>? circuits,
    Map<String, CircuitGraphData>? graphs,
  }) : _circuits = circuits ?? _defaultMockCircuits(),
       _graphs = graphs ?? _defaultMockGraphs();

  @override
  Future<List<CircuitSummary>> getCircuits() async {
    return _circuits;
  }

  @override
  Future<CircuitGraphData?> getCircuitGraph(String circuitId) async {
    return _graphs[circuitId] ?? _graphs.values.firstOrNull;
  }

  @override
  Future<void> forceResolveWire(String circuitId, String wireKey) async {
    final graph = _graphs[circuitId];
    if (graph != null && graph.wireMap.containsKey(wireKey)) {
      final wire = graph.wireMap[wireKey]!;
      graph.wireMap[wireKey] = wire.copyWith(
        status: 'resolved',
        resolutionDuration: const Duration(milliseconds: 2),
      );
    }
  }

  static List<CircuitSummary> _defaultMockCircuits() {
    return const [
      CircuitSummary(
        id: 'circuit_app_root',
        tag: 'root',
        state: 'ready',
        wireCount: 6,
      ),
      CircuitSummary(
        id: 'circuit_auth_feature',
        tag: 'auth',
        state: 'ready',
        wireCount: 4,
      ),
      CircuitSummary(
        id: 'circuit_cart_checkout',
        tag: 'checkout',
        state: 'building',
        wireCount: 3,
      ),
    ];
  }

  static Map<String, CircuitGraphData> _defaultMockGraphs() {
    final rootWireMap = <String, WireModel>{
      'Logger': const WireModel(
        key: 'Logger',
        typeName: 'Logger',
        isAsync: false,
        waveLevel: 0,
        status: 'resolved',
        resolutionDuration: Duration(microseconds: 800),
      ),
      'AppConfig': const WireModel(
        key: 'AppConfig',
        typeName: 'AppConfig',
        isAsync: false,
        waveLevel: 0,
        status: 'resolved',
        resolutionDuration: Duration(microseconds: 1200),
      ),
      'DatabaseService': const WireModel(
        key: 'DatabaseService',
        typeName: 'DatabaseService',
        dependencies: ['AppConfig'],
        isAsync: true,
        waveLevel: 1,
        status: 'resolved',
        resolutionDuration: Duration(milliseconds: 14),
        isCriticalPath: true,
      ),
      'ApiClient': const WireModel(
        key: 'ApiClient',
        typeName: 'ApiClient',
        dependencies: ['AppConfig', 'Logger'],
        isAsync: true,
        waveLevel: 1,
        status: 'resolved',
        resolutionDuration: Duration(milliseconds: 18),
        isCriticalPath: true,
      ),
      'UserRepository': const WireModel(
        key: 'UserRepository',
        typeName: 'UserRepository',
        dependencies: ['DatabaseService', 'ApiClient'],
        isAsync: false,
        waveLevel: 2,
        status: 'resolved',
        resolutionDuration: Duration(microseconds: 650),
        isCriticalPath: true,
      ),
      'AnalyticsService': const WireModel(
        key: 'AnalyticsService',
        typeName: 'AnalyticsService',
        dependencies: ['Logger'],
        isAsync: false,
        waveLevel: 1,
        status: 'unresolvedLazy',
      ),
    };

    return {
      'circuit_app_root': CircuitGraphData(
        circuitId: 'circuit_app_root',
        wireMap: rootWireMap,
        maxWaveLevel: 2,
        criticalPath: const ['AppConfig', 'ApiClient', 'UserRepository'],
        totalDuration: const Duration(milliseconds: 20),
      ),
    };
  }
}
