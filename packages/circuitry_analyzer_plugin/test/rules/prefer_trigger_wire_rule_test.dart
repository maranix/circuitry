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

  Future<void> test_action_registered_via_wire_builder() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class Client {}
class SendEmailAction implements CircuitAction {
  SendEmailAction(Client c);
}

void main() {
  final wire = Wire.takes<Client>().to((c) => SendEmailAction(c));
}
''',
      [
        lint(
          170,
          50,
          messageContainsAll: [
            "type 'SendEmailAction' implements 'CircuitAction'",
          ],
        ),
      ],
    );
  }

  Future<void> test_action_registered_via_async_wire_builder() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class Client {}
class SendEmailAction implements CircuitAction {
  SendEmailAction(Client c);
}

void main() {
  final wire = AsyncWire.takes<Client>().to((c) async => SendEmailAction(c));
}
''',
      [
        lint(
          170,
          61,
          messageContainsAll: [
            "type 'SendEmailAction' implements 'CircuitAction'",
          ],
        ),
      ],
    );
  }

  Future<void>
  test_action_registered_via_trigger_wire_builder_no_diagnostic() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

class Client {}
class SendEmailAction implements CircuitAction {
  SendEmailAction(Client c);
}

void main() {
  final wire = TriggerWire.takes<Client>().to((c) => SendEmailAction(c));
}
''');
  }

  Future<void> test_action_subclass_registered_with_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

abstract class BaseAction implements CircuitAction {}
class ConcreteAction extends BaseAction {}

void main() {
  final wire = Wire(() => ConcreteAction());
}
''',
      [
        lint(
          171,
          28,
          messageContainsAll: [
            "type 'ConcreteAction' implements 'CircuitAction'",
          ],
        ),
      ],
    );
  }

  Future<void> test_action_registered_with_tagged_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }
class SendEmailAction implements CircuitAction {}

void main() {
  final wire = Wire.tag(() => SendEmailAction(), tag: Environment.dev);
}
''',
      [
        lint(
          155,
          55,
          messageContainsAll: [
            "type 'SendEmailAction' implements 'CircuitAction'",
          ],
        ),
      ],
    );
  }

  Future<void>
  test_action_registered_with_tagged_trigger_wire_no_diagnostic() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }
class SendEmailAction implements CircuitAction {}

void main() {
  final wire = TriggerWire.tag(() => SendEmailAction(), tag: Environment.dev);
}
''');
  }
}
