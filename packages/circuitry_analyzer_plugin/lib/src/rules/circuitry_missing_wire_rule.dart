import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:circuitry_analyzer_plugin/src/utils/wire_analysis_utils.dart';

/// Warns when a declared dependency is missing from a statically declared circuit wire list.
final class CircuitryMissingWireRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'circuitry_missing_wire',
    "Missing dependency wire for key '{0}' required by '{1}'.",
    correctionMessage: "Add a wire providing '{0}' to the circuit.",
    severity: DiagnosticSeverity.WARNING,
  );

  CircuitryMissingWireRule()
    : super(
        name: 'circuitry_missing_wire',
        description: 'Warns when declared dependencies are missing from a static wire list.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _CircuitryMissingWireVisitor(this);
    registry.addMethodInvocation(this, visitor);
    registry.addInstanceCreationExpression(this, visitor);
  }
}

class _CircuitryMissingWireVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _CircuitryMissingWireVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final wiresList = extractCircuitWiresList(node);
    if (wiresList != null) {
      _checkMissingWires(wiresList);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final wiresList = extractCircuitWiresList(node);
    if (wiresList != null) {
      _checkMissingWires(wiresList);
    }
  }

  void _checkMissingWires(ListLiteral wiresList) {
    // If the list contains spread elements (...wires) or non-wire expressions,
    // we cannot statically determine all available wires, so skip to prevent false positives.
    for (final element in wiresList.elements) {
      if (element is SpreadElement) return;
      if (element is Expression && extractWireDeclaration(element) == null) {
        return;
      }
    }

    final declaredWires = <WireDeclarationInfo>[];
    final providedKeys = <WireKeyRecord>{};

    for (final element in wiresList.elements) {
      if (element is! Expression) continue;
      final wire = extractWireDeclaration(element);
      if (wire == null) continue;

      declaredWires.add(wire);
      providedKeys.add(wire.key);
    }

    for (final wire in declaredWires) {
      for (final dep in wire.dependencies) {
        if (!providedKeys.contains(dep.key)) {
          final targetNode = dep.sourceNode is AstNode
              ? dep.sourceNode as AstNode
              : wire.node;
          rule.reportAtNode(
            targetNode,
            arguments: [
              dep.key.displayString,
              wire.outputType.getDisplayString(),
            ],
          );
        }
      }
    }
  }
}
