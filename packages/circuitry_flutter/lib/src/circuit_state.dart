part of '../circuitry_flutter.dart';

/// Sealed hierarchy representing the compilation and readiness state of a [Circuit].
sealed class const CircuitState() {
  /// Represents a circuit that is currently resolving and compiling asynchronous wires.
  const factory building() = CircuitBuilding;

  /// Represents a successfully built and verified circuit ready for dependency injection.
  const factory ready(Circuit circuit) = CircuitReady;

  /// Represents a failure encountered during circuit validation or asynchronous wire resolution.
  const factory failure(Object error, [StackTrace? stackTrace]) =
      CircuitFailure;
}

/// State emitted while the circuit's dependency graph is validating and resolving.
final class const CircuitBuilding() extends CircuitState {
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CircuitBuilding;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'CircuitBuilding()';
}

/// State emitted when the circuit has completed all asynchronous wire resolutions and is ready.
final class const CircuitReady(final Circuit circuit) extends CircuitState {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircuitReady && identical(circuit, other.circuit);

  @override
  int get hashCode => identityHashCode(circuit);

  @override
  String toString() => 'CircuitReady($circuit)';
}

/// State emitted when circuit construction or wire resolution throws an error.
final class const CircuitFailure(
  final Object error, [
  final StackTrace? stackTrace,
]) extends CircuitState {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircuitFailure &&
          error == other.error &&
          stackTrace == other.stackTrace;

  @override
  int get hashCode => Object.hash(error, stackTrace);

  @override
  String toString() => 'CircuitFailure($error)';
}
