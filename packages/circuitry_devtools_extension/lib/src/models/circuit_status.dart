/// Lifecycle status of an active or terminated [Circuit].
enum CircuitLifecycleStatus {
  building,
  ready,
  failed,
  disposed;

  /// Returns the human-readable label for this lifecycle status.
  String get label => switch (this) {
    building => 'Building',
    ready => 'Ready',
    failed => 'Failed',
    disposed => 'Disposed',
  };

  /// Derives the lifecycle status from container state flags and counts.
  factory fromState({
    required bool isDisposed,
    required int wireCount,
    required int initializedWireCount,
    bool hasFailed = false,
  }) => switch ((isDisposed, hasFailed, wireCount)) {
    (true, _, _) => .disposed,
    (_, true, _) => .failed,
    (_, _, 0) => .building,
    _ => .ready,
  };

  /// Parses a status name (case-insensitive) into a [CircuitLifecycleStatus].
  factory fromName(String? name) => switch (name?.toLowerCase()) {
    'building' => .building,
    'failed' => .failed,
    'disposed' => .disposed,
    _ => .ready,
  };
}
