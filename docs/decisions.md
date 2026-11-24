# Decisions

## 2026-11-15: Monorepo Foundation and Platform Architecture

- **Status:** agreed
- **Choice:** Scaffold a native Dart pub workspace containing pure Dart `packages/circuitry` and Flutter companion `packages/circuitry_flutter`.
- **Reason:** Keeps the core graph DI engine platform-agnostic (CLI, server, web) while giving Flutter apps native lifecycle integration.
- **Alternative:** Single monolithic Flutter-dependent package or codegen-based DI (`build_runner`).

## 2026-11-15: Modular Package Decomposition and Modern Constructors

- **Status:** agreed
- **Choice:** Decompose package implementations into modular `lib/src/` units with barrel exports, adopting Dart 3.14+ concise and primary constructors (intermediate `part` directives superseded by the subsequent `connect(circuit)` decision).
- **Reason:** Isolates domain responsibilities and leverages modern Dart constructor syntax without boilerplate.
- **Alternative:** Flat single-file library structure or legacy verbose constructor syntax.

## 2026-11-15: Encapsulation of Intermediate Builders and Internal Factories

- **Status:** agreed
- **Choice:** Hide `WireBuilder`, `AsyncWireBuilder`, and internal factory typedefs from the `lib/circuitry.dart` barrel export.
- **Reason:** Keeps intermediate accumulator chaining types out of the public API while keeping classes public in `src/wire.dart` to satisfy Dart lint rules.
- **Alternative:** Exposing builder classes publicly or making them library-private and triggering linter warnings.

## 2026-11-15: Elimination of part / part of and Introduction of wire.connect(circuit)

- **Status:** agreed
- **Choice:** Use independent modular libraries with package imports and define typed `connect(Circuit circuit)` on `Wire<T>` and `AsyncWire<T>`.
- **Reason:** Eliminates brittle `part` directives, removes `FutureOr` from base wire, and enables exhaustive pattern matching in `Circuit`.
- **Alternative:** Retaining `part` files or using generic `FutureOr` on base `CircuitWire`.

## 2026-11-15: Package Metadata and Discovery Topics

- **Status:** agreed
- **Choice:** Configure pubspec metadata with deep tree links, issue tracker labels, and discovery topics.
- **Reason:** Maximizes pub.dev discoverability and score compliance for monorepo packages.
- **Alternative:** Generic repository links without package-scoped issue routing.

## 2026-11-15: Package Examples and Visual Architecture Assets

- **Status:** agreed
- **Choice:** Add standalone runnable examples in each package and maintain visual SVG and PNG architecture diagrams in `assets/`.
- **Reason:** Meets pub.dev score criteria and provides clear visual documentation across READMEs.
- **Alternative:** In-repo code snippets only without runnable standalone apps.

## 2026-11-16: Taggable CircuitProvider with O(1) Ambient Registry Map Merging (Issue #1)

- **Status:** agreed
- **Choice:** Propagate `Map<Enum, Circuit> taggedCircuits` in `_CircuitScope` via shallow map merging, accessed with `CircuitProvider.of(context, tag: ...)`.
- **Reason:** Provides true O(1) ancestor container access in nested hierarchies without widget tree traversal.
- **Alternative:** Tree-walking (`visitAncestorElements`) or merging graphs inside core pure Dart engine.

## 2026-11-16: Compute-Optimized CI Workflows

- **Status:** agreed
- **Choice:** Restrict automated PR CI runs to review approval events (`pull_request_review: types: [submitted]`) and `workflow_dispatch`, while keeping automated runs on `push: branches: [main]`.
- **Reason:** Prevents redundant compute runs on draft or intermediate PR pushes while ensuring merged code is fully verified.
- **Alternative:** Running complete CI matrix on every commit push across all PR branches.

## 2026-11-17: Modular DAG Compiler and Container Decomposition (Issue #7)

- **Status:** agreed
- **Choice:** Extract DAG compilation and static validation into `CircuitGraph` in `src/graph.dart`, keeping `Circuit` in `src/circuit.dart` focused on runtime instance management and lifecycle execution.
- **Reason:** Separates static graph analysis from runtime instance caching and wave execution, enabling isolated testing of graph validation.
- **Alternative:** Keeping all graph compilation and container logic in a single monolithic `Circuit` class.

## 2026-11-17: Fail-Fast AsyncWave Resolution with Immediate Rollback

