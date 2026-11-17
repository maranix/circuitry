import 'package:circuitry_devtools_extension/src/screens/circuitry_devtools_screen.dart';
import 'package:circuitry_devtools_extension/src/services/circuitry_service_client.dart';
import 'package:circuitry_devtools_extension/src/services/mock_circuitry_service_client.dart';
import 'package:circuitry_devtools_extension/src/services/vm_circuitry_service_client.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const CircuitryDevToolsApp());
}

/// Root application widget for the Circuitry DevTools Extension.
class CircuitryDevToolsApp extends StatelessWidget {
  const CircuitryDevToolsApp({super.key, this.serviceClient});

  /// Optional override client for testing or standalone execution.
  final CircuitryServiceClient? serviceClient;

  @override
  Widget build(BuildContext context) {
    return DevToolsExtension(
      child: Builder(
        builder: (context) {
          final client = serviceClient ?? _resolveClient();
          return MaterialApp(
            title: 'Circuitry DevTools',
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF1976D2),
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: const Color(0xFF1976D2),
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            home: CircuitryDevToolsScreen(serviceClient: client),
          );
        },
      ),
    );
  }

  CircuitryServiceClient _resolveClient() {
    final vmService = serviceManager.service;
    if (vmService != null) {
      return VmCircuitryServiceClient(vmService);
    }
    // Graceful fallback to mock data when run standalone or in tests without VM service
    return MockCircuitryServiceClient();
  }
}
