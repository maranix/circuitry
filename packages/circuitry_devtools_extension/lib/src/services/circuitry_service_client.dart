import 'package:circuitry_devtools_extension/src/models/circuit_graph_data.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_summary.dart';

/// Abstract contract for communicating with a running Dart/Flutter runtime
/// exposing Circuitry DevTools VM service extensions.
abstract interface class CircuitryServiceClient {
  /// Stream of live lifecycle events emitted by the running app under the `'Circuitry'` stream.
  Stream<Map<String, Object?>> get onCircuitryEvent;

  /// Retrieves summaries of all active and recent circuits tracked in the app.
  Future<List<CircuitSummary>> getCircuits();

  /// Retrieves the complete serialized DAG and runtime status for [circuitId].
  Future<CircuitGraphData> getCircuitGraph(String circuitId);

  /// Forces on-demand initialization of an uninitialized lazy wire.
  Future<bool> forceResolveWire(String circuitId, String wireKey);

  /// Disposes resources and stream controllers associated with this client.
  void dispose();
}
