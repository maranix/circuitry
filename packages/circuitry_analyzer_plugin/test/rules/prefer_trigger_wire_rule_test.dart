// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:circuitry_analyzer_plugin/circuitry_analyzer_plugin.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../test_helper.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferTriggerWireRuleTest);
  });
}

@reflectiveTest
class PreferTriggerWireRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = CircuitryPreferTriggerWireRule();
    addCircuitryPackageStubs(this);
    super.setUp();
  }

  Future<void> test_action_registered_with_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class SendEmailAction implements CircuitAction {}

void main() {
  final wire = Wire(() => SendEmailAction());
}
''',
      [
        lint(
          124,
          29,
          messageContainsAll: [
            "type 'SendEmailAction' implements 'CircuitAction'",
          ],
        ),
      ],
    );
  }

  Future<void> test_action_registered_with_async_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class SendEmailAction implements CircuitAction {}

void main() {
  final wire = AsyncWire(() async => SendEmailAction());
}
''',
      [
        lint(
          124,
          40,
          messageContainsAll: [
            "type 'SendEmailAction' implements 'CircuitAction'",
          ],
        ),
      ],
    );
  }

  Future<void> test_action_registered_with_trigger_wire_no_diagnostic() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

class SendEmailAction implements CircuitAction {}

void main() {
  final wire = TriggerWire(() => SendEmailAction());
}
''');
  }

  Future<void> test_normal_service_registered_with_wire_no_diagnostic() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

class NormalService {}

void main() {
  final wire = Wire(() => NormalService());
}
''');
  }
}
