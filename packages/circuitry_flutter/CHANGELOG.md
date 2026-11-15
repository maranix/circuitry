# Changelog

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
