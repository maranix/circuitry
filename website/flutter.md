# Flutter Integration

`circuitry_flutter` connects `Circuit` lifecycles to your Flutter widget tree and re-exports `package:circuitry/circuitry.dart`.

## Install

```bash
flutter pub add circuitry_flutter
```

::: tip Recommended: Analyzer Plugin
Install [`circuitry_analyzer_plugin`](/tooling#analyzer-plugin) in your `analysis_options.yaml` for real-time IDE and `flutter analyze` checks on your wire definitions.
:::

## `CircuitProvider` & `CircuitBuilder`

Wrap your app (or a feature subtree) with `CircuitProvider` and pattern-match on `CircuitState`:

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
```

`CircuitBuilder<T>` is syntactic sugar for `CircuitProvider.of(context).get<T>()`, letting you resolve a dependency inline without boilerplate:

```dart
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircuitBuilder<UserService>(
        builder: (context, user) => Text('Welcome, ${user.name}'),
      ),
    );
  }
}
```

`CircuitProvider` automatically disposes the `Circuit` when unmounted.

## Side Effects with `listener`

Pass `listener` to `CircuitProvider` for one-off side effects (snackbars, navigation, logging) on state transitions:

```dart
CircuitProvider(
  wires: [...],
  listener: (context, state) {
    if (state case CircuitFailure(:final error)) {
      // Show error snackbar or report telemetry
    }
  },
  builder: (context, state) => ...,
)
```

## Nested Scoped Providers

Tag nested `CircuitProvider` widgets with an `Enum` to access specific ancestor circuits in **O(1)**:

```dart
enum AppScope { global, feature }

// Root provider
CircuitProvider(
  tag: AppScope.global,
  wires: [...],
  builder: (context, state) => ...,
)

// Access anywhere below
final globalCircuit = CircuitProvider.of(context, tag: AppScope.global);
final nearestCircuit = CircuitProvider.of(context);
```