- **Status:** agreed
- **Choice:** Configure `Future.wait` during async wave resolution with `eagerError: true` and guarded post-completion lifecycle teardown for late-completing in-flight wires (`if (_isDisposed) await wire.disposeInstance(instance)`).
- **Reason:** Prevents circuit initialization from stalling on slow or hanging concurrent async operations when another wire in the same wave has already failed, while maintaining strict leak-free instance disposal.
- **Alternative:** Default `eagerError: false` waiting for all futures in the wave to complete before teardown and error propagation.

## 2026-11-17: On-Demand Introspection and Compile-Time Reverse Adjacency (Issue #4)

- **Status:** agreed
- **Choice:** Precompute `reverseDependencies` in `CircuitGraph.compile()` and expose on-demand immutable snapshots via `circuit.inspect()` (`CircuitIntrospection`) without storing extra diagnostic fields in `Circuit`.
- **Reason:** Enables instant O(1) direct dependent queries and tree-shakes 100% of introspection and export logic in production builds where `inspect()` is unused.
- **Alternative:** Storing live mutable telemetry state, Stopwatches, or observers inside `Circuit`, which incurs memory and GC overhead in release builds.

## 2026-11-17: Ambient CircuitRegistry and VM Service Extension Endpoints (Issue #11)

- **Status:** agreed
- **Choice:** Maintain ambient `CircuitRegistry` and VM Service extension handlers (`ext.circuitry.*`) in pure Dart `packages/circuitry`, disabled by default and activated explicitly via `registerVmServiceExtensions()`. In profile and release modes or when disabled, `CircuitRegistry` methods and properties are complete no-ops, with VM service extensions omitted and telemetry calls tree-shaken by the compiler for zero memory and runtime overhead.
- **Reason:** Provides pure Dart VM Service inspection endpoints across all runtimes without adding Flutter SDK dependencies or web build bloat to `circuitry`.
- **Alternative:** Automatic registration on `Circuit.build`, which binds extension handlers unconditionally.

## 2026-11-17: Standalone Opt-In Companion DevTools Extension Package (Issue #5)

- **Status:** agreed
- **Choice:** Package and publish the DevTools Extension as an independent companion package in `packages/circuitry_devtools_extension`, containing the extension UI, `extension/devtools/` configuration, pre-built web bundle, and public registration/deregistration methods (`registerCircuitryDevToolsExtension`, `unregisterCircuitryDevToolsExtension`). Users opt into DevTools inspection by adding `circuitry_devtools_extension` to `dev_dependencies` and calling `registerCircuitryDevToolsExtension()`.
- **Reason:** Keeps `circuitry` (~28 KB) and `circuitry_flutter` (~25 KB) ultra-lightweight runtime dependencies without forcing users to download the ~15 MB compiled web bundle. Only developers who explicitly add the extension to `dev_dependencies` download the DevTools assets, which DevTools discovers automatically from `package_config.json`.
- **Alternative:** Bundling the precompiled web assets inside `packages/circuitry` (superseded, forced a 15 MB archive on all users) or `packages/circuitry_flutter`.

## 2026-11-24: Type-Indexed Fast-Path and Single-Hash Hot-Path Retrieval

- **Status:** agreed
- **Choice:** Maintain an internal `Map<Type, Object?> _untaggedInstances` fast-path cache alongside `_instances`, and adopt single-hash lookup assignment (`final cached = _instances[key]; if (cached != null) return cached;`).
- **Reason:** Eliminates record tuple allocations `(T, null)` on every `circuit.get<T>()` read and avoids double-hash traversals (`containsKey` + `[]`). Benchmarks proved a 267%–332% throughput improvement (from 7.9M ops/sec to 32.1M–34.1M ops/sec) and reduced lookup latency from 126 ns down to 29–31 ns with zero API breaking changes.
- **Alternative:** Rewriting DAG compilation wave bucketing into a manual bucket loop was rejected after empirical benchmarking revealed it added list allocation overhead and was up to 25% slower on small graphs (10–35 nodes) compared to Dart's optimized iterable filtering.

### Architecture Sketch

Circuitry is architected as an offline, zero-codegen runtime dependency graph compiler. `packages/circuitry` defines declarative dependency recipes (`Wire<T>`, `AsyncWire<T>`), record tuple keys `(Type, Enum?)`, and accumulator builders (`takes<A>().to(...)`), validated and compiled by `Circuit.build(wires)` into a Directed Acyclic Graph (DAG) with parallel topological wave resolution and reverse-wave disposal. `packages/circuitry_flutter` bridges this compiled container to the Flutter widget hierarchy via `CircuitProvider`, managing asynchronous build lifecycles, didUpdateWidget epoch race prevention, and unmount cleanup. For full architectural details, see [architecture.md](architecture.md).
