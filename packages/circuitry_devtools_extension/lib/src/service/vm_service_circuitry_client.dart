import 'package:circuitry_devtools_extension/src/model/circuit_devtools_models.dart';
import 'package:circuitry_devtools_extension/src/service/circuitry_client.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/foundation.dart';

/// Production implementation of [CircuitryClient] communicating with
/// running Flutter applications via VM service extensions.
class VmServiceCircuitryClient implements CircuitryClient {
  /// Extension method names matching circuitry_flutter VM service extensions.
  static const String getCircuitsExtension = 'ext.circuitry.getCircuits';
  static const String getCircuitGraphExtension =
      'ext.circuitry.getCircuitGraph';
  static const String forceResolveWireExtension =
      'ext.circuitry.forceResolveWire';

  /// Creates a [VmServiceCircuitryClient].
  const VmServiceCircuitryClient();

  bool _isServiceAvailable() {
    try {
      return serviceManager.isServiceAvailable;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<CircuitSummary>> getCircuits() async {
    if (!_isServiceAvailable()) {
      return const [];
    }

    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        getCircuitsExtension,
      );
      final json = response.json;
      if (json != null && json['circuits'] is List) {
        final circuitsList = json['circuits'] as List<Object?>;
        return circuitsList
            .whereType<Map<String, Object?>>()
            .map(CircuitSummary.fromJson)
            .toList();
      }
    } catch (e, st) {
      debugPrint('Failed to query $getCircuitsExtension: $e\n$st');
    }
    return const [];
  }

  @override
  Future<CircuitGraphData?> getCircuitGraph(String circuitId) async {
    if (!_isServiceAvailable()) {
      return null;
    }

    try {
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        getCircuitGraphExtension,
        args: {'id': circuitId},
      );
      final json = response.json;
      if (json != null) {
        return CircuitGraphData.fromJson(circuitId, json);
      }
    } catch (e, st) {
      debugPrint('Failed to query $getCircuitGraphExtension: $e\n$st');
    }
    return null;
  }

  @override
  Future<void> forceResolveWire(String circuitId, String wireKey) async {
    if (!_isServiceAvailable()) {
      return;
    }

    try {
      await serviceManager.callServiceExtensionOnMainIsolate(
        forceResolveWireExtension,
        args: {'id': circuitId, 'key': wireKey},
      );
    } catch (e, st) {
      debugPrint('Failed to query $forceResolveWireExtension: $e\n$st');
    }
  }
}
