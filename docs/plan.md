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
- [x] Refactor Monorepo to Modular `src/` Architecture and Dart 3.14+ Primary Constructors
  - Requirements:
    - Modularize `packages/circuitry/lib/` into separate domain units under `lib/src/` (`exceptions.dart`, `wire.dart`, `circuit.dart`) and expose them via public barrel file `lib/circuitry.dart`.
    - Modularize `packages/circuitry_flutter/lib/` into separate units under `lib/src/` (`circuit_state.dart`, `circuit_provider.dart` with internal `_CircuitScope`) and expose via public barrel file `lib/circuitry_flutter.dart`.
    - Eliminate redundant type aliases and remove unnecessary public `createInstance` redirection methods by leveraging library-level `part of` encapsulation so `Circuit` accesses `_create` directly without exposing internal details to package consumers.
    - Introduce strongly typed and documented functional contracts (`WireFactory`, `AsyncWireFactory`, `WireBuilderFactory`, `AsyncWireBuilderFactory`, `WireDependencyResolver`, `WireDisposer`).
    - Refactor classes across production code and test suites (`wire_test.dart`, `circuit_test.dart`, `circuit_provider_test.dart`) to use Dart 3.14+ primary constructors and concise constructor syntax.
    - Preserve `name: circuitry_workspace` in root `pubspec.yaml` to satisfy `package_names` linter rules.
    - Synchronize project documentation (`docs/decisions.md`, `docs/architecture.md`, `README.md`).
    - Verify with `dart format`, `flutter analyze --fatal-infos --fatal-warnings`, and all tests passing.
  - Sub-steps:
    - [x] Update `docs/decisions.md` with architectural decision on modularization, encapsulation, and primary constructors.
    - [x] Add modular `src/` structure and barrel exports to `packages/circuitry/lib/circuitry.dart` and `packages/circuitry_flutter/lib/circuitry_flutter.dart`.
    - [x] Eliminate `createInstance` and keep wire creation private to the library using `part of`.
    - [x] Define typed functional contracts (`WireFactory`, `AsyncWireFactory`, `WireBuilderFactory`, `AsyncWireBuilderFactory`, `WireDependencyResolver`, `WireDisposer`) with dartdoc.
    - [x] Restore valid workspace package name `circuitry_workspace` in root `pubspec.yaml`.
    - [x] Migrate test mock/helper classes in `packages/circuitry/test/wire_test.dart`, `circuit_test.dart`, and `circuit_provider_test.dart` to concise/primary constructor syntax.
    - [x] Update `docs/architecture.md` and `README.md` to reflect the new `src/` file tree and constructor syntax.
    - [x] Run full verification gate (`dart format`, `flutter analyze --fatal-infos --fatal-warnings`, test suites).

## Next
- [ ] Publish v0.1.0 to pub.dev
