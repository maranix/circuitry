import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:circuitry_analyzer_plugin/src/rules/circuitry_avoid_async_in_wire_rule.dart';
import 'package:circuitry_analyzer_plugin/src/rules/circuitry_duplicate_wire_rule.dart';
import 'package:circuitry_analyzer_plugin/src/rules/circuitry_missing_wire_rule.dart';
import 'package:circuitry_analyzer_plugin/src/rules/circuitry_prefer_trigger_wire_rule.dart';

/// Circuitry Analysis Server Plugin providing static validation and best practices.
final class CircuitryPlugin extends Plugin {
  @override
  String get name => 'Circuitry Analyzer Plugin';

  @override
  void register(PluginRegistry registry) {
    // All rules registered as warning rules are enabled by default for consuming projects
    registry.registerWarningRule(CircuitryDuplicateWireRule());
    registry.registerWarningRule(CircuitryMissingWireRule());
    registry.registerWarningRule(CircuitryPreferTriggerWireRule());
    registry.registerWarningRule(CircuitryAvoidAsyncInWireRule());
  }
}
