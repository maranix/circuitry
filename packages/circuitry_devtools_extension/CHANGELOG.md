# Changelog

## 0.2.0

Initial public release of Circuitry DevTools Extension as a standalone opt-in companion tool.

### Features
- **Standalone Companion Package**: Opt-in developer tool added to `dev_dependencies` without bloating runtime app bundles.
- **Explicit Registration API**:
  - `registerCircuitryDevToolsExtension()` enables Dart VM Service extensions (`ext.circuitry.*`) and live telemetry streaming.
  - `unregisterCircuitryDevToolsExtension()` disables extensions and silences telemetry.
  - `CircuitryDevTools.register()` and `CircuitryDevTools.unregister()` static namespace accessors.
- **Interactive DAG Canvas**: Visualizes topological wave columns with cubic Bézier spline edge routing, wire node selection, and status badges.
- **Wave Waterfall Profiler**: Visualizes startup wave resolution timeline, critical path analysis, and cumulative latency metrics.
- **Multi-Scope Circuit Navigator**: Switch between multiple active `Circuit` instances and tagged scopes.
- **Live Wire Inspector**: Inspect wire configurations, dependencies, direct/transitive dependents, and trigger on-demand singleton initialization via `ext.circuitry.forceResolveWire`.
- **Multi-Format Exporters**: Export graphs to Mermaid flowchart diagrams, structured JSON, or SVG markup.
