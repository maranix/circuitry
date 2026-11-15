# Decisions

## 2026-11-15: Modular Package Decomposition and Dart 3.14+ Primary Constructors

- **Status:** agreed
- **Request:** Carry over and complete refactoring of Circuitry monorepo: decompose single-file package entry points into clean `lib/src/` modules, migrate constructors to Dart 3.14+ primary constructor syntax, and maintain strict static analysis and test integrity.
- **Scope:** Both `packages/circuitry` and `packages/circuitry_flutter` along with their test harnesses, root workspace configuration, and architectural documentation.
- **Choices:**
  - **Modular `src/` Layout & Library Encapsulation (`part` / `part of`):**
    - `packages/circuitry`: `lib/circuitry.dart` exports `src/circuit.dart` and `src/exceptions.dart`, where `src/circuit.dart` declares `part './wire.dart';`. This allows `Circuit` to directly invoke the library-private factory `_create` on `Wire` and `AsyncWire` without any unnecessary `createInstance` public redirection method, guaranteeing that internal entities remain private to the package.
    - `packages/circuitry_flutter`: `lib/circuitry_flutter.dart` exports `src/circuit_provider.dart` and `src/circuit_state.dart`. The internal implementation details (`_CircuitWireProvider`, `_CircuitValueProvider`, and `_CircuitScope`) are kept strictly private to `src/circuit_provider.dart`, eliminating unnecessary separate part files while exposing a clean public API (`CircuitProvider`, `CircuitStateWidgetBuilder`, `CircuitState`).
  - **Modern Concise & Primary Constructors:**
    - Adopt modern concise constructor declarations (`new(...)`, `new _(...)`, `static tag(...) => Wire<T>._(...)`) in `Wire`, `AsyncWire`, `WireBuilder`, `AsyncWireBuilder`, and `Circuit`.
    - Retain primary constructors (`final class const ...`, `sealed class const ...`) across exception hierarchies and test fixtures.
  - **Type Contracts for Closures & Callbacks:**
    - Explicit, documented typedefs for all functional boundaries: `WireFactory<T>` / `AsyncWireFactory<T>` for zero-dependency public wire creation, `WireBuilderFactory<T>` / `AsyncWireBuilderFactory<T>` for circuit-bound wire creation, `WireDependencyResolver<Acc>` for accumulator unpacking, and `WireDisposer<T>` for resource teardown.
  - **Workspace Naming:**
    - Preserve `name: circuitry_workspace` in root `pubspec.yaml` to comply with the `package_names` linter rule under `--fatal-infos`.

## 2026-11-15: Project Foundation and Monorepo Architecture for Circuitry

- **Status:** agreed
- **Request:** Scaffold a monorepo in `/Users/maranix/Developer/circuitry` housing two packages: `circuitry` (a pure Dart 3 zero-codegen, graph-based dependency injection engine backed by a Directed Acyclic Graph) and `circuitry_flutter` (Flutter bridge providing `InheritedWidget` scoping, reactive state matching, and async lifecycle management).
- **Scope:** Scaffold (complete monorepo workspace with root configuration, pure Dart `circuitry` package, Flutter `circuitry_flutter` companion package, comprehensive unit/widget test harnesses, automated CI workflow, accessibility/lifecycle testing, and project documentation).
- **Choices:**
  - **Stack & Toolchain:** Dart 3.13+ / Flutter 3.24+ (running on Flutter 3.50.0 / Dart 3.14.0 stable). Native Dart pub workspace with `resolution: workspace` managing inter-package linking.
  - **Monorepo Split:**
    - `packages/circuitry`: Pure Dart core dependency injection engine. Zero Flutter SDK dependencies, enabling use in CLI tools, backend servers, Dart Frog, Shelf, web, and mobile.
    - `packages/circuitry_flutter`: Flutter bridge package depending on `circuitry` and `flutter` SDK. Re-exports `package:circuitry/circuitry.dart` and adds `CircuitProvider`, `CircuitState`, `_CircuitScope`, and widget tree lifecycle hooks.
  - **Package Identities:**
    - Root Workspace: `circuitry_workspace` (`publish_to: 'none'`)
    - Core Package: `circuitry` (v0.1.0)
    - Flutter Bridge: `circuitry_flutter` (v0.1.0)
    - Organization / GitHub: `maranix/circuitry`
  - **License:** MIT License, Copyright (c) 2026 Raman Verma.
  - **Code Quality & Linter:** Strict static analysis via `lints` for pure Dart and `flutter_lints` for Flutter, with `--fatal-infos --fatal-warnings` enforced in CI.
  - **Agent Instructions:** Included (`AGENTS.md` at repository root).
  - **README Outline:**
    - Project Overview & Core Philosophy
    - Key Features (DAG validation, parallel wave resolution, reverse topological disposal, type-safe accumulator chaining, dot-shorthand tagged singletons)
    - Monorepo Package Layout (`circuitry` and `circuitry_flutter`)
    - Installation & Quickstart for Pure Dart and Flutter
    - Verification & Testing commands
    - License notice

### Architecture Sketch

Circuitry is architected as an offline, zero-codegen runtime dependency graph compiler. `packages/circuitry` defines declarative dependency recipes (`Wire<T>`, `AsyncWire<T>`), record tuple keys `(Type, Enum?)`, and accumulator builders (`takes<A>().to(...)`), validated and compiled by `Circuit.build(wires)` into a Directed Acyclic Graph (DAG) with parallel topological wave resolution and reverse-wave disposal. `packages/circuitry_flutter` bridges this compiled container to the Flutter widget hierarchy via `CircuitProvider`, managing asynchronous build lifecycles, didUpdateWidget epoch race prevention, and unmount cleanup. For full architectural details, see [architecture.md](architecture.md).
