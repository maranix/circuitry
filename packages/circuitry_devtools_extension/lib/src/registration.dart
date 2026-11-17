import 'package:circuitry/circuitry.dart';

/// Registers Dart VM Service extensions for Circuitry (`ext.circuitry.*`) and enables
/// live telemetry event streaming to the DevTools extension.
///
/// Call this in your application (e.g. inside `main()` during debug mode) to connect
/// your Dart or Flutter application to the Circuitry DevTools extension tab:
///
/// ```dart
/// void main() {
///   registerCircuitryDevToolsExtension();
///   runApp(const MyApp());
/// }
/// ```
void registerCircuitryDevToolsExtension() {
  CircuitRegistry.instance.registerVmServiceExtensions();
}

/// Deregisters and disables Circuitry DevTools VM service extensions and telemetry events.
void unregisterCircuitryDevToolsExtension() {
  CircuitRegistry.instance.unregisterVmServiceExtensions();
}

/// Static namespace providing registration utilities for Circuitry DevTools.
abstract final class CircuitryDevTools {
  /// Registers Dart VM Service extensions for Circuitry and enables live inspection.
  static void register() => registerCircuitryDevToolsExtension();

  /// Deregisters and disables Circuitry DevTools VM service extensions.
  static void unregister() => unregisterCircuitryDevToolsExtension();
}
