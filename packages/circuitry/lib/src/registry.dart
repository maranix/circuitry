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

/// Ambient runtime registry tracking active [Circuit] instances exclusively in debug mode.
///
/// Automatically tracks circuits created via [Circuit.build] and disposed via [Circuit.dispose]
/// when assertions are enabled (`isDebugMode`).
///
/// **Profile and Release Modes:**
/// In profile and release modes (when assertions are disabled), [CircuitRegistry], its properties,
/// and all lifecycle methods are complete no-ops with zero memory or execution overhead:
/// * [descriptors] returns an empty unmodifiable list.
/// * [areExtensionsRegistered] evaluates to `false`.
/// * [getCircuit], [getId], and [getDebugTag] return `null`.
/// * [register] and [unregister] perform no tracking and return an empty string or `null`.
/// * [setDebugTag], [clear], and all `on*` lifecycle callbacks immediately return without operation.
/// * Dart VM Service extensions (`ext.circuitry.*`) are never registered with `dart:developer`.
final class CircuitRegistry._() {
  /// The global singleton registry instance.
  static final CircuitRegistry instance = CircuitRegistry._();

  final Map<String, Circuit> _circuits = {};
  final Map<Circuit, String> _circuitIds = {};
  final Map<String, String?> _circuitDebugTags = {};
  int _counter = 0;
  bool _enabled = false;
  bool _extensionsRegistered = false;

  /// Whether the DevTools VM service extensions and telemetry events are currently active.
  ///
  /// Always returns `false` in profile and release modes or when not explicitly enabled.
  bool get areExtensionsRegistered => _enabled;

  /// Returns descriptors for all currently registered active circuits.
  ///
  /// Always returns an empty list in profile and release modes.
  List<CircuitDescriptor> get descriptors => !isDebugMode
      ? const <CircuitDescriptor>[]
      : _circuits.entries
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
  ///
  /// Always returns `null` in profile and release modes.
  Circuit? getCircuit(String id) => isDebugMode ? _circuits[id] : null;

  /// Retrieves the unique identifier for an active [circuit].
  ///
  /// Always returns `null` in profile and release modes.
  String? getId(Circuit circuit) => isDebugMode ? _circuitIds[circuit] : null;

  /// Retrieves the debug tag for a given circuit [id].
  ///
  /// Always returns `null` in profile and release modes.
  String? getDebugTag(String id) => isDebugMode ? _circuitDebugTags[id] : null;

  /// Sets or updates the [debugTag] for an active [circuit].
  ///
  /// A complete no-op in profile and release modes.
  void setDebugTag(Circuit circuit, String? debugTag) {
    if (!isDebugMode) return;
    final id = _circuitIds[circuit];
    if (id != null) {
      _circuitDebugTags[id] = debugTag;
    }
  }

  /// Registers [circuit] in the registry with an optional [debugTag].
  ///
  /// Returns the assigned unique circuit ID (e.g. `circuit_0`).
  ///
  /// A complete no-op in profile and release modes, returning an empty string.
  String register(Circuit circuit, {String? debugTag}) {
    if (!isDebugMode) return '';

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
  ///
  /// A complete no-op in profile and release modes, returning `null`.
  String? unregister(Circuit circuit) {
    if (!isDebugMode) return null;
    final id = _circuitIds.remove(circuit);
    if (id != null) {
      _circuits.remove(id);
      _circuitDebugTags.remove(id);
    }
    return id;
  }

  /// Clears all registered circuits and resets the ID counter (useful for unit tests).
  ///
  /// A complete no-op in profile and release modes.
  void clear() {
    if (!isDebugMode) return;
    _circuits.clear();
    _circuitIds.clear();
    _circuitDebugTags.clear();
    _counter = 0;
    _enabled = false;
  }

  /// Called by [Circuit.build] to register a building container and emit a lifecycle event.
  ///
  /// A complete no-op in profile and release modes or when DevTools extension is not enabled.
  void onCircuitBuilding(Circuit circuit, {String? debugTag}) {
    if (!isDebugMode) return;
    final id = register(circuit, debugTag: debugTag);
    if (!_enabled) return;
    developer.postEvent('Circuitry', {
      'type': 'circuit_building',
      'circuitId': id,
      'debugTag': ?debugTag,
    });
  }

  /// Called by [Circuit.build] when all async waves have resolved successfully.
  ///
  /// A complete no-op in profile and release modes or when DevTools extension is not enabled.
  void onCircuitReady(Circuit circuit, {String? debugTag}) {
    if (!isDebugMode || !_enabled) return;
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
  ///
  /// A complete no-op in profile and release modes or when DevTools extension is not enabled.
  void onCircuitFailed(Circuit circuit, Object error, {String? debugTag}) {
    if (!isDebugMode || !_enabled) return;
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
  ///
  /// A complete no-op in profile and release modes or when DevTools extension is not enabled.
  void onWireResolved(Circuit circuit, WireKey key, {required bool isAsync}) {
    if (!isDebugMode || !_enabled) return;
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
  ///
  /// A complete no-op in profile and release modes or when DevTools extension is not enabled.
  void onCircuitDisposed(Circuit circuit) {
    if (!isDebugMode) return;
    final id = unregister(circuit);
    if (id != null && _enabled) {
      developer.postEvent('Circuitry', {
        'type': 'circuit_disposed',
        'circuitId': id,
      });
    }
  }

  /// Registers Dart VM Service extensions for Circuitry (`ext.circuitry.*`) and enables telemetry.
  ///
  /// A complete no-op in profile and release modes.
  void registerVmServiceExtensions() {
    if (!isDebugMode) return;
    _enabled = true;
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

    try {
      developer.registerExtension(
        'ext.circuitry.forceResolveWire',
        handleForceResolveWire,
      );
    } catch (_) {}
  }

  /// Deregisters and disables Circuitry DevTools VM service extensions and telemetry events.
  ///
  /// A complete no-op in profile and release modes.
  void unregisterVmServiceExtensions() {
    _enabled = false;
  }

  /// Handles VM service invocations for `ext.circuitry.getCircuits`.
  ///
  /// In profile and release modes or when disabled, returns an empty circuit list.
  Future<developer.ServiceExtensionResponse> handleGetCircuits(
    String method,
    Map<String, String> parameters,
  ) async {
    if (!isDebugMode || !_enabled) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'circuits': const <Map<String, Object?>>[]}),
      );
    }
    final circuitList = descriptors.map((d) => d.toJson()).toList();
    final json = jsonEncode({'circuits': circuitList});
    return developer.ServiceExtensionResponse.result(json);
  }

