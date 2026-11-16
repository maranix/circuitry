import 'package:circuitry/src/circuit.dart';
import 'package:circuitry/src/wire.dart';

/// Metadata describing a [Circuit] container during its build lifecycle.
final class const CircuitInfo({
  /// The total number of registered wires in the circuit.
  required final int wireCount,

  /// The number of asynchronous wires in the circuit.
  final int asyncWireCount = 0,

  /// The maximum topological wave level (depth) in the circuit.
  final int maxWaveLevel = 0,

  /// Additional contextual metadata associated with this circuit build.
  final Map<String, Object?> metadata = const {},
}) {
  /// The number of synchronous lazy wires in the circuit.
  int get syncWireCount => wireCount - asyncWireCount;
}

/// An observer interface for monitoring the lifecycle of a [Circuit].
///
/// Implementations can be attached to [CircuitObserver.global], provided via
/// [Zone] specification `#circuitObserver`, or passed explicitly to [Circuit.build]
/// to receive notifications when circuits are building, resolving waves,
/// resolving wires, becoming ready, or disposing.
abstract interface class CircuitObserver {
  /// The global observer instance receiving lifecycle events across all circuits.
  static CircuitObserver? global;

  /// Creates a composite observer that fans out events to all [observers].
  static CircuitObserver composite(List<CircuitObserver> observers) =>
      _CompositeCircuitObserver(observers);

  /// Called when a circuit begins its build phase.
  void onCircuitBuilding(CircuitInfo info);

  /// Called when a topological wave of asynchronous wires begins resolution.
  void onWaveStarted(int waveLevel, List<WireKey> wireKeys);

  /// Called when a wire has successfully resolved.
  void onWireResolved(WireKey key, Duration duration, [Object? instance]);

  /// Called when wire resolution throws an error.
  void onWireFailed(
    WireKey key,
    Object error,
    StackTrace stackTrace, [
    Duration? duration,
  ]);

  /// Called when all asynchronous wires in a topological wave finish resolution.
  void onWaveCompleted(int waveLevel, Duration duration);

  /// Called when a circuit completes its build phase and is ready for use.
  void onCircuitReady(Circuit circuit, [Duration? totalDuration]);

  /// Called when a circuit begins tearing down its active instances.
  void onCircuitDisposing(Circuit circuit);

  /// Called when a circuit completes disposal of all active instances.
  void onCircuitDisposed(Circuit circuit, [Duration? totalDuration]);
}

/// A composite implementation of [CircuitObserver] that dispatches each lifecycle event
/// to all inner observers.
base class CompositeCircuitObserver implements CircuitObserver {
  final List<CircuitObserver> _observers;

  /// Constructs a [CompositeCircuitObserver] wrapping the given [_observers].
  const CompositeCircuitObserver(this._observers);

  /// The list of inner observers receiving dispatched events.
  List<CircuitObserver> get observers => _observers;

  @override
  void onCircuitBuilding(CircuitInfo info) {
    for (final observer in _observers) {
      observer.onCircuitBuilding(info);
    }
  }

  @override
  void onWaveStarted(int waveLevel, List<WireKey> wireKeys) {
    for (final observer in _observers) {
      observer.onWaveStarted(waveLevel, wireKeys);
    }
  }

  @override
  void onWireResolved(WireKey key, Duration duration, [Object? instance]) {
    for (final observer in _observers) {
      observer.onWireResolved(key, duration, instance);
    }
  }

  @override
  void onWireFailed(
    WireKey key,
    Object error,
    StackTrace stackTrace, [
    Duration? duration,
  ]) {
    for (final observer in _observers) {
      observer.onWireFailed(key, error, stackTrace, duration);
    }
  }

  @override
  void onWaveCompleted(int waveLevel, Duration duration) {
    for (final observer in _observers) {
      observer.onWaveCompleted(waveLevel, duration);
    }
  }

  @override
  void onCircuitReady(Circuit circuit, [Duration? totalDuration]) {
    for (final observer in _observers) {
      observer.onCircuitReady(circuit, totalDuration);
    }
  }

  @override
  void onCircuitDisposing(Circuit circuit) {
    for (final observer in _observers) {
      observer.onCircuitDisposing(circuit);
    }
  }

  @override
  void onCircuitDisposed(Circuit circuit, [Duration? totalDuration]) {
    for (final observer in _observers) {
      observer.onCircuitDisposed(circuit, totalDuration);
    }
  }
}

/// Internal composite implementation of [CircuitObserver].
final class _CompositeCircuitObserver extends CompositeCircuitObserver {
  const _CompositeCircuitObserver(super.observers);
}

/// A convenient base implementation of [CircuitObserver] with no-op default methods.
///
/// Subclass this when you only need to observe a subset of lifecycle events.
base class BaseCircuitObserver implements CircuitObserver {
  /// Constructs a [BaseCircuitObserver].
  const BaseCircuitObserver();

  @override
  void onCircuitBuilding(CircuitInfo info) {}

  @override
  void onWaveStarted(int waveLevel, List<WireKey> wireKeys) {}

  @override
  void onWireResolved(WireKey key, Duration duration, [Object? instance]) {}

  @override
  void onWireFailed(
    WireKey key,
    Object error,
    StackTrace stackTrace, [
    Duration? duration,
  ]) {}

  @override
  void onWaveCompleted(int waveLevel, Duration duration) {}

  @override
  void onCircuitReady(Circuit circuit, [Duration? totalDuration]) {}

  @override
  void onCircuitDisposing(Circuit circuit) {}

  @override
  void onCircuitDisposed(Circuit circuit, [Duration? totalDuration]) {}
}
