# Circuitry Analyzer Plugin

First-party Dart Analysis Server plugin providing static Directed Acyclic Graph (DAG) validation, safety checks, and best practice warnings for the Circuitry ecosystem.

Built on Dart's official [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin) framework (Dart 3.10+ / Flutter 3.38+).

---

## Features

- **Shift-Left Static DAG Validation**: Catches duplicate wire registrations and missing dependencies at edit time right inside your IDE (VS Code, Android Studio, IntelliJ) and during `dart analyze` / `flutter analyze`.
- **Zero Configuration Required**: All diagnostics are registered as **warning-level rules enabled by default**—no manual `diagnostics:` declarations in `analysis_options.yaml` needed.
- **Native Dart SDK Architecture**: Runs directly inside the Dart Analysis Server's isolated plugin worker without requiring third-party background daemons or external runner tools.

---

## Getting Started

Add `circuitry_analyzer_plugin` under the top-level `plugins` section of your `analysis_options.yaml`:

```yaml
plugins:
  circuitry_analyzer_plugin: ^0.1.0
```

During local monorepo development, you can reference the local package path:

```yaml
plugins:
  circuitry_analyzer_plugin:
    path: ./packages/circuitry_analyzer_plugin
```

Once added, the Dart Analysis Server automatically activates the plugin across your workspace.

---

## Rules Reference

### 1. `circuitry_duplicate_wire` (Warning)
Flags duplicate wire keys `(Type, Enum?)` defined within the same `Circuit.build([...])` or `CircuitProvider(wires: [...])` static list.

#### ❌ Bad
```dart
await Circuit.build([
  Wire(() => DatabaseService()),
  Wire(() => DatabaseService()), // LINT: Duplicate wire registered for key 'DatabaseService'.
]);
```

#### ✅ Good
```dart
await Circuit.build([
  Wire.tag(() => DatabaseConfig('dev.db'), tag: Environment.dev),
  Wire.tag(() => DatabaseConfig('prod.db'), tag: Environment.prod),
]);
```

---

### 2. `circuitry_missing_wire` (Warning)
Validates that any dependency declared via `.takes<T>()` or `.takesTagged<T, K>()` is fulfilled by another wire registered in the same static wire list.

#### ❌ Bad
```dart
await Circuit.build([
  // LINT: Missing dependency wire for key 'DatabaseService' required by 'UserService'.
  Wire.takes<DatabaseService>().to(UserService.new),
]);
```

#### ✅ Good
```dart
await Circuit.build([
  Wire(() => DatabaseService()),
  Wire.takes<DatabaseService>().to(UserService.new),
]);
```

> **Note:** If a wire list contains spread operators (`...otherWires`) or dynamic variables, `circuitry_missing_wire` safely skips the check for that list to eliminate false positives.

---

### 3. `circuitry_prefer_trigger_wire` (Warning)
Enforces the CircuitAction blueprint pattern: flags classes implementing `CircuitAction` that are registered via `Wire` or `AsyncWire` instead of `TriggerWire`.

#### ❌ Bad
```dart
class SendEmailAction implements CircuitAction {}

// LINT: The type 'SendEmailAction' implements 'CircuitAction' and should be registered using 'TriggerWire'.
final wire = Wire(() => SendEmailAction());
```

#### ✅ Good
```dart
final wire = TriggerWire(() => SendEmailAction());
```

---

### 4. `circuitry_avoid_async_in_wire` (Warning)
Warns when a synchronous `Wire(...)` factory returns a `Future<T>`, pointing the developer to use `AsyncWire<T>`.

#### ❌ Bad
```dart
// LINT: Synchronous 'Wire' factory returns a 'Future<DatabaseService>'. Use 'AsyncWire' instead.
final wire = Wire(() async => DatabaseService());
```

#### ✅ Good
```dart
final wire = AsyncWire(() async => DatabaseService());
```

---

## Verification & Testing

```bash
# Run unit tests
cd packages/circuitry_analyzer_plugin && dart test

# Analyze codebase
dart analyze packages/circuitry_analyzer_plugin
```
