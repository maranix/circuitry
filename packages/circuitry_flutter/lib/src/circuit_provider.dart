import 'package:circuitry/circuitry.dart';
import 'package:circuitry_flutter/src/circuit_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Signature for a builder callback that creates a widget tree based on the current [CircuitState].
///
/// Used by [CircuitProvider.new] to reactively render different UI representations
/// as the dependency graph transitions through [CircuitBuilding], [CircuitReady],
/// and [CircuitFailure].
typedef CircuitStateWidgetBuilder = Widget Function(
  BuildContext context,
  CircuitState state,
);

/// A widget that provides a [Circuit] dependency injection container to its descendants.
///
/// [CircuitProvider] acts as the composition root bridge between Circuitry's
/// Directed Acyclic Graph (DAG) dependency injection engine and the Flutter widget tree.
/// It exposes the active [Circuit] to descendant widgets via [CircuitProvider.of]
/// and [CircuitProvider.maybeOf].
///
/// ## Modes of Operation
///
/// 1. **Asynchronous DAG Compilation ([CircuitProvider])**:
///    Compiles a list of declarative [CircuitWire] recipes into a [Circuit]
///    container. This constructor manages the full asynchronous lifecycle:
///    it executes parallel topological wave resolution for [AsyncWire]s,
///    notifies its [builder] of state transitions ([CircuitBuilding],
///    [CircuitReady], [CircuitFailure]), and automatically disposes all
///    resolved singletons in reverse topological order when removed from the
///    widget tree or when [wires] change.
///
/// 2. **Synchronous Value Injection ([CircuitProvider.value])**:
///    Injects a pre-built [Circuit] directly into the widget subtree.
///    Useful for widget tests or apps that initialize dependencies prior to
///    [runApp]. This constructor does not track state, recompile graphs, or
///    dispose the container on unmount.
///
/// ## Examples
///
/// ### Asynchronous App Root Composition
///
/// ```dart
/// CircuitProvider(
///   wires: [
///     Wire(DatabaseConfig.new),
///     AsyncWire.takes<DatabaseConfig>().to(DatabaseService.connect),
///     Wire.takes<DatabaseService>().to(UserRepository.new),
///   ],
///   builder: (context, state) => switch (state) {
///     CircuitReady() => const MainApp(),
///     CircuitBuilding() => const SplashScreen(),
///     CircuitFailure(:final error, :final stackTrace) =>
///       ErrorScreen(error: error, stackTrace: stackTrace),
///   },
/// );
/// ```
///
/// ### Accessing Dependencies in Descendants
///
/// Descendants read singletons directly from the ambient [Circuit]:
///
/// ```dart
/// class UserProfileView extends StatelessWidget {
///   const UserProfileView({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final circuit = CircuitProvider.of(context);
///     final userRepo = circuit.get<UserRepository>();
///
///     return Text('User repository ready: $userRepo');
///   }
/// }
/// ```
///
/// ### Synchronous Injection in Tests
///
/// ```dart
/// testWidgets('renders profile with mock circuit', (tester) async {
///   final mockCircuit = await Circuit.build([
///     Wire<UserRepository>(MockUserRepository.new),
///   ]);
///
///   await tester.pumpWidget(
///     CircuitProvider.value(
///       value: mockCircuit,
///       child: const MaterialApp(home: UserProfileView()),
///     ),
///   );
///
///   expect(find.byType(UserProfileView), findsOneWidget);
///   await mockCircuit.dispose();
/// });
/// ```
///
/// See also:
///
/// * [Circuit], the underlying pure Dart dependency injection engine.
/// * [CircuitWire], the base class for synchronous and asynchronous wire recipes.
/// * [CircuitState], the sealed state hierarchy yielded to [builder].
sealed class const CircuitProvider._({super.key}) extends StatelessWidget {
  /// Asynchronously compiles [wires] into a [Circuit] and yields reactive [CircuitState] to [builder].
  ///
  /// During initialization, [AsyncWire] singletons are resolved concurrently in
  /// topological waves. While compilation is in flight, [builder] receives a
  /// [CircuitBuilding] state. Once all wave dependencies settle, [builder] receives
  /// [CircuitReady] carrying the active [Circuit]. If any factory throws or DAG validation
  /// fails (e.g., circular dependencies or missing wires), [builder] receives [CircuitFailure].
  ///
  /// When this widget is unmounted from the tree or when [wires] changes, the
  /// resolved [Circuit] is automatically disposed in reverse topological order,
  /// executing all registered `onDispose` hooks.
  ///
  /// If [wires] changes while compilation is still in flight, the superseded build
  /// is cancelled and any partially resolved singletons are safely discarded. If the
  /// new [wires] list contains the same wire elements (compared using [listEquals]),
  /// compilation is not restarted and the existing circuit is preserved.
  const factory({
    Key? key,
    required List<CircuitWire> wires,
    required CircuitStateWidgetBuilder builder,
  }) = _CircuitWireProvider;

  /// Injects an existing [value] into the widget subtree without managing its lifecycle.
  ///
  /// Descendant widgets can immediately access [value] via [CircuitProvider.of] or
  /// [CircuitProvider.maybeOf].
  ///
  /// Unlike [CircuitProvider.new], this constructor does not perform asynchronous compilation,
  /// emit [CircuitState] updates, or dispose [value] when unmounted. The caller remains
  /// responsible for managing the lifecycle and disposing [value].
  const factory value({
    Key? key,
    required Circuit value,
    required Widget child,
  }) = _CircuitValueProvider;

