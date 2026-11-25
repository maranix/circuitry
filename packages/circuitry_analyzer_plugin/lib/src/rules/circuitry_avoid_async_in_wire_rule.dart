import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:circuitry_analyzer_plugin/src/utils/wire_analysis_utils.dart';

/// Warns when a synchronous `Wire` factory closure returns a `Future`.
final class CircuitryAvoidAsyncInWireRule() extends AnalysisRule {
  static const LintCode code = LintCode(
    'circuitry_avoid_async_in_wire',
    "Synchronous 'Wire' factory returns a 'Future<{0}>'. Use 'AsyncWire' instead.",
    correctionMessage: "Replace 'Wire' with 'AsyncWire'.",
    severity: .WARNING,
  );

  this
    : super(
        name: 'circuitry_avoid_async_in_wire',
        description: 'Warns when a synchronous Wire factory returns a Future.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _CircuitryAvoidAsyncInWireVisitor(this);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addMethodInvocation(this, visitor);
  }
}

class _CircuitryAvoidAsyncInWireVisitor(final AnalysisRule rule)
    extends SimpleAstVisitor<void> {
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

    if (!wire.isSyncWire) return;

    if (isAsynchronousFactory(wire.factoryExpression, wire.outputType)) {
      final unwrappedType = unwrapFutureType(wire.outputType);
      rule.reportAtNode(
        wire.node,
        arguments: [unwrappedType.getDisplayString()],
      );
    }
  }
}
