# Getting Started

`circuitry` is a pure Dart 3.14+ dependency injection engine with zero code generation. You declare wires, build a `Circuit`, and read singletons in **O(1)** time.

## Install

```bash
dart pub add circuitry
```

::: tip Recommended: Analyzer Plugin
Install [`circuitry_analyzer_plugin`](/tooling#analyzer-plugin) in your `analysis_options.yaml` for real-time IDE and `dart analyze` checks on your wire definitions.
:::

## Quick Example

Define your services and assemble them with `Circuit.build`:

```dart
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }

final class const DatabaseConfig(final String path);

final class DatabaseService(final DatabaseConfig config) {
  Future<void> close() async {}
}

final class UserService(final DatabaseService db);

final class SendEmailAction implements CircuitAction {
  final UserService user;
  SendEmailAction(this.user);

  Future<bool> call(String recipient, {String? subject}) async {
    return true;
  }
}

void main() async {
  final circuit = await Circuit.build([
    // Tagged synchronous wire
    Wire.tag(() => const DatabaseConfig('app.db'), tag: Environment.prod),

    // Asynchronous wire with disposal hook
    AsyncWire.takesTagged<DatabaseConfig, Environment>(Environment.prod).to(
      (config) async => DatabaseService(config),
      onDispose: (service) => service.close(),
    ),

    // Synchronous wire via constructor tear-off
    Wire.takes<DatabaseService>().to(UserService.new),

    // Callable action singleton
    TriggerWire.takes<UserService>().to(SendEmailAction.new),
  ]);

  final userService = circuit.get<UserService>();
  final config = circuit.getTagged<DatabaseConfig, Environment>(Environment.prod);

  final sendEmail = circuit.get<SendEmailAction>();
  await sendEmail('alice@example.com', subject: 'Welcome');

  // Disposes in reverse topological order (UserService -> DatabaseService -> DatabaseConfig)
  await circuit.dispose();
}
```

## Wire Types

| Wire | Purpose | Evaluation |
| --- | --- | --- |
| `Wire<T>` | Synchronous singleton | Lazy (on first `get<T>()` or when needed by an `AsyncWire`) |
| `AsyncWire<T>` | Asynchronous singleton | Eager during `Circuit.build`, resolved in parallel waves |
| `TriggerWire<T>` | Action implementing `CircuitAction` | Lazy singleton, retained for zero-churn `call(...)` invocations |

## Chaining Dependencies

Use `.takes<A>()` or `.takesTagged<A, K>(tag)` to declare dependencies:

```dart
// Single dependency (constructor tear-off works directly)
Wire.takes<DatabaseService>().to(UserService.new)

// Multiple dependencies (destructured record)
Wire.takes<UserService>()
    .takes<Logger>()
    .to((deps) => OrderService(deps.$1, deps.$2))
```

## Graph Validation & Introspection

`Circuit.build(wires)` validates the entire graph before instantiating anything:

- **Duplicate keys** throw `DuplicateWireException`
- **Missing dependencies** throw `MissingWireException`
- **Cycles** throw `CircularDependencyException` with the exact cycle path

You can also inspect a built circuit or export it as Mermaid/JSON:

```dart
final inspection = circuit.inspect();
print(inspection.toMermaid());
```