  /// Finds the nearest [Circuit] ancestor provided by a [CircuitProvider].
  ///
  /// Calling this method creates a dependency on the nearest [CircuitProvider],
  /// causing the calling [context] to rebuild if the active [Circuit] changes.
  ///
  /// Throws a [StateError] if no [CircuitProvider] is found in [context], or if
  /// the enclosing [CircuitProvider.new] has not finished building and is not yet
  /// in the [CircuitReady] state.
  ///
  /// To safely query the [Circuit] without throwing when it is unavailable, use [maybeOf].
  static Circuit of(BuildContext context) {
    final circuit = maybeOf(context);
    if (circuit == null) {
      throw StateError(
        'No CircuitProvider found in context. Ensure that CircuitProvider or '
        'CircuitProvider.value wraps this widget tree and that the circuit is ready.',
      );
    }
    return circuit;
  }

  /// Finds the nearest [Circuit] ancestor provided by a [CircuitProvider], or `null` if none exists.
  ///
  /// Returns `null` if no [CircuitProvider] encloses [context], or if the enclosing
  /// [CircuitProvider.new] is currently in the [CircuitBuilding] or [CircuitFailure] state.
  ///
  /// Calling this method creates a dependency on the nearest [CircuitProvider],
  /// causing the calling [context] to rebuild if the active [Circuit] changes.
  static Circuit? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_CircuitScope>()?.circuit;
  }
}

/// Internal [CircuitProvider] implementation that synchronously injects an existing [Circuit].
///
/// Backs the [CircuitProvider.value] factory constructor. It mounts a [_CircuitScope]
/// directly with [value] and renders [child] without executing asynchronous DAG compilation,
/// tracking state transitions, or disposing [value] when unmounted from the tree.
final class const _CircuitValueProvider({
  super.key,
  required final Circuit value,
  required final Widget child,
}) extends CircuitProvider {
  this : super._();

  @override
  Widget build(BuildContext context) =>
      _CircuitScope(circuit: value, child: child);
}

/// Internal [CircuitProvider] implementation that manages asynchronous compilation of [wires].
///
/// Backs the default [CircuitProvider.new] constructor. It delegates to the stateful
/// [_CircuitWireStateful] widget to handle asynchronous DAG compilation, cancellation on input
/// updates, and automatic reverse topological disposal on unmount.
final class const _CircuitWireProvider({
  super.key,
  required final List<CircuitWire> wires,
  required final CircuitStateWidgetBuilder builder,
}) extends CircuitProvider {
  this : super._();

  @override
  Widget build(BuildContext context) {
    return _CircuitWireStateful(wires: wires, builder: builder);
  }
}

/// Internal stateful host widget that tracks compilation lifecycle and epoch state for [wires].
final class const _CircuitWireStateful({
  required final List<CircuitWire> wires,
  required final CircuitStateWidgetBuilder builder,
}) extends StatefulWidget {
  @override
  State<_CircuitWireStateful> createState() => _CircuitWireStatefulState();
}

/// State object managing asynchronous DAG compilation, race condition prevention, and disposal.
///
/// Maintains a `_compilationEpoch` counter to detect and discard stale compilation results
/// when [widget.wires] changes in [didUpdateWidget] or when this state is unmounted.
class _CircuitWireStatefulState extends State<_CircuitWireStateful> {
  CircuitState _state = const .building();
  Circuit? _circuit;
  int _compilationEpoch = 0;

  @override
  void initState() {
    super.initState();
    _startCompilation();
  }

  @override
  void didUpdateWidget(covariant _CircuitWireStateful oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.wires, oldWidget.wires)) {
      _compilationEpoch++;
      _circuit?.dispose().ignore();
      _circuit = null;
      setState(() {
        _state = const .building();
      });
      _startCompilation();
    }
  }

  void _startCompilation() {
    final currentEpoch = ++_compilationEpoch;
    Circuit.build(widget.wires).then(
      (circuit) {
        if (!mounted || currentEpoch != _compilationEpoch) {
          circuit.dispose().ignore();
          return;
        }
        _circuit = circuit;
        setState(() {
          _state = .ready(circuit);
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || currentEpoch != _compilationEpoch) return;
        setState(() {
          _state = .failure(error, stackTrace);
        });
      },
    );
  }

  @override
  void dispose() {
    _compilationEpoch++;
    _circuit?.dispose().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      CircuitReady(:final circuit) => _CircuitScope(
        circuit: circuit,
        child: Builder(builder: (context) => widget.builder(context, _state)),
      ),
      _ => widget.builder(context, _state),
    };
  }
}

/// Internal [InheritedWidget] carrying the active [Circuit] through the widget tree.
///
/// Inserted into the widget hierarchy by [_CircuitValueProvider] or by [_CircuitWireStatefulState]
/// when the compilation state reaches [CircuitReady]. Descendant widgets access this container
/// via [CircuitProvider.of] and [CircuitProvider.maybeOf].
///
/// Dependent widgets are notified to rebuild whenever [circuit] identity changes
/// according to [updateShouldNotify].
final class const _CircuitScope({
  required super.child,
  required final Circuit circuit,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(_CircuitScope oldWidget) =>
      circuit != oldWidget.circuit;
}
