import 'dart:async';

import 'package:circuitry/src/exceptions.dart';

part './wire.dart';

/// A dependency injection container managing lazy synchronous singletons
/// and asynchronously resolved dependencies backed by a Directed Acyclic Graph (DAG).
final class Circuit._({
  required final Map<WireKey, CircuitWire> _wires,
  required final Map<WireKey, Object?> _instances,
  required final Map<WireKey, int> _levels,
  required final int _maxLevel,
}) {
  final Set<WireKey> _creating = {};
  bool _isDisposed = false;
  Future<void>? _disposeFuture;

  /// Whether this circuit has been shut down via [dispose].
  bool get isDisposed => _isDisposed;

  /// Whether the wire for [key] has been instantiated on an active circuit.
  bool isKeyInitialized(WireKey key) =>
      !_isDisposed && _instances.containsKey(key);

  /// Whether the untagged wire of type [T] has been instantiated.
  bool isInitialized<T>() => isKeyInitialized((T, null));

  /// Whether the tagged wire of type [T] with [tag] has been instantiated.
  bool isInitializedTagged<T, K extends Enum>(K tag) =>
      isKeyInitialized((T, tag));

  /// Builds a [Circuit] from the provided [wires].
  ///
  /// Validates the dependency graph for:
  /// - Duplicate keys -> throws [DuplicateWireException]
  /// - Missing dependencies -> throws [MissingWireException]
  /// - Circular dependencies -> throws [CircularDependencyException]
  ///
  /// Once validated, all [AsyncWire]s are resolved in parallel topological waves
  /// using [Future.wait].
  static Future<Circuit> build(List<CircuitWire> wires) async {
    // 1. Duplicate wire detection
    final wireMap = <WireKey, CircuitWire>{};
    for (final wire in wires) {
      if (wireMap.containsKey(wire.key)) {
        throw DuplicateWireException(
          'Duplicate wire registered for key ${_formatKey(wire.key)}.',
          key: wire.key,
        );
      }
      wireMap[wire.key] = wire;
    }

    // 2. Missing dependency validation
    for (final wire in wires) {
      for (final depKey in wire.dependencies) {
        if (!wireMap.containsKey(depKey)) {
          throw MissingWireException(
            'Missing wire for dependency ${_formatKey(depKey)} required by ${_formatKey(wire.key)}.',
            missingKey: depKey,
            requiredBy: wire.key,
          );
        }
      }
    }

    // 3. Cycle detection (DFS with recursion stack tracking)
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
            'Circular dependency detected: ${cycle.map(_formatKey).join(' -> ')}',
            cycle: .unmodifiable(cycle),
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

    // 4. Compute topological levels
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

    final instances = <WireKey, Object?>{};
    final circuit = Circuit._(
      wires: .unmodifiable(wireMap),
      levels: .unmodifiable(levels),
      instances: instances,
      maxLevel: maxLevel,
    );

    // 5. Resolve AsyncWires in parallel topological waves
    try {
      for (var i = 0; i <= maxLevel; i++) {
        final asyncWiresAtLevel = wireMap.values
            .whereType<AsyncWire<Object?>>()
            .where((w) => levels[w.key] == i)
            .toList();

        if (asyncWiresAtLevel.isNotEmpty) {
          await Future.wait(
            asyncWiresAtLevel.map((wire) async {
              final instance = await wire._create(circuit);
              instances[wire.key] = instance;
            }),
          );
        }
      }
    } catch (error, stackTrace) {
      try {
        await circuit.dispose();
      } catch (_) {
        // Suppress secondary disposal errors so original build failure is preserved.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    return circuit;
  }

  /// Synchronously retrieves the untagged dependency instance of type [T].
  ///
  /// Throws [DisposedCircuitException] if this circuit has been disposed.
  /// Throws [WireNotFoundException] if no wire is registered for [T].
  T get<T>() {
    _checkNotDisposed();
    return _getByKey((T, null)) as T;
  }

  /// Synchronously retrieves the tagged dependency instance of type [T] with [tag].
  ///
  /// Throws [DisposedCircuitException] if this circuit has been disposed.
  /// Throws [WireNotFoundException] if no wire is registered for [T] with [tag].
  T getTagged<T, K extends Enum>(K tag) {
    _checkNotDisposed();
    return _getByKey((T, tag)) as T;
  }

  Object? _getByKey(WireKey key) {
    _checkNotDisposed();

    if (_instances.containsKey(key)) {
      return _instances[key];
    }

    final wire = _wires[key];
    if (wire == null) {
      throw WireNotFoundException(
        'Wire for key ${_formatKey(key)} not found in circuit.',
        key: key,
      );
    }

    if (wire is! Wire<Object?>) {
      throw StateError(
        'Async wire ${_formatKey(key)} was not resolved during circuit build.',
      );
    }

    if (_creating.contains(key)) {
      throw CircularDependencyException(
        'Circular dependency detected while creating ${_formatKey(key)}.',
        cycle: [..._creating, key],
      );
    }

    _creating.add(key);
    try {
      final instance = wire._create(this);
      _instances[key] = instance;
      return instance;
    } finally {
      _creating.remove(key);
    }
  }

  /// Disposes this circuit in idempotent reverse topological waves (leaves -> roots),
  /// awaiting [onDispose] callbacks in parallel waves.
  ///
  /// Aggregates all disposal failures into a [DisposalException].
  /// Repeated calls after completion are safe no-ops.
  Future<void> dispose() async {
    if (_disposeFuture != null) {
      try {
        await _disposeFuture;
      } catch (_) {
        // If already disposed, subsequent calls are safe no-ops.
      }
      return;
    }
    return _disposeFuture = _performDispose();
  }

  Future<void> _performDispose() async {
    _isDisposed = true;

    final errors = <Object>[];
    final stackTraces = <StackTrace>[];

    try {
      for (var i = _maxLevel; i >= 0; i--) {
        final wiresAtLevel = _wires.values
            .where((w) => _levels[w.key] == i && _instances.containsKey(w.key))
            .toList();

        if (wiresAtLevel.isEmpty) continue;

        await Future.wait(
          wiresAtLevel.map((wire) async {
            try {
              final instance = _instances[wire.key];
              await wire.disposeInstance(instance);
            } catch (error, stackTrace) {
              errors.add(error);
              stackTraces.add(stackTrace);
            }
          }),
        );
      }
    } finally {
      _instances.clear();
    }

    if (errors.isNotEmpty) {
      throw DisposalException(
        'Circuit disposal encountered ${errors.length} error(s).',
        errors: .unmodifiable(errors),
        stackTraces: .unmodifiable(stackTraces),
      );
    }
  }

  void _checkNotDisposed() {
    if (_isDisposed) {
      throw const DisposedCircuitException(
        'The Circuit has been disposed and cannot be used.',
      );
    }
  }

  static String _formatKey(WireKey key) {
    final typeName = key.$1.toString();
    if (key.$2 == null) {
      return typeName;
    }
    return '$typeName#${key.$2}';
  }
}
