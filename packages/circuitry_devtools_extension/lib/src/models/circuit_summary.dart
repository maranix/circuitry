import 'package:circuitry_devtools_extension/src/models/circuit_status.dart';

/// Immutable model representing an active or recent [Circuit] summary
/// received from `ext.circuitry.getCircuits`.
final class CircuitSummary {
  const CircuitSummary({
    required this.id,
    this.debugTag,
    required this.wireCount,
    required this.initializedWireCount,
    required this.maxLevel,
    required this.isDisposed,
    this.status = CircuitLifecycleStatus.ready,
  });

  /// Unique container identifier (e.g. `circuit_0`).
  final String id;

  /// Optional debug tag or scope identifier (e.g. `AppScope.global`).
  final String? debugTag;

  /// Total number of dependency wires registered in the container.
  final int wireCount;

  /// Number of wires that have been instantiated.
  final int initializedWireCount;

  /// Maximum topological wave level (depth) in this circuit.
  final int maxLevel;

  /// Whether this circuit has been disposed.
  final bool isDisposed;

  /// The active lifecycle status of the container.
  final CircuitLifecycleStatus status;

  /// Number of wires registered but not yet initialized.
  int get uninitializedWireCount => wireCount - initializedWireCount;

  /// Parses a [CircuitSummary] from a JSON map.
  factory CircuitSummary.fromJson(Map<String, Object?> json) {
    final isDisposed = json['isDisposed'] as bool? ?? false;
    final statusString = json['status'] as String?;
    final status = switch (statusString) {
      'building' => CircuitLifecycleStatus.building,
      'ready' => CircuitLifecycleStatus.ready,
      'failed' => CircuitLifecycleStatus.failed,
      'disposed' => CircuitLifecycleStatus.disposed,
      _ =>
        isDisposed
            ? CircuitLifecycleStatus.disposed
            : CircuitLifecycleStatus.ready,
    };

    return CircuitSummary(
      id: json['id'] as String? ?? '',
      debugTag: json['debugTag'] as String?,
      wireCount: (json['wireCount'] as num?)?.toInt() ?? 0,
      initializedWireCount:
          (json['initializedWireCount'] as num?)?.toInt() ?? 0,
      maxLevel: (json['maxLevel'] as num?)?.toInt() ?? 0,
      isDisposed: isDisposed,
      status: status,
    );
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
