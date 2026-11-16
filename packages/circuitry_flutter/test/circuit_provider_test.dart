import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:circuitry_flutter/circuitry_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

final class const _RepositoryA([final String name = 'repo_a']);

final class const _RepositoryB(final _RepositoryA a);

final class const _AsyncService(final String status);

enum _TestScope { global, feature, child, shared, unused }

enum _BranchScope { branchA, branchB }

void main() {
  group('CircuitState Hierarchy', () {
    test('constructors and equality', () {
      const building1 = CircuitState.building();
      const building2 = CircuitBuilding();
      expect(building1, equals(building2));
      expect(building1.hashCode, equals(building2.hashCode));
      expect(building1.toString(), equals('CircuitBuilding()'));

      final exception = StateError('test error');
      final failure1 = CircuitState.failure(exception);
      final failure2 = CircuitFailure(exception);
      expect(failure1, equals(failure2));
      expect(failure1.hashCode, equals(failure2.hashCode));
      expect(failure1.toString(), contains('test error'));
    });

    test('CircuitReady equality is identity-based on Circuit', () async {
      final circuit1 = await Circuit.build([]);
      final circuit2 = await Circuit.build([]);
      addTearDown(() async {
        await circuit1.dispose();
        await circuit2.dispose();
      });

      final ready1 = CircuitState.ready(circuit1);
      final ready1Alias = CircuitReady(circuit1);
      final ready2 = CircuitState.ready(circuit2);

      expect(ready1, equals(ready1Alias));
      expect(ready1, isNot(equals(ready2)));
      expect(ready1.hashCode, equals(identityHashCode(circuit1)));
      expect(ready1.toString(), contains('CircuitReady'));
    });
  });

  group('CircuitProvider Async Compilation Lifecycle', () {
    testWidgets('starts in CircuitBuilding and transitions to CircuitReady', (
      tester,
    ) async {
      final completer = Completer<String>();
      final asyncWire = AsyncWire<_AsyncService>(() async {
        final status = await completer.future;
        return _AsyncService(status);
      });

      Circuit? resolvedCircuit;
      CircuitState? capturedState;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CircuitProvider(
            wires: [asyncWire],
            builder: (context, state) {
              capturedState = state;
              return switch (state) {
                CircuitBuilding() => const Text('Building'),
                CircuitReady(:final circuit) => Builder(
                  builder: (childContext) {
                    resolvedCircuit = CircuitProvider.of(childContext);
                    return Text(
                      'Ready: ${circuit.get<_AsyncService>().status}',
                    );
                  },
                ),
                CircuitFailure(:final error) => Text('Failure: $error'),
              };
            },
          ),
        ),
      );

      expect(find.text('Building'), findsOneWidget);
      expect(capturedState, isA<CircuitBuilding>());
      expect(resolvedCircuit, isNull);

      completer.complete('connected');
      await tester.pumpAndSettle();

      expect(find.text('Ready: connected'), findsOneWidget);
      expect(capturedState, isA<CircuitReady>());
      expect(resolvedCircuit, isNotNull);
      expect(resolvedCircuit!.isDisposed, isFalse);

      // Unmount widget and verify circuit is disposed
      await tester.pumpWidget(const SizedBox());
      expect(resolvedCircuit!.isDisposed, isTrue);
    });

    testWidgets(
      'unmounting while async build is in flight disposes resolved circuit immediately',
      (tester) async {
        final completer = Completer<_AsyncService>();
        var disposeCalled = false;

        final asyncWire = AsyncWire<_AsyncService>(
          () => completer.future,
          onDispose: (_) => disposeCalled = true,
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              wires: [asyncWire],
              builder: (context, state) => switch (state) {
                CircuitBuilding() => const Text('Building'),
                CircuitReady() => const Text('Ready'),
                CircuitFailure() => const Text('Failure'),
              },
            ),
          ),
        );

        expect(find.text('Building'), findsOneWidget);

        // Unmount before completion
        await tester.pumpWidget(const SizedBox());

        // Now complete the async factory
        const service = _AsyncService('abandoned');
        completer.complete(service);

        // Yield to allow microtask/future callbacks to run
        await tester.pump(Duration.zero);

        expect(disposeCalled, isTrue);
      },
    );

    testWidgets(
      'disposes active circuit and invokes onDispose hooks on unmount',
      (tester) async {
        final teardownLog = <String>[];

        final wireA = Wire<_RepositoryA>(
          () => const _RepositoryA(),
          onDispose: (_) => teardownLog.add('dispose:A'),
        );
        final wireB = Wire.takes<_RepositoryA>().to<_RepositoryB, Enum>(
          (_RepositoryA a) => _RepositoryB(a),
          onDispose: (_) => teardownLog.add('dispose:B'),
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              wires: [wireA, wireB],
              builder: (context, state) => switch (state) {
                CircuitReady(:final circuit) => Text(
                  'Initialized: ${circuit.get<_RepositoryB>().a.name}',
                ),
                _ => const Text('Loading'),
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Initialized: repo_a'), findsOneWidget);

        // Unmount
        await tester.pumpWidget(const SizedBox());

        // Reverse topological teardown: B before A
        expect(teardownLog, equals(['dispose:B', 'dispose:A']));
      },
    );

    testWidgets(
      'compiles successfully and transitions to ready when wires list is empty',
      (tester) async {
        Circuit? emptyCircuit;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              wires: const [],
              builder: (context, state) => switch (state) {
                CircuitReady(:final circuit) => Builder(
                  builder: (childContext) {
                    emptyCircuit = circuit;
                    return const Text('Empty Ready');
                  },
                ),
                _ => const Text('Loading'),
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Empty Ready'), findsOneWidget);
        expect(emptyCircuit, isNotNull);
        expect(emptyCircuit!.isDisposed, isFalse);
      },
    );

    testWidgets(
      'recompiles and disposes previous circuit when wires list is updated',
      (tester) async {
        var disposeV1Called = false;
        final wireV1 = Wire<_RepositoryA>(
          () => const _RepositoryA('v1'),
          onDispose: (_) => disposeV1Called = true,
        );
        final wireV2 = Wire<_RepositoryA>(() => const _RepositoryA('v2'));

        var activeWires = [wireV1];
        late StateSetter updateTree;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              updateTree = setState;
              return Directionality(
                textDirection: TextDirection.ltr,
                child: CircuitProvider(
                  wires: activeWires,
                  builder: (context, state) => switch (state) {
                    CircuitReady(:final circuit) => Text(
                      'Ready: ${circuit.get<_RepositoryA>().name}',
                    ),
                    CircuitBuilding() => const Text('Building'),
                    CircuitFailure() => const Text('Failure'),
                  },
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Ready: v1'), findsOneWidget);
        expect(disposeV1Called, isFalse);

        // Update wires to V2
        updateTree(() {
          activeWires = [wireV2];
        });
        await tester.pumpAndSettle();

        expect(find.text('Ready: v2'), findsOneWidget);
        expect(disposeV1Called, isTrue);
      },
    );

    testWidgets(
      'cancels and disposes in-flight compilation when wires change before completion',
      (tester) async {
        final completerV1 = Completer<String>();
        var disposeV1Called = false;
        final asyncWireV1 = AsyncWire<String>(
          () => completerV1.future,
          onDispose: (_) => disposeV1Called = true,
        );

        final asyncWireV2 = AsyncWire<String>(() async => 'v2_fast');

        var activeWires = <CircuitWire>[asyncWireV1];
        late StateSetter updateTree;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              updateTree = setState;
              return Directionality(
                textDirection: TextDirection.ltr,
                child: CircuitProvider(
                  wires: activeWires,
                  builder: (context, state) => switch (state) {
                    CircuitReady(:final circuit) => Text(
                      'Ready: ${circuit.get<String>()}',
                    ),
                    CircuitBuilding() => const Text('Building'),
                    CircuitFailure() => const Text('Failure'),
                  },
                ),
              );
            },
          ),
        );

        expect(find.text('Building'), findsOneWidget);

        // While V1 is in flight, update wires to V2
        updateTree(() {
          activeWires = [asyncWireV2];
        });
        await tester.pumpAndSettle();

        expect(find.text('Ready: v2_fast'), findsOneWidget);

        // Now V1 completes
        completerV1.complete('v1_stale');
        await tester.pump(Duration.zero);

        // Stale V1 completion should be ignored and disposed
        expect(find.text('Ready: v2_fast'), findsOneWidget);
        expect(disposeV1Called, isTrue);
      },
    );

    testWidgets(
      'does not recompile or dispose active circuit when wires list elements are identical',
      (tester) async {
        final wireA = Wire<_RepositoryA>(() => const _RepositoryA('stable'));
        Circuit? firstCircuit;
        Circuit? secondCircuit;
        late StateSetter updateTree;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              updateTree = setState;
              return Directionality(
                textDirection: TextDirection.ltr,
                child: CircuitProvider(
                  wires: [
                    wireA,
                  ], // Fresh list instance with same wire reference
                  builder: (context, state) => switch (state) {
                    CircuitReady(:final circuit) => Builder(
                      builder: (childContext) {
                        if (firstCircuit == null) {
                          firstCircuit = circuit;
                        } else {
                          secondCircuit = circuit;
                        }
                        return const Text('Ready');
                      },
                    ),
                    _ => const Text('Loading'),
                  },
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Ready'), findsOneWidget);
        expect(firstCircuit, isNotNull);

        // Trigger rebuild with a new list instance holding the same wire
        updateTree(() {});
        await tester.pump();

        expect(secondCircuit, isNotNull);
        expect(identical(firstCircuit, secondCircuit), isTrue);
        expect(firstCircuit!.isDisposed, isFalse);
      },
    );
  });

  group('CircuitProvider Failure State', () {
    testWidgets(
      'transitions to CircuitFailure when missing dependency is detected',
      (tester) async {
        final wireB = Wire.takes<_RepositoryA>().to<_RepositoryB, Enum>(
          (_RepositoryA a) => _RepositoryB(a),
        );

        CircuitState? capturedState;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              wires: [wireB], // Missing _RepositoryA wire
              builder: (context, state) {
                capturedState = state;
                return switch (state) {
                  CircuitFailure(:final error) => Text(
                    'Error: ${error.runtimeType}',
                  ),
                  CircuitReady() => const Text('Ready'),
                  CircuitBuilding() => const Text('Building'),
                };
              },
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Error: MissingWireException'), findsOneWidget);
        expect(capturedState, isA<CircuitFailure>());
        final failure = capturedState as CircuitFailure;
        expect(failure.error, isA<MissingWireException>());
      },
    );

    testWidgets(
      'transitions to CircuitFailure when duplicate wire keys are registered',
      (tester) async {
        final wire1 = Wire<String>(() => 'first');
        final wire2 = Wire<String>(() => 'second');

        CircuitState? capturedState;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              wires: [wire1, wire2],
              builder: (context, state) {
                capturedState = state;
                return switch (state) {
                  CircuitFailure(:final error) => Text(
                    'Error: ${error.runtimeType}',
                  ),
                  CircuitReady() => const Text('Ready'),
                  CircuitBuilding() => const Text('Building'),
                };
              },
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Error: DuplicateWireException'), findsOneWidget);
        expect(capturedState, isA<CircuitFailure>());
        final failure = capturedState as CircuitFailure;
        expect(failure.error, isA<DuplicateWireException>());
      },
    );

    testWidgets(
      'transitions to CircuitFailure when circular dependency is detected',
      (tester) async {
        // Create cyclic wires: A depends on B, B depends on A
        final wireA = Wire.takes<_RepositoryB>().to<_RepositoryA, Enum>(
          (_) => const _RepositoryA(),
        );
        final wireB = Wire.takes<_RepositoryA>().to<_RepositoryB, Enum>(
          (a) => _RepositoryB(a),
        );

        CircuitState? capturedState;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              wires: [wireA, wireB],
              builder: (context, state) {
                capturedState = state;
                return switch (state) {
                  CircuitFailure(:final error) => Text(
                    'Error: ${error.runtimeType}',
                  ),
                  CircuitReady() => const Text('Ready'),
                  CircuitBuilding() => const Text('Building'),
                };
              },
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Error: CircularDependencyException'), findsOneWidget);
        expect(capturedState, isA<CircuitFailure>());
        final failure = capturedState as CircuitFailure;
        expect(failure.error, isA<CircularDependencyException>());
      },
    );

    testWidgets('transitions to CircuitFailure when AsyncWire factory throws', (
      tester,
    ) async {
      final failingWire = AsyncWire<String>(
        () async => throw StateError('database connection refused'),
      );

      CircuitState? capturedState;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CircuitProvider(
            wires: [failingWire],
            builder: (context, state) {
              capturedState = state;
              return switch (state) {
                CircuitFailure(:final error) => Text('Error: $error'),
                CircuitReady() => const Text('Ready'),
                CircuitBuilding() => const Text('Building'),
              };
            },
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text('Error: Bad state: database connection refused'),
        findsOneWidget,
      );
      expect(capturedState, isA<CircuitFailure>());
      final failure = capturedState as CircuitFailure;
      expect(failure.error, isA<StateError>());
    });

    testWidgets(
      'CircuitProvider.maybeOf returns null and of throws in building/failure states',
      (tester) async {
        final failingWire = AsyncWire<String>(
          () async => throw StateError('fail'),
        );

        Circuit? maybeCircuitDuringFailure;
        Object? thrownErrorDuringFailure;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              wires: [failingWire],
              builder: (context, state) {
                if (state is CircuitFailure) {
                  maybeCircuitDuringFailure = CircuitProvider.maybeOf(context);
                  try {
                    CircuitProvider.of(context);
                  } catch (e) {
                    thrownErrorDuringFailure = e;
                  }
                  return const Text('Handled Failure');
                }
                return const Text('Pending');
              },
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Handled Failure'), findsOneWidget);
        expect(maybeCircuitDuringFailure, isNull);
        expect(thrownErrorDuringFailure, isA<StateError>());
      },
    );
  });

  group('CircuitProvider of(context) and maybeOf(context) Accessors', () {
    testWidgets(
      'retrieves active circuit in builder and across deeply nested descendants',
      (tester) async {
        final wireA = Wire<_RepositoryA>(() => const _RepositoryA('vault_db'));
        Circuit? inheritedCircuit;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              wires: [wireA],
              builder: (context, state) => switch (state) {
                CircuitReady() => Builder(
                  builder: (childContext) {
                    inheritedCircuit = CircuitProvider.of(childContext);
                    return Text(
                      'Value: ${inheritedCircuit!.get<_RepositoryA>().name}',
                    );
                  },
                ),
                _ => const Text('Loading'),
              },
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Value: vault_db'), findsOneWidget);
        expect(inheritedCircuit, isNotNull);
        expect(inheritedCircuit!.get<_RepositoryA>().name, equals('vault_db'));
      },
    );

    testWidgets(
      'maybeOf returns null and of throws StateError when outside CircuitProvider',
      (tester) async {
        Circuit? maybeCircuit;
        Object? thrownError;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                maybeCircuit = CircuitProvider.maybeOf(context);
                try {
                  CircuitProvider.of(context);
                } catch (e) {
                  thrownError = e;
                }
                return const Text('Isolated');
              },
            ),
          ),
        );

        expect(find.text('Isolated'), findsOneWidget);
        expect(maybeCircuit, isNull);
        expect(thrownError, isA<StateError>());
        expect(
          (thrownError as StateError).message,
          contains('No CircuitProvider found in context'),
        );
      },
    );
  });

  group('CircuitProvider.value Synchronous Injection', () {
    testWidgets(
      'immediately provides circuit without async compilation delay',
      (tester) async {
        final circuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('prebuilt')),
        ]);
        addTearDown(circuit.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider.value(
              value: circuit,
              child: Builder(
                builder: (context) {
                  final c = CircuitProvider.of(context);
                  return Text('Resolved: ${c.get<_RepositoryA>().name}');
                },
              ),
            ),
          ),
        );

        // Does not require pump/await: available on frame 1
        expect(find.text('Resolved: prebuilt'), findsOneWidget);
      },
    );

    testWidgets(
      'unmounting CircuitProvider.value does NOT dispose the injected circuit',
      (tester) async {
        final circuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('keep_alive')),
        ]);
        addTearDown(circuit.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider.value(
              value: circuit,
              child: const Text('Alive'),
            ),
          ),
        );

        expect(find.text('Alive'), findsOneWidget);
        expect(circuit.isDisposed, isFalse);

        // Unmount
        await tester.pumpWidget(const SizedBox());

        // Value provider does not own circuit: must remain active
        expect(circuit.isDisposed, isFalse);
        expect(circuit.get<_RepositoryA>().name, equals('keep_alive'));
      },
    );

    testWidgets(
      'updates descendants when value changes without disposing old circuit',
      (tester) async {
        final circuit1 = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('first_value')),
        ]);
        final circuit2 = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('second_value')),
        ]);
        addTearDown(() async {
          await circuit1.dispose();
          await circuit2.dispose();
        });

        var activeCircuit = circuit1;
        late StateSetter updateTree;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              updateTree = setState;
              return Directionality(
                textDirection: TextDirection.ltr,
                child: CircuitProvider.value(
                  value: activeCircuit,
                  child: Builder(
                    builder: (childContext) {
                      final c = CircuitProvider.of(childContext);
                      return Text('Active: ${c.get<_RepositoryA>().name}');
                    },
                  ),
                ),
              );
            },
          ),
        );

        expect(find.text('Active: first_value'), findsOneWidget);

        // Switch to circuit2
        updateTree(() {
          activeCircuit = circuit2;
        });
        await tester.pump();

        expect(find.text('Active: second_value'), findsOneWidget);
        expect(circuit1.isDisposed, isFalse);
        expect(circuit2.isDisposed, isFalse);
      },
    );
  });

  group('Example App Composition Root Integration', () {
    testWidgets(
      'displays splash screen on initial frame and transitions to main content',
      (tester) async {
        final completer = Completer<String>();
        final asyncWire = AsyncWire<String>(() => completer.future);

        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFF000000),
            builder: (context, _) => CircuitProvider(
              wires: [asyncWire],
              builder: (context, state) => switch (state) {
                CircuitReady(:final circuit) => Text(
                  'Ready: ${circuit.get<String>()}',
                  textDirection: TextDirection.ltr,
                ),
                CircuitBuilding() => const Text(
                  'Splash Loading',
                  textDirection: TextDirection.ltr,
                ),
                CircuitFailure() => const Text(
                  'Error',
                  textDirection: TextDirection.ltr,
                ),
              },
            ),
          ),
        );

        expect(find.text('Splash Loading'), findsOneWidget);

        completer.complete('app_initialized');
        await tester.pumpAndSettle();

        expect(find.text('Ready: app_initialized'), findsOneWidget);
      },
    );

    testWidgets('displays error screen when circuit compilation fails', (
      tester,
    ) async {
      final failingWire = AsyncWire<String>(
        () async => throw StateError('disk corruption'),
      );

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => CircuitProvider(
            wires: [failingWire],
            builder: (context, state) => switch (state) {
              CircuitReady() => const Text(
                'Ready',
                textDirection: TextDirection.ltr,
              ),
              CircuitBuilding() => const Text(
                'Loading',
                textDirection: TextDirection.ltr,
              ),
              CircuitFailure(:final error) => Text(
                'Failed: $error',
                textDirection: TextDirection.ltr,
              ),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed: Bad state: disk corruption'), findsOneWidget);
    });
  });

  group('Taggable CircuitProvider with Scoped Ambient Registry', () {
    testWidgets(
      'retrieves nearest circuit when tag is omitted across nested providers',
      (tester) async {
        final globalWire = Wire<_RepositoryA>(
          () => const _RepositoryA('global_val'),
        );
        final featureWire = Wire<_RepositoryA>(
          () => const _RepositoryA('feature_val'),
        );

        String? nearestValue;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              tag: _TestScope.global,
              wires: [globalWire],
              builder: (context, globalState) => switch (globalState) {
                CircuitReady() => CircuitProvider(
                  tag: _TestScope.feature,
                  wires: [featureWire],
                  builder: (context, featureState) => switch (featureState) {
                    CircuitReady() => Builder(
                      builder: (childContext) {
                        nearestValue = CircuitProvider.of(childContext)
                            .get<_RepositoryA>()
                            .name;
                        return Text('Nearest: $nearestValue');
                      },
                    ),
                    _ => const SizedBox(),
                  },
                ),
                _ => const SizedBox(),
              },
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Nearest: feature_val'), findsOneWidget);
        expect(nearestValue, equals('feature_val'));
      },
    );

    testWidgets(
      'retrieves tagged ancestor circuits across nested CircuitProvider hierarchies in O(1)',
      (tester) async {
        final globalWire = Wire<_RepositoryA>(
          () => const _RepositoryA('global_repo'),
        );
        final featureWire = Wire<_RepositoryB>(
          () => const _RepositoryB(_RepositoryA('feature_repo')),
        );

        Circuit? resolvedGlobal;
        Circuit? resolvedFeature;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              tag: _TestScope.global,
              wires: [globalWire],
              builder: (context, globalState) => switch (globalState) {
                CircuitReady() => CircuitProvider(
                  tag: _TestScope.feature,
                  wires: [featureWire],
                  builder: (context, featureState) => switch (featureState) {
                    CircuitReady() => Builder(
                      builder: (childContext) {
                        resolvedGlobal = CircuitProvider.of(
                          childContext,
                          tag: _TestScope.global,
                        );
                        resolvedFeature = CircuitProvider.of(
                          childContext,
                          tag: _TestScope.feature,
                        );
                        return Text(
                          'G: ${resolvedGlobal!.get<_RepositoryA>().name}, '
                          'F: ${resolvedFeature!.get<_RepositoryB>().a.name}',
                        );
                      },
                    ),
                    _ => const SizedBox(),
                  },
                ),
                _ => const SizedBox(),
              },
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('G: global_repo, F: feature_repo'), findsOneWidget);
        expect(resolvedGlobal, isNotNull);
        expect(resolvedFeature, isNotNull);
        expect(resolvedGlobal!.get<_RepositoryA>().name, equals('global_repo'));
        expect(
          resolvedFeature!.get<_RepositoryB>().a.name,
          equals('feature_repo'),
        );
      },
    );

    testWidgets(
      'propagates tagged circuits across intermediate untagged CircuitProvider',
      (tester) async {
        final rootWire = Wire<_RepositoryA>(
          () => const _RepositoryA('root_service'),
        );
        final intermediateWire = Wire<_RepositoryB>(
          () => const _RepositoryB(_RepositoryA('intermediate_service')),
        );
        final leafWire = Wire<String>(() => 'leaf_service');

        Circuit? retrievedRoot;
        Circuit? retrievedLeaf;
        Circuit? retrievedNearest;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider(
              tag: _TestScope.global,
              wires: [rootWire],
              builder: (context, rootState) => switch (rootState) {
                CircuitReady() => CircuitProvider(
                  // Untagged intermediate provider
                  wires: [intermediateWire],
                  builder: (context, interState) => switch (interState) {
                    CircuitReady() => CircuitProvider(
                      tag: _TestScope.child,
                      wires: [leafWire],
                      builder: (context, leafState) => switch (leafState) {
                        CircuitReady() => Builder(
                          builder: (leafContext) {
                            retrievedRoot = CircuitProvider.of(
                              leafContext,
                              tag: _TestScope.global,
                            );
                            retrievedLeaf = CircuitProvider.of(
                              leafContext,
                              tag: _TestScope.child,
                            );
                            retrievedNearest = CircuitProvider.of(leafContext);
                            return Text(
                              'Root: ${retrievedRoot!.get<_RepositoryA>().name}, '
                              'Leaf: ${retrievedLeaf!.get<String>()}, '
                              'Nearest: ${retrievedNearest!.get<String>()}',
                            );
                          },
                        ),
                        _ => const SizedBox(),
                      },
                    ),
                    _ => const SizedBox(),
                  },
                ),
                _ => const SizedBox(),
              },
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(
          find.text(
            'Root: root_service, Leaf: leaf_service, Nearest: leaf_service',
          ),
          findsOneWidget,
        );
        expect(retrievedRoot!.get<_RepositoryA>().name, equals('root_service'));
        expect(retrievedLeaf!.get<String>(), equals('leaf_service'));
        expect(retrievedNearest!.get<String>(), equals('leaf_service'));
      },
    );

    testWidgets('supports tagged scoped retrieval with CircuitProvider.value', (
      tester,
    ) async {
      final circuit1 = await Circuit.build([
        Wire<_RepositoryA>(() => const _RepositoryA('val_global')),
      ]);
      final circuit2 = await Circuit.build([
        Wire<_RepositoryA>(() => const _RepositoryA('val_feature')),
      ]);
      addTearDown(() async {
        await circuit1.dispose();
        await circuit2.dispose();
      });

      Circuit? foundGlobal;
      Circuit? foundFeature;
      Circuit? foundNearest;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CircuitProvider.value(
            tag: _TestScope.global,
            value: circuit1,
            child: CircuitProvider.value(
              tag: _TestScope.feature,
              value: circuit2,
              child: Builder(
                builder: (context) {
                  foundGlobal = CircuitProvider.of(
                    context,
                    tag: _TestScope.global,
                  );
                  foundFeature = CircuitProvider.of(
                    context,
                    tag: _TestScope.feature,
                  );
                  foundNearest = CircuitProvider.of(context);
                  return Text(
                    'Global: ${foundGlobal!.get<_RepositoryA>().name}, '
                    'Feature: ${foundFeature!.get<_RepositoryA>().name}',
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('Global: val_global, Feature: val_feature'),
        findsOneWidget,
      );
      expect(foundGlobal, equals(circuit1));
      expect(foundFeature, equals(circuit2));
      expect(foundNearest, equals(circuit2));
    });

    testWidgets(
      'missing tag returns null in maybeOf and throws StateError in of',
      (tester) async {
        final circuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('present')),
        ]);
        addTearDown(circuit.dispose);

        Circuit? missingResult;
        Object? thrownError;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider.value(
              tag: _TestScope.global,
              value: circuit,
              child: Builder(
                builder: (context) {
                  missingResult = CircuitProvider.maybeOf(
                    context,
                    tag: _TestScope.unused,
                  );
                  try {
                    CircuitProvider.of(context, tag: _TestScope.unused);
                  } catch (e) {
                    thrownError = e;
                  }
                  return const Text('Done');
                },
              ),
            ),
          ),
        );

        expect(find.text('Done'), findsOneWidget);
        expect(missingResult, isNull);
        expect(thrownError, isA<StateError>());
        expect(
          (thrownError as StateError).message,
          equals(
            'No CircuitProvider found with tag _TestScope.unused in context.',
          ),
        );
      },
    );

    testWidgets(
      'context outside any CircuitProvider throws descriptive StateError when tag is requested',
      (tester) async {
        Circuit? missingResult;
        Object? thrownError;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                missingResult = CircuitProvider.maybeOf(
                  context,
                  tag: _TestScope.global,
                );
                try {
                  CircuitProvider.of(context, tag: _TestScope.global);
                } catch (e) {
                  thrownError = e;
                }
                return const Text('Isolated Tag');
              },
            ),
          ),
        );

        expect(find.text('Isolated Tag'), findsOneWidget);
        expect(missingResult, isNull);
        expect(thrownError, isA<StateError>());
        expect(
          (thrownError as StateError).message,
          equals(
            'No CircuitProvider found with tag _TestScope.global in context.',
          ),
        );
      },
    );

    testWidgets(
      'lexical shadowing: nearer ancestor tag shadows outer ancestor with same tag',
      (tester) async {
        final outerCircuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('outer_shadow')),
        ]);
        final innerCircuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('inner_shadow')),
        ]);
        addTearDown(() async {
          await outerCircuit.dispose();
          await innerCircuit.dispose();
        });

        Circuit? resolvedCircuit;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider.value(
              tag: _TestScope.shared,
              value: outerCircuit,
              child: CircuitProvider.value(
                tag: _TestScope.shared,
                value: innerCircuit,
                child: Builder(
                  builder: (context) {
                    resolvedCircuit = CircuitProvider.of(
                      context,
                      tag: _TestScope.shared,
                    );
                    return Text(
                      'Shadowed: ${resolvedCircuit!.get<_RepositoryA>().name}',
                    );
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.text('Shadowed: inner_shadow'), findsOneWidget);
        expect(resolvedCircuit, equals(innerCircuit));
        expect(resolvedCircuit, isNot(equals(outerCircuit)));
      },
    );

    testWidgets(
      'sibling subtrees maintain isolated scoped registries without leaking',
      (tester) async {
        final globalCircuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('root_val')),
        ]);
        final branchACircuit = await Circuit.build([
          Wire<String>(() => 'branch_a_val'),
        ]);
        final branchBCircuit = await Circuit.build([
          Wire<String>(() => 'branch_b_val'),
        ]);
        addTearDown(() async {
          await globalCircuit.dispose();
          await branchACircuit.dispose();
          await branchBCircuit.dispose();
        });

        Circuit? aSeesGlobal;
        Circuit? aSeesA;
        Circuit? aSeesB;
        Object? aThrowsForB;

        Circuit? bSeesGlobal;
        Circuit? bSeesB;
        Circuit? bSeesA;
        Object? bThrowsForA;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider.value(
              tag: _TestScope.global,
              value: globalCircuit,
              child: Row(
                children: [
                  CircuitProvider.value(
                    tag: _BranchScope.branchA,
                    value: branchACircuit,
                    child: Builder(
                      builder: (context) {
                        aSeesGlobal = CircuitProvider.of(
                          context,
                          tag: _TestScope.global,
                        );
                        aSeesA = CircuitProvider.of(
                          context,
                          tag: _BranchScope.branchA,
                        );
                        aSeesB = CircuitProvider.maybeOf(
                          context,
                          tag: _BranchScope.branchB,
                        );
                        try {
                          CircuitProvider.of(
                            context,
                            tag: _BranchScope.branchB,
                          );
                        } catch (e) {
                          aThrowsForB = e;
                        }
                        return const Text('BranchA');
                      },
                    ),
                  ),
                  CircuitProvider.value(
                    tag: _BranchScope.branchB,
                    value: branchBCircuit,
                    child: Builder(
                      builder: (context) {
                        bSeesGlobal = CircuitProvider.of(
                          context,
                          tag: _TestScope.global,
                        );
                        bSeesB = CircuitProvider.of(
                          context,
                          tag: _BranchScope.branchB,
                        );
                        bSeesA = CircuitProvider.maybeOf(
                          context,
                          tag: _BranchScope.branchA,
                        );
                        try {
                          CircuitProvider.of(
                            context,
                            tag: _BranchScope.branchA,
                          );
                        } catch (e) {
                          bThrowsForA = e;
                        }
                        return const Text('BranchB');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('BranchA'), findsOneWidget);
        expect(find.text('BranchB'), findsOneWidget);

        expect(aSeesGlobal, equals(globalCircuit));
        expect(aSeesA, equals(branchACircuit));
        expect(aSeesB, isNull);
        expect(aThrowsForB, isA<StateError>());

        expect(bSeesGlobal, equals(globalCircuit));
        expect(bSeesB, equals(branchBCircuit));
        expect(bSeesA, isNull);
        expect(bThrowsForA, isA<StateError>());
      },
    );

    testWidgets(
      'reactive rebuild: descendant listening to tagged ancestor circuit rebuilds when ancestor circuit changes',
      (tester) async {
        final circuitV1 = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('ancestor_v1')),
        ]);
        final circuitV2 = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('ancestor_v2')),
        ]);
        final featureCircuit = await Circuit.build([
          Wire<String>(() => 'feature_constant'),
        ]);
        addTearDown(() async {
          await circuitV1.dispose();
          await circuitV2.dispose();
          await featureCircuit.dispose();
        });

        var activeRootCircuit = circuitV1;
        late StateSetter updateTree;
        var buildCount = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              updateTree = setState;
              return Directionality(
                textDirection: TextDirection.ltr,
                child: CircuitProvider.value(
                  tag: _TestScope.global,
                  value: activeRootCircuit,
                  child: CircuitProvider.value(
                    tag: _TestScope.feature,
                    value: featureCircuit,
                    child: Builder(
                      builder: (childContext) {
                        buildCount++;
                        final global = CircuitProvider.of(
                          childContext,
                          tag: _TestScope.global,
                        );
                        return Text(
                          'Observed: ${global.get<_RepositoryA>().name}',
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );

        expect(find.text('Observed: ancestor_v1'), findsOneWidget);
        expect(buildCount, equals(1));

        // Update ancestor circuit from v1 to v2
        updateTree(() {
          activeRootCircuit = circuitV2;
        });
        await tester.pump();

        expect(find.text('Observed: ancestor_v2'), findsOneWidget);
        expect(buildCount, equals(2));
      },
    );

    testWidgets(
      'child in CircuitBuilding state can access ancestor tagged circuit in builder',
      (tester) async {
        final rootCircuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('root_in_building')),
        ]);
        addTearDown(rootCircuit.dispose);

        final completer = Completer<String>();
        final asyncFeatureWire = AsyncWire<String>(() => completer.future);

        Circuit? capturedRootDuringBuilding;
        Circuit? capturedFeatureDuringBuilding;
        Circuit? capturedRootAfterReady;
        Circuit? capturedFeatureAfterReady;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider.value(
              tag: _TestScope.global,
              value: rootCircuit,
              child: CircuitProvider(
                tag: _TestScope.feature,
                wires: [asyncFeatureWire],
                builder: (context, state) => switch (state) {
                  CircuitBuilding() => Builder(
                    builder: (childContext) {
                      capturedRootDuringBuilding = CircuitProvider.of(
                        childContext,
                        tag: _TestScope.global,
                      );
                      capturedFeatureDuringBuilding = CircuitProvider.maybeOf(
                        childContext,
                        tag: _TestScope.feature,
                      );
                      return const Text('Feature Building');
                    },
                  ),
                  CircuitReady() => Builder(
                    builder: (childContext) {
                      capturedRootAfterReady = CircuitProvider.of(
                        childContext,
                        tag: _TestScope.global,
                      );
                      capturedFeatureAfterReady = CircuitProvider.of(
                        childContext,
                        tag: _TestScope.feature,
                      );
                      return Text(
                        'Feature Ready: ${capturedFeatureAfterReady!.get<String>()}',
                      );
                    },
                  ),
                  CircuitFailure() => const Text('Feature Failed'),
                },
              ),
            ),
          ),
        );

        expect(find.text('Feature Building'), findsOneWidget);
        expect(capturedRootDuringBuilding, equals(rootCircuit));
        expect(capturedFeatureDuringBuilding, isNull);

        // Complete feature compilation
        completer.complete('feature_now_ready');
        await tester.pumpAndSettle();

        expect(find.text('Feature Ready: feature_now_ready'), findsOneWidget);
        expect(capturedRootAfterReady, equals(rootCircuit));
        expect(capturedFeatureAfterReady, isNotNull);
        expect(
          capturedFeatureAfterReady!.get<String>(),
          equals('feature_now_ready'),
        );
      },
    );

    testWidgets(
      'nested CircuitProvider in building state intercepts untagged of/maybeOf so nearest building circuit returns null / throws',
      (tester) async {
        final rootCircuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('root')),
        ]);
        addTearDown(rootCircuit.dispose);

        final featureCompleter = Completer<String>();
        final featureWire = AsyncWire<String>(() => featureCompleter.future);

        Circuit? foundMaybeInBuilding;
        Object? thrownErrorInBuilding;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider.value(
              value: rootCircuit,
              child: CircuitProvider(
                wires: [featureWire],
                builder: (context, state) => switch (state) {
                  CircuitBuilding() => Builder(
                    builder: (childCtx) {
                      foundMaybeInBuilding = CircuitProvider.maybeOf(childCtx);
                      try {
                        CircuitProvider.of(childCtx);
                      } catch (e) {
                        thrownErrorInBuilding = e;
                      }
                      return const Text('Feature Building');
                    },
                  ),
                  CircuitReady() => const Text('Feature Ready'),
                  CircuitFailure() => const Text('Feature Failed'),
                },
              ),
            ),
          ),
        );

        expect(find.text('Feature Building'), findsOneWidget);
        expect(foundMaybeInBuilding, isNull);
        expect(thrownErrorInBuilding, isA<StateError>());
      },
    );

    testWidgets(
      'nested CircuitProvider in failure state intercepts untagged of/maybeOf while preserving ancestor tagged circuits',
      (tester) async {
        final rootCircuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('root_val')),
        ]);
        addTearDown(rootCircuit.dispose);

        final failingWire = AsyncWire<String>(
          () async => throw StateError('failed feature init'),
        );

        Circuit? foundMaybeInFailure;
        Object? thrownErrorInFailure;
        Circuit? ancestorInFailure;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CircuitProvider.value(
              tag: _TestScope.global,
              value: rootCircuit,
              child: CircuitProvider(
                tag: _TestScope.feature,
                wires: [failingWire],
                builder: (context, state) => switch (state) {
                  CircuitFailure() => Builder(
                    builder: (childCtx) {
                      foundMaybeInFailure = CircuitProvider.maybeOf(childCtx);
                      try {
                        CircuitProvider.of(childCtx);
                      } catch (e) {
                        thrownErrorInFailure = e;
                      }
                      ancestorInFailure = CircuitProvider.of(
                        childCtx,
                        tag: _TestScope.global,
                      );
                      return const Text('Feature Failed');
                    },
                  ),
                  _ => const Text('Pending'),
                },
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Feature Failed'), findsOneWidget);
        expect(foundMaybeInFailure, isNull);
        expect(thrownErrorInFailure, isA<StateError>());
        expect(ancestorInFailure, equals(rootCircuit));
      },
    );

    testWidgets(
      'dynamic removal of intermediate tagged provider purges its tag from ambient scope',
      (tester) async {
        final rootCircuit = await Circuit.build([
          Wire<_RepositoryA>(() => const _RepositoryA('root_val')),
        ]);
        final intermediateCircuit = await Circuit.build([
          Wire<String>(() => 'intermediate_val'),
        ]);
        addTearDown(() async {
          await rootCircuit.dispose();
          await intermediateCircuit.dispose();
        });

        var showIntermediate = true;
        late StateSetter updateTree;

        Circuit? observedGlobal;
        Circuit? observedIntermediate;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              updateTree = setState;
              Widget content = Builder(
                builder: (childCtx) {
                  observedGlobal = CircuitProvider.of(
                    childCtx,
                    tag: _TestScope.global,
                  );
                  observedIntermediate = CircuitProvider.maybeOf(
                    childCtx,
                    tag: _TestScope.feature,
                  );
                  return Text(
                    'Global: ${observedGlobal != null}, Intermediate: ${observedIntermediate != null}',
                  );
                },
              );

              if (showIntermediate) {
                content = CircuitProvider.value(
                  tag: _TestScope.feature,
                  value: intermediateCircuit,
                  child: content,
                );
              }

              return Directionality(
                textDirection: TextDirection.ltr,
                child: CircuitProvider.value(
                  tag: _TestScope.global,
                  value: rootCircuit,
                  child: content,
                ),
              );
            },
          ),
        );

        expect(find.text('Global: true, Intermediate: true'), findsOneWidget);
        expect(observedGlobal, equals(rootCircuit));
        expect(observedIntermediate, equals(intermediateCircuit));

        // Dynamically pop / remove intermediate provider
        updateTree(() {
          showIntermediate = false;
        });
        await tester.pump();

        expect(find.text('Global: true, Intermediate: false'), findsOneWidget);
        expect(observedGlobal, equals(rootCircuit));
        expect(observedIntermediate, isNull);
      },
    );

    testWidgets(
      'dynamic tag updates on CircuitProvider at runtime update scoped registries reactively',
      (tester) async {
        final wireA = Wire<_RepositoryA>(
          () => const _RepositoryA('dynamic_tag'),
        );
        late StateSetter updateTree;
        _TestScope? activeTag = _TestScope.global;

        Circuit? foundGlobal;
        Circuit? foundFeature;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              updateTree = setState;
              return Directionality(
                textDirection: TextDirection.ltr,
                child: CircuitProvider(
                  tag: activeTag,
                  wires: [wireA],
                  builder: (context, state) => switch (state) {
                    CircuitReady() => Builder(
                      builder: (childCtx) {
                        foundGlobal = CircuitProvider.maybeOf(
                          childCtx,
                          tag: _TestScope.global,
                        );
                        foundFeature = CircuitProvider.maybeOf(
                          childCtx,
                          tag: _TestScope.feature,
                        );
                        return Text('Tag: $activeTag');
                      },
                    ),
                    _ => const Text('Loading'),
                  },
                ),
              );
            },
          ),
        );

        await tester.pump();
        expect(find.text('Tag: _TestScope.global'), findsOneWidget);
        expect(foundGlobal, isNotNull);
        expect(foundFeature, isNull);

        // Update tag dynamically to _TestScope.feature
        updateTree(() {
          activeTag = _TestScope.feature;
        });
        await tester.pump();

        expect(find.text('Tag: _TestScope.feature'), findsOneWidget);
        expect(foundGlobal, isNull);
        expect(foundFeature, isNotNull);

        // Update tag dynamically to null (untagged)
        updateTree(() {
          activeTag = null;
        });
        await tester.pump();

        expect(find.text('Tag: null'), findsOneWidget);
        expect(foundGlobal, isNull);
        expect(foundFeature, isNull);
      },
    );
  });
}