  (Circuit? circuit, String? id, developer.ServiceExtensionResponse? error)
  _lookupCircuitForExtension(Map<String, String> parameters) {
    if (!isDebugMode || !_enabled) {
      return (
        null,
        null,
        developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Circuitry DevTools extension is not registered or has been deregistered.',
        ),
      );
    }
    final id = parameters['id'] ?? parameters['circuitId'];
    if (id == null || id.isEmpty) {
      return (
        null,
        null,
        developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          'Missing required parameter "id" or "circuitId".',
        ),
      );
    }
    final circuit = _circuits[id];
    if (circuit == null) {
      return (
        null,
        id,
        developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Circuit with id "$id" not found in registry.',
        ),
      );
    }
    return (circuit, id, null);
  }

  /// Handles VM service invocations for `ext.circuitry.getCircuitGraph`.
  ///
  /// In profile and release modes or when disabled, returns an error response.
  Future<developer.ServiceExtensionResponse> handleGetCircuitGraph(
    String method,
    Map<String, String> parameters,
  ) async {
    final (circuit, id, error) = _lookupCircuitForExtension(parameters);
    if (error != null) return error;

    final data = <String, Object?>{
      'id': id!,
      'debugTag': ?_circuitDebugTags[id],
      'isDisposed': circuit!.isDisposed,
      'wireCount': circuit.graph.wireMap.length,
      ...circuit.inspect().toJson(),
    };

    return developer.ServiceExtensionResponse.result(jsonEncode(data));
  }

  /// Handles VM service invocations for `ext.circuitry.forceResolveWire`.
  ///
  /// In profile and release modes or when disabled, returns an error response.
  Future<developer.ServiceExtensionResponse> handleForceResolveWire(
    String method,
    Map<String, String> parameters,
  ) async {
    final (circuit, id, error) = _lookupCircuitForExtension(parameters);
    if (error != null) return error;

    final keyString = parameters['key'] ?? parameters['wireKey'];
    if (keyString == null || keyString.isEmpty) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Missing required parameter "key" or "wireKey".',
      );
    }

    if (circuit!.isDisposed) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'Circuit with id "$id" has been disposed.',
      );
    }

    final targetKey = circuit.graph.wireMap.keys
        .where((k) => formatWireKey(k) == keyString)
        .firstOrNull;

    if (targetKey == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'Wire with key "$keyString" not found in circuit "$id".',
      );
    }

    try {
      circuit.resolveWireKey(targetKey);
      return developer.ServiceExtensionResponse.result(
        jsonEncode({
          'success': true,
          'key': formatWireKey(targetKey),
          'initialized': circuit.isKeyInitialized(targetKey),
        }),
      );
    } catch (err) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'Failed to resolve wire "$keyString": $err',
      );
    }
  }
}
