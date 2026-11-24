# Circuitry

> **Pure Dart 3.14+ zero-codegen, graph-based dependency injection engine backed by a Directed Acyclic Graph (DAG), with Flutter bindings.**

Circuitry provides compile-time-checked runtime dependency wiring with parallel topological wave resolution for asynchronous singletons, reverse topological wave disposal, and type-safe dependency chaining without code generation, mirrors, or reflection.

---

## Monorepo Packages

| Package | Version | Description |
| --- | --- | --- |
| [`circuitry`](packages/circuitry) | [![pub](https://img.shields.io/pub/v/circuitry.svg)](https://pub.dev/packages/circuitry) | Pure Dart dependency injection engine (~28 KB). Zero Flutter dependencies; runs on CLI, server, web, and mobile. |
| [`circuitry_flutter`](packages/circuitry_flutter) | [![pub](https://img.shields.io/pub/v/circuitry_flutter.svg)](https://pub.dev/packages/circuitry_flutter) | Flutter bridge with `CircuitProvider`, `CircuitBuilder`, `InheritedWidget` scoping, `CircuitState` matching, and unmount disposal. |
| [`circuitry_devtools_extension`](packages/circuitry_devtools_extension) | [![pub](https://img.shields.io/pub/v/circuitry_devtools_extension.svg)](https://pub.dev/packages/circuitry_devtools_extension) | Optional opt-in DevTools companion package (`dev_dependencies`). Interactive DAG canvas, wave waterfall profiler, and live wire inspector. |

---

## Architecture Overview

![Circuitry Architecture](https://raw.githubusercontent.com/maranix/circuitry/main/assets/circuitry_architecture.png)

---

## Architectural Principles

1. **Zero Codegen & Pure Dart 3.14+**: No `build_runner`, code generation steps, or reflection. Fully leverages Dart 3.14+ primary constructors, switch expressions, and record tuple keys `(Type, Enum?)`.
2. **DAG Static Validation**: Validates the dependency graph during `Circuit.build(wires)` before creating singletons:
   - Duplicate wire keys throw `DuplicateWireException`
   - Missing dependencies throw `MissingWireException`
   - Cycles throw `CircularDependencyException` with exact cycle paths
3. **Parallel Topological Wave Resolution**: Asynchronous singletons (`AsyncWire<T>`) resolve concurrently wave-by-wave using `Future.wait` with fail-fast semantics (`eagerError: true`). Immediately rolls back and disposes partially created instances in reverse topological order if any wave fails.
4. **Type-Safe Accumulator Chaining & Action Blueprints**: Chain dependencies with `.takes<A>()` and `.takesTagged<B, K>(tag)` producing strongly-typed accumulators. Support direct tear-offs (`.to(UserService.new)`) or destructuring for multi-dependencies. Dedicated `TriggerWire<T extends CircuitAction>` enforces compile-time blueprint conformance for callable actions, evaluated lazily and retained for zero-churn invocations.
5. **Reverse Topological Wave Disposal**: Idempotent teardown in reverse dependency waves (`leaves -> roots`), awaiting asynchronous `onDispose` callbacks concurrently and aggregating errors into `DisposalException`.
6. **Flutter Lifecycle Integration & Scoped Registries**: `CircuitProvider` manages async build lifecycles, didUpdateWidget monotonic compilation epoch race prevention, unmount teardown, and ambient `Map<Enum, Circuit>` scoping for nested tagged providers with **O(1)** retrieval (`CircuitProvider.of(context, tag: Scope.global)`). `CircuitBuilder<T>` localizes dependency consumption to leaf widgets without broad screen rebuilds.
7. **On-Demand Introspection & Exporters**: `circuit.inspect()` provides on-demand DAG inspection (`dependentsOf`, `dependenciesOf`, `topologicalOrder`), valid Mermaid flowchart generation (`toMermaid()`), and structured JSON serialization (`toJson()`), fully tree-shaken in release builds when unused.
8. **DevTools Integration & Ambient Registry**: Ambient `CircuitRegistry` tracks containers in debug mode, exposing VM Service endpoints (`ext.circuitry.getCircuits`, `ext.circuitry.getCircuitGraph`, `ext.circuitry.forceResolveWire`) and streaming lifecycle events via `developer.postEvent`. In profile and release modes, `CircuitRegistry`, its properties, and `debugTag` are complete no-ops and tree-shaken with zero runtime or memory overhead.
9. **Interactive DevTools Extension UI & Opt-In Companion**: The 15 MB compiled DevTools extension is published as a dedicated, opt-in `dev_dependency` package (`circuitry_devtools_extension`). This keeps `circuitry` ultra-lightweight (~28 KB). Developers opt into DevTools inspection by adding `circuitry_devtools_extension` to `dev_dependencies` and calling `registerCircuitryDevToolsExtension()` in `main()`, unlocking the interactive DAG canvas, horizontal topological waves, wave waterfall profiler, and on-demand singleton initialization.

---

## Quickstart

### 1. Pure Dart Engine

Add `circuitry` to your `pubspec.yaml`:
```bash
dart pub add circuitry
```

#### Define Services & Action Blueprints
```dart
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }

final class const DatabaseConfig(final String path);

final class DatabaseService(final DatabaseConfig config) {
  Future<void> close() async {}
}

final class UserService(final DatabaseService db);

/// Actions implement the CircuitAction blueprint marker interface.
final class SendEmailAction implements CircuitAction {
  final UserService user;
  SendEmailAction(this.user);

  Future<bool> call(String recipient, {String? subject}) async {
    return true;
  }
}
```

#### Declare Wire Recipes & Build Circuit
```dart
void main() async {
  final circuit = await Circuit.build(
    [
      // Synchronous wire with tagged enum
      Wire.tag(
        () => const DatabaseConfig('app.db'),
        tag: Environment.prod,
      ),

      // Asynchronous wire depending on tagged config with disposal hook
      AsyncWire.takesTagged<DatabaseConfig, Environment>(Environment.prod).to(
        (config) async => DatabaseService(config),
        onDispose: (service) => service.close(),
      ),

      // Synchronous wire depending on DatabaseService via constructor tear-off
      Wire.takes<DatabaseService>().to(UserService.new),

      // Action singleton wire evaluated lazily and retained for zero-churn invocations
      TriggerWire.takes<UserService>().to(SendEmailAction.new),
    ],
    debugTag: 'main_circuit',
  );

  // Synchronous O(1) instance retrieval (< 20 ns)
  final userService = circuit.get<UserService>();

  // Tagged dependency retrieval
  final config = circuit.getTagged<DatabaseConfig, Environment>(Environment.prod);

  // Retrieve and invoke action using native call() syntax
  final sendEmail = circuit.get<SendEmailAction>();
  await sendEmail('alice@example.com', subject: 'Welcome');

  // Reverse topological wave teardown (users -> db -> config)
  await circuit.dispose();
}
```

---

### 2. Flutter Integration

Add `circuitry_flutter` to your `pubspec.yaml`:
```bash
flutter pub add circuitry_flutter
```

#### Application Composition with `CircuitProvider` & `CircuitBuilder`
```dart
import 'package:circuitry_flutter/circuitry_flutter.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CircuitProvider(
      wires: [
        Wire(() => const DatabaseConfig('app.db')),
        AsyncWire.takes<DatabaseConfig>().to(DatabaseManager.open),
        Wire.takes<DatabaseService>().to(UserService.new),
      ],
      builder: (context, state) => switch (state) {
        CircuitReady() => const MainScreen(),
        CircuitBuilding() => const SplashScreen(),
        CircuitFailure(:final error) => ErrorScreen(error: error),
      },
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      // Localized leaf read: rebuilds only this widget, not the whole screen
      child: CircuitBuilder<UserService>(
        builder: (context, user) => Text('Welcome, ${user.name}'),
      ),
    );
  }
}
```

---

## Performance Benchmarks

Circuitry includes a reproducible, micro-benchmarking suite calibrated against empty-loop baselines:

```bash
# Run hot-path retrieval benchmarks
cd packages/circuitry && dart run benchmark/retrieval_benchmark.dart

# Run DAG compilation and static validation benchmarks
cd packages/circuitry && dart run benchmark/compilation_benchmark.dart
```

### Measured Throughput & Latency

| Benchmark Operation | Throughput | Net Latency | Description |
| --- | --- | --- | --- |
| `circuit.get<T>()` (Untagged Root) | **30,086,951 ops/sec** | **33.24 ns/op** | Direct type-indexed lookup |
| `circuit.get<T>()` (Untagged Leaf) | **50,010,002 ops/sec** | **20.00 ns/op** | Leaf dependency hot-path retrieval |
| Polymorphic interleaved reads | **53,273,667 ops/sec** | **18.77 ns/op** | 5 distinct singletons in rotation |
| `circuit.getTagged<T, K>(tag)` | **14,309,427 ops/sec** | **69.88 ns/op** | Record tuple key `(Type, Enum)` lookup |
| `circuit.get<Action>()` | **36,063,327 ops/sec** | **27.73 ns/op** | Retained action singleton retrieval |
| Action direct invocation | **1,000,000,000+ ops/sec** | **< 1.00 ns/op** | Direct `action(...)` call (zero GC churn) |
| Micro DAG Compilation (10 nodes) | **35,761 comp/sec** | **27.96 µs/comp** | Cycle detection, missing check, wave grouping |
| Feature DAG Compilation (35 nodes) | **10,899 comp/sec** | **91.75 µs/comp** | Multi-wave dependency compilation |
| Monolith DAG Compilation (100 nodes)| **4,871 comp/sec** | **205.31 µs/comp** | Large graph validation & topological ordering |

---

## DevTools Extension Setup

To inspect your dependency graphs in Dart / Flutter DevTools without adding weight to production builds:

1. Add `circuitry_devtools_extension` to `dev_dependencies`:
```yaml
dev_dependencies:
  circuitry_devtools_extension: ^0.2.0
```

2. Register the extension in debug mode:
```dart
import 'package:circuitry_devtools_extension/circuitry_devtools_extension.dart';
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    registerCircuitryDevToolsExtension();
  }
  runApp(const MyApp());
}
```

3. Launch your app in debug mode and open DevTools. Select the **Circuitry** tab to access:
   - **Interactive DAG Canvas**: Horizontal topological wave columns, Bézier splines, action badges, and dependency illumination.
   - **Startup Wave Waterfall**: Visual timeline showing parallel wave concurrency, initialization latencies, and critical path highlighting.
   - **Live Wire Inspector**: Metadata inspection, dependency links, and on-demand force initialization via VM Service.

---

## Workspace Structure

```
circuitry/
├── .github/workflows/ci.yml       # Automated format, analyze, and test verification
├── docs/
│   ├── decisions.md               # Architectural decision records
│   ├── architecture.md            # System architecture, module tree, and seams
│   └── plan.md                    # Active roadmap and checklist
├── packages/
│   ├── circuitry/                 # Pure Dart dependency injection engine (~28 KB)
│   │   ├── benchmark/             # Performance benchmark suite (hot-path retrieval & compilation)
│   │   │   ├── compilation_benchmark.dart
│   │   │   └── retrieval_benchmark.dart
│   │   ├── lib/
│   │   │   ├── circuitry.dart     # Public barrel export
│   │   │   └── src/               # Core engine implementation (circuit, graph, wire, registry, utils, extensions)
│   │   └── test/                  # Unit tests for DAG, waves, laziness, disposal, and registry
│   ├── circuitry_devtools_extension/ # Standalone Flutter Web DevTools extension UI & companion package
│   │   ├── extension/             # Dart & Flutter DevTools extension configuration
│   │   │   └── devtools/
│   │   │       ├── build/         # Compiled Flutter Web extension bundle
│   │   │       └── config.yaml
│   │   ├── lib/
│   │   │   ├── circuitry_devtools_extension.dart # Public registration API
│   │   │   ├── main.dart          # DevToolsExtension web entry point
│   │   │   └── src/               # UI controllers, models, screens, services, widgets
│   │   └── test/                  # Model, controller, widget, and registration unit tests
│   └── circuitry_flutter/         # Flutter companion package
│       ├── lib/
│       │   ├── circuitry_flutter.dart # Public barrel export
│       │   └── src/               # Flutter bridge implementation (provider, scope, state, builder)
│       │       ├── circuit_builder.dart  # CircuitBuilder widget for localized leaf reads
│       │       ├── circuit_provider.dart # CircuitProvider widget declarations and internal _CircuitScope
│       │       └── circuit_state.dart    # CircuitState sealed hierarchy
│       └── test/                  # Widget, lifecycle, and integration tests
├── analysis_options.yaml          # Strict static analysis rules
├── pubspec.yaml                   # Root pub workspace
└── README.md
```

---

## Verification & Commands

### Code Formatting

```bash
# Check formatting across all packages
dart format --output=none --set-exit-if-changed .

# Apply formatting
dart format .
```

### Static Analysis

```bash
# Run strict linter across workspace
flutter analyze --fatal-infos --fatal-warnings
```

### Run Tests

```bash
# Run pure Dart tests in circuitry
cd packages/circuitry && dart test

# Run Flutter tests in circuitry_flutter
cd packages/circuitry_flutter && flutter test

# Run DevTools extension tests in circuitry_devtools_extension
cd packages/circuitry_devtools_extension && flutter test
```

### Run Benchmarks

```bash
# Run hot-path dependency retrieval benchmarks
cd packages/circuitry && dart run benchmark/retrieval_benchmark.dart

# Run DAG compilation and static validation benchmarks
cd packages/circuitry && dart run benchmark/compilation_benchmark.dart
```

---

## License

Copyright © 2026 [Raman Verma](https://github.com/maranix). Released under the [MIT License](LICENSE).
