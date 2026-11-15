import 'dart:async';

import 'package:circuitry/src/circuit.dart';

/// A record tuple uniquely identifying a registered dependency in a [Circuit].
///
/// Keys are represented as a pair containing the registered dependency [Type]
/// and an optional [Enum] tag:
/// * **Untagged wire**: `(T, null)`
/// * **Tagged wire**: `(T, tag)` where `tag is Enum`
///
/// Using enum tags enables concise Dart dot-shorthands (e.g. `tag: .dev`, `tag: .prod`)
/// while preventing collisions between multiple registrations of the same underlying type.
///
/// ```dart
/// enum Environment { dev, prod }
///
/// const untaggedKey = (DatabaseService, null);
/// const devKey = (DatabaseService, Environment.dev);
/// ```
typedef WireKey = (Type type, Enum? tag);

/// Signature for a synchronous zero-dependency factory closure that constructs an instance of [T].
///
/// Because zero-dependency singletons accept no parameters, existing constructor tear-offs
/// (such as `DatabaseConfig.new`) can be passed directly to [Wire.new] and [Wire.tag].
///
/// This closure intentionally omits access to the [Circuit] to ensure that zero-dependency
/// root singletons cannot circumvent the Directed Acyclic Graph (DAG) by dynamically
/// querying undeclared dependencies at runtime.
typedef WireFactory<T> = T Function();

/// Signature for an asynchronous zero-dependency factory closure that constructs a `Future<T>`.
///
/// Passed to [AsyncWire.new] and [AsyncWire.tag] to define asynchronous root singletons.
/// Like [WireFactory], this closure omits access to the [Circuit] to guarantee that all
/// dependencies must be explicitly declared within the Directed Acyclic Graph (DAG).
typedef AsyncWireFactory<T> = Future<T> Function();

/// Signature for a cleanup callback invoked when an active instance of [T] is disposed by a [Circuit].
///
/// Disposers can perform either synchronous or asynchronous resource cleanup by returning
/// `FutureOr<void>`. When a [Circuit] is disposed, all active singletons with registered
/// disposers are torn down in reverse topological order (dependents before dependencies).
typedef WireDisposer<T> = FutureOr<void> Function(T instance);

/// Signature for a synchronous factory closure that instantiates [T] using an active [Circuit].
///
/// Used internally by [WireBuilder.to] to resolve all declared dependencies
/// from the [Circuit] container and supply them to the user-provided instantiation function.
typedef WireBuilderFactory<T> = T Function(Circuit circuit);

/// Signature for an asynchronous factory closure that instantiates [T] using an active [Circuit].
///
/// Used internally by [AsyncWireBuilder.to] to resolve all declared dependencies
/// from the [Circuit] container and supply them to the user-provided asynchronous
/// instantiation function.
typedef AsyncWireBuilderFactory<T> = Future<T> Function(Circuit circuit);

/// Signature for a closure that unpacks and resolves accumulated dependencies of type [Acc] from a [Circuit].
///
/// Used by [WireBuilder] and [AsyncWireBuilder] to recursively resolve left-nested
/// dependency tuples from the active [Circuit] container during wire instantiation.
typedef WireDependencyResolver<Acc> = Acc Function(Circuit circuit);

/// Abstract base class representing a declarative dependency recipe in a [Circuit].
///
/// A wire defines the static metadata required to construct and manage a singleton
/// within a Directed Acyclic Graph (DAG), including its unique [key], its list of
/// required [dependencies], and its [disposeInstance] lifecycle hook.
///
/// Circuitry provides two concrete wire implementations:
/// * [Wire], representing synchronous lazy singletons instantiated on first access.
/// * [AsyncWire], representing asynchronous singletons resolved in parallel topological
///   waves during `Circuit.build`.
///
/// See also:
///
/// * [Wire], for synchronous dependency recipes.
/// * [AsyncWire], for asynchronous dependency recipes.
/// * [WireKey], for dependency tuple identifiers.
sealed class CircuitWire({
  /// The unique record tuple identifying this wire in a [Circuit].
  required final WireKey key,

  /// The record tuple keys of all dependencies required by this wire.
  required final List<WireKey> dependencies,
}) {
  /// Binds this wire recipe to [circuit], resolving all declared dependencies and returning the singleton instance.
  FutureOr<Object?> bind(Circuit circuit);

  /// Cleans up the provided [instance] if an `onDispose` hook was registered for this wire.
  ///
  /// Invoked by [Circuit.dispose] in reverse topological order. If [instance] was never
  /// instantiated or does not match this wire's runtime type, no cleanup is performed.
  FutureOr<void> disposeInstance(Object? instance);
}

