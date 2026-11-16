// ignore_for_file: deprecated_member_use

import 'package:circuitry_devtools_extension/src/service/vm_service_circuitry_client.dart';
import 'package:circuitry_devtools_extension/src/ui/circuitry_dashboard.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CircuitryDevToolsApp());
}

/// Root application widget for the Circuitry DevTools Extension.
class CircuitryDevToolsApp extends StatelessWidget {
  /// Creates a [CircuitryDevToolsApp].
  const CircuitryDevToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: CircuitryDashboard(client: VmServiceCircuitryClient()),
    );
  }
}
