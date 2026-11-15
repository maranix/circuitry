# Plan

## Done
- [x] Scaffold Circuitry Monorepo (`circuitry` and `circuitry_flutter`)
  - Requirements:
    - Configure root pub workspace in `/Users/maranix/Developer/circuitry/pubspec.yaml` with packages `circuitry` and `circuitry_flutter`.
    - Create `packages/circuitry` as a pure Dart package with zero Flutter dependencies, housing `WireKey`, `CircuitWire`, `Wire<T>`, `AsyncWire<T>`, `WireBuilder`, `AsyncWireBuilder`, `CircuitException` hierarchy, and `Circuit` DAG container.
    - Create `packages/circuitry_flutter` as a Flutter bridge package depending on `circuitry` and Flutter SDK, housing `CircuitState` sealed hierarchy, `CircuitProvider` (`CircuitWireProvider`, `CircuitValueProvider`), `_CircuitScope`, and re-exporting `package:circuitry/circuitry.dart`.
    - Create comprehensive test suites across both packages (pure Dart unit tests in `circuitry/test/`, Flutter widget & lifecycle tests in `circuitry_flutter/test/`).
    - Setup strict linting (`analysis_options.yaml`) and GitHub Actions CI workflow (`.github/workflows/ci.yml`).
    - Provide complete project documentation (`README.md`, package READMEs, `docs/architecture.md`, `docs/decisions.md`, `AGENTS.md`).
    - Verify with `dart format`, `flutter analyze --fatal-infos --fatal-warnings`, and all tests passing.
  - Sub-steps:
    - [x] Record decisions in `docs/decisions.md`.
    - [x] Create root `pubspec.yaml`, `analysis_options.yaml`, and workspace structure.
    - [x] Implement `packages/circuitry` (pure Dart library, exceptions, wires, DAG compiler).
    - [x] Port pure Dart tests to `packages/circuitry/test/` (wire tests, circuit tests - 46 tests).
    - [x] Implement `packages/circuitry_flutter` (Flutter bridge widgets and state matching).
    - [x] Port Flutter tests to `packages/circuitry_flutter/test/` (21 tests).
    - [x] Run `flutter pub get` and verify compilation across workspace.
    - [x] Add GitHub Actions CI workflow.
    - [x] Complete `README.md`, `docs/architecture.md`, and `AGENTS.md`.
    - [x] Run full verification gate (`dart format`, `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`).

## Next
- [ ] Publish v0.1.0 to pub.dev
