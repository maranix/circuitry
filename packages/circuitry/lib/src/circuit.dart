import 'dart:async';

import 'package:circuitry/src/exceptions.dart';
import 'package:circuitry/src/graph.dart';
import 'package:circuitry/src/introspection.dart';
import 'package:circuitry/src/registry.dart';
import 'package:circuitry/src/utils.dart';
import 'package:circuitry/src/wire.dart';

/// A dependency injection container managing lazy synchronous singletons
/// and asynchronously resolved dependencies backed by a Directed Acyclic Graph (DAG).
final class Circuit._(final CircuitGraph _graph) {
  final Map<WireKey, Object?> _instances = {};
  final Set<WireKey> _creating = {};
  bool _isDisposed = false;
  Future<void>? _disposeFuture;

  /// The compiled [CircuitGraph] backing this container.
  CircuitGraph get graph => _graph;

  /// Returns an on-demand [CircuitIntrospection] snapshot inspecting this circuit.
  CircuitIntrospection inspect() => CircuitIntrospection.of(this);

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
  /// Optionally accepts a [debugTag] string to label the container in DevTools
  /// and the ambient [CircuitRegistry]. In profile and release modes (when assertions
  /// are disabled), [debugTag] is a complete no-op and is stripped by the compiler.
  ///
  /// Validates the dependency graph for:
  /// - Duplicate keys -> throws [DuplicateWireException]
  /// - Missing dependencies -> throws [MissingWireException]
  /// - Circular dependencies -> throws [CircularDependencyException]
  ///
  /// Once validated, all [AsyncWire]s are resolved in parallel topological waves
  /// using [Future.wait] with fail-fast error handling.
  static Future<Circuit> build(
    List<CircuitWire> wires, {
    String? debugTag,
  }) async {
    final graph = CircuitGraph(wires)..compile();
    final circuit = Circuit._(graph);

    if (isDebugMode) {
      CircuitRegistry.instance.onCircuitBuilding(circuit, debugTag: debugTag);
    }

    try {
      await circuit._resolveAsyncWaves();
      if (isDebugMode) {
        CircuitRegistry.instance.onCircuitReady(circuit, debugTag: debugTag);
      }
      return circuit;
    } catch (error) {
      if (isDebugMode) {
        CircuitRegistry.instance.onCircuitFailed(
          circuit,
          error,
          debugTag: debugTag,
        );
      }
      rethrow;
    }
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

  /// Synchronously resolves and returns the dependency instance registered for [key].
  ///
  /// Instantiates lazy synchronous singletons on-demand if not already created.
  /// Throws [DisposedCircuitException] if this circuit has been disposed.
  /// Throws [WireNotFoundException] if no wire is registered for [key].
  Object? resolveWireKey(WireKey key) {
    _checkNotDisposed();
    return _getByKey(key);
  }

  Object? _getByKey(WireKey key) {
    _checkNotDisposed();

    if (_instances.containsKey(key)) {
      return _instances[key];
    }

    final wire = _graph.wireMap[key];
    if (wire == null) {
      throw WireNotFoundException(
        'Wire for key ${formatWireKey(key)} not found in circuit.',
        key: key,
      );
    }

    switch (wire) {
      case Wire<Object?>():
        if (_creating.contains(key)) {
          throw CircularDependencyException(
            'Circular dependency detected while creating ${formatWireKey(key)}.',
            cycle: [..._creating, key],
          );
        }

        _creating.add(key);
        try {
          final instance = wire.connect(this);
          _instances[key] = instance;
          if (isDebugMode) {
            CircuitRegistry.instance.onWireResolved(this, key, isAsync: false);
          }
          return instance;
        } finally {
          _creating.remove(key);
        }
      case AsyncWire<Object?>():
        throw StateError(
          'Async wire ${formatWireKey(key)} was not resolved during circuit build.',
        );
    }
  }

  /// Resolves all [AsyncWire]s in parallel topological waves.
  ///
  /// Fails fast upon the first error in any wave using [Future.wait] with `eagerError: true`,
  /// immediately performing reverse topological disposal on already-initialized instances
  /// before rethrowing the failure.
  Future<void> _resolveAsyncWaves() async {
    try {
      for (var level = 0; level <= _graph.maxLevel; level++) {
        final asyncWires = _graph.asyncWiresAtLevel(level);
        if (asyncWires.isEmpty) continue;

        await Future.wait(
          asyncWires.map((wire) async {
            final instance = await wire.connect(this);
            if (_isDisposed) {
              try {
                await wire.disposeInstance(instance);
              } catch (_) {
                // Suppress disposal errors during teardown of late-resolving wire.
              }
            } else {
              _instances[wire.key] = instance;
              if (isDebugMode) {
                CircuitRegistry.instance.onWireResolved(
                  this,
                  wire.key,
                  isAsync: true,
                );
              }
            }
          }),
          eagerError: true,
        );
      }
    } catch (error, stackTrace) {
      try {
        await dispose();
      } catch (_) {
        // Suppress secondary disposal errors so original build failure is preserved.
      }
      Error.throwWithStackTrace(error, stackTrace);
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
    if (isDebugMode) {
      CircuitRegistry.instance.onCircuitDisposed(this);
    }

    final errors = <Object>[];
    final stackTraces = <StackTrace>[];

    try {
      for (var level = _graph.maxLevel; level >= 0; level--) {
        final wiresAtLevel = _graph
            .wiresAtLevel(level)
            .where((w) => _instances.containsKey(w.key))
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
}
