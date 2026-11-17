import 'package:circuitry/src/utils.dart';
import 'package:circuitry/src/wire.dart';

/// Extension on [WireKey] providing human-readable formatting.
extension WireKeyFormatting on WireKey {
  /// Returns a human-readable string representation of this key (e.g. `Type` or `Type#tag`).
  String format() => formatWireKey(this);
}
