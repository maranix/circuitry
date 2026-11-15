# Changelog

All notable changes to the Circuitry monorepo are documented in this file.

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
