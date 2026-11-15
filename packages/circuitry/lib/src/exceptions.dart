/// A record tuple uniquely identifying a wire in a circuit.
///
/// Untagged wires have a key of `(T, null)`.
/// Tagged wires have a key of `(T, tag)` where `tag is Enum`.
typedef WireKey = (Type type, Enum? tag);

/// Base exception for all circuit-related errors.
sealed class CircuitException implements Exception {
  final String message;

  const CircuitException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when multiple wires are registered with the same [WireKey].
final class DuplicateWireException extends CircuitException {
  final WireKey key;

  DuplicateWireException(super.message, {required this.key});
}

/// Thrown when a wire requires a dependency that was not provided to the circuit.
final class MissingWireException extends CircuitException {
  final WireKey missingKey;
  final WireKey? requiredBy;

  MissingWireException(
    super.message, {
    required this.missingKey,
    this.requiredBy,
  });
}

/// Thrown when a dependency cycle is detected in the circuit graph.
final class CircularDependencyException extends CircuitException {
  final List<WireKey> cycle;

  CircularDependencyException(super.message, {required this.cycle});
}

/// Thrown when looking up a wire that does not exist in the circuit.
final class WireNotFoundException extends CircuitException {
  final WireKey key;

  WireNotFoundException(super.message, {required this.key});
}

/// Thrown when attempting to resolve dependencies on a disposed [Circuit].
final class DisposedCircuitException extends CircuitException {
  const DisposedCircuitException([
    super.message = 'The Circuit has been disposed and cannot be used.',
  ]);
}

/// Thrown when one or more disposal callbacks throw during circuit shutdown.
final class DisposalException extends CircuitException {
  final List<Object> errors;
  final List<StackTrace> stackTraces;

  DisposalException(
    super.message, {
    required this.errors,
    required this.stackTraces,
  });
}
