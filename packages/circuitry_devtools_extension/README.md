<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/maranix/circuitry/main/assets/circuitry_logo_horizontal_transparent.png">
    <img alt="Circuitry DevTools Extension" src="https://raw.githubusercontent.com/maranix/circuitry/main/assets/circuitry_logo_horizontal_light.png" width="600">
  </picture>
</p>

# Circuitry DevTools Extension

> **Dedicated Flutter DevTools companion extension for inspecting, profiling, and debugging Circuitry dependency graphs at runtime.**

<p align="center">
  <a href="https://pub.dev/packages/circuitry_devtools_extension"><img src="https://img.shields.io/pub/v/circuitry_devtools_extension.svg" alt="Pub Package" /></a>
  <a href="https://github.com/maranix/circuitry/actions"><img src="https://img.shields.io/badge/build-passing-brightgreen.svg" alt="Build Status" /></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT" /></a>
</p>

---

This package is distributed as an optional, opt-in developer tool. Installing it in `dev_dependencies` ensures that your production runtime bundles stay completely free of DevTools web assets.

---

## Installation

Add `circuitry_devtools_extension` to your project's `dev_dependencies`:

```yaml
dev_dependencies:
  circuitry_devtools_extension: ^0.2.0
```

---

## Usage

In your application's entry point (e.g. `main()`), call `registerCircuitryDevToolsExtension()` to register the VM Service extension endpoints and enable live telemetry:

```dart
import 'package:circuitry/circuitry.dart';
import 'package:circuitry_devtools_extension/circuitry_devtools_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

void main() {
  // Explicitly register Circuitry DevTools extension in debug mode
  if (kDebugMode) {
    registerCircuitryDevToolsExtension();
    // or: CircuitryDevTools.register();
  }

  runApp(const MyApp());
}
```

To disable the extension at runtime:

```dart
unregisterCircuitryDevToolsExtension();
// or: CircuitryDevTools.unregister();
```

When you launch Dart or Flutter DevTools, the **Circuitry** tab appears automatically.

---

## Features

- **Interactive DAG Canvas**: Renders dependency graphs organized into horizontal topological wave columns with cubic Bézier spline edge routing, wire node selection, and status badges.
- **Wave Waterfall Profiler**: Visualizes asynchronous startup resolution across topological waves, computing and highlighting the critical path with cumulative latency metrics.
- **Multi-Scope Circuit Navigator**: Switch between multiple active `Circuit` instances and tagged scopes.
- **Live Wire Inspector**: Inspect wire configurations, dependencies, direct/transitive dependents, and trigger on-demand singleton initialization via VM Service protocol (`ext.circuitry.forceResolveWire`).
- **Multi-Format Exporters**: Export the graph schema directly to Mermaid flowchart diagrams, structured JSON, or SVG markup.

---

## Architecture & Seams

The DevTools UI is decoupled from the VM Service transport behind the abstract `CircuitryServiceClient` interface:

- `VmCircuitryServiceClient`: Communicates with live Dart VM Service extensions (`ext.circuitry.*`) in debug builds.
- `MockCircuitryServiceClient`: Provides deterministic mock graph data enabling 100% test coverage with `flutter test` without a running Dart VM Service daemon.

---

## Development & Building

### Running Tests

```bash
cd packages/circuitry_devtools_extension
flutter test
```

### Compiling Web Bundle

To recompile the pre-built web extension assets into `extension/devtools/build`:

```bash
cd packages/circuitry_devtools_extension
dart run devtools_extensions build_and_copy --source=. --dest=.
```

---

## License

MIT © [Raman Verma](https://github.com/maranix)
