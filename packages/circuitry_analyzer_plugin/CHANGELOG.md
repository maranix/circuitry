# Changelog

## 0.1.0

Initial release of `circuitry_analyzer_plugin`: the first-party Dart Analysis Server plugin for Circuitry.

### Features
- **Zero-Configuration Default Warning Rules** (built on `package:analysis_server_plugin`):
  - `circuitry_duplicate_wire`: Detects duplicate wire keys `(Type, Enum?)` within `Circuit.build([...])` and `CircuitProvider(wires: [...])`.
  - `circuitry_missing_wire`: Validates that `.takes<T>()` and `.takesTagged<T, K>()` dependencies are provided in static wire lists, safely skipping lists with spread elements (`...wires`) or dynamic expressions.
  - `circuitry_prefer_trigger_wire`: Flags classes implementing `CircuitAction` registered via `Wire` or `AsyncWire` instead of `TriggerWire`.
  - `circuitry_avoid_async_in_wire`: Warns when synchronous `Wire` factories return a `Future<T>`.
