# Plan

## Next

### Publish v0.1.0 to pub.dev

- **Release:** 0.1.0
- **Goal:** Publish initial stable releases of `circuitry` and `circuitry_flutter` to pub.dev.
- **Requirements:**
  - Verify package validation passes with zero warnings (`dart pub publish --dry-run`).
  - Tag release commits matching versions in pubspec.yaml.
- **Approach:** Run dry-run checks in both packages, create git tag `v0.1.0`, and publish.
- **Acceptance:** Both packages published and verified on pub.dev.

## Done this release

- Add ambient CircuitRegistry, VM Service extensions, and DevTools packaging to circuitry (#11).
- Add core introspection API with reverse dependency queries and Mermaid/JSON export (#4).
- Fail fast on async wave resolution with immediate rollback (#9).
- Modularize Circuit and extract DAG compiler to CircuitGraph (#7).
- Optimize CI workflows for reduced GitHub compute.
- Add taggable CircuitProvider with O(1) ambient registry map merging (#1).
