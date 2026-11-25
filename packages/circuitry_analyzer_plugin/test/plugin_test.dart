import 'package:analysis_server_plugin/src/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/error/error.dart';
import 'package:circuitry_analyzer_plugin/circuitry_analyzer_plugin.dart';
import 'package:test/test.dart';

void main() {
  group('CircuitryPlugin registration', () {
    test('registers all 4 warning rules with warning severity', () {
      final plugin = CircuitryPlugin();
      expect(plugin.name, equals('Circuitry Analyzer Plugin'));

      final registry = PluginRegistryImpl('circuitry_analyzer_plugin');
      plugin.register(registry);

      // Verify all 4 rules are registered as warning rules (enabled by default)
      expect(registry.warningRules, hasLength(4));
      expect(registry.lintRules, isEmpty);

      final registeredNames = registry.warningRules.keys.toSet();
      expect(
        registeredNames,
        containsAll([
          'circuitry_duplicate_wire',
          'circuitry_missing_wire',
          'circuitry_prefer_trigger_wire',
          'circuitry_avoid_async_in_wire',
        ]),
      );

      // Verify each rule diagnostic code has WARNING severity
      for (final rule in registry.warningRules.values) {
        final analysisRule = rule as AnalysisRule;
        expect(
          analysisRule.diagnosticCode.severity,
          equals(DiagnosticSeverity.WARNING),
          reason: 'Rule ${rule.name} must have WARNING severity',
        );
      }
    });
  });
}
