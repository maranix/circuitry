# Circuitry DevTools Extension

A dedicated Flutter Web DevTools extension UI for inspecting, profiling, and debugging Circuitry dependency injection graphs at runtime.

The compiled web assets are packaged directly into `packages/circuitry/extension/devtools/build/` for zero-configuration discovery by Dart DevTools.

---

## Features

- **Interactive DAG Canvas**: Renders dependency graphs organized into horizontal topological wave columns with cubic Bézier spline edge routing, wire node selection, and status badges.
- **Wave Waterfall Profiler**: Visualizes asynchronous startup resolution across topological waves, computing and highlighting the critical path with cumulative latency metrics.
- **Multi-Scope Circuit Navigator**: Switch between multiple active `Circuit` instances and tagged scopes registered in the ambient `CircuitRegistry`.
- **Live Wire Inspector**: Inspect wire configurations, dependencies, direct/transitive dependents, and trigger on-demand singleton initialization via VM Service protocol (`ext.circuitry.forceResolveWire`).
- **Multi-Format Exporters**: Export the graph schema directly to Mermaid flowchart diagrams, structured JSON, or SVG markup.

---

## Architecture & Seams

The DevTools UI is decoupled from the VM Service transport behind the abstract `CircuitryServiceClient` interface:

- `VmCircuitryServiceClient`: Communicates with live Dart VM Service extensions (`ext.circuitry.*`) in debug builds.
- `MockCircuitryServiceClient`: Provides deterministic mock graph data enabling 100% test coverage with `flutter test` without a running Dart VM Service daemon.

---

## Development & Building

### Running Tests

```bash
cd packages/circuitry_devtools_extension
flutter test
```

### Compiling Web Bundle

To compile and update the bundled extension inside `packages/circuitry`:

```bash
cd packages/circuitry_devtools_extension
dart run devtools_extensions build_and_copy --source=. --dest=../circuitry/extension/devtools
```

---

## License

MIT © [Raman Verma](https://github.com/maranix)
