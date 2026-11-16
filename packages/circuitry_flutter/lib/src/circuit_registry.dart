import 'package:circuitry/circuitry.dart';
import 'package:circuitry_flutter/src/circuit_state.dart';
import 'package:flutter/foundation.dart';

/// An entry in [CircuitRegistry] tracking an active [Circuit] instance.
final class CircuitEntry {
  /// Unique identifier for this circuit in the registry (e.g. `'circuit_1'`).
  final String id;

  /// The active [Circuit] instance.
  final Circuit circuit;

  /// Optional enum tag associated with this circuit (e.g. for scoped retrieval).
  final Enum? tag;

  /// The current compilation or lifecycle state of this circuit.
  final CircuitState state;

  /// Creates a new [CircuitEntry].
  CircuitEntry({
    required this.id,
    required this.circuit,
    this.tag,
    CircuitState? state,
  }) : state = state ?? CircuitState.ready(circuit);

  /// Returns a serializable JSON-compatible map representing this circuit entry.
  Map<String, Object?> toJson() => {
    'id': id,
    'tag': tag?.name,
    'state': switch (state) {
      CircuitBuilding() => 'building',
      CircuitReady() => 'ready',
      CircuitFailure() => 'failure',
    },
    'isDisposed': circuit.isDisposed,
    'wireCount': circuit.wires.length,
  };

  @override
  String toString() =>
      'CircuitEntry(id: $id, tag: $tag, state: $state, wireCount: ${circuit.wires.length})';
}

/// Central registry tracking active [Circuit] instances mounted in the Flutter widget tree.
///
/// Designed for DevTools inspection and VM service extensions.
/// All registry operations and internal mappings are strictly gated by [kDebugMode]
/// to ensure complete tree-shaking and zero overhead in production release builds.
final class CircuitRegistry {
  CircuitRegistry._();

  /// The singleton instance of [CircuitRegistry].
  static final CircuitRegistry instance = CircuitRegistry._();

  final Map<String, CircuitEntry> _circuits = {};
  final Map<Circuit, String> _circuitToId = Map.identity();
  int _counter = 0;

  /// An unmodifiable view of all registered circuit entries, keyed by circuit ID.
  Map<String, CircuitEntry> get circuits {
    if (!kDebugMode) return const {};
    return Map.unmodifiable(_circuits);
  }

  /// Number of active registered circuits.
  int get count => circuits.length;

  /// Whether no circuits are currently registered.
  bool get isEmpty => circuits.isEmpty;

  /// Whether at least one circuit is currently registered.
  bool get isNotEmpty => circuits.isNotEmpty;

  /// Registers an active [circuit] in the registry.
  ///
  /// If the circuit was already registered, updates its entry with the provided [tag] and [state].
  /// Gated by [kDebugMode]; returns `null` in release builds.
  String? register(Circuit circuit, {Enum? tag, CircuitState? state}) {
    if (!kDebugMode) return null;

    final id = _circuitToId.putIfAbsent(circuit, () => 'circuit_${++_counter}');
    _circuits[id] = CircuitEntry(
      id: id,
      circuit: circuit,
      tag: tag,
      state: state ?? CircuitState.ready(circuit),
    );
    return id;
  }

  /// Unregisters an active [circuit] from the registry.
  ///
  /// Gated by [kDebugMode]; no-op in release builds.
  void unregister(Circuit circuit) {
    if (!kDebugMode) return;

    final id = _circuitToId.remove(circuit);
    if (id != null) {
      _circuits.remove(id);
    }
  }

  /// Updates the lifecycle [state] of an already registered [circuit].
  ///
  /// If the circuit was not yet registered, it is registered with the given [state].
  /// Gated by [kDebugMode]; no-op in release builds.
  void updateState(Circuit circuit, CircuitState state) {
    if (!kDebugMode) return;

    final id = _circuitToId[circuit];
    if (id != null) {
      final existing = _circuits[id];
      _circuits[id] = CircuitEntry(
        id: id,
        circuit: circuit,
        tag: existing?.tag,
        state: state,
      );
    } else {
      register(circuit, state: state);
    }
  }

  /// Finds a [CircuitEntry] by its unique [id].
  CircuitEntry? getCircuitById(String id) {
    if (!kDebugMode) return null;
    return _circuits[id];
  }

  /// Finds a [CircuitEntry] by its unique [id], or `null` if not found.
  CircuitEntry? operator [](String id) => getCircuitById(id);

  /// Finds a [CircuitEntry] by its [Circuit] instance.
  CircuitEntry? getEntry(Circuit circuit) {
    if (!kDebugMode) return null;
    final id = _circuitToId[circuit];
    return id != null ? _circuits[id] : null;
  }

  /// Clears all registered circuits and resets internal counters.
  ///
  /// Primarily intended for test isolation between test cases.
  @visibleForTesting
  void clear() {
    _circuits.clear();
    _circuitToId.clear();
    _counter = 0;
  }
}
