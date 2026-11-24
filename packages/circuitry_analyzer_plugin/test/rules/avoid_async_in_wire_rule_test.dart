// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:circuitry_analyzer_plugin/circuitry_analyzer_plugin.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../test_helper.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidAsyncInWireRuleTest);
  });
}

@reflectiveTest
class AvoidAsyncInWireRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = CircuitryAvoidAsyncInWireRule();
    addCircuitryPackageStubs(this);
    super.setUp();
  }

  Future<void> test_async_lambda_in_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class DatabaseService {}

void main() {
  final wire = Wire(() async => DatabaseService());
}
''',
      [
        lint(
          99,
          35,
          messageContainsAll: [
            "returns a 'Future<DatabaseService>'",
            "Use 'AsyncWire' instead",
          ],
        ),
      ],
    );
  }

  Future<void> test_future_return_type_in_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class DatabaseService {}
Future<DatabaseService> initDb() async => DatabaseService();

void main() {
  final wire = Wire(() => initDb());
}
''',
      [
        lint(
          160,
          20,
          messageContainsAll: [
            "returns a 'Future<DatabaseService>'",
            "Use 'AsyncWire' instead",
          ],
        ),
      ],
    );
  }

  Future<void> test_async_wire_no_diagnostic() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

class DatabaseService {}

void main() {
  final wire = AsyncWire(() async => DatabaseService());
}
''');
  }

  Future<void> test_sync_wire_no_diagnostic() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

class DatabaseService {}

void main() {
  final wire = Wire(() => DatabaseService());
}
''');
  }
}
