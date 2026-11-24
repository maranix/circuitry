import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:circuitry_analyzer_plugin/src/utils/wire_analysis_utils.dart';

/// Warns when duplicate wire keys `(Type, Enum?)` are declared within the same circuit.
final class CircuitryDuplicateWireRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'circuitry_duplicate_wire',
    "Duplicate wire registered for key '{0}'.",
    correctionMessage:
        'Remove the duplicate wire or differentiate it with a unique tag.',
    severity: DiagnosticSeverity.WARNING,
  );

  CircuitryDuplicateWireRule()
    : super(
        name: 'circuitry_duplicate_wire',
        description:
            'Warns when duplicate wire keys are declared in a circuit.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _CircuitryDuplicateWireVisitor(this);
    registry.addMethodInvocation(this, visitor);
    registry.addInstanceCreationExpression(this, visitor);
  }
}

class _CircuitryDuplicateWireVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _CircuitryDuplicateWireVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final wiresList = extractCircuitWiresList(node);
    if (wiresList != null) {
      _checkDuplicateWires(wiresList);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final wiresList = extractCircuitWiresList(node);
    if (wiresList != null) {
      _checkDuplicateWires(wiresList);
    }
  }

  void _checkDuplicateWires(ListLiteral wiresList) {
    final seenKeys = <WireKeyRecord, WireDeclarationInfo>{};

    for (final element in wiresList.elements) {
      if (element is! Expression) continue;
      final wire = extractWireDeclaration(element);
      if (wire == null) continue;

      final key = wire.key;
      if (seenKeys.containsKey(key)) {
        rule.reportAtNode(wire.node, arguments: [key.displayString]);
      } else {
        seenKeys[key] = wire;
      }
    }
  }
}
