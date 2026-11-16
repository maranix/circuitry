import 'dart:collection';

import 'package:circuitry/src/circuit.dart';
import 'package:circuitry/src/exceptions.dart';
import 'package:circuitry/src/wire.dart';

/// Formats a [WireKey] into a human-readable display string.
String formatWireKey(WireKey key) {
  final (type, tag) = key;
  return tag == null ? '$type' : '$type(tag: $tag)';
}

/// The runtime lifecycle status of a wire within a [Circuit].
enum WireStatus {
  /// The wire is a synchronous lazy wire that has not yet been requested or instantiated.
  unresolvedLazy,

  /// The wire is currently being instantiated or resolved.
  resolving,

  /// The wire has been successfully resolved and its instance is memoized.
  resolved,

  /// The wire failed during instantiation or asynchronous resolution.
  failed,

  /// The circuit or wire instance has been disposed.
  disposed,
}

/// An immutable descriptor capturing the static wiring and runtime status
/// of a single wire registered within a [Circuit].
final class const WireDescriptor({
  /// The unique record tuple key identifying this wire.
  required final WireKey key,

  /// The list of dependency keys required by this wire.
  required final List<WireKey> dependencies,

  /// Whether this wire resolves asynchronously.
  required final bool isAsync,

  /// The topological wave level of this wire (0 for root dependencies).
  required final int topologicalLevel,

  /// The current runtime lifecycle status of this wire.
  required final WireStatus status,

  /// The duration taken to resolve this wire, or `null` if not yet resolved.
  final Duration? resolutionDuration,
}) {
  /// Returns a serializable JSON-compatible representation of this descriptor.
  Map<String, Object?> toJson() => {
    'key': formatWireKey(key),
    'dependencies': dependencies.map(formatWireKey).toList(),
    'isAsync': isAsync,
    'topologicalLevel': topologicalLevel,
    'status': status.name,
    if (resolutionDuration != null)
      'resolutionDurationMicros': resolutionDuration!.inMicroseconds,
  };

  /// Creates a copy of this descriptor with the given fields replaced.
  WireDescriptor copyWith({
    WireKey? key,
    List<WireKey>? dependencies,
    bool? isAsync,
    int? topologicalLevel,
    WireStatus? status,
    Duration? resolutionDuration,
  }) => WireDescriptor(
    key: key ?? this.key,
    dependencies: dependencies ?? this.dependencies,
    isAsync: isAsync ?? this.isAsync,
    topologicalLevel: topologicalLevel ?? this.topologicalLevel,
    status: status ?? this.status,
    resolutionDuration: resolutionDuration ?? this.resolutionDuration,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WireDescriptor &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          isAsync == other.isAsync &&
          topologicalLevel == other.topologicalLevel &&
          status == other.status &&
          resolutionDuration == other.resolutionDuration;

  @override
  int get hashCode =>
      Object.hash(key, isAsync, topologicalLevel, status, resolutionDuration);

  @override
  String toString() =>
      'WireDescriptor(key: ${formatWireKey(key)}, level: $topologicalLevel, status: $status, isAsync: $isAsync)';
}

/// An introspection interface exposing the Directed Acyclic Graph (DAG) structure,
/// topological wave compilation, and runtime status of a [Circuit].
abstract interface class CircuitIntrospection {
  /// Resolves a [CircuitIntrospection] instance for the given [circuit].
  static CircuitIntrospection of(Circuit circuit) =>
      CircuitIntrospectionImpl(circuit);

  /// All wires registered in the circuit, captured as immutable [WireDescriptor]s.
  List<WireDescriptor> get wires;

  /// The topological resolution waves of the circuit, grouped by level.
  ///
  /// Key `0` contains the root wires with no dependencies, key `1` contains
  /// wires that depend only on level 0, and so forth.
  Map<int, List<WireDescriptor>> get waves;

  /// The maximum topological wave level (depth) in the circuit graph.
  int get maxWaveLevel;

  /// Returns the keys of all direct dependencies required by [key].
  ///
  /// If [transitive] is `true`, recursively resolves all upstream dependencies.
  List<WireKey> dependenciesOf(WireKey key, {bool transitive = false});

  /// Returns the keys of all wires that directly depend on [key].
  ///
  /// If [transitive] is `true`, recursively resolves all downstream dependents.
  List<WireKey> dependentsOf(WireKey key, {bool transitive = false});

  /// Returns all registered wire keys in a valid topological dependency order.
  List<WireKey> get topologicalOrder;

  /// Returns the current runtime [WireStatus] of the wire identified by [key].
  WireStatus statusOf(WireKey key);

  /// Generates a Mermaid flowchart diagram representing the circuit DAG.
  String toMermaid({bool showStatus = true, bool groupByWave = true});

  /// Generates a Graphviz DOT representation of the circuit DAG.
  String toDot({bool showStatus = true});

  /// Returns a serializable JSON-compatible map describing the circuit graph.
  Map<String, Object?> toJson();

  /// Returns the keys of all orphan wires in the circuit.
  ///
  /// Orphan wires are wires that have no dependents in the DAG.
  List<WireKey> findOrphanWires();

  /// Detects and returns the sequence of wire keys forming the critical path
  /// (the longest dependency path by level) in the DAG.
  List<WireKey> detectCriticalPath();
}

/// The default implementation of [CircuitIntrospection], inspecting a live [Circuit].
final class CircuitIntrospectionImpl implements CircuitIntrospection {
  final Circuit _circuit;

  /// Creates a [CircuitIntrospectionImpl] bound to the given [_circuit].
  CircuitIntrospectionImpl(this._circuit);

  @override
  List<WireDescriptor> get wires {
    final result = <WireDescriptor>[];
    for (final wire in _circuit.wires.values) {
      result.add(
        WireDescriptor(
          key: wire.key,
          dependencies: wire.dependencies,
          isAsync: wire is AsyncWire,
          topologicalLevel: _circuit.levels[wire.key] ?? 0,
          status: statusOf(wire.key),
        ),
      );
    }
    return List<WireDescriptor>.unmodifiable(result);
  }

  @override
  Map<int, List<WireDescriptor>> get waves {
    if (_circuit.wires.isEmpty) {
      return const <int, List<WireDescriptor>>{};
    }

    final waveMap = <int, List<WireDescriptor>>{};
    for (var i = 0; i <= _circuit.maxLevel; i++) {
      waveMap[i] = <WireDescriptor>[];
    }

    for (final descriptor in wires) {
      waveMap[descriptor.topologicalLevel]!.add(descriptor);
    }

    return Map<int, List<WireDescriptor>>.unmodifiable(
      waveMap.map(
        (level, list) =>
            MapEntry(level, List<WireDescriptor>.unmodifiable(list)),
      ),
    );
  }

  @override
  int get maxWaveLevel => _circuit.maxLevel;

  @override
  List<WireKey> dependenciesOf(WireKey key, {bool transitive = false}) {
    final wire = _circuit.wires[key];
    if (wire == null) {
      throw WireNotFoundException(
        'Wire for key ${formatWireKey(key)} not found in circuit.',
        key: key,
      );
    }

    if (!transitive) {
      return List<WireKey>.unmodifiable(wire.dependencies);
    }

    final result = <WireKey>[];
    final visited = <WireKey>{key};
    final queue = Queue<WireKey>()..addAll(wire.dependencies);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (visited.add(current)) {
        result.add(current);
        final currentWire = _circuit.wires[current];
        if (currentWire != null) {
          for (final dep in currentWire.dependencies) {
            if (!visited.contains(dep)) {
              queue.add(dep);
            }
          }
        }
      }
    }

    return List<WireKey>.unmodifiable(result);
  }

  @override
  List<WireKey> dependentsOf(WireKey key, {bool transitive = false}) {
    if (!_circuit.wires.containsKey(key)) {
      throw WireNotFoundException(
        'Wire for key ${formatWireKey(key)} not found in circuit.',
        key: key,
      );
    }

    final direct = _circuit.reverseDependencies[key] ?? const <WireKey>{};
    if (!transitive) {
      return List<WireKey>.unmodifiable(direct);
    }

    final result = <WireKey>[];
    final visited = <WireKey>{key};
    final queue = Queue<WireKey>()..addAll(direct);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (visited.add(current)) {
        result.add(current);
        final downstream =
            _circuit.reverseDependencies[current] ?? const <WireKey>{};
        for (final dep in downstream) {
          if (!visited.contains(dep)) {
            queue.add(dep);
          }
        }
      }
    }

    return List<WireKey>.unmodifiable(result);
  }

  @override
  List<WireKey> get topologicalOrder {
    final keys = _circuit.wires.keys.toList();
    keys.sort((a, b) {
      final levelA = _circuit.levels[a] ?? 0;
      final levelB = _circuit.levels[b] ?? 0;
      final cmp = levelA.compareTo(levelB);
      if (cmp != 0) return cmp;
      return formatWireKey(a).compareTo(formatWireKey(b));
    });
    return List<WireKey>.unmodifiable(keys);
  }

  @override
  WireStatus statusOf(WireKey key) {
    final wire = _circuit.wires[key];
    if (wire == null) {
      throw WireNotFoundException(
        'Wire for key ${formatWireKey(key)} not found in circuit.',
        key: key,
      );
    }

    if (_circuit.isDisposed) {
      return WireStatus.disposed;
    }

    if (_circuit.creatingKeys.contains(key)) {
      return WireStatus.resolving;
    }

    if (_circuit.instances.containsKey(key)) {
      return WireStatus.resolved;
    }

    return switch (wire) {
      AsyncWire<Object?>() => WireStatus.failed,
      Wire<Object?>() => WireStatus.unresolvedLazy,
    };
  }

  @override
  String toMermaid({bool showStatus = true, bool groupByWave = true}) {
    final buffer = StringBuffer()..writeln('flowchart TD');

    if (_circuit.wires.isEmpty) {
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
        '  classDef resolved fill:#d4edda,stroke:#28a745,stroke-width:2px;',
      );
      buffer.writeln(
        '  classDef unresolvedLazy fill:#fff3cd,stroke:#ffc107,stroke-width:2px;',
      );
      buffer.writeln(
        '  classDef resolving fill:#cce5ff,stroke:#007bff,stroke-width:2px;',
      );
      buffer.writeln(
        '  classDef failed fill:#f8d7da,stroke:#dc3545,stroke-width:2px;',
      );
      buffer.writeln(
        '  classDef disposed fill:#e2e3e5,stroke:#6c757d,stroke-width:2px;',
      );

      for (final descriptor in wires) {
        final id = sanitize(descriptor.key);
        buffer.writeln('  class $id ${descriptor.status.name};');
      }
    }

    return buffer.toString().trimRight();
  }

  @override
  String toDot({bool showStatus = true}) {
    final buffer = StringBuffer()
      ..writeln('digraph Circuit {')
      ..writeln('  rankdir=TB;')
      ..writeln('  node [shape=box, style=filled];');

    if (_circuit.wires.isEmpty) {
      buffer.writeln('}');
      return buffer.toString().trimRight();
    }

    String sanitize(WireKey key) {
      final formatted = formatWireKey(key);
      return 'wire_${formatted.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    }

    String statusColor(WireStatus status) => switch (status) {
      WireStatus.resolved => '#d4edda',
      WireStatus.unresolvedLazy => '#fff3cd',
      WireStatus.resolving => '#cce5ff',
      WireStatus.failed => '#f8d7da',
      WireStatus.disposed => '#e2e3e5',
    };

    for (final descriptor in wires) {
      final id = sanitize(descriptor.key);
      final label = formatWireKey(descriptor.key).replaceAll('"', r'\"');
      if (showStatus) {
        final color = statusColor(descriptor.status);
        buffer.writeln('  $id [label="$label", fillcolor="$color"];');
      } else {
        buffer.writeln('  $id [label="$label"];');
      }
    }

    for (final descriptor in wires) {
      final consumerId = sanitize(descriptor.key);
      for (final depKey in descriptor.dependencies) {
        final depId = sanitize(depKey);
        buffer.writeln('  $depId -> $consumerId;');
      }
    }

    buffer.writeln('}');
    return buffer.toString().trimRight();
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'wires': wires.map((w) => w.toJson()).toList(),
      'waves': waves.map(
        (level, waveWires) => MapEntry(
          level.toString(),
          waveWires.map((w) => w.toJson()).toList(),
        ),
      ),
      'maxWaveLevel': maxWaveLevel,
    };
  }

  @override
  List<WireKey> findOrphanWires() {
    final orphans = <WireKey>[];
    for (final key in _circuit.wires.keys) {
      final dependents = _circuit.reverseDependencies[key];
      if (dependents == null || dependents.isEmpty) {
        orphans.add(key);
      }
    }
    return List<WireKey>.unmodifiable(orphans);
  }

  @override
  List<WireKey> detectCriticalPath() {
    if (_circuit.wires.isEmpty) {
      return const <WireKey>[];
    }

    final maxLevelNodes = topologicalOrder
        .where((k) => _circuit.levels[k] == _circuit.maxLevel)
        .toList();

    if (maxLevelNodes.isEmpty) {
      return const <WireKey>[];
    }

    final endKey = maxLevelNodes.first;
    final path = <WireKey>[endKey];
    var currentKey = endKey;
    var currentLevel = _circuit.maxLevel;

    while (currentLevel > 0) {
      final currentWire = _circuit.wires[currentKey]!;
      WireKey? nextKey;
      for (final depKey in currentWire.dependencies) {
        if (_circuit.levels[depKey] == currentLevel - 1) {
          nextKey = depKey;
          break;
        }
      }
      if (nextKey == null) {
        var maxDepLevel = -1;
        for (final depKey in currentWire.dependencies) {
          final lvl = _circuit.levels[depKey] ?? 0;
          if (lvl > maxDepLevel) {
            maxDepLevel = lvl;
            nextKey = depKey;
          }
        }
      }
      if (nextKey == null) break;
      path.add(nextKey);
      currentKey = nextKey;
      currentLevel = _circuit.levels[currentKey] ?? 0;
    }

    return List<WireKey>.unmodifiable(path.reversed);
  }
}
