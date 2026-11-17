# Plan

## Next

### Fail-Fast AsyncWave Resolution

- **Goal:** Enable fail-fast resolution during topological async waves in `Circuit.build`.
- **Requirements:**
  - Resolve async waves with `Future.wait(..., eagerError: true)` so wave resolution immediately fails upon the first rejected `AsyncWire` instead of waiting for all in-flight wires in that wave to finish.
  - Immediately perform reverse topological rollback and disposal of initialized instances on failure before rethrowing.
  - Handle late-completing in-flight async wires safely: if the container is already disposed, invoke their `onDispose` lifecycle hooks and discard instances without polluting `_instances`.
  - Add comprehensive unit tests verifying that failure aborts eagerly without waiting for uncompleted futures and cleans up initialized singletons.
- **Approach:** Update `_resolveAsyncWaves` in `packages/circuitry/lib/src/circuit.dart` to specify `eagerError: true` and add post-completion disposal guard for in-flight wires.
- **Acceptance:** Tests pass confirming immediate error propagation and instance cleanup on wave failure.

### Publish v0.1.0 to pub.dev

- **Release:** 0.1.0
- **Goal:** Publish initial stable releases of `circuitry` and `circuitry_flutter` to pub.dev.
- **Requirements:**
  - Verify package validation passes with zero warnings (`dart pub publish --dry-run`).
  - Tag release commits matching versions in pubspec.yaml.
- **Approach:** Run dry-run checks in both packages, create git tag `v0.1.0`, and publish.
- **Acceptance:** Both packages published and verified on pub.dev.

## Done this release

- Modularize Circuit and extract DAG compiler to CircuitGraph (#7).
- Optimize CI workflows for reduced GitHub compute.
- Add taggable CircuitProvider with O(1) ambient registry map merging (#1).
- Add package examples, visual architecture diagrams, and pub.dev metadata.
- Modularize packages to `src/` layout with Dart 3.14+ primary constructors.
