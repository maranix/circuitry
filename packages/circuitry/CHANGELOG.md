# Changelog

## 0.5.0

### Performance
- **Type-Indexed Fast-Path for Untagged Singletons**:
  - Maintained dedicated `_untaggedInstances` mapped directly by canonical Dart `Type` to eliminate runtime record tuple `(T, null)` allocations on every `circuit.get<T>()`.
  - Achieved ~78% lower lookup latency (from 126.6 ns down to 24.9–28.3 ns) and 4.5x higher throughput (>35M–40M ops/sec) with zero nursery heap allocations.
- **Single-Hash Assignment Lookups**:
  - Replaced double-hash traversals (`containsKey` + `[]`) with single-lookup assignment (`final cached = _instances[key]; if (cached != null) return cached;`) in runtime resolution and topological depth computation.
- **Reproducible Benchmark Suite**:
  - Added standalone benchmark suite in `benchmark/` covering monomorphic, polymorphic/interleaved retrieval, and DAG compilation with dead-code elimination protection and loop overhead calibration.

## 0.2.0

### Features
- **Ambient `CircuitRegistry` & DevTools Integration**:
  - Automatically tracks `Circuit` instances in debug mode (`assert(...)`), tracking status, wire resolution counts, and lifecycle events.
  - Exposes `registerVmServiceExtensions()` and `unregisterVmServiceExtensions()` for explicit Dart VM Service extension lifecycle control:
    - `ext.circuitry.getCircuits`: Lists all active circuits, descriptors, and metadata.
    - `ext.circuitry.getCircuitGraph`: Returns full graph schema, waves, wire details, dependencies, and resolution timings.
    - `ext.circuitry.forceResolveWire`: Triggers on-demand wire resolution across the VM Service protocol.
  - Streams real-time lifecycle events via `developer.postEvent('circuitry:lifecycle', ...)`.
  - Added optional `debugTag` identifier to `Circuit.build(wires, debugTag: '...')` for multi-circuit identification in DevTools.
  - Decoupled the 15 MB compiled DevTools extension web bundle into the opt-in `circuitry_devtools_extension` package, reducing `circuitry` package archive size to ~28 KB.
  - Zero-overhead in profile and release builds: assertions are disabled, `CircuitRegistry` methods and properties become no-ops, and telemetry call sites are fully tree-shaken by the compiler.
- **Core Introspection API & Exporters**:
  - Precomputes reverse dependency adjacency in `CircuitGraph.compile()` for instant O(1) direct and transitive queries.
  - Added `circuit.inspect()` returning an immutable `CircuitIntrospection` snapshot with `dependentsOf`, `dependenciesOf`, `transitiveDependentsOf`, `transitiveDependenciesOf`, and topological order queries.
  - Built-in visual diagram generation via `toMermaid()` producing valid Mermaid flowchart syntax with wave subgraphs and edge arrows.
  - Built-in structured JSON serialization via `toJson()` for exporting graph schemas.
  - Zero release overhead: 100% tree-shaken when unused in production code.
- **Fail-Fast Async Wave Resolution with Immediate Rollback**:
  - Parallel topological wave execution now uses `Future.wait` with `eagerError: true` to fail immediately upon the first encountered error instead of waiting for long-running concurrent sibling wires.
  - Enhanced lifecycle rollback safety: automatically tears down already resolved instances in reverse topological order, and disposes late-completing in-flight wires (`if (_isDisposed) await wire.disposeInstance(...)`) to prevent resource leaks and unhandled exceptions.
- **Modular DAG Compiler & Container Decomposition**:
  - Separated static graph validation and compilation (`CircuitGraph` in `src/graph.dart`) from runtime instance caching and lifecycle execution (`Circuit` in `src/circuit.dart`).
  - Extracted helper modules `src/utils.dart` and `src/extensions.dart`.
  - Migrated engine codebase to modern Dart 3.14+ primary and concise constructors, switch expressions, and contextual dot-shorthands.

## 0.1.0

Initial release of Circuitry: a pure Dart 3.14+ zero-codegen, Directed Acyclic Graph (DAG) based dependency injection engine.

### Features
- **Zero-Codegen & Reflection-Free**: Pure modern Dart without code generation, mirrors, or reflection.
- **Record Tuple Keys (`WireKey`)**: Strongly typed wire keys `(Type, Enum?)` supporting dot-shorthands (e.g. `tag: .prod`) and distinct registrations of the same generic Dart type.
- **Declarative Wires**:
  - `Wire<T>`: Synchronous, lazy singletons constructed on first access or when required by dependent wires.
  - `AsyncWire<T>`: Asynchronous singletons resolved during `Circuit.build(wires)` with lifecycle hooks (`onDispose`).
- **DAG Static Validation**: Pre-execution verification preventing invalid dependency graphs:
  - Detects duplicate wire keys (`DuplicateWireException`).
  - Identifies missing dependencies (`MissingWireException`).
  - Detects dependency cycles with exact cycle paths (`CircularDependencyException`).
- **Parallel Topological Wave Resolution**: Asynchronous singletons are resolved concurrently level-by-level using `Future.wait`, rolling back and disposing previously created instances if an error occurs during build.
- **Type-Safe Accumulator Chaining**: Fluent dependency declarations with `Wire.takes<A>()`, `Wire.takesTagged<B, K>(tag)`, `AsyncWire.takes<A>()`, and `AsyncWire.takesTagged<B, K>(tag)`. Supports constructor tear-offs (`.to(Service.new)`) and destructuring nested tuples for multiple dependencies.
- **Reverse Topological Wave Disposal**: Idempotent teardown in reverse dependency waves (`leaves -> roots`), awaiting parallel asynchronous `onDispose` hooks and aggregating failures into `DisposalException`.