/// A declarative recipe for a synchronous, lazily instantiated singleton of type [T].
///
/// Synchronous wires are evaluated lazily: their factory is only executed upon the
/// first call to `circuit.get<T>()` or when an [AsyncWire] depends on [T] during `Circuit.build`.
/// Once created, the singleton instance is memoized for the remainder of the [Circuit]'s lifecycle.
///
/// ## Declaring Synchronous Wires
///
/// ### Zero-Dependency Root Wires
///
/// Pass a zero-argument constructor tear-off or closure:
/// ```dart
/// final wire = Wire(DatabaseConfig.new);
/// ```
///
/// ### Tagged Wires
///
/// Use enum tags to differentiate multiple singletons of the same generic type:
/// ```dart
/// enum Environment { dev, prod }
///
/// final devConfig = Wire.tag(
///   () => const DatabaseConfig('dev.db'),
///   tag: Environment.dev,
/// );
/// ```
///
/// ### Declaring Dependencies
///
/// Chain dependencies fluently using [Wire.takes] and [Wire.takesTagged]:
/// ```dart
/// final userWire = Wire.takes<DatabaseService>()
///     .to(UserService.new);
///
/// final orderWire = Wire.takes<DatabaseService>()
///     .takes<UserService>()
///     .to((deps) => OrderService(deps.$1, deps.$2));
/// ```
///
/// ## Disposal
///
/// Register an optional [onDispose] callback to release resources when the [Circuit] is disposed:
/// ```dart
/// final serviceWire = Wire(
///   DatabaseService.new,
///   onDispose: (service) => service.close(),
/// );
/// ```
///
/// Uninitialized synchronous singletons are never passed to [onDispose].
///
/// See also:
///
/// * [WireBuilder], for chaining multiple synchronous dependencies.
/// * [AsyncWire], for asynchronous singletons.
final class Wire<T>._({
  required super.key,
  required super.dependencies,
  required final WireBuilderFactory<T> _create,
  final WireDisposer<T>? onDispose,
}) extends CircuitWire {
  /// Binds this wire recipe to [circuit], resolving all declared dependencies synchronously and returning the singleton of type [T].
  @override
  T bind(Circuit circuit) => _create(circuit);

  /// Creates an untagged synchronous wire with no dependencies.
  ///
  /// The [create] closure is evaluated lazily when the singleton is first requested
  /// via `circuit.get<T>()`.
  ///
  /// An optional [onDispose] callback may be supplied to clean up resources when the
  /// [Circuit] is disposed.
  new(WireFactory<T> create, {WireDisposer<T>? onDispose})
    : this._(
        key: (T, null),
        dependencies: const [],
        create: (_) => create(),
        onDispose: onDispose,
      );

  /// Creates a tagged synchronous wire of type [T] identified by [tag] with no dependencies.
  ///
  /// The [create] closure is evaluated lazily when the singleton is first requested
  /// via `circuit.getTagged<T, K>(tag)`.
  ///
  /// An optional [onDispose] callback may be supplied to clean up resources when the
  /// [Circuit] is disposed.
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

  /// Starts building a synchronous wire that depends on an untagged singleton of type [A].
  ///
  /// Returns a [WireBuilder] that can either chain additional dependencies or finalize
  /// the wire recipe using [WireBuilder.to].
  static WireBuilder<A> takes<A>() => ._([(A, null)], (c) => c.get<A>());

  /// Starts building a synchronous wire that depends on a tagged singleton of type [A] with [tag].
  ///
  /// Returns a [WireBuilder] that can either chain additional dependencies or finalize
  /// the wire recipe using [WireBuilder.to].
  static WireBuilder<A> takesTagged<A, K extends Enum>(K tag) =>
      ._([(A, tag)], (c) => c.getTagged<A, K>(tag));

  @override
  FutureOr<void> disposeInstance(Object? instance) {
    if (instance is T && onDispose != null) {
      return onDispose!(instance);
    }
  }
}

