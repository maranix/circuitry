import 'dart:async';

import 'package:circuitry/circuitry.dart';
import 'package:test/test.dart';

sealed class ObserverEvent {
  const ObserverEvent();
}

final class CircuitBuildingEvent extends ObserverEvent {
  final CircuitInfo info;
  const CircuitBuildingEvent(this.info);
}

final class WaveStartedEvent extends ObserverEvent {
  final int waveLevel;
  final List<WireKey> wireKeys;
  const WaveStartedEvent(this.waveLevel, this.wireKeys);
}

final class WireResolvedEvent extends ObserverEvent {
  final WireKey key;
  final Duration duration;
  final Object? instance;
  const WireResolvedEvent(this.key, this.duration, this.instance);
}

final class WireFailedEvent extends ObserverEvent {
  final WireKey key;
  final Object error;
  final StackTrace stackTrace;
  final Duration? duration;
  const WireFailedEvent(this.key, this.error, this.stackTrace, this.duration);
}

final class WaveCompletedEvent extends ObserverEvent {
  final int waveLevel;
  final Duration duration;
  const WaveCompletedEvent(this.waveLevel, this.duration);
}

final class CircuitReadyEvent extends ObserverEvent {
  final Circuit circuit;
  final Duration? totalDuration;
  const CircuitReadyEvent(this.circuit, this.totalDuration);
}

final class CircuitDisposingEvent extends ObserverEvent {
  final Circuit circuit;
  const CircuitDisposingEvent(this.circuit);
}

final class CircuitDisposedEvent extends ObserverEvent {
  final Circuit circuit;
  final Duration? totalDuration;
  const CircuitDisposedEvent(this.circuit, this.totalDuration);
}

final class RecordingObserver extends BaseCircuitObserver {
  final List<ObserverEvent> events = [];

  @override
  void onCircuitBuilding(CircuitInfo info) {
    events.add(CircuitBuildingEvent(info));
  }

  @override
  void onWaveStarted(int waveLevel, List<WireKey> wireKeys) {
    events.add(WaveStartedEvent(waveLevel, wireKeys));
  }

  @override
  void onWireResolved(WireKey key, Duration duration, [Object? instance]) {
    events.add(WireResolvedEvent(key, duration, instance));
  }

  @override
  void onWireFailed(
    WireKey key,
    Object error,
    StackTrace stackTrace, [
    Duration? duration,
  ]) {
    events.add(WireFailedEvent(key, error, stackTrace, duration));
  }

  @override
  void onWaveCompleted(int waveLevel, Duration duration) {
    events.add(WaveCompletedEvent(waveLevel, duration));
  }

  @override
  void onCircuitReady(Circuit circuit, [Duration? totalDuration]) {
    events.add(CircuitReadyEvent(circuit, totalDuration));
  }

  @override
  void onCircuitDisposing(Circuit circuit) {
    events.add(CircuitDisposingEvent(circuit));
  }

  @override
  void onCircuitDisposed(Circuit circuit, [Duration? totalDuration]) {
    events.add(CircuitDisposedEvent(circuit, totalDuration));
  }
}

