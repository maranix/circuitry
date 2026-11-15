import 'package:circuitry/src/circuit.dart';

/// Base exception for all circuit-related errors.
sealed class const CircuitException(final String message) implements Exception {
  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when multiple wires are registered with the same [WireKey].
final class const DuplicateWireException(
  super.message, {
  required final WireKey key,
}) extends CircuitException;

/// Thrown when a wire requires a dependency that was not provided to the circuit.
final class const MissingWireException(
  super.message, {
  required final WireKey missingKey,
  final WireKey? requiredBy,
}) extends CircuitException;

/// Thrown when a dependency cycle is detected in the circuit graph.
final class const CircularDependencyException(
  super.message, {
  required final List<WireKey> cycle,
}) extends CircuitException;

/// Thrown when looking up a wire that does not exist in the circuit.
final class const WireNotFoundException(
  super.message, {
  required final WireKey key,
}) extends CircuitException;

/// Thrown when attempting to resolve dependencies on a disposed [Circuit].
final class const DisposedCircuitException([
  super.message = 'The Circuit has been disposed and cannot be used.',
]) extends CircuitException;

/// Thrown when one or more disposal callbacks throw during circuit shutdown.
final class const DisposalException(
  super.message, {
  required final List<Object> errors,
  required final List<StackTrace> stackTraces,
}) extends CircuitException;