/// A declarative recipe for an asynchronous singleton of type [T] resolved during circuit build.
///
/// Unlike synchronous [Wire]s, all [AsyncWire] instances are resolved during `Circuit.build`.
/// Independent asynchronous wires are resolved concurrently in parallel topological waves
/// based on their depth in the Directed Acyclic Graph (DAG).
///
/// If any asynchronous factory throws an error during compilation, all singletons that
/// were successfully created in earlier waves are automatically cleaned up in reverse
/// topological order before `Circuit.build` rethrows the error.
///
/// ## Declaring Asynchronous Wires
///
/// ### Zero-Dependency Asynchronous Wires
///
/// ```dart
/// final clientWire = AsyncWire(
///   () async => HttpClient.connect('https://api.example.com'),
///   onDispose: (client) => client.close(),
/// );
/// ```
///
/// ### Tagged Asynchronous Wires
///
/// ```dart
/// enum Environment { dev, prod }
///
/// final dbWire = AsyncWire.tag(
///   () => Database.open('dev.sqlite'),
///   tag: Environment.dev,
///   onDispose: (db) => db.disconnect(),
/// );
/// ```
///
/// ### Declaring Dependencies
///
/// Chain dependencies fluently using [AsyncWire.takes] and [AsyncWire.takesTagged]:
/// ```dart
/// final authWire = AsyncWire.takes<Database>()
///     .to((db) => AuthService.create(db));
///
/// final apiWire = AsyncWire.takes<Database>()
///     .takesTagged<HttpClient, Environment>(Environment.prod)
///     .to((deps) => ApiGateway.initialize(deps.$1, deps.$2));
/// ```
///
/// See also:
///
/// * [AsyncWireBuilder], for chaining multiple asynchronous dependencies.
/// * [Wire], for synchronous lazy singletons.
final class AsyncWire<T>._({
  required super.key,
  required super.dependencies,
  required final AsyncWireBuilderFactory<T> _create,

  /// Optional disposal callback invoked when the circuit is disposed.
  final WireDisposer<T>? onDispose,
}) extends CircuitWire {
  /// Binds this wire recipe to [circuit], resolving all declared dependencies asynchronously and returning the singleton of type [T].
  @override
  Future<T> bind(Circuit circuit) => _create(circuit);

  /// Creates an untagged asynchronous wire with no dependencies.
  ///
  /// The [create] closure is evaluated asynchronously in parallel topological waves
  /// during `Circuit.build`.
  ///
  /// An optional [onDispose] callback may be supplied to clean up resources when the
  /// [Circuit] is disposed.
  new(AsyncWireFactory<T> create, {WireDisposer<T>? onDispose})
    : this._(
        key: (T, null),
        dependencies: const [],
        create: (_) => create(),
        onDispose: onDispose,
      );

  /// Creates a tagged asynchronous wire of type [T] identified by [tag] with no dependencies.
  ///
  /// The [create] closure is evaluated asynchronously in parallel topological waves
  /// during `Circuit.build`.
  ///
  /// An optional [onDispose] callback may be supplied to clean up resources when the
  /// [Circuit] is disposed.
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

  /// Starts building an asynchronous wire that depends on an untagged singleton of type [A].
  ///
  /// Returns an [AsyncWireBuilder] that can either chain additional dependencies or finalize
  /// the wire recipe using [AsyncWireBuilder.to].
  static AsyncWireBuilder<A> takes<A>() => ._([(A, null)], (c) => c.get<A>());

  /// Starts building an asynchronous wire that depends on a tagged singleton of type [A] with [tag].
  ///
  /// Returns an [AsyncWireBuilder] that can either chain additional dependencies or finalize
  /// the wire recipe using [AsyncWireBuilder.to].
  static AsyncWireBuilder<A> takesTagged<A, K extends Enum>(K tag) =>
      ._([(A, tag)], (c) => c.getTagged<A, K>(tag));

  @override
  FutureOr<void> disposeInstance(Object? instance) {
    if (instance is T && onDispose != null) {
      return onDispose!(instance);
    }
  }
}

