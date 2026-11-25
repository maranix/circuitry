# DevTools & Analyzer

Circuitry ships two optional first-party tooling packages.

## Analyzer Plugin

`circuitry_analyzer_plugin` runs inside the Dart Analysis Server to catch graph mistakes as you type.

Add it to your `analysis_options.yaml`:

```yaml
plugins:
  circuitry_analyzer_plugin: ^0.1.0
```

All rules are enabled by default as warnings:

- **`circuitry_duplicate_wire`**: Flags duplicate `(Type, Enum?)` keys in wire lists.
- **`circuitry_missing_wire`**: Catches missing `.takes<T>()` / `.takesTagged<T, K>()` dependencies.
- **`circuitry_prefer_trigger_wire`**: Enforces `TriggerWire` for classes implementing `CircuitAction`.
- **`circuitry_avoid_async_in_wire`**: Warns when a synchronous `Wire` returns a `Future<T>`.

## DevTools Extension

`circuitry_devtools_extension` adds a **Circuitry** tab to Dart & Flutter DevTools with an interactive DAG canvas, wave waterfall profiler, and live wire inspector.

1. Add it to `dev_dependencies` (so it adds zero weight to release builds):

```yaml
dev_dependencies:
  circuitry_devtools_extension: ^0.2.0
```

2. Register it in debug mode in `main()`:

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
