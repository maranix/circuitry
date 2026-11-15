import 'package:circuitry/circuitry.dart';

/// Supported deployment environments for tagged dependencies.
enum Environment { dev, prod }

/// Configuration class demonstrating primary constructors.
final class DatabaseConfig {
  const DatabaseConfig({required this.host, required this.port});

  final String host;
  final int port;
}

/// Simulated database service with asynchronous initialization and disposal.
final class DatabaseService {
  DatabaseService({required this.config, required this.sessionId});

  final DatabaseConfig config;
  final String sessionId;

  static Future<DatabaseService> connect(DatabaseConfig config) async {
    // Simulate asynchronous connection handshake
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return DatabaseService(
      config: config,
      sessionId: 'session-${config.host}-${config.port}',
    );
  }

  Future<void> close() async {
    // Teardown resource on circuit disposal
  }
}

/// Authentication service depending synchronously on [DatabaseService].
final class AuthService {
  const AuthService({required this.database});

  final DatabaseService database;

  bool authenticate(String token) => token.isNotEmpty;
}

/// User domain service depending on both [AuthService] and [DatabaseService].
final class UserService {
  const UserService({required this.auth, required this.database});

  final AuthService auth;
  final DatabaseService database;

  String getUserStatus(String userId) {
    if (!auth.authenticate('valid-token')) {
      return 'unauthenticated';
    }
    return 'active (db: ${database.sessionId})';
  }
}

void main() async {
  // 1. Declare wires with synchronous, asynchronous, and tagged dependencies
  final devConfigWire = Wire.tag(
    () => const DatabaseConfig(host: 'localhost', port: 5432),
    tag: Environment.dev,
  );

  final prodConfigWire = Wire.tag(
    () => const DatabaseConfig(host: 'db.prod.internal', port: 5432),
    tag: Environment.prod,
  );

  // Asynchronous wire taking tagged DatabaseConfig with an onDispose hook
  final dbWire = AsyncWire.takesTagged<DatabaseConfig, Environment>(
    Environment.prod,
  ).to(DatabaseService.connect, onDispose: (db) => db.close());

  // Synchronous wire taking DatabaseService via constructor tear-off
  final authWire = Wire.takes<DatabaseService>().to(
    (db) => AuthService(database: db),
  );

  // Multi-dependency wire chaining AuthService and DatabaseService
  final userWire = Wire.takes<AuthService>().takes<DatabaseService>().to(
    (deps) => UserService(auth: deps.$1, database: deps.$2),
  );

  // 2. Validate DAG and compile circuit with parallel topological wave resolution
  final circuit = await Circuit.build([
    devConfigWire,
    prodConfigWire,
    dbWire,
    authWire,
    userWire,
  ]);

  // 3. Synchronous O(1) instance lookup
  final userService = circuit.get<UserService>();
  // ignore: avoid_print
  print('User status: ${userService.getUserStatus('user-42')}');

  // 4. Tagged lookup with Dart dot-shorthands
  final prodConfig = circuit.getTagged<DatabaseConfig, Environment>(
    Environment.prod,
  );
  // ignore: avoid_print
  print('Connected to host: ${prodConfig.host}');

  // 5. Reverse topological wave teardown (UserService/AuthService -> DatabaseService -> Config)
  await circuit.dispose();
  // ignore: avoid_print
  print('Circuit successfully disposed.');
}
