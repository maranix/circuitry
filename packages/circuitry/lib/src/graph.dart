import 'package:circuitry/src/exceptions.dart';
import 'package:circuitry/src/wire.dart';

/// Represents a compiled and validated Directed Acyclic Graph (DAG) of dependency wire recipes.
///
/// Encapsulates DAG static validation (duplicate keys, missing dependencies, cycle detection)
/// and topological depth analysis for wave-based resolution and reverse disposal.
final class CircuitGraph {
  /// Unmodifiable map of wire keys to their registered [CircuitWire] recipes.
  final Map<WireKey, CircuitWire> wires;

  /// Unmodifiable map associating each wire key with its topological level (0 = roots).
  final Map<WireKey, int> levels;

  /// The maximum topological level present in the compiled graph.
  final int maxLevel;

  final List<List<CircuitWire>> _wiresByLevel;
  final List<List<AsyncWire<Object?>>> _asyncWiresByLevel;

  const CircuitGraph._({
    required this.wires,
    required this.levels,
    required this.maxLevel,
    required this._wiresByLevel,
    required this._asyncWiresByLevel,
  });

  /// Compiles and validates a dependency graph from [wires].
  ///
  /// Validates the graph for:
  /// - Duplicate wire keys -> throws [DuplicateWireException]
  /// - Missing dependencies -> throws [MissingWireException]
  /// - Circular dependencies -> throws [CircularDependencyException]
  ///
  /// Computes topological levels and precomputes wave buckets for parallel execution.
  factory CircuitGraph.compile(List<CircuitWire> wires) {
    _validateNoDuplicates(wires);

    final wireMap = <WireKey, CircuitWire>{
      for (final wire in wires) wire.key: wire,
    };

    _validateDependencies(wireMap);
    _detectCycles(wireMap);

    final (levels, maxLevel) = _computeTopologicalLevels(wireMap);

    final wiresByLevel = List.generate(
      maxLevel + 1,
      (level) => wireMap.values.where((w) => levels[w.key] == level).toList(),
      growable: false,
    );

    final asyncWiresByLevel = List.generate(
      maxLevel + 1,
      (level) => wiresByLevel[level].whereType<AsyncWire<Object?>>().toList(),
      growable: false,
    );

    return CircuitGraph._(
      wires: Map.unmodifiable(wireMap),
      levels: Map.unmodifiable(levels),
      maxLevel: maxLevel,
      wiresByLevel: wiresByLevel,
      asyncWiresByLevel: asyncWiresByLevel,
    );
  }

  /// Returns all wires scheduled at the specified topological [level].
  List<CircuitWire> wiresAtLevel(int level) => _wiresByLevel[level];

  /// Returns all [AsyncWire]s scheduled at the specified topological [level].
  List<AsyncWire<Object?>> asyncWiresAtLevel(int level) =>
      _asyncWiresByLevel[level];

  static void _validateNoDuplicates(List<CircuitWire> wires) {
    final seen = <WireKey>{};
    for (final wire in wires) {
      if (!seen.add(wire.key)) {
        throw DuplicateWireException(
          'Duplicate wire registered for key ${formatWireKey(wire.key)}.',
          key: wire.key,
        );
      }
    }
  }

  static void _validateDependencies(Map<WireKey, CircuitWire> wireMap) {
    for (final wire in wireMap.values) {
      for (final depKey in wire.dependencies) {
        if (!wireMap.containsKey(depKey)) {
          throw MissingWireException(
            'Missing wire for dependency ${formatWireKey(depKey)} required by ${formatWireKey(wire.key)}.',
            missingKey: depKey,
            requiredBy: wire.key,
          );
        }
      }
    }
  }

  static void _detectCycles(Map<WireKey, CircuitWire> wireMap) {
    final visitState =
        <WireKey, int>{}; // 0 = unvisited, 1 = visiting, 2 = visited
    final recursionStack = <WireKey>[];

    void checkCycle(WireKey current) {
      visitState[current] = 1;
      recursionStack.add(current);

      final currentWire = wireMap[current]!;
      for (final depKey in currentWire.dependencies) {
        final state = visitState[depKey] ?? 0;
        if (state == 1) {
          final cycleStartIndex = recursionStack.indexOf(depKey);
          final cycle = [...recursionStack.sublist(cycleStartIndex), depKey];
          throw CircularDependencyException(
            'Circular dependency detected: ${cycle.map(formatWireKey).join(' -> ')}',
            cycle: List.unmodifiable(cycle),
          );
        } else if (state == 0) {
          checkCycle(depKey);
        }
      }

      recursionStack.removeLast();
      visitState[current] = 2;
    }

    for (final key in wireMap.keys) {
      if ((visitState[key] ?? 0) == 0) {
        checkCycle(key);
      }
    }
  }

  static (Map<WireKey, int> levels, int maxLevel) _computeTopologicalLevels(
    Map<WireKey, CircuitWire> wireMap,
  ) {
    final levels = <WireKey, int>{};

    int computeLevel(WireKey key) {
      if (levels.containsKey(key)) {
        return levels[key]!;
      }
      final wire = wireMap[key]!;
      if (wire.dependencies.isEmpty) {
        levels[key] = 0;
        return 0;
      }
      var maxDep = 0;
      for (final depKey in wire.dependencies) {
        final depLevel = computeLevel(depKey);
        if (depLevel > maxDep) {
          maxDep = depLevel;
        }
      }
      final level = maxDep + 1;
      levels[key] = level;
      return level;
    }

    var maxLevel = 0;
    for (final key in wireMap.keys) {
      final lvl = computeLevel(key);
      if (lvl > maxLevel) {
        maxLevel = lvl;
      }
    }

    return (levels, maxLevel);
  }
}
