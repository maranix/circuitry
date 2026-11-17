import 'dart:collection';

import 'package:circuitry/src/exceptions.dart';
import 'package:circuitry/src/utils.dart';
import 'package:circuitry/src/wire.dart';

/// Represents a Directed Acyclic Graph (DAG) of dependency wire recipes.
///
/// Encapsulates DAG compilation, static validation (duplicate keys, missing dependencies,
/// cycle detection), topological depth analysis, and dependency/dependent queries.
final class CircuitGraph(final List<CircuitWire> wires) {
  Map<WireKey, CircuitWire>? _wireMap;
  Map<WireKey, int>? _levels;
  int? _maxLevel;
  List<List<CircuitWire>>? _wiresByLevel;
  List<List<AsyncWire<Object?>>>? _asyncWiresByLevel;
  Map<WireKey, Set<WireKey>>? _reverseDependencies;
  List<WireKey>? _topologicalOrder;

  /// Whether this graph has been compiled via [compile].
  bool get isCompiled => _wireMap != null;

  /// Unmodifiable map of wire keys to their registered [CircuitWire] recipes.
  ///
  /// Throws [StateError] if this graph has not been compiled.
  Map<WireKey, CircuitWire> get wireMap {
    _checkCompiled();
    return _wireMap!;
  }

  /// Unmodifiable map associating each wire key with its topological level (0 = roots).
  ///
  /// Throws [StateError] if this graph has not been compiled.
  Map<WireKey, int> get levels {
    _checkCompiled();
    return _levels!;
  }

  /// The maximum topological level present in the compiled graph.
  ///
  /// Throws [StateError] if this graph has not been compiled.
  int get maxLevel {
    _checkCompiled();
    return _maxLevel!;
  }

  /// Unmodifiable map associating each wire key with the set of wire keys that directly depend on it.
  ///
  /// Throws [StateError] if this graph has not been compiled.
  Map<WireKey, Set<WireKey>> get reverseDependencies {
    _checkCompiled();
    return _reverseDependencies!;
  }

  /// Returns all registered wire keys sorted in valid topological dependency order
  /// (from root dependencies at level 0 to leaf dependents at max level).
  ///
  /// Ties between wires at the same topological level are deterministically ordered
  /// by formatted key name.
  ///
  /// Throws [StateError] if this graph has not been compiled.
  List<WireKey> get topologicalOrder {
    _checkCompiled();
    if (_topologicalOrder != null) return _topologicalOrder!;

    final keys = _wireMap!.keys.toList();
    keys.sort((a, b) {
      final levelA = _levels![a] ?? 0;
      final levelB = _levels![b] ?? 0;
      final cmp = levelA.compareTo(levelB);
      if (cmp != 0) return cmp;
      return formatWireKey(a).compareTo(formatWireKey(b));
    });
    return _topologicalOrder = .unmodifiable(keys);
  }

  /// Compiles and validates the dependency graph.
  ///
  /// Runs in sequence:
  /// 1. [validateDuplicates] -> throws [DuplicateWireException]
  /// 2. [validateDependencies] -> throws [MissingWireException]
  /// 3. [detectCycles] -> throws [CircularDependencyException]
  /// 4. [computeTopologicalLevels] -> computes topological depth and wave buckets
  /// 5. Computes reverse dependency index and caches topological ordering
  ///
  /// Returns `this` for fluent chaining.
  CircuitGraph compile() {
    validateDuplicates();
    final map = <WireKey, CircuitWire>{
      for (final wire in wires) wire.key: wire,
    };
    validateDependencies(map);
    detectCycles(map);

    final (levelsMap, computedMaxLevel) = computeTopologicalLevels(map);

    final wiresByLevel = List.generate(
      computedMaxLevel + 1,
      (level) => map.values.where((w) => levelsMap[w.key] == level).toList(),
      growable: false,
    );

    final asyncWiresByLevel = List.generate(
      computedMaxLevel + 1,
      (level) => wiresByLevel[level].whereType<AsyncWire<Object?>>().toList(),
      growable: false,
    );

    final reverseMap = <WireKey, Set<WireKey>>{
      for (final key in map.keys) key: <WireKey>{},
    };
    for (final wire in map.values) {
      for (final depKey in wire.dependencies) {
        reverseMap[depKey]?.add(wire.key);
      }
    }

    _wireMap = .unmodifiable(map);
    _levels = .unmodifiable(levelsMap);
    _maxLevel = computedMaxLevel;
    _wiresByLevel = wiresByLevel;
    _asyncWiresByLevel = asyncWiresByLevel;
    _reverseDependencies = .unmodifiable(
      reverseMap.map((k, v) => MapEntry(k, Set<WireKey>.unmodifiable(v))),
    );
    _topologicalOrder = null;

    return this;
  }

  /// Returns the set of wire keys that directly depend on [key].
  ///
  /// If [transitive] is `true`, recursively resolves all downstream dependents in BFS order.
  /// Throws [StateError] if this graph has not been compiled.
  /// Throws [WireNotFoundException] if [key] is not registered in this graph.
  Set<WireKey> dependentsOf(WireKey key, {bool transitive = false}) {
    _checkCompiled();
    final direct = _reverseDependencies![key];
    if (direct == null) {
      throw WireNotFoundException(
        'Wire for key ${formatWireKey(key)} not found in graph.',
        key: key,
      );
    }

    if (!transitive) {
      return direct;
    }

    // Transitive dependents requested: traverse downstream dependents using breadth-first search (BFS).
    final result = <WireKey>{};
    final queue = Queue<WireKey>()..addAll(direct);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (result.add(current)) {
        final downstream = _reverseDependencies![current];
        if (downstream != null) {
          for (final dep in downstream) {
            if (!result.contains(dep)) {
              queue.add(dep);
            }
          }
        }
      }
    }

