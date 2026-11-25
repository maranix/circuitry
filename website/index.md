---
layout: doc
sidebar: false
aside: false
prev: false
next: false
---

<div class="banner-wrap">
  <img src="/banner-light.svg" alt="Circuitry" class="banner-light" />
  <img src="/banner-dark.svg" alt="Circuitry" class="banner-dark" />
</div>

## Install

```bash
dart pub add circuitry
```

## How it looks

Declare your wires, build the circuit, and read them synchronously in **O(1)**!

```dart
import 'package:circuitry/circuitry.dart';

void main() async {
  final circuit = await Circuit.build([
    Wire(() => const DatabaseConfig('app.db')),
    AsyncWire.takes<DatabaseConfig>().to(
      DatabaseService.open,
      onDispose: (db) => db.close(),
    ),
    Wire.takes<DatabaseService>().to(UserService.new),
    TriggerWire.takes<UserService>().to(SendEmailAction.new),
  ]);

  final userService = circuit.get<UserService>();
  final sendEmail = circuit.get<SendEmailAction>();
  await sendEmail('alice@example.com');

  await circuit.dispose();
}
```

## Packages

- **[`circuitry`](/guide)** — Pure Dart DI engine (~28 KB). Zero Flutter dependencies; runs on CLI, server, web, and mobile.
- **[`circuitry_flutter`](/flutter)** — `CircuitProvider`, `CircuitBuilder`, `listener` callbacks, and tagged `O(1)` scoping.
- **[`circuitry_analyzer_plugin`](/tooling#analyzer-plugin)** — Edit-time IDE and CLI lints for missing wires, duplicate keys, and action blueprints.
- **[`circuitry_devtools_extension`](/tooling#devtools-extension)** — Opt-in DevTools tab with an interactive DAG canvas and wave waterfall profiler.

<style scoped>
.banner-wrap {
  display: flex;
  justify-content: center;
  margin-block: 8px 36px;
}

.banner-wrap img {
  max-inline-size: min(560px, 100%);
  block-size: auto;
}

.banner-dark {
  display: none;
}

:global(html.dark) .banner-light {
  display: none;
}

:global(html.dark) .banner-dark {
  display: block;
}
</style>
