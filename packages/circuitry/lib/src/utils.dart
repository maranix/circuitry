import 'package:circuitry/src/wire.dart';

/// Formats a [WireKey] into a human-readable string representation (e.g. `Type` or `Type#tag`).
String formatWireKey(WireKey key) {
  final typeName = key.$1.toString();
  final tag = key.$2;
  return tag == null ? typeName : '$typeName#$tag';
}

/// Whether assertions are enabled in the current runtime environment.
///
/// Evaluates to `true` exclusively in debug mode with assertions enabled (`dart --enable-asserts`).
/// In profile and release modes, assertions are disabled by the runtime/compiler and this getter
/// evaluates to `false`, allowing callers to tree-shake telemetry logic.
bool get isDebugMode {
  var debug = false;
  assert(debug = true);
  return debug;
}