void main() {
  tearDown(() {
    CircuitObserver.global = null;
  });

  group('CircuitInfo', () {
    test('computes syncWireCount from wireCount and asyncWireCount', () {
      const info = CircuitInfo(
        wireCount: 10,
        asyncWireCount: 3,
        maxWaveLevel: 2,
        metadata: {'environment': 'test'},
      );

      expect(info.wireCount, equals(10));
      expect(info.asyncWireCount, equals(3));
      expect(info.maxWaveLevel, equals(2));
      expect(info.syncWireCount, equals(7));
      expect(info.metadata['environment'], equals('test'));
    });

    test('defaults asyncWireCount, maxWaveLevel, and metadata', () {
      const info = CircuitInfo(wireCount: 5);

      expect(info.wireCount, equals(5));
      expect(info.asyncWireCount, equals(0));
      expect(info.maxWaveLevel, equals(0));
      expect(info.syncWireCount, equals(5));
      expect(info.metadata, isEmpty);
    });
  });

  group('CircuitObserver and BaseCircuitObserver', () {
    test('CircuitObserver.global can be set and cleared', () {
      expect(CircuitObserver.global, isNull);
      final observer = RecordingObserver();
      CircuitObserver.global = observer;
      expect(CircuitObserver.global, same(observer));
      CircuitObserver.global = null;
      expect(CircuitObserver.global, isNull);
    });

    test('BaseCircuitObserver provides safe no-op implementations', () {
      const observer = BaseCircuitObserver();
      const info = CircuitInfo(wireCount: 2);

      expect(() => observer.onCircuitBuilding(info), returnsNormally);
      expect(() => observer.onWaveStarted(0, const []), returnsNormally);
      expect(
        () => observer.onWireResolved(
          (String, null),
          const Duration(milliseconds: 5),
          'test',
        ),
        returnsNormally,
      );
      expect(
        () => observer.onWireFailed(
          (int, null),
          Exception('test'),
          StackTrace.empty,
          const Duration(milliseconds: 2),
        ),
        returnsNormally,
      );
      expect(
        () => observer.onWaveCompleted(0, const Duration(milliseconds: 10)),
        returnsNormally,
      );
    });
  });

  group('CompositeCircuitObserver', () {
    test('fans out all lifecycle calls to all inner observers', () {
      final obs1 = RecordingObserver();
      final obs2 = RecordingObserver();
      final composite = CompositeCircuitObserver([obs1, obs2]);

      const info = CircuitInfo(wireCount: 2);
      composite.onCircuitBuilding(info);
      composite.onWaveStarted(0, [(String, null)]);
      composite.onWireResolved(
        (String, null),
        const Duration(milliseconds: 10),
        'hello',
      );
      composite.onWireFailed(
        (int, null),
        StateError('err'),
        StackTrace.empty,
        const Duration(milliseconds: 3),
      );
      composite.onWaveCompleted(0, const Duration(milliseconds: 15));

      expect(obs1.events.length, equals(5));
      expect(obs2.events.length, equals(5));

      expect(obs1.events[0], isA<CircuitBuildingEvent>());
      expect(obs1.events[1], isA<WaveStartedEvent>());
      expect(obs1.events[2], isA<WireResolvedEvent>());
      expect(obs1.events[3], isA<WireFailedEvent>());
      expect(obs1.events[4], isA<WaveCompletedEvent>());

      expect(obs2.events[0], isA<CircuitBuildingEvent>());
      expect(obs2.events[2], isA<WireResolvedEvent>());
    });

    test('CircuitObserver.composite wraps observers list', () {
      final obs1 = RecordingObserver();
      final obs2 = RecordingObserver();
      final composite = CircuitObserver.composite([obs1, obs2]);

      expect(composite, isA<CompositeCircuitObserver>());
      expect(
        (composite as CompositeCircuitObserver).observers,
        equals([obs1, obs2]),
      );
    });
  });

  group('Circuit.build with observers', () {
    test(
      'notifies explicit observer throughout build, wave, and ready',
      () async {
        final observer = RecordingObserver();

        final circuit = await Circuit.build([
          AsyncWire(() async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return 'async-value';
          }),
          Wire(() => 42),
        ], observer: observer);

        expect(observer.events, isNotEmpty);

        // 1. onCircuitBuilding
        final building = observer.events[0] as CircuitBuildingEvent;
        expect(building.info.wireCount, equals(2));
        expect(building.info.asyncWireCount, equals(1));
        expect(building.info.maxWaveLevel, equals(0));

        // 2. onWaveStarted
        final waveStarted = observer.events[1] as WaveStartedEvent;
        expect(waveStarted.waveLevel, equals(0));
        expect(waveStarted.wireKeys, equals([(String, null)]));

        // 3. onWireResolved
        final wireResolved = observer.events[2] as WireResolvedEvent;
        expect(wireResolved.key, equals((String, null)));
        expect(wireResolved.instance, equals('async-value'));
        expect(wireResolved.duration, greaterThan(Duration.zero));

        // 4. onWaveCompleted
        final waveCompleted = observer.events[3] as WaveCompletedEvent;
        expect(waveCompleted.waveLevel, equals(0));
        expect(waveCompleted.duration, greaterThan(Duration.zero));

        // 5. onCircuitReady
        final ready = observer.events[4] as CircuitReadyEvent;
        expect(ready.circuit, same(circuit));
        expect(ready.totalDuration, isNotNull);

        await circuit.dispose();
      },
    );

    test('resolves Zone.current[#circuitObserver]', () async {
      final zoneObserver = RecordingObserver();

      final circuit = await runZoned(() async {
        return Circuit.build([AsyncWire(() async => 'zone-test')]);
      }, zoneValues: {#circuitObserver: zoneObserver});

      expect(zoneObserver.events, isNotEmpty);
      expect(zoneObserver.events.any((e) => e is CircuitReadyEvent), isTrue);

      await circuit.dispose();
      expect(zoneObserver.events.any((e) => e is CircuitDisposedEvent), isTrue);
    });

    test('resolves CircuitObserver.global', () async {
      final globalObserver = RecordingObserver();
      CircuitObserver.global = globalObserver;

      final circuit = await Circuit.build([AsyncWire(() async => 100)]);

      expect(globalObserver.events, isNotEmpty);
      expect(globalObserver.events.any((e) => e is CircuitReadyEvent), isTrue);

      await circuit.dispose();
      expect(
        globalObserver.events.any((e) => e is CircuitDisposedEvent),
        isTrue,
      );
    });

    test(
      'combines explicit, zone, and global observers without duplication',
      () async {
        final explicit = RecordingObserver();
        final inZone = RecordingObserver();
        final global = RecordingObserver();
        CircuitObserver.global = global;

        final circuit = await runZoned(() async {
          return Circuit.build([
            AsyncWire(() async => 'combined'),
          ], observer: explicit);
        }, zoneValues: {#circuitObserver: inZone});

        expect(explicit.events.any((e) => e is CircuitReadyEvent), isTrue);
        expect(inZone.events.any((e) => e is CircuitReadyEvent), isTrue);
        expect(global.events.any((e) => e is CircuitReadyEvent), isTrue);

        await circuit.dispose();

        expect(explicit.events.any((e) => e is CircuitDisposedEvent), isTrue);
        expect(inZone.events.any((e) => e is CircuitDisposedEvent), isTrue);
        expect(global.events.any((e) => e is CircuitDisposedEvent), isTrue);
      },
    );

    test('deduplicates when same observer is in multiple sources', () async {
      final sharedObserver = RecordingObserver();
      CircuitObserver.global = sharedObserver;

      final circuit = await runZoned(() async {
        return Circuit.build([
          AsyncWire(() async => 'dedup'),
        ], observer: sharedObserver);
      }, zoneValues: {#circuitObserver: sharedObserver});

      final readyEvents = sharedObserver.events
          .whereType<CircuitReadyEvent>()
          .toList();
      // Only 1 ready event because the observer was deduplicated
      expect(readyEvents.length, equals(1));

      await circuit.dispose();
    });
  });

  group('Lazy wire resolution observer events', () {
    test('times and fires onWireResolved when lazy wire is accessed', () async {
      final observer = RecordingObserver();

      final circuit = await Circuit.build([
        Wire(() => 'lazy-greeting'),
      ], observer: observer);

      // During build, no lazy wires are resolved
      expect(observer.events.any((e) => e is WireResolvedEvent), isFalse);

      final val = circuit.get<String>();
      expect(val, equals('lazy-greeting'));

      final resolved = observer.events
          .whereType<WireResolvedEvent>()
          .singleOrNull;
      expect(resolved, isNotNull);
      expect(resolved!.key, equals((String, null)));
      expect(resolved.instance, equals('lazy-greeting'));
      expect(resolved.duration, greaterThanOrEqualTo(Duration.zero));

      // Subsequent get() does not re-fire onWireResolved
      circuit.get<String>();
      final count = observer.events.whereType<WireResolvedEvent>().length;
      expect(count, equals(1));

      await circuit.dispose();
    });

    test('fires onWireFailed when lazy wire throws during connect', () async {
      final observer = RecordingObserver();

      final circuit = await Circuit.build([
        Wire<int>(() => throw StateError('lazy-boom')),
      ], observer: observer);

      expect(() => circuit.get<int>(), throwsA(isA<StateError>()));

      final failed = observer.events.whereType<WireFailedEvent>().singleOrNull;
      expect(failed, isNotNull);
      expect(failed!.key, equals((int, null)));
      expect(failed.error, isA<StateError>());
      expect(failed.duration, isNotNull);

      await circuit.dispose();
    });
  });

  group('Async wire failure during build', () {
    test(
      'fires onWireFailed, disposes partially resolved, and propagates error',
      () async {
        final observer = RecordingObserver();

        expect(
          () => Circuit.build([
            AsyncWire<String>(() async => throw StateError('async-fail')),
          ], observer: observer),
          throwsA(isA<StateError>()),
        );

        // Wait a microtask to allow async disposal to complete
        await Future<void>.delayed(Duration.zero);

        final failed = observer.events
            .whereType<WireFailedEvent>()
            .singleOrNull;
        expect(failed, isNotNull);
        expect(failed!.key, equals((String, null)));
        expect(failed.error, isA<StateError>());

        // Circuit disposal is triggered automatically upon build failure
        expect(observer.events.any((e) => e is CircuitDisposingEvent), isTrue);
        expect(observer.events.any((e) => e is CircuitDisposedEvent), isTrue);
      },
    );
  });

  group('Disposal lifecycle events', () {
    test(
      'fires onCircuitDisposing and onCircuitDisposed with elapsed time',
      () async {
        final observer = RecordingObserver();

        final circuit = await Circuit.build([
          Wire(() => 'value'),
        ], observer: observer);

        await circuit.dispose();

        final disposing = observer.events
            .whereType<CircuitDisposingEvent>()
            .singleOrNull;
        final disposed = observer.events
            .whereType<CircuitDisposedEvent>()
            .singleOrNull;

        expect(disposing, isNotNull);
        expect(disposing!.circuit, same(circuit));

        expect(disposed, isNotNull);
        expect(disposed!.circuit, same(circuit));
        expect(disposed.totalDuration, isNotNull);

        // Repeated calls to dispose() are idempotent and do not re-fire
        await circuit.dispose();
        expect(
          observer.events.whereType<CircuitDisposingEvent>().length,
          equals(1),
        );
        expect(
          observer.events.whereType<CircuitDisposedEvent>().length,
          equals(1),
        );
      },
    );
  });

  group('Package-internal Circuit getters', () {
    test('exposes wires, instances, levels, maxLevel, creatingKeys, and reverseDependencies', () async {
      final wireA = Wire(() => 'A');
      final wireB = Wire.takes<String>().to((a) => 42);

      final circuit = await Circuit.build([wireA, wireB]);

      // 1. wires
      expect(circuit.wires.length, equals(2));
      expect(circuit.wires.containsKey((String, null)), isTrue);
      expect(circuit.wires.containsKey((int, null)), isTrue);

      // 2. levels & maxLevel
      expect(circuit.levels[(String, null)], equals(0));
      expect(circuit.levels[(int, null)], equals(1));
      expect(circuit.maxLevel, equals(1));

      // 3. creatingKeys
      expect(circuit.creatingKeys, isEmpty);

      // 4. reverseDependencies
      expect(
        circuit.reverseDependencies[(String, null)],
        contains((int, null)),
      );
      expect(circuit.reverseDependencies[(int, null)], isEmpty);

      // 5. instances before & after get
      expect(circuit.instances, isEmpty);
      final b = circuit.get<int>();
      expect(b, equals(42));
      expect(circuit.instances.length, equals(2));

      // 6. inspect returns CircuitIntrospection
      expect(circuit.inspect(), isA<CircuitIntrospection>());

      await circuit.dispose();
    });
  });
}
