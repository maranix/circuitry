import 'package:circuitry_devtools_extension/src/models/circuit_status.dart';

/// Immutable model representing an active or recent [Circuit] summary
/// received from `ext.circuitry.getCircuits`.
final class const CircuitSummary({
  /// Unique container identifier (e.g. `circuit_0`).
  required final String id,

  /// Optional debug tag or scope identifier (e.g. `AppScope.global`).
  final String? debugTag,

  /// Total number of dependency wires registered in the container.
  required final int wireCount,

  /// Number of wires that have been instantiated.
  required final int initializedWireCount,

  /// Maximum topological wave level (depth) in this circuit.
  required final int maxLevel,

  /// Whether this circuit has been disposed.
  required final bool isDisposed,

  /// The active lifecycle status of the container.
  final CircuitLifecycleStatus status = CircuitLifecycleStatus.ready,
}) {
  /// Number of wires registered but not yet initialized.
  int get uninitializedWireCount => wireCount - initializedWireCount;

  /// Parses a [CircuitSummary] from a JSON map using pattern matching.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'id': final String id,
      'isDisposed': final bool isDisposed,
      'wireCount': final num wireCount,
      'initializedWireCount': final num initializedWireCount,
      'maxLevel': final num maxLevel,
    }) {
      final debugTag = switch (json['debugTag']) {
        final String s => s,
        _ => null,
      };
      final status = switch (json['status']) {
        final String s => CircuitLifecycleStatus.fromName(s),
        _ => CircuitLifecycleStatus.fromState(
          isDisposed: isDisposed,
          wireCount: wireCount.toInt(),
          initializedWireCount: initializedWireCount.toInt(),
        ),
      };

      return CircuitSummary(
        id: id,
        debugTag: debugTag,
        wireCount: wireCount.toInt(),
        initializedWireCount: initializedWireCount.toInt(),
        maxLevel: maxLevel.toInt(),
        isDisposed: isDisposed,
        status: status,
      );
    }
    throw FormatException('Invalid circuit summary schema: $json');
  }

  /// Creates a copy of this summary with updated fields.
  CircuitSummary copyWith({
    String? id,
    String? debugTag,
    int? wireCount,
    int? initializedWireCount,
    int? maxLevel,
    bool? isDisposed,
    CircuitLifecycleStatus? status,
  }) => CircuitSummary(
    id: id ?? this.id,
    debugTag: debugTag ?? this.debugTag,
    wireCount: wireCount ?? this.wireCount,
    initializedWireCount: initializedWireCount ?? this.initializedWireCount,
    maxLevel: maxLevel ?? this.maxLevel,
    isDisposed: isDisposed ?? this.isDisposed,
    status: status ?? this.status,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircuitSummary &&
          id == other.id &&
          debugTag == other.debugTag &&
          wireCount == other.wireCount &&
          initializedWireCount == other.initializedWireCount &&
          maxLevel == other.maxLevel &&
          isDisposed == other.isDisposed &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
    id,
    debugTag,
    wireCount,
    initializedWireCount,
    maxLevel,
    isDisposed,
    status,
  );
}
