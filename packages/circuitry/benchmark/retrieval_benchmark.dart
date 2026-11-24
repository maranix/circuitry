// ignore_for_file: avoid_print

import 'package:circuitry/circuitry.dart';

// Test service models for dependency injection benchmarks
class ConfigService {
  final String env;
  ConfigService(this.env);
}

class DatabaseService {
  final ConfigService config;
  DatabaseService(this.config);
}

class UserService {
  final DatabaseService db;
  UserService(this.db);
}

class OrderService {
  final UserService users;
  final DatabaseService db;
  OrderService(this.users, this.db);
}

class NotificationService {
  final OrderService orders;
  NotificationService(this.orders);
}

enum AppScope { global, feature }

class TaggedService {
  final String label;
  TaggedService(this.label);
}

/// Global volatile blackhole sink to prevent Dead-Code Elimination (DCE).
/// Writing to this top-level variable prevents the Dart compiler (JIT and AOT)
/// from optimizing away dependency retrieval loops or treating returned objects as dead.
@pragma('vm:entry-point')
Object? blackhole;

void main() async {
  final circuit = await Circuit.build([
    Wire(() => ConfigService('prod')),
    Wire.takes<ConfigService>().to(DatabaseService.new),
    Wire.takes<DatabaseService>().to(UserService.new),
    Wire.takes<UserService>().takes<DatabaseService>().to(
      (deps) => OrderService(deps.$1, deps.$2),
    ),
    Wire.takes<OrderService>().to(NotificationService.new),
    Wire.tag(() => TaggedService('global-auth'), tag: AppScope.global),
    Wire.tag(() => TaggedService('feature-cart'), tag: AppScope.feature),
  ]);

  // Pre-instantiate all singletons so benchmarks strictly measure cached hot-path retrieval.
  circuit.get<ConfigService>();
  circuit.get<DatabaseService>();
  circuit.get<UserService>();
  circuit.get<OrderService>();
  circuit.get<NotificationService>();
  circuit.getTagged<TaggedService, AppScope>(AppScope.global);
  circuit.getTagged<TaggedService, AppScope>(AppScope.feature);

  print('================================================================');
  print('          CIRCUITRY HOT-PATH RETRIEVAL BENCHMARK SUITE          ');
  print('================================================================');

  const warmupIterations = 300000;
  const benchmarkIterations = 1000000;
  const sampleRounds = 7;

  // Step 1: Calibrate empty loop baseline overhead
  final loopOverheadMicros = _calibrateLoopOverhead(
    iterations: benchmarkIterations,
    rounds: sampleRounds,
  );
  final loopNsPerOp = (loopOverheadMicros / benchmarkIterations) * 1000;
  print(
    '  [Baseline Loop Calibration]: ${loopOverheadMicros / 1000} ms '
    '(${loopNsPerOp.toStringAsFixed(2)} ns/empty-iter)\n',
  );

  // Benchmark 1: Monomorphic Untagged Root Singleton (ConfigService)
  _benchmark(
    name: 'Monomorphic: circuit.get<ConfigService>() [Untagged Root]',
    warmup: () {
      for (var i = 0; i < warmupIterations; i++) {
        blackhole = circuit.get<ConfigService>();
      }
    },
    run: () {
      for (var i = 0; i < benchmarkIterations; i++) {
        blackhole = circuit.get<ConfigService>();
      }
    },
    iterations: benchmarkIterations,
    rounds: sampleRounds,
    loopOverheadMicros: loopOverheadMicros,
  );

  // Benchmark 2: Monomorphic Untagged Leaf Singleton (NotificationService - Depth 4)
  _benchmark(
    name: 'Monomorphic: circuit.get<NotificationService>() [Untagged Leaf]',
    warmup: () {
      for (var i = 0; i < warmupIterations; i++) {
        blackhole = circuit.get<NotificationService>();
      }
    },
    run: () {
      for (var i = 0; i < benchmarkIterations; i++) {
        blackhole = circuit.get<NotificationService>();
      }
    },
    iterations: benchmarkIterations,
    rounds: sampleRounds,
    loopOverheadMicros: loopOverheadMicros,
  );

  // Benchmark 3: Polymorphic / Interleaved Multi-Service Retrieval (5 services round-robin)
  // Simulates real-world application code querying multiple distinct services in succession.
  _benchmark(
    name: 'Interleaved: 5 distinct services in rotation [Polymorphic Cache]',
    warmup: () {
      for (var i = 0; i < warmupIterations ~/ 5; i++) {
        blackhole = circuit.get<ConfigService>();
        blackhole = circuit.get<DatabaseService>();
        blackhole = circuit.get<UserService>();
        blackhole = circuit.get<OrderService>();
        blackhole = circuit.get<NotificationService>();
      }
    },
    run: () {
      const rounds = benchmarkIterations ~/ 5;
      for (var i = 0; i < rounds; i++) {
        blackhole = circuit.get<ConfigService>();
        blackhole = circuit.get<DatabaseService>();
        blackhole = circuit.get<UserService>();
        blackhole = circuit.get<OrderService>();
        blackhole = circuit.get<NotificationService>();
      }
    },
    iterations: benchmarkIterations,
    rounds: sampleRounds,
    loopOverheadMicros: loopOverheadMicros,
  );

  // Benchmark 4: Tagged Singleton Retrieval (TaggedService with AppScope.global)
  _benchmark(
    name: 'Tagged: circuit.getTagged<TaggedService, AppScope>(.global)',
    warmup: () {
      for (var i = 0; i < warmupIterations; i++) {
        blackhole = circuit.getTagged<TaggedService, AppScope>(AppScope.global);
      }
    },
    run: () {
      for (var i = 0; i < benchmarkIterations; i++) {
        blackhole = circuit.getTagged<TaggedService, AppScope>(AppScope.global);
      }
    },
    iterations: benchmarkIterations,
    rounds: sampleRounds,
    loopOverheadMicros: loopOverheadMicros,
  );

  // Blackhole sanity verification: ensure optimizer didn't discard assignments
  if (blackhole == null) {
    throw StateError(
      'Sanity check failed: blackhole sink was unexpectedly null.',
    );
  }

  print('\n================================================================');
  await circuit.dispose();
}

