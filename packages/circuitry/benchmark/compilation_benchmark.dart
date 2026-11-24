// ignore_for_file: avoid_print

import 'package:circuitry/circuitry.dart';
import 'package:circuitry/src/graph.dart';

/// Global volatile blackhole sink to prevent Dead-Code Elimination (DCE).
@pragma('vm:entry-point')
Object? blackhole;

class _BenchmarkAction implements CircuitAction {
  final String dep;
  _BenchmarkAction(this.dep);
  String call() => dep;
}

// Helper to generate synthetic DAG of N nodes with multiple topological levels
List<CircuitWire> _generateDag(int size) {
  final wires = <CircuitWire>[];

  // Root wires (Level 0)
  final rootCount = (size * 0.2).clamp(2, 20).toInt();
  for (var i = 0; i < rootCount; i++) {
    wires.add(
      Wire.tag(
        () => 'root_$i',
        tag: _IndexTag.values[i % _IndexTag.values.length],
      ),
    );
  }

  // Dependent wires (Levels 1+)
  for (var i = rootCount; i < size; i++) {
    final depIndex = (i - 1) % rootCount;
    final tag = _IndexTag.values[i % _IndexTag.values.length];
    final depTag = _IndexTag.values[depIndex % _IndexTag.values.length];

    if (i % 5 == 0) {
      wires.add(
        TriggerWire.takesTagged<String, _IndexTag>(depTag)
            .to((dep) => _BenchmarkAction(dep), tag: tag),
      );
    } else {
      wires.add(
        Wire.takesTagged<String, _IndexTag>(depTag)
            .to((dep) => 'node_${i}_from_$dep', tag: tag),
      );
    }
  }

  return wires;
}

enum _IndexTag {
  t0,
  t1,
  t2,
  t3,
  t4,
  t5,
  t6,
  t7,
  t8,
  t9,
  t10,
  t11,
  t12,
  t13,
  t14,
  t15,
  t16,
  t17,
  t18,
  t19,
  t20,
  t21,
  t22,
  t23,
  t24,
  t25,
  t26,
  t27,
  t28,
  t29,
  t30,
  t31,
  t32,
  t33,
  t34,
  t35,
  t36,
  t37,
  t38,
  t39,
  t40,
  t41,
  t42,
  t43,
  t44,
  t45,
  t46,
  t47,
  t48,
  t49,
  t50,
  t51,
  t52,
  t53,
  t54,
  t55,
  t56,
  t57,
  t58,
  t59,
  t60,
  t61,
  t62,
  t63,
  t64,
  t65,
  t66,
  t67,
  t68,
  t69,
  t70,
  t71,
  t72,
  t73,
  t74,
  t75,
  t76,
  t77,
  t78,
  t79,
  t80,
  t81,
  t82,
  t83,
  t84,
  t85,
  t86,
  t87,
  t88,
  t89,
  t90,
  t91,
  t92,
  t93,
  t94,
  t95,
  t96,
  t97,
  t98,
  t99,
}

void main() async {
  print('================================================================');
  print('         CIRCUITRY DAG COMPILATION BENCHMARK SUITE              ');
  print('================================================================');

  final dag10 = _generateDag(10);
  final dag35 = _generateDag(35);
  final dag100 = _generateDag(100);

  const warmupRounds = 500;
  const benchmarkRounds = 2000;
  const sampleRounds = 7;

  _benchmark(
    name: 'CircuitGraph.compile() [10 nodes - Micro DAG]',
    warmup: () {
      for (var i = 0; i < warmupRounds; i++) {
        blackhole = CircuitGraph(dag10).compile();
      }
    },
    run: () {
      for (var i = 0; i < benchmarkRounds; i++) {
        blackhole = CircuitGraph(dag10).compile();
      }
    },
    iterations: benchmarkRounds,
    rounds: sampleRounds,
  );

  _benchmark(
    name: 'CircuitGraph.compile() [35 nodes - Standard Feature DAG]',
    warmup: () {
      for (var i = 0; i < warmupRounds; i++) {
        blackhole = CircuitGraph(dag35).compile();
      }
    },
    run: () {
      for (var i = 0; i < benchmarkRounds; i++) {
        blackhole = CircuitGraph(dag35).compile();
      }
    },
    iterations: benchmarkRounds,
    rounds: sampleRounds,
  );

  _benchmark(
    name: 'CircuitGraph.compile() [100 nodes - Enterprise Monolith DAG]',
    warmup: () {
      for (var i = 0; i < warmupRounds ~/ 2; i++) {
        blackhole = CircuitGraph(dag100).compile();
      }
    },
    run: () {
      for (var i = 0; i < benchmarkRounds ~/ 2; i++) {
        blackhole = CircuitGraph(dag100).compile();
      }
    },
    iterations: benchmarkRounds ~/ 2,
    rounds: sampleRounds,
  );

  if (blackhole == null) {
    throw StateError(
      'Sanity check failed: blackhole sink was unexpectedly null.',
    );
  }

  print('\n================================================================');
}

void _benchmark({
  required String name,
  required void Function() warmup,
  required void Function() run,
  required int iterations,
  required int rounds,
}) {
  warmup();

  final times = <int>[]; // microseconds
  for (var r = 0; r < rounds; r++) {
    final sw = Stopwatch()..start();
    run();
    sw.stop();
    times.add(sw.elapsedMicroseconds);
  }

  times.sort();
  final trimmed = times.sublist(1, rounds - 1);
  final medianMicros = trimmed[trimmed.length ~/ 2];
  final microsPerOp = medianMicros / iterations;
  final opsPerSec = (iterations / (medianMicros / 1000000)).round();

  print(
    '  $name:\n'
    '    Median: ${(medianMicros / 1000).toStringAsFixed(2)} ms '
    '(${microsPerOp.toStringAsFixed(2)} µs/compilation) '
    '| ${_formatNumber(opsPerSec)} compilations/sec',
  );
}

String _formatNumber(int number) => number.toString().replaceAllMapped(
  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);
