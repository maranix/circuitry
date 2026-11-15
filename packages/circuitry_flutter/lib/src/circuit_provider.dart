part of '../circuitry_flutter.dart';

/// Flutter bridge providing a [Circuit] container to the widget tree.
///
/// Use the default constructor to compile a list of [CircuitWire] recipes asynchronously:
/// ```dart
/// CircuitProvider(
///   wires: [myWire1, myWire2],
///   builder: (context, state) => switch (state) {
///     CircuitReady(:final circuit) => MyHomeScreen(),
///     CircuitBuilding() => const LoadingScreen(),
///     CircuitFailure(:final error) => const ErrorScreen(),
///   },
/// );
/// ```
///
/// Use [CircuitProvider.value] to provide an already-built [Circuit] synchronously:
/// ```dart
/// CircuitProvider.value(
///   value: existingCircuit,
///   child: MyHomeScreen(),
/// );
/// ```
sealed class const CircuitProvider._({super.key}) extends StatelessWidget {
  /// Asynchronously builds a [Circuit] from [wires] and executes [builder] with reactive [CircuitState].
  ///
  /// Disposes the resolved [Circuit] automatically when removed from the widget tree.
  const factory CircuitProvider({
    Key? key,
    required List<CircuitWire> wires,
    required Widget Function(BuildContext context, CircuitState state) builder,
  }) = CircuitWireProvider;

  /// Injects an already existing [Circuit] into the widget subtree without managing its lifecycle.
  const factory CircuitProvider.value({
    Key? key,
    required Circuit value,
    required Widget child,
  }) = CircuitValueProvider;

  /// Retrieves the nearest [Circuit] ancestor from [context].
  ///
  /// Throws a [StateError] if no [CircuitProvider] is found in [context] or if the circuit is not yet ready.
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

  /// Retrieves the nearest [Circuit] ancestor from [context], or `null` if none exists or the circuit is not ready.
  static Circuit? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_CircuitScope>()?.circuit;
  }
}

/// A [CircuitProvider] variant that synchronously injects an already resolved [Circuit] value.
///
/// Does not track state, execute asynchronous builds, or dispose the [Circuit] when unmounted.
final class const CircuitValueProvider({
  super.key,
  required final Circuit value,
  required final Widget child,
}) extends CircuitProvider {
  this : super._();

  @override
  Widget build(BuildContext context) =>
      _CircuitScope(circuit: value, child: child);
}

/// A [CircuitProvider] variant that manages the asynchronous build lifecycle of a list of [CircuitWire]s.
final class const CircuitWireProvider({
  super.key,
  required final List<CircuitWire> wires,
  required final Widget Function(BuildContext context, CircuitState state)
  builder,
}) extends CircuitProvider {
  this : super._();

  @override
  Widget build(BuildContext context) {
    return _CircuitWireStateful(wires: wires, builder: builder);
  }
}

final class const _CircuitWireStateful({
  required final List<CircuitWire> wires,
  required final Widget Function(BuildContext context, CircuitState state)
  builder,
}) extends StatefulWidget {
  @override
  State<_CircuitWireStateful> createState() => _CircuitWireStatefulState();
}

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
