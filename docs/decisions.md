# Decisions

## 2026-11-17: Modular DAG Compiler and Container Decomposition (Issue #7)

- **Status:** agreed
- **Request:** Resolve [Issue #7: Decompose monolithic Circuit class into CircuitGraph and runtime container](https://github.com/maranix/circuitry/issues/7). Make `packages/circuitry/lib/src/circuit.dart` modular, maintainable, and easy to reason about by decoupling static DAG compilation and validation from runtime instance management and lifecycle execution.
- **Scope:** `packages/circuitry/lib/src/`, architectural documentation, and project plans.
- **Choices:**
  - **Decoupled `CircuitGraph` Compiler (`packages/circuitry/lib/src/graph.dart`):**
    - Encapsulates static DAG compilation into `CircuitGraph.compile(List<CircuitWire> wires)`.
    - Houses all graph theory validation algorithms: duplicate detection (`_validateNoDuplicates`), missing dependency verification (`_validateDependencies`), and depth-first search (DFS) cycle detection (`_detectCycles`).
    - Computes topological levels and precomputes wave buckets (`_wiresByLevel`, `_asyncWiresByLevel`) for O(1) wave execution access during build and disposal.
  - **Focused `Circuit` Container (`packages/circuitry/lib/src/circuit.dart`):**
    - Streamlined from 297 lines to ~140 lines of focused container and lifecycle logic.
    - Symmetrical wave lifecycles: forward async waves ($0 \rightarrow \text{maxLevel}$) during `build` and reverse disposal waves ($\text{maxLevel} \rightarrow 0$) during `dispose`.
    - Encapsulates instance memoization (`_instances`) and reentrancy protection (`_creating`) for lazy synchronous retrieval (`get`, `getTagged`).
  - **Centralized `WireKey` Formatting (`packages/circuitry/lib/src/wire.dart`):**
    - Unifies record tuple key string representation via `formatWireKey(WireKey key)` and extension `WireKeyFormatting on WireKey`.
  - **Zero Breaking Changes:**
    - All public API contracts (`Circuit.build`, `circuit.get`, `circuit.getTagged`, `circuit.dispose`, `circuit.isInitialized`) remain identical and backward-compatible.
    - `CircuitGraph` is internal to `packages/circuitry/lib/src/` to avoid polluting the public barrel export.

## 2026-11-16: Compute-Optimized CI Workflows

- **Status:** agreed
- **Request:** Decrease GitHub compute load by eliminating automatic CI runs on arbitrary PR push events. Merging to `main` should run all lint, format, and test workflows. For PRs, workflows must be manually invoked before merging or run automatically only when the PR is approved.
- **Scope:** `.github/workflows/ci.yml` and repository automation documentation.
- **Choices:**
  - **Main Branch Execution**:
    - Retain `push: branches: [ main ]` to automatically run all format, lint, and test steps when code is merged into `main`.
  - **PR Gating & Approval Trigger**:
    - Remove automatic `pull_request` push/synchronize triggers.
    - Add `pull_request_review: types: [ submitted ]` trigger guarded by `if: github.event.review.state == 'approved' && github.event.pull_request.base.ref == 'main'` to run CI only when an approval review is submitted.
    - Check out the PR head SHA via `ref: ${{ github.event.pull_request.head.sha || github.ref }}` so tests evaluate the exact reviewed commit.
  - **Manual Dispatch**:
    - Add `workflow_dispatch` to allow maintainers to manually run CI for any PR branch on demand via the GitHub Actions UI or `gh workflow run`.

## 2026-11-16: Taggable CircuitProvider with O(1) Ambient Registry Map Merging (Issue #1)

- **Status:** agreed
- **Request:** Resolve [Issue #1: Circuit should be tag-able like Wire](https://github.com/maranix/circuitry/issues/1). When `CircuitProvider` widgets are nested (e.g., `GlobalCircuitProvider` -> `FooApp` -> `BarCircuitProvider` -> `BarFeature`), descendants in `BarFeature` need to access tagged ancestor circuits (e.g. `GlobalCircuit`).
- **Scope:** `packages/circuitry_flutter`, project documentation, and widget test suites. Core engine `packages/circuitry` remains untouched.
- **Choices:**
  - **Core Independence**: Pure Dart `Circuit` instances remain completely decoupled, independent containers without any cross-circuit parenting or graph merging in `packages/circuitry`.
  - **Flutter Scoped Ambient Registry**:
    - Add `Enum? tag` parameter to `CircuitProvider` and `CircuitProvider.value`.
    - `_CircuitScope` maintains an ambient `Map<Enum, Circuit> taggedCircuits`.
    - When a `_CircuitScope` is created, it merges its own `?tag: circuit` into an immutable copy (`Map.unmodifiable`) of its ancestor's `taggedCircuits`, reusing parent maps directly without allocation when `tag` is omitted.
    - When `_CircuitWireStatefulState` is in `CircuitBuilding` or `CircuitFailure`, it mounts `_CircuitScope` with `circuit: null` and inherits `taggedCircuits`. This intercepts untagged `of`/`maybeOf` calls in nested scopes, preventing accidental leakage of outer ancestor circuits while preserving access to ready ancestor tagged circuits in O(1).
  - **True O(1) Context Retrieval**:
    - Flutter's `context.dependOnInheritedWidgetOfExactType<_CircuitScope>()` performs a single hash map lookup on `Element._inheritedElements` in **O(1)**.
    - `CircuitProvider.of(context)` returns `scope.circuit` (nearest circuit) in **O(1)**.
    - `CircuitProvider.of(context, tag: tag)` looks up `scope.taggedCircuits[tag]` in **O(1)**, throwing a descriptive `StateError` if not found.
    - Avoids any O(N) tree-walking or `visitAncestorElements`.
  - **Lexical Shadowing & Sibling Isolation**:
    - Nearer ancestor providers registering the same tag shadow outer ancestors in the merged map.
    - Sibling subtrees maintain isolated registries without leaking into each other.
  - **Clean Public API**:
    - Only `CircuitProvider.of(context, {Enum? tag})` and `CircuitProvider.maybeOf(context, {Enum? tag})`. No auxiliary helper methods (such as `.tagged(...)`) polluting the public surface.

## 2026-11-15: Package Examples and Visual Architecture Diagram Asset

- **Status:** agreed
- **Request:** Add runnable examples for each package (`circuitry` and `circuitry_flutter`) to satisfy pub.dev scoring requirements, and provide a visual representation of how Circuitry works reusable across all READMEs as an asset.
- **Scope:** `packages/circuitry/example/`, `packages/circuitry_flutter/example/`, `assets/`, `docs/architecture.md`, and all package READMEs.
- **Choices:**
  - **Pure Dart Example (`packages/circuitry/example/main.dart`):**
    - Standalone runnable `example/main.dart` demonstrating tagged wires, asynchronous connection with `onDispose` hooks, constructor tear-offs, and multi-dependency `.takes<A>().takes<B>()` chaining.
  - **Flutter Example App (`packages/circuitry_flutter/example/`):**
    - Complete Flutter example with `example/pubspec.yaml` and `example/lib/main.dart` showcasing `CircuitProvider`, `CircuitState` pattern matching (`CircuitBuilding`, `CircuitReady`, `CircuitFailure`), and scoped context retrieval with `CircuitProvider.of(context)`.
    - Linked to root `pubspec.yaml` workspace with `resolution: workspace`.
  - **Visual Diagram Asset & Reusability (`assets/circuitry_architecture.png` & `.svg`):**
    - High-resolution SVG and 1600px Retina PNG asset generated in `assets/circuitry_architecture.png` and `assets/circuitry_architecture.svg` illustrating declarative wires, DAG validation, parallel topological waves, runtime container, and Flutter bridge.
    - Referenced across root `README.md`, `packages/circuitry/README.md`, and `packages/circuitry_flutter/README.md` via GitHub raw URL so images render correctly on both GitHub and pub.dev without broken relative subfolder paths.
    - Embedded accompanying Mermaid flowchart in `docs/architecture.md`.

## 2026-11-15: Metadata and Topics Configuration for pub.dev Discovery

- **Status:** agreed
- **Request:** Update `pubspec.yaml` with appropriate repository details (`homepage`, `repository`, `issue_tracker`) with package-specific issue labels, discovery topics, `CHANGELOG.md` files, and package-level `LICENSE` files for pub.dev across both packages using `github.com/maranix/circuitry`.
- **Scope:** `packages/circuitry`, `packages/circuitry_flutter`, root workspace configuration, and project documentation.
- **Choices:**
  - **Repository & Issue Tracker URLs:**
    - `homepage`: `https://github.com/maranix/circuitry` (unified landing repository).
    - `repository`: Deep-linked to respective monorepo tree paths (`https://github.com/maranix/circuitry/tree/main/packages/circuitry` and `https://github.com/maranix/circuitry/tree/main/packages/circuitry_flutter`), following pub.dev best practices for monorepo packages so directory links accurately land on package sources.
    - `issue_tracker`: Filtered with package-specific labels so users and maintainers directly see package-scoped issues:
      - `packages/circuitry`: `https://github.com/maranix/circuitry/issues?q=is%3Aissue+is%3Aopen+label%3Acircuitry`
      - `packages/circuitry_flutter`: `https://github.com/maranix/circuitry/issues?q=is%3Aissue+is%3Aopen+label%3Acircuitry_flutter`
  - **Discovery Topics (Maximum 5 per Package):**
    - `packages/circuitry`: `dependency-injection`, `di`, `ioc`, `dag`, `architecture`.
    - `packages/circuitry_flutter`: `dependency-injection`, `di`, `ioc`, `flutter`, `state-management`.
  - **Changelog & Licensing:**
    - Standard `CHANGELOG.md` files created in `packages/circuitry/`, `packages/circuitry_flutter/`, and repository root documenting v0.1.0 initial features.
    - Root MIT `LICENSE` copied into `packages/circuitry/LICENSE` and `packages/circuitry_flutter/LICENSE` to satisfy pub.dev package publishing validation.
  - **Package Descriptions:**
    - Refined `circuitry_flutter` description to 122 characters without trailing whitespace, staying within pub.dev's optimal 60–180 character threshold.

## 2026-11-15: Elimination of `part` / `part of` in Core Engine and Introduction of `wire.connect(circuit)`

- **Status:** agreed
- **Request:** Eliminate `part` and `part of` directives across `packages/circuitry`, converting `circuit.dart`, `wire.dart`, and `exceptions.dart` into independent libraries. Avoid `FutureOr` on base `CircuitWire`; use pattern matching on the sealed `CircuitWire` hierarchy in `Circuit` and rename the method to `wire.connect(circuit)` to represent connecting a wire to the circuit.
- **Scope:** `packages/circuitry` module architecture and public contract.
- **Choices:**
  - **Modular Independent Libraries:**
    - `packages/circuitry/lib/circuitry.dart` exports `src/circuit.dart`, `src/exceptions.dart`, and `src/wire.dart` (hiding internal builder classes and internal typedefs).
    - `packages/circuitry/lib/src/circuit.dart`, `wire.dart`, and `exceptions.dart` use standard package imports (`import 'package:circuitry/src/...'`) without `part` / `part of` directives, mirroring the modular architecture of `circuitry_flutter`.
  - **Exhaustive Sealed Pattern Matching & `connect(Circuit circuit)` Method:**
    - `CircuitWire` base class does not define `connect` (eliminating unnecessary `FutureOr` abstraction).
    - `Wire<T>` defines synchronous `T connect(Circuit circuit) => _create(circuit);`.
    - `AsyncWire<T>` defines asynchronous `Future<T> connect(Circuit circuit) => _create(circuit);`.
    - In `Circuit._getByKey`, exhaustive pattern matching with `switch (wire)` promotes `wire` to `Wire<Object?>` to directly call synchronous `wire.connect(this)` without type casts or `is!` checks.
    - In `Circuit.build`, `asyncWiresAtLevel` directly invokes `await wire.connect(circuit)`.

## 2026-11-15: Encapsulation of Intermediate Builders and Internal Factories

- **Status:** agreed
- **Request:** Hide `WireBuilder` and `AsyncWireBuilder` from the public API and package export surface since they are intermediate fluent builders used internally for accumulator chaining.
- **Scope:** `packages/circuitry` public barrel export (`lib/circuitry.dart`) and associated architectural documents.
- **Choices:**
  - **Hide Intermediate Builders from Barrel Export:**
    - `packages/circuitry/lib/circuitry.dart` exports `src/circuit.dart hide AsyncWireBuilder, AsyncWireBuilderFactory, WireBuilder, WireBuilderFactory, WireDependencyResolver;`.
    - `WireBuilder` and `AsyncWireBuilder` remain public classes in `lib/src/wire.dart` to avoid triggering Dart's `library_private_types_in_public_api` lint on the public `Wire.takes` / `AsyncWire.takes` return types.
    - By hiding them from the package export, consumers cannot mistakenly reference or attempt to instantiate `WireBuilder` or `AsyncWireBuilder` directly, and IDE auto-completion will not pollute consumer namespaces with intermediate builder types or internal factory typedefs.

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
