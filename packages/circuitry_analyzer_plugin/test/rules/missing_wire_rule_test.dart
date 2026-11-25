// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:circuitry_analyzer_plugin/circuitry_analyzer_plugin.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../test_helper.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingWireRuleTest);
  });
}

@reflectiveTest
class MissingWireRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = CircuitryMissingWireRule();
    addCircuitryPackageStubs(this);
    super.setUp();
  }

  Future<void> test_missing_dependency() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class DatabaseService {}
class UserService {
  UserService(DatabaseService db);
}

void main() async {
  await Circuit.build([
    Wire.takes<DatabaseService>().to((db) => UserService(db)),
  ]);
}
''',
      [
        lint(
          185,
          17,
          messageContainsAll: [
            "key 'DatabaseService'",
            "required by 'UserService'",
          ],
        ),
      ],
    );
  }

  Future<void> test_dependency_provided_no_diagnostic() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

class DatabaseService {}
class UserService {
  UserService(DatabaseService db);
}

void main() async {
  await Circuit.build([
    Wire(() => DatabaseService()),
    Wire.takes<DatabaseService>().to((db) => UserService(db)),
  ]);
}
''');
  }

  Future<void> test_missing_tagged_dependency() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }
class Config {}
class DatabaseService {
  DatabaseService(Config config);
}

void main() async {
  await Circuit.build([
    Wire.tag(() => Config(), tag: Environment.dev),
    Wire.takesTagged<Config, Environment>(Environment.prod).to(
      (c) => DatabaseService(c),
    ),
  ]);
}
''',
      [
        lint(
          268,
          21,
          messageContainsAll: [
            "key '(Config, Environment.prod)'",
            "required by 'DatabaseService'",
          ],
        ),
      ],
    );
  }

  Future<void> test_tagged_dependency_provided_no_diagnostic() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }
class Config {}
class DatabaseService {
  DatabaseService(Config config);
}

void main() async {
  await Circuit.build([
    Wire.tag(() => Config(), tag: Environment.prod),
    Wire.takesTagged<Config, Environment>(Environment.prod).to(
      (c) => DatabaseService(c),
    ),
  ]);
}
''');
  }

  Future<void> test_spread_element_skips_missing_check() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

class DatabaseService {}
class UserService {
  UserService(DatabaseService db);
}

void main() async {
  final otherWires = <CircuitWire>[];
  await Circuit.build([
    ...otherWires,
    Wire.takes<DatabaseService>().to((db) => UserService(db)),
  ]);
}
''');
  }

  Future<void> test_multiple_dependencies_one_missing() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class ServiceA {}
class ServiceB {}
class ServiceC {
  ServiceC(ServiceA a, ServiceB b);
}

void main() async {
  await Circuit.build([
    Wire(() => ServiceA()),
    Wire.takes<ServiceA>().takes<ServiceB>().to((deps) => ServiceC(deps.$1, deps.$2)),
  ]);
}
''',
      [
        lint(
          240,
          10,
          messageContainsAll: ["key 'ServiceB'", "required by 'ServiceC'"],
        ),
      ],
    );
  }

  Future<void> test_order_independence_no_diagnostic() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

class DatabaseService {}
class UserService {
  UserService(DatabaseService db);
}

void main() async {
  // Consumer appears BEFORE provider in the wires list
  await Circuit.build([
    Wire.takes<DatabaseService>().to((db) => UserService(db)),
    Wire(() => DatabaseService()),
  ]);
}
''');
  }

  Future<void> test_missing_async_wire_dependency() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class Config {}
class DatabaseService {
  DatabaseService(Config c);
}

void main() async {
  await Circuit.build([
    AsyncWire.takes<Config>().to((c) async => DatabaseService(c)),
  ]);
}
''',
      [
        lint(
          179,
          8,
          messageContainsAll: ["key 'Config'", "required by 'DatabaseService'"],
        ),
      ],
    );
  }

  Future<void> test_missing_trigger_wire_dependency() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class EmailClient {}
class SendEmailAction implements CircuitAction {
  SendEmailAction(EmailClient client);
}

void main() async {
  await Circuit.build([
    TriggerWire.takes<EmailClient>().to((c) => SendEmailAction(c)),
  ]);
}
''',
      [
        lint(
          221,
          13,
          messageContainsAll: [
            "key 'EmailClient'",
            "required by 'SendEmailAction'",
          ],
        ),
      ],
    );
  }

  Future<void> test_missing_untagged_when_tagged_provided() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }
class Config {}
class DatabaseService {
  DatabaseService(Config config);
}

void main() async {
  await Circuit.build([
    Wire.tag(() => Config(), tag: Environment.dev),
    Wire.takes<Config>().to((c) => DatabaseService(c)),
  ]);
}
''',
      [
        lint(
          262,
          8,
          messageContainsAll: ["key 'Config'", "required by 'DatabaseService'"],
        ),
      ],
    );
  }

  Future<void> test_circuit_provider_missing_dependency() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry_flutter/circuitry_flutter.dart';

class DatabaseService {}
class UserService {
  UserService(DatabaseService db);
}

void test() {
  CircuitProvider(
    wires: [
      Wire.takes<DatabaseService>().to((db) => UserService(db)),
    ],
  );
}
''',
      [
        lint(
          205,
          17,
          messageContainsAll: [
            "key 'DatabaseService'",
            "required by 'UserService'",
          ],
        ),
      ],
    );
  }
}
