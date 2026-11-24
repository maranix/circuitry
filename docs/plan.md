# Plan

## Done this release

- Add Flutter companion enhancements: introduce `CircuitProvider.listener` for safe side effects on state transitions, and add `CircuitBuilder<T>` (with `.tagged()` constructor and `circuitTag` support) for localized leaf dependency reads.
- Overhaul DevTools extension performance: offload JSON deserialization and diagram/SVG exporters to background isolates (`compute()`), pre-compute and cache DAG layout geometry with zero-allocation Bézier splines, batch edge draw calls, scope fine-grained pane rebuilding with `RepaintBoundary`, and debounce search inputs.
- Optimize hot-path dependency retrieval with type-indexed fast-path and single-hash lookups, yielding 267%–332% higher throughput (>32M–34M ops/sec) and sub-32ns latency with reproducible benchmark suite in `benchmark/`.
- Decouple DevTools extension into standalone opt-in companion package `circuitry_devtools_extension` with explicit registration, reducing `circuitry` package archive size to ~28 KB.
- Add DevTools extension UI with interactive DAG canvas, wave waterfall, and wire inspector (#5).
- Add ambient CircuitRegistry, VM Service extensions, and DevTools packaging to circuitry (#11).
- Add core introspection API with reverse dependency queries and Mermaid/JSON export (#4).
- Fail fast on async wave resolution with immediate rollback (#9).
- Modularize Circuit and extract DAG compiler to CircuitGraph (#7).
- Optimize CI workflows for reduced GitHub compute.
- Add taggable CircuitProvider with O(1) ambient registry map merging (#1).
