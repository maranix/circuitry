import 'package:circuitry/src/circuit.dart';
import 'package:circuitry/src/utils.dart';
import 'package:circuitry/src/wire.dart';

/// An immutable descriptor capturing the static wiring and runtime status
/// of a single wire registered within a [Circuit].
final class const WireDescriptor({
  /// The unique record tuple key identifying this wire.
  required final WireKey key,

  /// The list of dependency keys required by this wire.
  required final List<WireKey> dependencies,

  /// Whether this wire resolves asynchronously.
  required final bool isAsync,

  /// Whether this wire represents an actionable domain trigger ([TriggerWire]).
  final bool isAction = false,

  /// The topological wave level of this wire (0 for root dependencies).
  required final int topologicalLevel,

  /// Whether this wire has been instantiated in the circuit.
  required final bool isInitialized,
}) {
  /// Returns a serializable JSON-compatible representation of this descriptor.
  Map<String, Object?> toJson() => {
    'key': formatWireKey(key),
    'dependencies': dependencies.map(formatWireKey).toList(),
    'isAsync': isAsync,
    'isAction': isAction,
    'topologicalLevel': topologicalLevel,
    'isInitialized': isInitialized,
  };

  /// Creates a copy of this descriptor with the given fields replaced.
  WireDescriptor copyWith({
    WireKey? key,
    List<WireKey>? dependencies,
    bool? isAsync,
    bool? isAction,
    int? topologicalLevel,
    bool? isInitialized,
  }) => WireDescriptor(
    key: key ?? this.key,
    dependencies: dependencies ?? this.dependencies,
    isAsync: isAsync ?? this.isAsync,
    isAction: isAction ?? this.isAction,
    topologicalLevel: topologicalLevel ?? this.topologicalLevel,
    isInitialized: isInitialized ?? this.isInitialized,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WireDescriptor &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          isAsync == other.isAsync &&
          isAction == other.isAction &&
          topologicalLevel == other.topologicalLevel &&
          isInitialized == other.isInitialized;

  @override
  int get hashCode =>
      Object.hash(key, isAsync, isAction, topologicalLevel, isInitialized);

  @override
  String toString() =>
      'WireDescriptor(key: ${formatWireKey(key)}, level: $topologicalLevel, initialized: $isInitialized, isAsync: $isAsync)';
}

/// An introspection interface exposing the Directed Acyclic Graph (DAG) structure,
/// topological wave compilation, and runtime status of a [Circuit].
abstract interface class CircuitIntrospection {
  /// Resolves an on-demand [CircuitIntrospection] snapshot view for [circuit].
  static CircuitIntrospection of(Circuit circuit) =>
      CircuitIntrospectionImpl(circuit);

  /// All wires registered in the circuit, captured as immutable [WireDescriptor]s.
  List<WireDescriptor> get wires;

  /// The topological resolution waves of the circuit, grouped by level.
  ///
  /// Key `0` contains root wires with no dependencies, key `1` contains
  /// wires that depend only on level 0, and so forth.
  Map<int, List<WireDescriptor>> get waves;

  /// The maximum topological wave level (depth) in the circuit graph.
  int get maxWaveLevel;

  /// Returns the complete topological resolution order of all wire keys.
  List<WireKey> get topologicalOrder;

  /// Returns the set of all direct or transitive upstream dependencies required by [key].
  Set<WireKey> dependenciesOf(WireKey key, {bool transitive = false});

  /// Returns the set of all direct or transitive downstream dependents that rely on [key].
  Set<WireKey> dependentsOf(WireKey key, {bool transitive = false});

  /// Generates a Mermaid flowchart diagram representing the circuit DAG.
  String toMermaid({bool showStatus = true, bool groupByWave = true});

  /// Serializes the graph into a structured, JSON-compatible map.
  Map<String, Object?> toJson();
}

/// Default on-demand implementation of [CircuitIntrospection], inspecting a live [Circuit].
final class CircuitIntrospectionImpl(final Circuit _circuit)
    implements CircuitIntrospection {
  @override
  List<WireDescriptor> get wires {
    final result = <WireDescriptor>[];
    for (final wire in _circuit.graph.wireMap.values) {
      result.add(
        WireDescriptor(
          key: wire.key,
          dependencies: wire.dependencies,
          isAsync: wire is AsyncWire,
          isAction: wire is TriggerWire,
          topologicalLevel: _circuit.graph.levels[wire.key] ?? 0,
          isInitialized: _circuit.isKeyInitialized(wire.key),
        ),
      );
    }
    return .unmodifiable(result);
  }

  @override
  Map<int, List<WireDescriptor>> get waves {
    if (_circuit.graph.wireMap.isEmpty) {
      return const <int, List<WireDescriptor>>{};
    }

    final waveMap = <int, List<WireDescriptor>>{
      for (var i = 0; i <= _circuit.graph.maxLevel; i++) i: <WireDescriptor>[],
    };

    for (final descriptor in wires) {
      waveMap[descriptor.topologicalLevel]!.add(descriptor);
    }

    return .unmodifiable(
      waveMap.map(
        (level, list) =>
            MapEntry(level, List<WireDescriptor>.unmodifiable(list)),
      ),
    );
  }

  @override
  int get maxWaveLevel => _circuit.graph.maxLevel;

  @override
  List<WireKey> get topologicalOrder => _circuit.graph.topologicalOrder;

  @override
  Set<WireKey> dependenciesOf(WireKey key, {bool transitive = false}) =>
      _circuit.graph.dependenciesOf(key, transitive: transitive);

  @override
  Set<WireKey> dependentsOf(WireKey key, {bool transitive = false}) =>
      _circuit.graph.dependentsOf(key, transitive: transitive);

  @override
  String toMermaid({bool showStatus = true, bool groupByWave = true}) {
    final buffer = StringBuffer()..writeln('flowchart TD');

    if (_circuit.graph.wireMap.isEmpty) {
      return buffer.toString().trimRight();
    }

    String sanitize(WireKey key) {
      final formatted = formatWireKey(key);
      return 'wire_${formatted.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    }

    if (groupByWave) {
      for (var i = 0; i <= maxWaveLevel; i++) {
        final levelWires = waves[i] ?? const [];
        if (levelWires.isEmpty) continue;
        buffer.writeln('  subgraph wave_$i ["Wave $i"]');
        for (final descriptor in levelWires) {
          final id = sanitize(descriptor.key);
          final label = formatWireKey(descriptor.key).replaceAll('"', r'\"');
          buffer.writeln('    $id["$label"]');
        }
        buffer.writeln('  end');
      }
    } else {
      for (final descriptor in wires) {
        final id = sanitize(descriptor.key);
        final label = formatWireKey(descriptor.key).replaceAll('"', r'\"');
        buffer.writeln('  $id["$label"]');
      }
    }

    for (final descriptor in wires) {
      final consumerId = sanitize(descriptor.key);
      for (final depKey in descriptor.dependencies) {
        final depId = sanitize(depKey);
        buffer.writeln('  $depId --> $consumerId');
      }
    }

    if (showStatus) {
      buffer.writeln(
        '  classDef initialized fill:#d4edda,stroke:#28a745,stroke-width:2px;',
      );
      buffer.writeln(
        '  classDef uninitialized fill:#fff3cd,stroke:#ffc107,stroke-width:2px;',
      );

      for (final descriptor in wires) {
        final id = sanitize(descriptor.key);
        final statusClass = descriptor.isInitialized
            ? 'initialized'
            : 'uninitialized';
        buffer.writeln('  class $id $statusClass;');
      }
    }

    return buffer.toString().trimRight();
  }

  @override
  Map<String, Object?> toJson() => {
    'wires': wires.map((w) => w.toJson()).toList(),
    'waves': waves.map(
      (level, waveWires) =>
          MapEntry(level.toString(), waveWires.map((w) => w.toJson()).toList()),
    ),
    'maxWaveLevel': maxWaveLevel,
    'topologicalOrder': topologicalOrder.map(formatWireKey).toList(),
  };
}
