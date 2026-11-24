# Plan

## Next

### Publish v0.5.0 to pub.dev

- **Release:** 0.5.0
- **Goal:** Publish v0.5.0 releases of `circuitry`, `circuitry_flutter`, and `circuitry_devtools_extension` to pub.dev.
- **Requirements:**
  - Verify package validation passes with zero warnings (`dart pub publish --dry-run`).
  - Tag release commits matching versions in pubspec.yaml (`v0.5.0`).
- **Approach:** Run dry-run checks in all three packages, create git tag `v0.5.0`, and publish.
- **Acceptance:** All packages published and verified on pub.dev.

## Done this release

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
