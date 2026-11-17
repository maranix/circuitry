import 'package:circuitry/circuitry.dart';
import 'package:circuitry_devtools_extension/circuitry_devtools_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    CircuitRegistry.instance.clear();
  });

  tearDown(() {
    CircuitRegistry.instance.clear();
  });

  group('DevTools Extension Public Registration APIs', () {
    test('registerCircuitryDevToolsExtension enables extensions and unregister disables them', () {
      expect(CircuitRegistry.instance.areExtensionsRegistered, isFalse);

      registerCircuitryDevToolsExtension();
      expect(CircuitRegistry.instance.areExtensionsRegistered, isTrue);

      unregisterCircuitryDevToolsExtension();
      expect(CircuitRegistry.instance.areExtensionsRegistered, isFalse);
    });

    test(
      'CircuitryDevTools static methods register and unregister extensions',
      () {
        expect(CircuitRegistry.instance.areExtensionsRegistered, isFalse);

        CircuitryDevTools.register();
        expect(CircuitRegistry.instance.areExtensionsRegistered, isTrue);

        CircuitryDevTools.unregister();
        expect(CircuitRegistry.instance.areExtensionsRegistered, isFalse);
      },
    );
  });
}
