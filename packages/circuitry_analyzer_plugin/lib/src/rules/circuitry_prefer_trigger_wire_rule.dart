import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:circuitry_analyzer_plugin/src/utils/wire_analysis_utils.dart';

/// Warns when a class implementing `CircuitAction` is wired using `Wire` or `AsyncWire` instead of `TriggerWire`.
final class CircuitryPreferTriggerWireRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'circuitry_prefer_trigger_wire',
    "The type '{0}' implements 'CircuitAction' and should be registered using 'TriggerWire'.",
    correctionMessage: "Use 'TriggerWire' or 'TriggerWire.takes' instead.",
    severity: DiagnosticSeverity.WARNING,
  );

  CircuitryPreferTriggerWireRule()
    : super(
        name: 'circuitry_prefer_trigger_wire',
        description: 'Warns when classes implementing CircuitAction are registered without TriggerWire.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _CircuitryPreferTriggerWireVisitor(this);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addMethodInvocation(this, visitor);
  }
}

class _CircuitryPreferTriggerWireVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _CircuitryPreferTriggerWireVisitor(this.rule);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkWire(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _checkWire(node);
  }

  void _checkWire(Expression node) {
    final wire = extractWireDeclaration(node);
    if (wire == null) return;

    if (!wire.isTriggerWire && isCircuitAction(wire.outputType)) {
      rule.reportAtNode(
        wire.node,
        arguments: [wire.outputType.getDisplayString()],
      );
    }
  }
}
