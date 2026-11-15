/// Pure Dart zero-codegen, graph-based dependency injection engine backed by a Directed Acyclic Graph (DAG).
///
/// Circuitry provides compile-time-checked runtime dependency wiring with parallel
/// topological wave resolution for asynchronous singletons, reverse topological wave
/// disposal, and type-safe dependency chaining without code generation, mirrors, or reflection.
///
/// ## Core Concepts
///
/// * [Circuit], the compiled dependency injection container and DAG compiler.
/// * [Wire], declarative recipes for synchronous, lazily evaluated singletons.
/// * [AsyncWire], declarative recipes for asynchronous singletons resolved in parallel waves during build.
/// * [WireKey], record tuple identifiers `(Type, Enum?)` supporting Dart dot-shorthands for tagged singletons.
/// * [Wire.takes] and [AsyncWire.takes], fluent accumulator chaining for declaring dependencies.
///
/// ## Quickstart
///
/// ```dart
/// import 'package:circuitry/circuitry.dart';
///
/// final class DatabaseConfig {
///   final String url;
///   const DatabaseConfig(this.url);
/// }
///
/// final class DatabaseService {
///   final DatabaseConfig config;
///   DatabaseService(this.config);
///   Future<void> close() async {}
/// }
///
/// void main() async {
///   final circuit = await Circuit.build([
///     Wire(() => const DatabaseConfig('sqlite://app.db')),
///     Wire.takes<DatabaseConfig>().to(
///       DatabaseService.new,
///       onDispose: (db) => db.close(),
///     ),
///   ]);
///
///   final db = circuit.get<DatabaseService>();
///   await circuit.dispose();
/// }
/// ```
library;

export 'src/circuit.dart';

export 'src/exceptions.dart';

export 'src/wire.dart'
    hide
        AsyncWireBuilder,
        AsyncWireBuilderFactory,
        WireBuilder,
        WireBuilderFactory,
        WireDependencyResolver;
