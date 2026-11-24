# Changelog

## 0.5.0

### Changes
- **Dependency Update**:
  - Bumped core engine dependency to `circuitry: ^0.5.0` to take advantage of type-indexed fast-path retrieval throughput improvements.

## 0.2.0

### Features
- **Taggable Scopes & O(1) Nested Lookup**:
  - `CircuitProvider` now accepts an optional `tag: Enum` property (e.g. `tag: AppScope.global`).
  - Merges tagged containers into an ambient `Map<Enum, Circuit>` scope down the widget tree.
  - Descendants can query ancestor tagged containers in O(1) via `CircuitProvider.of(context, tag: ...)` and `CircuitProvider.maybeOf(context, tag: ...)` without expensive ancestor tree walking.
  - Automatically reacts to ancestor tagged circuit updates while maintaining local untagged provider shadowing.
- **DevTools Debug Tag Forwarding**:
  - `CircuitProvider` accepts an optional `debugTag: String` and forwards it to `Circuit.build(wires, debugTag: debugTag)` for named inspection in Dart and Flutter DevTools.
- **Dependency Update**:
  - Bumped core engine dependency to `circuitry: ^0.2.0`.
- **Refactoring & Modern Dart Idioms**:
  - Migrated internal widgets and state representations to Dart 3.14+ primary constructors and exhaustive switch expression pattern matching.

## 0.1.0

Initial release of Circuitry Flutter: the Flutter companion package for Circuitry.

### Features
- **Pure Dart Core Re-export**: Re-exports `package:circuitry/circuitry.dart` so Flutter applications only need to depend on `circuitry_flutter`.
- **Sealed `CircuitState` Hierarchy**: Pattern match `CircuitBuilding`, `CircuitReady`, and `CircuitFailure` using modern Dart 3 switch expressions.
- **Asynchronous Build Lifecycle (`CircuitProvider`)**: Asynchronously compiles `CircuitWire` recipes, displays loading/splash UI while resolving, and wraps child widgets in an internal `InheritedWidget` scope once ready.
- **Monotonic Epoch Race Prevention**: Safely handles dynamic wire updates (`didUpdateWidget`) without race conditions, canceling and disposing superseded in-flight builds.
- **Automatic Unmount Cleanup**: Automatically tears down and disposes the active circuit when `CircuitProvider` is unmounted from the widget tree.
- **Synchronous Value Injection (`CircuitProvider.value`)**: Injects pre-compiled `Circuit` instances for widget test harnesses or sub-trees without managing lifecycle disposal.
- **Explicit Scoped Accessors**: Context retrieval via `CircuitProvider.of(context)` and `CircuitProvider.maybeOf(context)` without `BuildContext` extension pollution.
