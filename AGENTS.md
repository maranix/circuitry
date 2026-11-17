# Agent Guidelines for Circuitry

Welcome! Circuitry is a pure Dart 3.14+ zero-codegen, graph-based dependency injection engine backed by a Directed Acyclic Graph (DAG), paired with a Flutter companion package `circuitry_flutter`.

When working on this repository, follow these conventions:

## 1. Required Reading Before Changing Code
Always read these four core project documents before proposing or implementing changes:
- [`docs/decisions.md`](docs/decisions.md): Architectural decisions, history, agreed choices, and rejected alternatives.
- [`docs/architecture.md`](docs/architecture.md): System shape, seams, module layout, dependencies, and command references.
- [`docs/plan.md`](docs/plan.md): Active goals, sub-step checklists, and project roadmap.
- [`README.md`](README.md): Project overview, monorepo layout, and verification commands.

## 2. Follow Mobile & Dart Conventions
- Invoke the `mobile-conventions` skill before changing or reviewing code, and follow the Flutter/Dart stack reference.
- Keep `packages/circuitry` strictly pure Dart (zero dependencies on `package:flutter` or UI frameworks).
- Keep `packages/circuitry_flutter` dedicated to Flutter integration (`CircuitProvider`, `CircuitState`, `_CircuitScope`).
- Never introduce reflection, mirrors, or code generation dependencies.

## 3. Plan First & Move Docs with Code
- A tracked feature or behavior change gets a short [`docs/plan.md`](docs/plan.md) entry before code; a rename, dependency bump, internal refactor, or one-line fix gets none.
- Update [`docs/architecture.md`](docs/architecture.md) and [`README.md`](README.md) in the **same atomic commit** whenever module shape, dependencies, commands, or behavior change.
- Record any new architectural choices or rejected options in [`docs/decisions.md`](docs/decisions.md).
- A change is considered incomplete while code and documents disagree.

## 4. Verification & Testing
- Work in the inner loop during implementation:
  ```bash
  # Pure Dart package:
  cd packages/circuitry && dart test

  # Flutter bridge package:
  cd packages/circuitry_flutter && flutter test
  ```
- Run the full verification gate before completing work:
  ```bash
  dart format --output=none --set-exit-if-changed .
  flutter analyze --fatal-infos --fatal-warnings
  (cd packages/circuitry && dart test) && (cd packages/circuitry_flutter && flutter test)
  ```