    return .unmodifiable(result);
  }

  /// Returns the set of wire keys that [key] directly depends on.
  ///
  /// If [transitive] is `true`, recursively resolves all upstream dependencies in BFS order.
  /// Throws [StateError] if this graph has not been compiled.
  /// Throws [WireNotFoundException] if [key] is not registered in this graph.
  Set<WireKey> dependenciesOf(WireKey key, {bool transitive = false}) {
    _checkCompiled();
    final wire = _wireMap![key];
    if (wire == null) {
      throw WireNotFoundException(
        'Wire for key ${formatWireKey(key)} not found in graph.',
        key: key,
      );
    }

    final direct = wire.dependencies;
    if (!transitive) {
      return .unmodifiable(direct.toSet());
    }

    // Transitive dependencies requested: traverse upstream dependencies using breadth-first search (BFS).
    final result = <WireKey>{};
    final queue = Queue<WireKey>()..addAll(direct);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (result.add(current)) {
        final currentWire = _wireMap![current];
        if (currentWire != null) {
          for (final dep in currentWire.dependencies) {
            if (!result.contains(dep)) {
              queue.add(dep);
            }
          }
        }
      }
    }

    return .unmodifiable(result);
  }

  /// Validates that no duplicate wire keys are registered.
  ///
  /// Throws [DuplicateWireException] if multiple wires share the same [WireKey].
  void validateDuplicates() {
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

  /// Validates that all declared dependencies exist in the graph.
  ///
  /// Throws [MissingWireException] if any dependency key is missing.
  void validateDependencies([Map<WireKey, CircuitWire>? lookupMap]) {
    final map = lookupMap ?? _lookupMap();
    for (final wire in map.values) {
      for (final depKey in wire.dependencies) {
        if (!map.containsKey(depKey)) {
          throw MissingWireException(
            'Missing wire for dependency ${formatWireKey(depKey)} required by ${formatWireKey(wire.key)}.',
            missingKey: depKey,
            requiredBy: wire.key,
          );
        }
      }
    }
  }

  /// Detects circular dependencies within the graph using depth-first search (DFS).
  ///
  /// Throws [CircularDependencyException] if a cycle is found.
  void detectCycles([Map<WireKey, CircuitWire>? lookupMap]) {
    final map = lookupMap ?? _lookupMap();
    final visitState =
        <WireKey, int>{}; // 0 = unvisited, 1 = visiting, 2 = visited
    final recursionStack = <WireKey>[];

    void checkCycle(WireKey current) {
      visitState[current] = 1;
      recursionStack.add(current);

      final currentWire = map[current];
      if (currentWire != null) {
        for (final depKey in currentWire.dependencies) {
          final state = visitState[depKey] ?? 0;
          if (state == 1) {
            final cycleStartIndex = recursionStack.indexOf(depKey);
            final cycle = [...recursionStack.sublist(cycleStartIndex), depKey];
            throw CircularDependencyException(
              'Circular dependency detected: ${cycle.map(formatWireKey).join(' -> ')}',
              cycle: .unmodifiable(cycle),
            );
          } else if (state == 0) {
            checkCycle(depKey);
          }
        }
      }

      recursionStack.removeLast();
      visitState[current] = 2;
    }

    for (final key in map.keys) {
      if ((visitState[key] ?? 0) == 0) {
        checkCycle(key);
      }
    }
  }

  /// Computes topological levels for each wire key in the graph.
  ///
  /// Returns a record tuple `(Map<WireKey, int> levels, int maxLevel)`.
  (Map<WireKey, int> levels, int maxLevel) computeTopologicalLevels([
    Map<WireKey, CircuitWire>? lookupMap,
  ]) {
    final map = lookupMap ?? _lookupMap();
    final levels = <WireKey, int>{};

    int computeLevel(WireKey key) {
      if (levels.containsKey(key)) {
        return levels[key]!;
      }
      final wire = map[key];
      if (wire == null || wire.dependencies.isEmpty) {
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
    for (final key in map.keys) {
      final lvl = computeLevel(key);
      if (lvl > maxLevel) {
        maxLevel = lvl;
      }
    }

    return (levels, maxLevel);
  }

  /// Returns all wires scheduled at the specified topological [level].
  ///
  /// Throws [StateError] if this graph has not been compiled.
  List<CircuitWire> wiresAtLevel(int level) {
    _checkCompiled();
    return _wiresByLevel![level];
  }

  /// Returns all [AsyncWire]s scheduled at the specified topological [level].
  ///
  /// Throws [StateError] if this graph has not been compiled.
  List<AsyncWire<Object?>> asyncWiresAtLevel(int level) {
    _checkCompiled();
    return _asyncWiresByLevel![level];
  }

  Map<WireKey, CircuitWire> _lookupMap() =>
      _wireMap ?? {for (final wire in wires) wire.key: wire};

  void _checkCompiled() {
    if (!isCompiled) {
      throw StateError(
        'CircuitGraph has not been compiled. Call compile() before accessing graph properties.',
      );
    }
  }
}
