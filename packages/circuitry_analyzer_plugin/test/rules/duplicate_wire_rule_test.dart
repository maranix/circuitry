// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:circuitry_analyzer_plugin/circuitry_analyzer_plugin.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../test_helper.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DuplicateWireRuleTest);
  });
}

@reflectiveTest
class DuplicateWireRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = CircuitryDuplicateWireRule();
    addCircuitryPackageStubs(this);
    super.setUp();
  }

  Future<void> test_duplicate_untagged_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class ServiceA {}

void main() async {
  await Circuit.build([
    Wire(() => ServiceA()),
    Wire(() => ServiceA()),
  ]);
}
''',
      [
        lint(139, 22, messageContainsAll: ["key 'ServiceA'"]),
      ],
    );
  }

  Future<void> test_no_duplicate_distinct_wires() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

class ServiceA {}
class ServiceB {}

void main() async {
  await Circuit.build([
    Wire(() => ServiceA()),
    Wire(() => ServiceB()),
  ]);
}
''');
  }

  Future<void> test_duplicate_tagged_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }
class Config {}

void main() async {
  await Circuit.build([
    Wire.tag(() => Config(), tag: Environment.dev),
    Wire.tag(() => Config(), tag: Environment.dev),
  ]);
}
''',
      [
        lint(192, 46, messageContainsAll: ["(Config, Environment.dev)"]),
      ],
    );
  }

  Future<void> test_different_tags_no_duplicate() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }
class Config {}

void main() async {
  await Circuit.build([
    Wire.tag(() => Config(), tag: Environment.dev),
    Wire.tag(() => Config(), tag: Environment.prod),
  ]);
}
''');
  }

  Future<void> test_circuit_provider_duplicate_wires() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry_flutter/circuitry_flutter.dart';

class ServiceA {}

void test() {
  CircuitProvider(
    wires: [
      Wire(() => ServiceA()),
      Wire(() => ServiceA()),
    ],
  );
}
''',
      [
        lint(161, 22, messageContainsAll: ["key 'ServiceA'"]),
      ],
    );
  }

  Future<void> test_duplicate_between_sync_and_async_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class ServiceA {}

void main() async {
  await Circuit.build([
    Wire(() => ServiceA()),
    AsyncWire(() async => ServiceA()),
  ]);
}
''',
      [
        lint(139, 33, messageContainsAll: ["key 'ServiceA'"]),
      ],
    );
  }

  Future<void> test_duplicate_between_builder_and_direct_wire() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class ServiceA {}
class ServiceB {
  ServiceB(ServiceA a);
}

void main() async {
  await Circuit.build([
    Wire(() => ServiceA()),
    Wire(() => ServiceB(ServiceA())),
    Wire.takes<ServiceA>().to((a) => ServiceB(a)),
  ]);
}
''',
      [
        lint(220, 45, messageContainsAll: ["key 'ServiceB'"]),
      ],
    );
  }

  Future<void> test_duplicate_multiple_registrations() async {
    await assertDiagnostics(
      r'''
import 'package:circuitry/circuitry.dart';

class ServiceA {}

void main() async {
  await Circuit.build([
    Wire(() => ServiceA()),
    Wire(() => ServiceA()),
    Wire(() => ServiceA()),
  ]);
}
''',
      [
        lint(139, 22, messageContainsAll: ["key 'ServiceA'"]),
        lint(167, 22, messageContainsAll: ["key 'ServiceA'"]),
      ],
    );
  }

  Future<void> test_same_tag_different_types_no_duplicate() async {
    await assertNoDiagnostics(r'''
import 'package:circuitry/circuitry.dart';

enum Environment { dev, prod }
class ServiceA {}
class ServiceB {}

void main() async {
  await Circuit.build([
    Wire.tag(() => ServiceA(), tag: Environment.dev),
    Wire.tag(() => ServiceB(), tag: Environment.dev),
  ]);
}
''');
  }
}
