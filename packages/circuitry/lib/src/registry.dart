import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:circuitry/src/circuit.dart';

/// An immutable descriptor summarizing an active [Circuit] instance tracked in [CircuitRegistry].
final class const CircuitDescriptor({
  /// Unique monotonic identifier assigned to this circuit (e.g. `circuit_0`).
  required final String id,

  /// Optional debug tag or scope label.
  final String? tag,

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
    'tag': ?tag,
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
          tag == other.tag &&
          wireCount == other.wireCount &&
          initializedWireCount == other.initializedWireCount &&
          maxLevel == other.maxLevel &&
          isDisposed == other.isDisposed;

  @override
  int get hashCode => Object.hash(
    id,
    tag,
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
final class CircuitRegistry {
  CircuitRegistry._();

  /// The global singleton registry instance.
  static final CircuitRegistry instance = CircuitRegistry._();

  final Map<String, Circuit> _circuits = {};
  final Map<Circuit, String> _circuitIds = {};
  final Map<String, String?> _circuitTags = {};
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
          tag: _circuitTags[id],
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
  String? getTag(String id) => _circuitTags[id];

  /// Sets or updates the debug [tag] for an active [circuit].
  void setTag(Circuit circuit, String? tag) {
    final id = _circuitIds[circuit];
    if (id != null) {
      _circuitTags[id] = tag;
    }
  }

  /// Registers [circuit] in the registry with an optional [tag].
  ///
  /// Automatically initializes VM Service extensions if not already registered.
  /// Returns the assigned unique circuit ID.
  String register(Circuit circuit, {String? tag}) {
    registerVmServiceExtensions();

    final existingId = _circuitIds[circuit];
    if (existingId != null) {
      if (tag != null) _circuitTags[existingId] = tag;
      return existingId;
    }

    final id = 'circuit_${_counter++}';
    _circuits[id] = circuit;
    _circuitIds[circuit] = id;
    _circuitTags[id] = tag;
    return id;
  }

  /// Unregisters [circuit] from the registry.
  String? unregister(Circuit circuit) {
    final id = _circuitIds.remove(circuit);
    if (id != null) {
      _circuits.remove(id);
      _circuitTags.remove(id);
    }
    return id;
  }

  /// Clears all registered circuits and resets the ID counter (useful for unit tests).
  void clear() {
    _circuits.clear();
    _circuitIds.clear();
    _circuitTags.clear();
    _counter = 0;
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
      'tag': ?_circuitTags[id],
      'isDisposed': circuit.isDisposed,
      'wireCount': circuit.graph.wireMap.length,
      ...circuit.inspect().toJson(),
    };

    return developer.ServiceExtensionResponse.result(jsonEncode(data));
  }
}
