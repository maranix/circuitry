/// Public registration and deregistration APIs for the Circuitry DevTools Extension.
///
/// To enable DevTools inspection in your application, add `circuitry_devtools_extension`
/// to your `dev_dependencies` and call [registerCircuitryDevToolsExtension] (or
/// [CircuitryDevTools.register]) in your entry point:
///
/// ```dart
/// import 'package:circuitry_devtools_extension/circuitry_devtools_extension.dart';
///
/// void main() {
///   registerCircuitryDevToolsExtension();
///   runApp(const MyApp());
/// }
/// ```
library;

export 'src/registration.dart';
