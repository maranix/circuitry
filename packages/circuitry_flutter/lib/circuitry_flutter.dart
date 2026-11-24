/// Flutter integration for Circuitry, a zero-codegen graph-based dependency injection engine.
///
/// This package bridges the pure Dart `circuitry` Directed Acyclic Graph (DAG) container
/// into the Flutter widget tree. It provides inherited widget scoping, reactive asynchronous
/// compilation lifecycle states, and automatic reverse topological disposal.
///
/// ## Key Concepts
///
/// * [CircuitProvider], the composition root widget that manages asynchronous DAG compilation
///   or synchronously injects pre-built containers into the widget tree.
/// * [CircuitState], the sealed state hierarchy ([CircuitBuilding], [CircuitReady], [CircuitFailure])
///   used to reactively render splash screens, main applications, or error views.
/// * [CircuitProvider.of] and [CircuitProvider.maybeOf], descendant accessors for querying the
///   ambient [Circuit] container from any [BuildContext].
///
/// ## Quickstart
///
/// ```dart
/// import 'package:circuitry_flutter/circuitry_flutter.dart';
/// import 'package:flutter/widgets.dart';
///
/// void main() {
///   runApp(
///     CircuitProvider(
///       wires: [
///         Wire(DatabaseConfig.new),
///         AsyncWire.takes<DatabaseConfig>().to(DatabaseService.connect),
///         Wire.takes<DatabaseService>().to(UserRepository.new),
///       ],
///       builder: (context, state) => switch (state) {
///         CircuitReady() => const MainApp(),
///         CircuitBuilding() => const SplashScreen(),
///         CircuitFailure(:final error, :final stackTrace) =>
///           ErrorScreen(error: error, stackTrace: stackTrace),
///       },
///     ),
///   );
/// }
/// ```
///
/// This library also re-exports `package:circuitry/circuitry.dart`, providing direct access
/// to [Circuit], [Wire], [AsyncWire], [CircuitWire], and related types without requiring an
/// explicit import of the pure Dart core.
library;

export 'package:circuitry/circuitry.dart';

export 'src/circuit_builder.dart';
export 'src/circuit_provider.dart';
export 'src/circuit_state.dart';
