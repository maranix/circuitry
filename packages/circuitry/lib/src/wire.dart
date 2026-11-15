part of './circuit.dart';

/// A record tuple uniquely identifying a wire in a circuit.
///
/// Untagged wires have a key of `(T, null)`.
/// Tagged wires have a key of `(T, tag)` where `tag is Enum`.
typedef WireKey = (Type type, Enum? tag);

/// Factory closure invoked synchronously with the active [Circuit] container
/// to resolve all declared dependencies and instantiate a [Wire].
typedef WireBuilderFactory<T> = T Function(Circuit circuit);

/// Asynchronous factory closure invoked with the active [Circuit] container
/// to resolve all declared dependencies and asynchronously instantiate an [AsyncWire].
typedef AsyncWireBuilderFactory<T> = Future<T> Function(Circuit circuit);

/// Synchronous zero-dependency factory closure for creating an instance of type [T].
typedef WireFactory<T> = T Function();

/// Asynchronous zero-dependency factory closure for creating an instance of type [T].
typedef AsyncWireFactory<T> = Future<T> Function();

/// Closure that resolves and unpacks accumulated dependencies of type [Acc] from a [Circuit].
typedef WireDependencyResolver<Acc> = Acc Function(Circuit circuit);

/// Callback invoked to clean up or dispose an active instance of type [T] when a [Circuit] is disposed.
typedef WireDisposer<T> = FutureOr<void> Function(T instance);

/// Base sealed class representing a dependency recipe in a circuit.
sealed class CircuitWire({
  /// Unique key identifying this wire in the circuit.
  required final WireKey key,

  /// The keys of all dependencies required by this wire.
  required final List<WireKey> dependencies,
}) {
  /// Invoked when disposing an active instance of this wire.
  FutureOr<void> disposeInstance(Object? instance);
}

/// A synchronous dependency recipe representing a lazy singleton.
final class Wire<T>._({
  required super.key,
  required super.dependencies,
  required final WireBuilderFactory<T> _create,
  final WireDisposer<T>? onDispose,
}) extends CircuitWire {
  /// Creates an untagged synchronous wire with no dependencies.
  new(WireFactory<T> create, {WireDisposer<T>? onDispose})
    : this._(
        key: (T, null),
        dependencies: const [],
        create: (_) => create(),
        onDispose: onDispose,
      );

  /// Creates a tagged synchronous wire with no dependencies.
  static Wire<T> tag<T, K extends Enum>(
    WireFactory<T> create, {
    required K tag,
    WireDisposer<T>? onDispose,
  }) => ._(
    key: (T, tag),
    dependencies: const [],
    create: (_) => create(),
    onDispose: onDispose,
  );

  /// Starts building a synchronous wire that depends on an untagged dependency of type [A].
  static WireBuilder<A> takes<A>() => ._([(A, null)], (c) => c.get<A>());

  /// Starts building a synchronous wire that depends on a tagged dependency of type [A] with [tag].
  static WireBuilder<A> takesTagged<A, K extends Enum>(K tag) =>
      ._([(A, tag)], (c) => c.getTagged<A, K>(tag));

  @override
  FutureOr<void> disposeInstance(Object? instance) {
    if (instance is T && onDispose != null) {
      return onDispose!(instance);
    }
  }
}

/// An asynchronous dependency recipe resolved in parallel topological waves during circuit build.
final class AsyncWire<T>._({
  required super.key,
  required super.dependencies,
  required final AsyncWireBuilderFactory<T> _create,

  /// Optional disposal callback invoked when the circuit is disposed.
  final WireDisposer<T>? onDispose,
}) extends CircuitWire {
  /// Creates an untagged asynchronous wire with no dependencies.
  new(AsyncWireFactory<T> create, {WireDisposer<T>? onDispose})
    : this._(
        key: (T, null),
        dependencies: const [],
        create: (_) => create(),
        onDispose: onDispose,
      );

  /// Creates a tagged asynchronous wire with no dependencies.
  static AsyncWire<T> tag<T, K extends Enum>(
    AsyncWireFactory<T> create, {
    required K tag,
    WireDisposer<T>? onDispose,
  }) => ._(
    key: (T, tag),
    dependencies: const [],
    create: (_) => create(),
    onDispose: onDispose,
  );

  /// Starts building an asynchronous wire that depends on an untagged dependency of type [A].
  static AsyncWireBuilder<A> takes<A>() => ._([(A, null)], (c) => c.get<A>());

  /// Starts building an asynchronous wire that depends on a tagged dependency of type [A] with [tag].
  static AsyncWireBuilder<A> takesTagged<A, K extends Enum>(K tag) =>
      ._([(A, tag)], (c) => c.getTagged<A, K>(tag));

  @override
  FutureOr<void> disposeInstance(Object? instance) {
    if (instance is T && onDispose != null) {
      return onDispose!(instance);
    }
  }
}

/// Accumulator-based chaining builder for synchronous [Wire]s.
final class WireBuilder<Acc>._(
  final List<WireKey> _dependencies,
  final WireDependencyResolver<Acc> _resolveDeps,
) {
  /// Appends an untagged dependency of type [Next] to the dependency accumulator.
  WireBuilder<(Acc, Next)> takes<Next>() => ._([
    ..._dependencies,
    (Next, null),
  ], (c) => (_resolveDeps(c), c.get<Next>()));

  /// Appends a tagged dependency of type [Next] with [tag] to the dependency accumulator.
  WireBuilder<(Acc, Next)> takesTagged<Next, K extends Enum>(K tag) => ._([
    ..._dependencies,
    (Next, tag),
  ], (c) => (_resolveDeps(c), c.getTagged<Next, K>(tag)));

  /// Completes the builder by defining the factory [create] that receives the accumulated dependencies.
  Wire<T> to<T, K extends Enum>(
    T Function(Acc deps) create, {
    K? tag,
    WireDisposer<T>? onDispose,
  }) => ._(
    key: (T, tag),
    dependencies: .unmodifiable(_dependencies),
    create: (Circuit c) => create(_resolveDeps(c)),
    onDispose: onDispose,
  );
}

/// Accumulator-based chaining builder for asynchronous [AsyncWire]s.
final class AsyncWireBuilder<Acc>._(
  final List<WireKey> _dependencies,
  final WireDependencyResolver<Acc> _resolveDeps,
) {
  /// Appends an untagged dependency of type [Next] to the dependency accumulator.
  AsyncWireBuilder<(Acc, Next)> takes<Next>() => ._([
    ..._dependencies,
    (Next, null),
  ], (c) => (_resolveDeps(c), c.get<Next>()));

  /// Appends a tagged dependency of type [Next] with [tag] to the dependency accumulator.
  AsyncWireBuilder<(Acc, Next)> takesTagged<Next, K extends Enum>(K tag) => ._([
    ..._dependencies,
    (Next, tag),
  ], (c) => (_resolveDeps(c), c.getTagged<Next, K>(tag)));

  /// Completes the builder by defining the asynchronous factory [create] that receives the accumulated dependencies.
  AsyncWire<T> to<T, K extends Enum>(
    Future<T> Function(Acc deps) create, {
    K? tag,
    WireDisposer<T>? onDispose,
  }) => ._(
    key: (T, tag),
    dependencies: .unmodifiable(_dependencies),
    create: (Circuit c) => create(_resolveDeps(c)),
    onDispose: onDispose,
  );
}
