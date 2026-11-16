# Circuitry Flutter

[![pub package](https://img.shields.io/pub/v/circuitry_flutter.svg)](https://pub.dev/packages/circuitry_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Flutter bridge for [`circuitry`](https://pub.dev/packages/circuitry) — providing `InheritedWidget` scoping, reactive `CircuitState` pattern matching, compilation epoch race prevention, and automatic unmount disposal.

---

## Architecture Overview

![Circuitry Architecture](https://raw.githubusercontent.com/maranix/circuitry/main/assets/circuitry_architecture.png)

---

## Features

- **Sealed `CircuitState` Hierarchy**: Pattern match `CircuitBuilding`, `CircuitReady`, and `CircuitFailure` using Dart 3 switch expressions.
- **Asynchronous Build Lifecycle (`CircuitProvider`)**: Compiles `CircuitWire` recipes asynchronously, displays loading/splash state while resolving, and wraps child in an internal `InheritedWidget` scope once ready.
- **Monotonic Epoch Race Prevention**: Handles dynamic widget wire updates (`didUpdateWidget`) without race conditions, safely discarding superseded in-flight builds.
- **Automatic Unmount Cleanup**: Automatically calls `circuit.dispose()` when the provider is unmounted from the widget tree.
- **Synchronous Value Injection (`CircuitProvider.value`)**: Injects an already resolved `Circuit` synchronously for test harnesses or sub-trees without managing lifecycle disposal.
- **Taggable Scopes & O(1) Nested Lookup**: Associate providers with tags (`tag: Scope.global`) to retrieve ancestor containers across nested providers in **O(1)** via `CircuitProvider.of(context, tag: Scope.global)` without widget tree walking.
- **Explicit Accessors**: Retrieve dependencies via `CircuitProvider.of(context)` and `CircuitProvider.maybeOf(context)` without `BuildContext` extension pollution.

---

## Installation

```bash
flutter pub add circuitry_flutter
```

---

## Quickstart

```dart
import 'package:circuitry_flutter/circuitry_flutter.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _defaultWires = [
    Wire(() => DatabaseConfig('app.db')),
    AsyncWire.takes<DatabaseConfig>().to(DatabaseManager.open),
  ];

  @override
  Widget build(BuildContext context) {
    return CircuitProvider(
      wires: _defaultWires,
      builder: (context, state) => switch (state) {
        CircuitReady(:final circuit) => const HomeScreen(),
        CircuitBuilding() => const SplashScreen(),
        CircuitFailure(:final error) => ErrorScreen(error: error),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final circuit = CircuitProvider.of(context);
    final db = circuit.get<DatabaseService>();

    return Center(
      child: Text('Database active: ${db.path}'),
    );
  }
}
```

---

## Nested Scopes & Tagged Circuit Providers

When nesting providers (e.g. global app scope wrapping feature-specific modules), tag each `CircuitProvider` to allow descendants to access ancestor containers in **O(1)**:

```dart
enum AppScope { global, feature }

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return CircuitProvider(
      tag: AppScope.global,
      wires: [Wire(GlobalAuthService.new)],
      builder: (context, state) => switch (state) {
        CircuitReady() => CircuitProvider(
          tag: AppScope.feature,
          wires: [Wire(FeatureViewModel.new)],
          builder: (context, state) => switch (state) {
            CircuitReady() => const FeatureScreen(),
            _ => const SplashScreen(),
          },
        ),
        _ => const SplashScreen(),
      },
    );
  }
}

class FeatureScreen extends StatelessWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Nearest circuit (feature):
    final featureCircuit = CircuitProvider.of(context);

    // 2. Ancestor tagged circuit (global) in O(1):
    final globalCircuit = CircuitProvider.of(context, tag: AppScope.global);

    return Text('Feature ready with global auth');
  }
}
```
```

---

## License

MIT © [Raman Verma](https://github.com/maranix)
