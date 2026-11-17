# Changelog

All notable changes to the Circuitry monorepo are documented in this file.

## 0.2.0 - 2026-11-17

Major feature release adding Dart and Flutter DevTools extension integration, core graph introspection, fail-fast async wave resolution, and taggable Flutter scopes.

### `circuitry` v0.2.0
- Ambient `CircuitRegistry` tracking active containers and exposing Dart VM Service extensions (`ext.circuitry.getCircuits`, `ext.circuitry.getCircuitGraph`, `ext.circuitry.forceResolveWire`) with zero profile/release overhead.
- Decoupled the 15 MB DevTools extension web bundle into the opt-in companion package `circuitry_devtools_extension`, reducing `circuitry` package archive size to ~28 KB.
- Added explicit VM Service extension registration and deregistration methods on `CircuitRegistry`.
- On-demand graph introspection API (`circuit.inspect()`) with precomputed reverse dependencies, direct and transitive queries, and Mermaid (`toMermaid()`) and JSON (`toJson()`) exporters.
- Fail-fast async wave resolution using `Future.wait` with `eagerError: true` and guarded rollback teardown of in-flight operations.
- Modularized DAG compiler (`CircuitGraph` in `src/graph.dart`) and runtime container (`Circuit` in `src/circuit.dart`).
- Migrated codebase to modern Dart 3.14+ primary constructors and contextual dot-shorthands.

### `circuitry_flutter` v0.2.0
- Taggable `CircuitProvider` with O(1) ambient map merging (`CircuitProvider.of(context, tag: ...)`) across nested hierarchies.
- Forwarding of `debugTag` from `CircuitProvider` to `Circuit.build` for DevTools identification.
- Bumped `circuitry` dependency to `^0.2.0`.
- Internal refactoring to Dart 3.14+ primary constructors and exhaustive pattern matching.

### `circuitry_devtools_extension` v0.2.0
- Published as an opt-in companion package (`dev_dependencies`) containing the compiled DevTools extension web bundle (~15 MB).
- Exposes `registerCircuitryDevToolsExtension()` and `unregisterCircuitryDevToolsExtension()` (and `CircuitryDevTools` static helper) for explicit runtime activation.
- Dedicated Flutter Web DevTools extension UI featuring an interactive DAG canvas, horizontal topological wave columns, cubic Bézier spline edge routing, multi-scope circuit navigation, startup wave waterfall profiler with critical path calculation, and live on-demand wire initialization.

## 0.1.0 - 2026-11-15

Initial release of `circuitry` and `circuitry_flutter`.

### `circuitry` v0.1.0
- Pure Dart 3.14+ zero-codegen, DAG-based dependency injection engine.
- Declarative synchronous `Wire<T>` and asynchronous `AsyncWire<T>` registrations.
- Record tuple keys `(Type, Enum?)` with dot-shorthand enum tagging.
- Full DAG static validation (cycle detection, missing wires, duplicate wire prevention).
- Parallel topological wave resolution and reverse-wave teardown disposal.
- Strongly-typed fluent accumulator chaining with `.takes<A>()`.

### `circuitry_flutter` v0.1.0
- Flutter bridge package providing `CircuitProvider` and `InheritedWidget` scoping.
- Reactive sealed `CircuitState` pattern matching (`CircuitBuilding`, `CircuitReady`, `CircuitFailure`).
- Monotonic compilation epoch tracking preventing widget update race conditions.
- Automatic unmount disposal and synchronous value injection support (`CircuitProvider.value`).
- Re-exports `package:circuitry/circuitry.dart`.
