import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:circuitry/src/circuit.dart';
import 'package:circuitry/src/utils.dart';
import 'package:circuitry/src/wire.dart';

/// An immutable descriptor summarizing an active [Circuit] instance tracked in [CircuitRegistry].
final class const CircuitDescriptor({
  /// Unique monotonic identifier assigned to this circuit (e.g. `circuit_0`).
  required final String id,

  /// Optional debug tag or scope label.
  final String? debugTag,

  /// Total number of wires registered in this circuit's graph.
  required final int wireCount,

  /// Number of wires that have been instantiated.
  required final int initializedWireCount,

  /// The maximum topological wave depth of the circuit.
  required final int maxLevel,

  /// Whether this circuit has been disposed.
  required final bool isDisposed,
}) {
  /// Converts this descriptor into a JSON-serializable map.
  Map<String, Object?> toJson() => {
    'id': id,
    'debugTag': ?debugTag,
    'wireCount': wireCount,
    'initializedWireCount': initializedWireCount,
    'maxLevel': maxLevel,
    'isDisposed': isDisposed,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircuitDescriptor &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          debugTag == other.debugTag &&
          wireCount == other.wireCount &&
          initializedWireCount == other.initializedWireCount &&
          maxLevel == other.maxLevel &&
          isDisposed == other.isDisposed;

  @override
  int get hashCode => Object.hash(
    id,
    debugTag,
    wireCount,
    initializedWireCount,
    maxLevel,
    isDisposed,
  );
}

/// Ambient runtime registry tracking active [Circuit] instances in debug and profile modes.
///
/// Automatically tracks circuits created via [Circuit.build] and disposed via [Circuit.dispose]
/// when asserts are enabled. All tracking logic is stripped in release/AOT builds.
///
/// Registers standard Dart VM Service extensions (`ext.circuitry.*`) using `dart:developer`.
final class CircuitRegistry._() {
  /// The global singleton registry instance.
  static final CircuitRegistry instance = CircuitRegistry._();

  final Map<String, Circuit> _circuits = {};
  final Map<Circuit, String> _circuitIds = {};
  final Map<String, String?> _circuitDebugTags = {};
  int _counter = 0;
  bool _extensionsRegistered = false;

  /// Whether VM service extensions have been registered with `dart:developer`.
  bool get areExtensionsRegistered => _extensionsRegistered;

  /// Returns descriptors for all currently registered active circuits.
  List<CircuitDescriptor> get descriptors => _circuits.entries
      .map((entry) {
        final id = entry.key;
        final circuit = entry.value;
        return CircuitDescriptor(
          id: id,
          debugTag: _circuitDebugTags[id],
          wireCount: circuit.graph.wireMap.length,
          initializedWireCount: circuit.graph.wireMap.keys
              .where(circuit.isKeyInitialized)
              .length,
          maxLevel: circuit.graph.maxLevel,
          isDisposed: circuit.isDisposed,
        );
      })
      .toList(growable: false);

  /// Retrieves an active circuit by its unique [id].
  Circuit? getCircuit(String id) => _circuits[id];

  /// Retrieves the unique identifier for an active [circuit].
  String? getId(Circuit circuit) => _circuitIds[circuit];

  /// Retrieves the debug tag for a given circuit [id].
  String? getDebugTag(String id) => _circuitDebugTags[id];

  /// Sets or updates the [debugTag] for an active [circuit].
  void setDebugTag(Circuit circuit, String? debugTag) {
    if (!isDebugMode) return;
    final id = _circuitIds[circuit];
    if (id != null) {
      _circuitDebugTags[id] = debugTag;
    }
  }

  /// Registers [circuit] in the registry with an optional [debugTag].
  ///
  /// Automatically initializes VM Service extensions if not already registered.
  /// Returns the assigned unique circuit ID.
  String register(Circuit circuit, {String? debugTag}) {
    registerVmServiceExtensions();

    final existingId = _circuitIds[circuit];
    if (existingId != null) {
      if (debugTag != null) _circuitDebugTags[existingId] = debugTag;
      return existingId;
    }

    final id = 'circuit_${_counter++}';
    _circuits[id] = circuit;
    _circuitIds[circuit] = id;
    _circuitDebugTags[id] = debugTag;
    return id;
  }

  /// Unregisters [circuit] from the registry.
  String? unregister(Circuit circuit) {
    final id = _circuitIds.remove(circuit);
    if (id != null) {
      _circuits.remove(id);
      _circuitDebugTags.remove(id);
    }
    return id;
  }

  /// Clears all registered circuits and resets the ID counter (useful for unit tests).
  void clear() {
    _circuits.clear();
    _circuitIds.clear();
    _circuitDebugTags.clear();
    _counter = 0;
  }

  /// Called by [Circuit.build] to register a building container and emit a lifecycle event.
  void onCircuitBuilding(Circuit circuit, {String? debugTag}) {
    if (!isDebugMode) return;
    final id = register(circuit, debugTag: debugTag);
    developer.postEvent('Circuitry', {
      'type': 'circuit_building',
      'circuitId': id,
      'debugTag': ?debugTag,
    });
  }

  /// Called by [Circuit.build] when all async waves have resolved successfully.
  void onCircuitReady(Circuit circuit, {String? debugTag}) {
    if (!isDebugMode) return;
    final id = getId(circuit);
    if (id != null) {
      developer.postEvent('Circuitry', {
        'type': 'circuit_ready',
        'circuitId': id,
        'debugTag': ?debugTag,
      });
    }
  }

  /// Called by [Circuit.build] when async wave compilation fails.
  void onCircuitFailed(Circuit circuit, Object error, {String? debugTag}) {
    if (!isDebugMode) return;
    final id = getId(circuit);
    if (id != null) {
      developer.postEvent('Circuitry', {
        'type': 'circuit_failed',
        'circuitId': id,
        'debugTag': ?debugTag,
        'error': error.toString(),
      });
    }
  }

  /// Called when a wire resolves to an instance.
  void onWireResolved(Circuit circuit, WireKey key, {required bool isAsync}) {
    if (!isDebugMode) return;
    final id = getId(circuit);
    if (id != null) {
      developer.postEvent('Circuitry', {
        'type': 'wire_resolved',
        'circuitId': id,
        'key': formatWireKey(key),
        'isAsync': isAsync,
      });
    }
  }

  /// Called when a circuit is disposed.
  void onCircuitDisposed(Circuit circuit) {
    if (!isDebugMode) return;
    final id = unregister(circuit);
    if (id != null) {
      developer.postEvent('Circuitry', {
        'type': 'circuit_disposed',
        'circuitId': id,
      });
    }
  }

  /// Registers Dart VM Service extensions for Circuitry (`ext.circuitry.*`).
  void registerVmServiceExtensions() {
    if (_extensionsRegistered) return;
    _extensionsRegistered = true;

    try {
      developer.registerExtension(
        'ext.circuitry.getCircuits',
        handleGetCircuits,
      );
    } catch (_) {}

    try {
      developer.registerExtension(
        'ext.circuitry.getCircuitGraph',
        handleGetCircuitGraph,
      );
    } catch (_) {}
  }

  /// Handles VM service invocations for `ext.circuitry.getCircuits`.
  Future<developer.ServiceExtensionResponse> handleGetCircuits(
    String method,
    Map<String, String> parameters,
  ) async {
    final circuitList = descriptors.map((d) => d.toJson()).toList();
    final json = jsonEncode({'circuits': circuitList});
    return developer.ServiceExtensionResponse.result(json);
  }

  /// Handles VM service invocations for `ext.circuitry.getCircuitGraph`.
  Future<developer.ServiceExtensionResponse> handleGetCircuitGraph(
    String method,
    Map<String, String> parameters,
  ) async {
    final id = parameters['id'] ?? parameters['circuitId'];
    if (id == null || id.isEmpty) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Missing required parameter "id" or "circuitId".',
      );
    }

    final circuit = _circuits[id];
    if (circuit == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'Circuit with id "$id" not found in registry.',
      );
    }

    final data = <String, Object?>{
      'id': id,
      'debugTag': ?_circuitDebugTags[id],
      'isDisposed': circuit.isDisposed,
      'wireCount': circuit.graph.wireMap.length,
      ...circuit.inspect().toJson(),
    };

    return developer.ServiceExtensionResponse.result(jsonEncode(data));
  }
}
