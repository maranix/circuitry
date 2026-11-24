import 'dart:collection';

import 'package:circuitry_devtools_extension/src/models/wire_node.dart';

/// Immutable model capturing the complete Directed Acyclic Graph (DAG) structure,
/// topological wave grouping, and runtime status of an inspected [Circuit].
final class CircuitGraphData({
  /// Unique circuit identifier.
  required final String id,

  /// Optional debug tag or scope identifier.
  final String? debugTag,

  /// Whether this circuit has been disposed.
  required final bool isDisposed,

  /// Total number of wires registered in this circuit.
  required final int wireCount,

  /// All wires registered in the circuit.
  required List<WireNode> wires,

  /// Wires grouped by their topological resolution wave level.
  required Map<int, List<WireNode>> waves,

  /// The highest wave level (depth) in this circuit DAG.
  required final int maxWaveLevel,

  /// Full deterministic topological resolution order of wire keys.
  required List<String> topologicalOrder,
}) {
  this
    : wires = .unmodifiable(wires),
      waves = .unmodifiable(
        waves.map((k, v) => MapEntry(k, List<WireNode>.unmodifiable(v))),
      ),
      topologicalOrder = .unmodifiable(topologicalOrder),
      _nodeMap = .unmodifiable({for (final w in wires) w.key: w}),
      _reverseDependencies = _computeReverseDependencies(wires);

  final List<WireNode> wires;
  final Map<int, List<WireNode>> waves;
  final List<String> topologicalOrder;
  final Map<String, WireNode> _nodeMap;
  final Map<String, Set<String>> _reverseDependencies;
  final Map<String, Set<String>> _transitiveDependenciesCache = {};
  final Map<String, Set<String>> _transitiveDependentsCache = {};
  Set<String>? _cachedCriticalPath;

  /// Fast lookup of a wire node by its formatted key.
  WireNode? findNode(String key) => _nodeMap[key];

  static Map<String, Set<String>> _computeReverseDependencies(
    List<WireNode> wires,
  ) {
    final reverse = <String, Set<String>>{
      for (final w in wires) w.key: <String>{},
    };
    for (final wire in wires) {
      for (final dep in wire.dependencies) {
        reverse.putIfAbsent(dep, () => <String>{}).add(wire.key);
      }
    }
    return .unmodifiable(
      reverse.map((k, v) => MapEntry(k, Set<String>.unmodifiable(v))),
    );
  }

  /// Returns upstream dependencies required by [key].
  Set<String> dependenciesOf(String key, {bool transitive = false}) {
    final node = _nodeMap[key];
    if (node == null) return const <String>{};

    if (!transitive) return .unmodifiable(node.dependencies);

    final cached = _transitiveDependenciesCache[key];
    if (cached != null) return cached;

    final visited = <String>{};
    final Queue<String> queue = .new()..addAll(node.dependencies);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (visited.add(current)) {
        final currentDep = _nodeMap[current];
        if (currentDep != null) {
          queue.addAll(currentDep.dependencies);
        }
      }
    }
    final result = Set<String>.unmodifiable(visited);
    _transitiveDependenciesCache[key] = result;
    return result;
  }

  /// Returns downstream dependents that rely on [key].
  Set<String> dependentsOf(String key, {bool transitive = false}) {
    final direct = _reverseDependencies[key] ?? const <String>{};
    if (!transitive) return direct;

    final cached = _transitiveDependentsCache[key];
    if (cached != null) return cached;

    final visited = <String>{};
    final Queue<String> queue = .new()..addAll(direct);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (visited.add(current)) {
        final children = _reverseDependencies[current];
        if (children != null) {
          queue.addAll(children);
        }
      }
    }
    final result = Set<String>.unmodifiable(visited);
    _transitiveDependentsCache[key] = result;
    return result;
  }

  /// Computes the critical path of the DAG (chain with the highest cumulative depth/duration).
  Set<String> computeCriticalPath() {
    if (_cachedCriticalPath != null) return _cachedCriticalPath!;
    if (wires.isEmpty) return const <String>{};

    // Calculate longest path length to each node using topological order
    final dist = <String, int>{for (final w in wires) w.key: 0};
    final pred = <String, String?>{for (final w in wires) w.key: null};

    for (final key in topologicalOrder) {
      final node = _nodeMap[key];
      if (node == null) continue;
      final currentDist = dist[key] ?? 0;
      final weight = (node.durationMs ?? (node.isAsync ? 100 : 10));

      final children = _reverseDependencies[key] ?? const <String>{};
      for (final child in children) {
        final newDist = currentDist + weight;
        if (newDist > (dist[child] ?? 0)) {
          dist[child] = newDist;
          pred[child] = key;
        }
      }
    }

    // Find the leaf node with the maximum distance
    var maxKey = topologicalOrder.first;
    var maxVal = dist[maxKey] ?? 0;
    for (final entry in dist.entries) {
      if (entry.value > maxVal) {
        maxVal = entry.value;
        maxKey = entry.key;
      }
    }

    // Trace back the critical path
    final path = <String>{};
    String? curr = maxKey;
    while (curr != null) {
      path.add(curr);
      curr = pred[curr];
    }
    return _cachedCriticalPath = .unmodifiable(path);
  }

  /// Generates a valid Mermaid flowchart diagram representing this circuit.
  String toMermaid({bool showStatus = true, bool groupByWave = true}) {
    final buffer = StringBuffer()..writeln('flowchart TD');
    if (wires.isEmpty) return buffer.toString().trimRight();

    String sanitize(String key) =>
        'wire_${key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';

    if (groupByWave) {
      for (var i = 0; i <= maxWaveLevel; i++) {
        final levelWires = waves[i] ?? const [];
        if (levelWires.isEmpty) continue;
        buffer.writeln('  subgraph wave_$i ["Wave $i"]');
        for (final wire in levelWires) {
          final id = sanitize(wire.key);
          final label = wire.key.replaceAll('"', r'\"');
          buffer.writeln('    $id["$label"]');
        }
        buffer.writeln('  end');
      }
    } else {
      for (final wire in wires) {
        final id = sanitize(wire.key);
        final label = wire.key.replaceAll('"', r'\"');
        buffer.writeln('  $id["$label"]');
      }
    }

    for (final wire in wires) {
      final consumerId = sanitize(wire.key);
      for (final dep in wire.dependencies) {
        final depId = sanitize(dep);
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
      for (final wire in wires) {
        final id = sanitize(wire.key);
        final statusClass = wire.isInitialized
            ? 'initialized'
            : 'uninitialized';
        buffer.writeln('  class $id $statusClass;');
      }
    }

    return buffer.toString().trimRight();
  }

  /// Generates an SVG representation of the dependency graph.
  String toSvg() {
    const colWidth = 220.0;
    const rowHeight = 70.0;
    final totalWidth = (maxWaveLevel + 1) * colWidth + 80.0;
    final maxPerWave = waves.values
        .map((l) => l.length)
        .fold(0, (a, b) => a > b ? a : b);
    final totalHeight = maxPerWave * rowHeight + 120.0;

    final buffer = StringBuffer();
    buffer.writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $totalWidth $totalHeight" width="$totalWidth" height="$totalHeight">',
    );
    buffer.writeln('  <style>');
    buffer.writeln('    .node { rx: 8; stroke-width: 2; }');
    buffer.writeln(
      '    .text { font-family: monospace; font-size: 12px; fill: #ffffff; }',
    );
    buffer.writeln(
      '    .subtext { font-family: monospace; font-size: 10px; fill: #a0a0a0; }',
    );
    buffer.writeln(
      '    .edge { stroke: #555555; stroke-width: 1.5; fill: none; }',
    );
    buffer.writeln('  </style>');

    final positions = <String, (double, double)>{};

    for (var level = 0; level <= maxWaveLevel; level++) {
      final waveWires = waves[level] ?? const [];
      final x = 40.0 + level * colWidth;
      for (var row = 0; row < waveWires.length; row++) {
        final y = 60.0 + row * rowHeight;
        positions[waveWires[row].key] = (x, y);
      }
    }

    // Draw edges
    for (final wire in wires) {
      final target = positions[wire.key];
      if (target == null) continue;
      for (final dep in wire.dependencies) {
        final source = positions[dep];
        if (source == null) continue;
        final sx = source.$1 + 160.0;
        final sy = source.$2 + 20.0;
        final tx = target.$1;
        final ty = target.$2 + 20.0;
        final mx = (sx + tx) / 2;
        buffer.writeln(
          '  <path d="M $sx $sy C $mx $sy, $mx $ty, $tx $ty" class="edge" />',
        );
      }
    }

    // Draw nodes
    for (final wire in wires) {
      final pos = positions[wire.key];
      if (pos == null) continue;
      final x = pos.$1;
      final y = pos.$2;
      final fillColor = wire.isInitialized ? '#1e3a24' : '#2d2d3a';
      final strokeColor = wire.isInitialized
          ? '#28a745'
          : (wire.isAsync ? '#ffc107' : '#6c757d');
      buffer.writeln(
        '  <rect x="$x" y="$y" width="160" height="42" class="node" fill="$fillColor" stroke="$strokeColor" />',
      );
      buffer.writeln(
        '  <text x="${x + 10}" y="${y + 18}" class="text">${wire.typeName}</text>',
      );
      final subtitle = wire.tag != null
          ? '#${wire.tag}'
          : (wire.isAsync ? 'async' : 'lazy');
      buffer.writeln(
        '  <text x="${x + 10}" y="${y + 32}" class="subtext">$subtitle</text>',
      );
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// Serializes this [CircuitGraphData] to a JSON-compatible map.
  Map<String, Object?> toJson() => {
    'id': id,
    if (debugTag != null) 'debugTag': debugTag,
    'isDisposed': isDisposed,
    'wireCount': wireCount,
    'maxWaveLevel': maxWaveLevel,
    'topologicalOrder': topologicalOrder,
    'wires': [for (final wire in wires) wire.toJson()],
    'waves': {
      for (final entry in waves.entries)
        '${entry.key}': [for (final wire in entry.value) wire.toJson()],
    },
  };

  /// Parses a [CircuitGraphData] from a JSON map returned by `ext.circuitry.getCircuitGraph`.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'id': final String id,
      'isDisposed': final bool isDisposed,
      'wireCount': final num wireCount,
      'maxWaveLevel': final num maxWaveLevel,
      'wires': final List<Object?> rawWires,
      'topologicalOrder': final List<Object?> rawTopological,
    }) {
      final debugTag = switch (json['debugTag']) {
        final String s => s,
        _ => null,
      };
      final wires = <WireNode>[
        for (final raw in rawWires)
          if (raw case final Map<String, Object?> m)
            .fromJson(m)
          else if (raw case final Map<Object?, Object?> m)
            .fromJson(m.cast<String, Object?>()),
      ];
      final waves = <int, List<WireNode>>{};
      if (json['waves'] case final Map<Object?, Object?> rawWaves) {
        for (final MapEntry(:key, :value) in rawWaves.entries) {
          if (int.tryParse('$key') case final int level) {
            if (value case final List<Object?> rawWaveList) {
              waves[level] = <WireNode>[
                for (final raw in rawWaveList)
                  if (raw case final Map<String, Object?> m)
                    .fromJson(m)
                  else if (raw case final Map<Object?, Object?> m)
                    .fromJson(m.cast<String, Object?>()),
              ];
            }
          }
        }
      }
      final topologicalOrder = [for (final item in rawTopological) '$item'];

      return CircuitGraphData(
        id: id,
        debugTag: debugTag,
        isDisposed: isDisposed,
        wireCount: wireCount.toInt(),
        wires: wires,
        waves: waves,
        maxWaveLevel: maxWaveLevel.toInt(),
        topologicalOrder: topologicalOrder,
      );
    }
    throw FormatException('Invalid circuit graph data schema: $json');
  }
}