/// Accumulator-based fluent builder for declaring dependencies of a synchronous [Wire].
///
/// Chained invocations of [takes] and [takesTagged] accumulate dependencies into strongly typed
/// left-nested record tuples:
/// * 1 dependency: `Acc = A`
/// * 2 dependencies: `Acc = (A, B)`
/// * 3 dependencies: `Acc = ((A, B), C)`
/// * 4 dependencies: `Acc = (((A, B), C), D)`
///
/// Call [to] to finalize the builder into a [Wire<T>].
///
/// ## Examples
///
/// Single dependency with constructor tear-off:
/// ```dart
/// final wire = Wire.takes<DatabaseService>()
///     .to(UserService.new);
/// ```
///
/// Multiple dependencies with record tuple destructuring:
/// ```dart
/// final wire = Wire.takes<DatabaseService>()
///     .takesTagged<AuthService, Environment>(Environment.prod)
///     .to((deps) => OrderService(deps.$1, deps.$2));
/// ```
final class WireBuilder<Acc>._(
  final List<WireKey> _dependencies,
  final WireDependencyResolver<Acc> _resolveDeps,
) {
  /// Appends an untagged dependency of type [Next] to the dependency accumulator.
  ///
  /// Returns a new [WireBuilder] carrying the accumulated tuple `(Acc, Next)`.
  WireBuilder<(Acc, Next)> takes<Next>() => ._([
    ..._dependencies,
    (Next, null),
  ], (c) => (_resolveDeps(c), c.get<Next>()));

  /// Appends a tagged dependency of type [Next] with [tag] to the dependency accumulator.
  ///
  /// Returns a new [WireBuilder] carrying the accumulated tuple `(Acc, Next)`.
  WireBuilder<(Acc, Next)> takesTagged<Next, K extends Enum>(K tag) => ._([
    ..._dependencies,
    (Next, tag),
  ], (c) => (_resolveDeps(c), c.getTagged<Next, K>(tag)));

  /// Completes the builder by defining the synchronous factory [create] receiving [Acc] dependencies.
  ///
  /// Supply an optional [tag] to register a tagged singleton, and an optional [onDispose]
  /// callback to handle resource teardown when the [Circuit] is disposed.
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

/// Accumulator-based fluent builder for declaring dependencies of an asynchronous [AsyncWire].
///
/// Chained invocations of [takes] and [takesTagged] accumulate dependencies into strongly typed
/// left-nested record tuples:
/// * 1 dependency: `Acc = A`
/// * 2 dependencies: `Acc = (A, B)`
/// * 3 dependencies: `Acc = ((A, B), C)`
/// * 4 dependencies: `Acc = (((A, B), C), D)`
///
/// Call [to] to finalize the builder into an [AsyncWire<T>].
///
/// ## Examples
///
/// Single dependency with asynchronous factory:
/// ```dart
/// final wire = AsyncWire.takes<DatabaseConfig>()
///     .to(DatabaseService.connect);
/// ```
///
/// Multiple dependencies with record tuple destructuring:
/// ```dart
/// final wire = AsyncWire.takes<DatabaseService>()
///     .takesTagged<NetworkConfig, Environment>(Environment.prod)
///     .to((deps) => ApiGateway.initialize(deps.$1, deps.$2));
/// ```
final class AsyncWireBuilder<Acc>._(
  final List<WireKey> _dependencies,
  final WireDependencyResolver<Acc> _resolveDeps,
) {
  /// Appends an untagged dependency of type [Next] to the dependency accumulator.
  ///
  /// Returns a new [AsyncWireBuilder] carrying the accumulated tuple `(Acc, Next)`.
  AsyncWireBuilder<(Acc, Next)> takes<Next>() => ._([
    ..._dependencies,
    (Next, null),
  ], (c) => (_resolveDeps(c), c.get<Next>()));

  /// Appends a tagged dependency of type [Next] with [tag] to the dependency accumulator.
  ///
  /// Returns a new [AsyncWireBuilder] carrying the accumulated tuple `(Acc, Next)`.
  AsyncWireBuilder<(Acc, Next)> takesTagged<Next, K extends Enum>(K tag) => ._([
    ..._dependencies,
    (Next, tag),
  ], (c) => (_resolveDeps(c), c.getTagged<Next, K>(tag)));

  /// Completes the builder by defining the asynchronous factory [create] receiving [Acc] dependencies.
  ///
  /// Supply an optional [tag] to register a tagged singleton, and an optional [onDispose]
  /// callback to handle resource teardown when the [Circuit] is disposed.
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
