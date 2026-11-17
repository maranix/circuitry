import 'package:circuitry_flutter/circuitry_flutter.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(const CircuitryExampleApp());
}

/// Simple logging service.
final class LoggerService {
  static Wire<LoggerService> get wire => .new(LoggerService.new);

  void log(String message) {
    // ignore: avoid_print
    print('[AppLog] $message');
  }
}

/// Mock database service that requires an async connection handshake.
final class AppDatabase({
  required final String connectionString,
  final LoggerService? _logger,
}) {
  static Future<AppDatabase> connect(LoggerService logger) async {
    logger.log('Connecting to database...');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    logger.log('Database connected successfully.');
    return AppDatabase(
      connectionString: 'db://production.cluster',
      logger: logger,
    );
  }

  Future<void> close() async {
    _logger?.log('Closing database connection...');
  }
}

/// Application configuration model.
final class const AppConfig({
  required final String appName,
  required final String version,
});

/// Root application widget demonstrating [CircuitProvider].
final class const CircuitryExampleApp({super.key}) extends StatefulWidget {
  @override
  State<CircuitryExampleApp> createState() => _CircuitryExampleAppState();
}

class _CircuitryExampleAppState extends State<CircuitryExampleApp> {
  late final List<CircuitWire> _wires;

  @override
  void initState() {
    super.initState();
    // 1. Declare synchronous and asynchronous wires
    final configWire = Wire(
      () => const AppConfig(
        appName: 'Circuitry Flutter Example',
        version: '0.2.0',
      ),
    );

    // Asynchronous wire taking LoggerService with an onDispose lifecycle hook
    final dbWire = AsyncWire.takes<LoggerService>().to(
      AppDatabase.connect,
      onDispose: (db) => db.close(),
    );

    _wires = [LoggerService.wire, configWire, dbWire];
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF3F51B5),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (ctx, _, _) => builder(ctx),
      ),
      home: CircuitProvider(
        wires: _wires,
        builder: (context, state) => switch (state) {
          CircuitBuilding() => const Center(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                'Compiling dependency graph...',
                style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
              ),
            ),
          ),
          CircuitReady() => const HomeScreen(),
          CircuitFailure(:final error) => Center(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                'Initialization failed: $error',
                style: const TextStyle(color: Color(0xFFFF5252), fontSize: 16),
              ),
            ),
          ),
        },
      ),
    );
  }
}

/// Main application screen demonstrating [CircuitProvider.of].
final class const HomeScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 2. Retrieve the active circuit from BuildContext
    final circuit = CircuitProvider.of(context);
    final config = circuit.get<AppConfig>();
    final db = circuit.get<AppDatabase>();

    return Container(
      color: const Color(0xFF1E1E2E),
      alignment: Alignment.center,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                config.appName,
                style: const TextStyle(
                  color: Color(0xFF89B4FA),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Version: ${config.version}',
                style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 14),
              ),
              const SizedBox(height: 24),
              Text(
                'Active Database: ${db.connectionString}',
                style: const TextStyle(color: Color(0xFFA6E3A1), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
