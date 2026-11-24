# Changelog

## 0.5.0

### Performance
- **Background Isolate Offloading**:
  - Offloaded `getCircuitGraph` JSON deserialization to a background isolate using Flutter foundation `compute()`, preventing UI frame drops during large graph payload ingestion.
  - Offloaded export formatting (Mermaid, formatted JSON, SVG markup) to background isolates via `compute()`.
- **DAG Canvas Rendering Engine Overhaul**:
  - Pre-computed and cached `_DagCanvasLayout` geometry (node coordinates, spline coordinates, and composite edge paths).
  - Eliminated runtime allocations of `Path` and `Paint` during interactive pan and zoom gestures (60/120 FPS rendering).
  - Batched edge draw calls: unselected DAG edges render via a single composite `canvas.drawPath` call; selected DAGs batch dimmed edges into a single path.
  - Wrapped `CustomPaint` and `InteractiveViewer` in `RepaintBoundary` to prevent canvas repainting during external UI changes.
- **Fine-Grained UI Partitioning**:
  - Removed monolithic `ListenableBuilder` wrapping the entire `Scaffold`.
  - Scoped controllers and wrapped each split pane (`CircuitNavigator`, `DevToolsAreaPane`, `WireDetailDrawer`, and `DevToolsToolbar`) with isolated `RepaintBoundary` layers.
- **Debounced Search & Filtering**:
  - Added a 150ms debounce on search queries to eliminate layout recalculation and filtering churn on every keystroke.
- **Serialization Model Updates**:
  - Added `CircuitGraphData.toJson()` to support structured cloning and reliable cross-isolate serialization.

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
