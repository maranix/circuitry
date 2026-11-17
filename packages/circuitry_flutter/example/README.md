# Circuitry Flutter Example

An end-to-end sample application demonstrating runtime dependency injection using `circuitry_flutter`.

## Features Demonstrated

- **Synchronous Wires**: `LoggerService` registered with `Wire.new(LoggerService.new)` and accessed by dependent services.
- **Asynchronous Wires with Lifecycle Hooks**: `AppDatabase` connects asynchronously using `AsyncWire.takes<LoggerService>().to(...)` and registers an `onDispose` teardown callback.
- **Tagged Configuration**: `AppConfig` providing version and application metadata.
- **Reactive State Pattern Matching**: `CircuitProvider` displays a loading splash during asynchronous wave compilation (`CircuitBuilding`), transitions to `HomeScreen` when ready (`CircuitReady`), and displays error handling (`CircuitFailure`).
- **DevTools Extension Ready**: Connects seamlessly to the Circuitry DevTools extension when launched in debug mode.

## Running the Example

```bash
# From workspace root:
cd packages/circuitry_flutter/example

# Run on macOS:
flutter run -d macos

# Run on Chrome:
flutter run -d chrome
```

## Running Example Tests

```bash
flutter test
```
