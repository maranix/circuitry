import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

/// Registers package stubs for `circuitry` and `circuitry_flutter` in analysis tests.
void addCircuitryPackageStubs(AnalysisRuleTest test) {
  test.newPackage('circuitry').addFile('lib/circuitry.dart', r'''
abstract class CircuitAction {}

class Circuit {
  static Future<Circuit> build(List<Object?> wires, {String? debugTag}) async => Circuit._();
  Circuit._();
}

abstract class CircuitWire {}

class Wire<T> extends CircuitWire {
  Wire(T Function() create);
  static Wire<T> tag<T, K extends Enum>(T Function() create, {required K tag}) => Wire(create);
  static WireBuilder<A> takes<A>() => WireBuilder._();
  static WireBuilder<A> takesTagged<A, K extends Enum>(K tag) => WireBuilder._();
}

class AsyncWire<T> extends CircuitWire {
  AsyncWire(Future<T> Function() create);
  static AsyncWire<T> tag<T, K extends Enum>(Future<T> Function() create, {required K tag}) => AsyncWire(create);
  static AsyncWireBuilder<A> takes<A>() => AsyncWireBuilder._();
  static AsyncWireBuilder<A> takesTagged<A, K extends Enum>(K tag) => AsyncWireBuilder._();
}

class TriggerWire<T extends CircuitAction> extends CircuitWire {
  TriggerWire(T Function() create);
  static TriggerWire<T> tag<T extends CircuitAction, K extends Enum>(T Function() create, {required K tag}) => TriggerWire(create);
  static TriggerWireBuilder<A> takes<A>() => TriggerWireBuilder._();
  static TriggerWireBuilder<A> takesTagged<A, K extends Enum>(K tag) => TriggerWireBuilder._();
}

class WireBuilder<Acc> {
  WireBuilder._();
  WireBuilder<(Acc, Next)> takes<Next>() => WireBuilder._();
  WireBuilder<(Acc, Next)> takesTagged<Next, K extends Enum>(K tag) => WireBuilder._();
  Wire<T> to<T>(T Function(Acc) create, {Enum? tag}) => Wire(() => create(null as Acc));
}

class AsyncWireBuilder<Acc> {
  AsyncWireBuilder._();
  AsyncWireBuilder<(Acc, Next)> takes<Next>() => AsyncWireBuilder._();
  AsyncWireBuilder<(Acc, Next)> takesTagged<Next, K extends Enum>(K tag) => AsyncWireBuilder._();
  AsyncWire<T> to<T>(Future<T> Function(Acc) create, {Enum? tag}) => AsyncWire(() => create(null as Acc));
}

class TriggerWireBuilder<Acc> {
  TriggerWireBuilder._();
  TriggerWireBuilder<(Acc, Next)> takes<Next>() => TriggerWireBuilder._();
  TriggerWireBuilder<(Acc, Next)> takesTagged<Next, K extends Enum>(K tag) => TriggerWireBuilder._();
  TriggerWire<T> to<T extends CircuitAction>(T Function(Acc) create, {Enum? tag}) => TriggerWire(() => create(null as Acc));
}
''');

  test.newPackage('circuitry_flutter').addFile(
    'lib/circuitry_flutter.dart',
    r'''
import 'package:circuitry/circuitry.dart';
export 'package:circuitry/circuitry.dart';

class CircuitProvider {
  CircuitProvider({required List<Object?> wires});
}
''',
  );
}
