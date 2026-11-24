import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rules/avoid_async_in_wire_rule_test.dart' as avoid_async_in_wire;
import 'rules/duplicate_wire_rule_test.dart' as duplicate_wire;
import 'rules/missing_wire_rule_test.dart' as missing_wire;
import 'rules/prefer_trigger_wire_rule_test.dart' as prefer_trigger_wire;

void main() {
  defineReflectiveSuite(() {
    avoid_async_in_wire.main();
    duplicate_wire.main();
    missing_wire.main();
    prefer_trigger_wire.main();
  });
}