int _calibrateLoopOverhead({required int iterations, required int rounds}) {
  final times = <int>[];
  for (var r = 0; r < rounds; r++) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      blackhole = null;
    }
    sw.stop();
    times.add(sw.elapsedMicroseconds);
  }
  times.sort();
  return times[rounds ~/ 2];
}

void _benchmark({
  required String name,
  required void Function() warmup,
  required void Function() run,
  required int iterations,
  required int rounds,
  required int loopOverheadMicros,
}) {
  warmup();

  final times = <int>[]; // microseconds
  for (var r = 0; r < rounds; r++) {
    final sw = Stopwatch()..start();
    run();
    sw.stop();
    times.add(sw.elapsedMicroseconds);
  }

  // Trim min and max outliers to isolate JIT GC/OS preemption spikes
  times.sort();
  final trimmed = times.sublist(1, rounds - 1);
  final medianMicros = trimmed[trimmed.length ~/ 2];

  final grossMicrosPerOp = medianMicros / iterations;
  final grossOpsPerSec = (iterations / (medianMicros / 1000000)).round();

  // Net timing (subtracting calibrated loop overhead)
  final netMicros = (medianMicros - loopOverheadMicros)
      .clamp(1, double.infinity)
      .toInt();
  final netNsPerOp = (netMicros / iterations) * 1000;
  final netOpsPerSec = (iterations / (netMicros / 1000000)).round();

  print(
    '  $name:\n'
    '    Gross: ${(medianMicros / 1000).toStringAsFixed(2)} ms '
    '(${(grossMicrosPerOp * 1000).toStringAsFixed(2)} ns/op) '
    '| ${_formatNumber(grossOpsPerSec)} ops/sec\n'
    '    Net:   ${(netMicros / 1000).toStringAsFixed(2)} ms '
    '(${netNsPerOp.toStringAsFixed(2)} ns/op) '
    '| ${_formatNumber(netOpsPerSec)} net-ops/sec',
  );
}

String _formatNumber(int number) => number.toString().replaceAllMapped(
  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);
