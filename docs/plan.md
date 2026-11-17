# Plan

## Next

### Core Diagnostics & Introspection API (#4)

- **Goal:** Provide compile-time reverse dependency querying, immutable introspection, and graph export (Mermaid/JSON) for `Circuit`.
- **Requirements:**
  - Precompute reverse adjacency (`dependentsOf`) and upstream queries (`dependenciesOf`) directly in `CircuitGraph`.
  - Expose `circuit.inspect()` returning `CircuitIntrospection` snapshot with `WireDescriptor` (`isAsync`, `isInitialized`, `topologicalLevel`), `waves`, and `topologicalOrder`.
  - Implement zero-overhead, tree-shakeable graph exporters (`toMermaid`, `toJson`) with zero external dependencies.
- **Approach:** Precompute reverse index during `CircuitGraph.compile()`, encapsulate inspection models in `src/introspection.dart`, and expose `circuit.inspect()`.
- **Sub-steps:**
  - [x] 1. Reverse adjacency indexing and direct/transitive dependency queries in `CircuitGraph`.
  - [x] 2. Introspection models (`WireDescriptor`), `CircuitIntrospection` snapshot contract, and `circuit.inspect()`.
  - [ ] 3. Diagram exporter (`toMermaid`) and structured JSON serialization (`toJson`).
- **Acceptance:** Full unit test suite covering reverse dependencies, transitive queries, introspection snapshots, and Mermaid/JSON exports with zero memory overhead and clean analysis.

### Publish v0.1.0 to pub.dev

- **Release:** 0.1.0
- **Goal:** Publish initial stable releases of `circuitry` and `circuitry_flutter` to pub.dev.
- **Requirements:**
  - Verify package validation passes with zero warnings (`dart pub publish --dry-run`).
  - Tag release commits matching versions in pubspec.yaml.
- **Approach:** Run dry-run checks in both packages, create git tag `v0.1.0`, and publish.
- **Acceptance:** Both packages published and verified on pub.dev.

## Done this release

- Fail fast on async wave resolution with immediate rollback (#9).
- Modularize Circuit and extract DAG compiler to CircuitGraph (#7).
- Optimize CI workflows for reduced GitHub compute.
- Add taggable CircuitProvider with O(1) ambient registry map merging (#1).
- Add package examples, visual architecture diagrams, and pub.dev metadata.
