# Changelog

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
