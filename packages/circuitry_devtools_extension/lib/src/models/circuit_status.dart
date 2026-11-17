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
}
