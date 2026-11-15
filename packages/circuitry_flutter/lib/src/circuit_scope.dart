part of '../circuitry_flutter.dart';

/// Internal [InheritedWidget] carrying the [Circuit] instance through the widget tree.
final class const _CircuitScope({
  required super.child,
  required final Circuit circuit,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(_CircuitScope oldWidget) =>
      circuit != oldWidget.circuit;
}
