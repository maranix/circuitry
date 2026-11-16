// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:circuitry_devtools_extension/src/model/circuit_devtools_models.dart';
import 'package:flutter/material.dart';

/// Displays an interactive Gantt / waterfall timeline of wave-based wire execution,
/// illustrating parallel resolution within each topological wave and highlighting
/// the DAG critical path.
class WaveProfiler extends StatefulWidget {
  /// All wire models in the inspected circuit.
  final List<WireModel> wires;

  /// The list of wire keys on the DAG critical path.
  final List<String> criticalPath;

  /// Total duration of the circuit compilation/resolution, if known.
  final Duration? totalDuration;

  /// Callback triggered when a wire bar is clicked to inspect it.
  final ValueChanged<String>? onSelectWire;

  /// Currently selected wire key, if any.
  final String? selectedWireKey;

  /// Creates a [WaveProfiler].
  const WaveProfiler({
    super.key,
    required this.wires,
    this.criticalPath = const [],
    this.totalDuration,
    this.onSelectWire,
    this.selectedWireKey,
  });

  @override
  State<WaveProfiler> createState() => _WaveProfilerState();
}

class _WaveProfilerState extends State<WaveProfiler> {
  bool _highlightCriticalPathOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.wires.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24.0),
        alignment: Alignment.center,
        child: Text(
          'No wires available for wave profiling.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.outline,
          ),
        ),
      );
    }

    // Group wires by wave level
    final waves = <int, List<WireModel>>{};
    for (final wire in widget.wires) {
      waves.putIfAbsent(wire.waveLevel, () => []).add(wire);
    }
    final sortedWaveLevels = waves.keys.toList()..sort();

    // Compute wave start times and durations in microseconds
    final waveDurationsMicros = <int, int>{};
    for (final waveLevel in sortedWaveLevels) {
      final waveWires = waves[waveLevel]!;
      int maxWireDuration = 0;
      for (final wire in waveWires) {
        final d = wire.resolutionDuration?.inMicroseconds ?? 1000;
        if (d > maxWireDuration) {
          maxWireDuration = d;
        }
      }
      waveDurationsMicros[waveLevel] = math.max(maxWireDuration, 1000);
    }

    final waveStartTimesMicros = <int, int>{};
    int runningOffset = 0;
    for (final waveLevel in sortedWaveLevels) {
      waveStartTimesMicros[waveLevel] = runningOffset;
      runningOffset += waveDurationsMicros[waveLevel]!;
    }
    final totalComputedMicros = math.max(
      runningOffset,
      widget.totalDuration?.inMicroseconds ?? 1000,
    );

    final criticalSet = widget.criticalPath.toSet();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Toolbar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.25,
              ),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    Icons.waterfall_chart,
                    size: 20.0,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Wave Profiler & Critical Path',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12.0),

                  // Metrics badges
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      '${sortedWaveLevels.length} Waves',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade50,
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: Colors.deepOrange.shade200),
                    ),
                    child: Text(
                      'Critical Path: ${widget.criticalPath.length} nodes',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.deepOrange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      'Total: ${_formatMicros(totalComputedMicros)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                  const SizedBox(width: 24.0),

                  // Toggle critical path filter
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Critical Path Only',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      Switch(
                        value: _highlightCriticalPathOnly,
                        onChanged: (val) {
                          setState(() {
                            _highlightCriticalPathOnly = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Waterfall Gantt chart
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const labelColumnWidth = 220.0;
                final timelineWidth = math.max(
                  constraints.maxWidth - labelColumnWidth - 32.0,
                  300.0,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeline Axis Header
                      Padding(
                        padding: const EdgeInsets.only(
                          left: labelColumnWidth,
                          bottom: 8.0,
                        ),
                        child: _buildTimeAxis(
                          context,
                          totalDurationMicros: totalComputedMicros,
                          width: timelineWidth,
                        ),
                      ),

                      // Wave rows
                      for (final waveLevel in sortedWaveLevels) ...[
                        _buildWaveSection(
                          context,
                          waveLevel: waveLevel,
                          wires: waves[waveLevel]!,
                          waveStartTimeMicros: waveStartTimesMicros[waveLevel]!,
                          waveDurationMicros: waveDurationsMicros[waveLevel]!,
                          totalDurationMicros: totalComputedMicros,
                          criticalSet: criticalSet,
                          labelColumnWidth: labelColumnWidth,
                          timelineWidth: timelineWidth,
                        ),
                        const SizedBox(height: 10.0),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAxis(
    BuildContext context, {
    required int totalDurationMicros,
    required double width,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const tickCount = 4;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(tickCount + 1, (i) {
        final progress = i / tickCount;
        final micros = (totalDurationMicros * progress).round();
        return Text(
          _formatMicros(micros),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.outline,
            fontSize: 10.0,
          ),
        );
      }),
    );
  }

  Widget _buildWaveSection(
    BuildContext context, {
    required int waveLevel,
    required List<WireModel> wires,
    required int waveStartTimeMicros,
    required int waveDurationMicros,
    required int totalDurationMicros,
    required Set<String> criticalSet,
    required double labelColumnWidth,
    required double timelineWidth,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayWires = _highlightCriticalPathOnly
        ? wires.where((w) => criticalSet.contains(w.key)).toList()
        : wires;

    if (displayWires.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wave Section Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 6.0,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5.0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 14.0,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6.0),
                Text(
                  'Wave $waveLevel',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8.0),
                Text(
                  '(${displayWires.length} wires, max ${_formatMicros(waveDurationMicros)})',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),

          // Wire Gantt Bars
          for (final wire in displayWires)
            _buildWireGanttRow(
              context,
              wire: wire,
              waveStartTimeMicros: waveStartTimeMicros,
              totalDurationMicros: totalDurationMicros,
              isCriticalPath: criticalSet.contains(wire.key),
              labelColumnWidth: labelColumnWidth,
              timelineWidth: timelineWidth,
            ),
        ],
      ),
    );
  }

  Widget _buildWireGanttRow(
    BuildContext context, {
    required WireModel wire,
    required int waveStartTimeMicros,
    required int totalDurationMicros,
    required bool isCriticalPath,
    required double labelColumnWidth,
    required double timelineWidth,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = wire.key == widget.selectedWireKey;

    final wireMicros = wire.resolutionDuration?.inMicroseconds ?? 1000;
    final startRatio = waveStartTimeMicros / totalDurationMicros;
    final widthRatio = math.max(wireMicros / totalDurationMicros, 0.02);

    final leftOffset = (startRatio * timelineWidth).clamp(0.0, timelineWidth);
    final barWidth = (widthRatio * timelineWidth).clamp(
      28.0,
      timelineWidth - leftOffset,
    );

    Color barColor;
    if (isCriticalPath) {
      barColor = const Color(0xFFE64A19);
    } else if (wire.isAsync) {
      barColor = const Color(0xFF1976D2);
    } else if (wire.status.toLowerCase() == 'unresolvedlazy' ||
        wire.status.toLowerCase() == 'lazy') {
      barColor = const Color(0xFF7B1FA2);
    } else if (wire.status.toLowerCase() == 'failed') {
      barColor = const Color(0xFFD32F2F);
    } else {
      barColor = const Color(0xFF2E7D32);
    }

    return InkWell(
      onTap: () => widget.onSelectWire?.call(wire.key),
      child: Container(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
        child: Row(
          children: [
            // Left label column
            SizedBox(
              width: labelColumnWidth,
              child: Row(
                children: [
                  if (isCriticalPath)
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Icon(
                        Icons.local_fire_department,
                        size: 14.0,
                        color: Colors.deepOrange.shade700,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      wire.typeName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (wire.tag != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        '#${wire.tag}',
                        style: TextStyle(
                          fontSize: 10.0,
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Timeline bar column
            Expanded(
              child: SizedBox(
                height: 22.0,
                child: Stack(
                  children: [
                    // Positioned Bar
                    Positioned(
                      left: leftOffset,
                      width: barWidth,
                      top: 2.0,
                      bottom: 2.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4.0),
                          boxShadow: isCriticalPath
                              ? [
                                  BoxShadow(
                                    color: Colors.deepOrange.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 4.0,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text(
                          _formatMicros(wireMicros),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMicros(int micros) {
    if (micros >= 1000) {
      final ms = micros / 1000.0;
      return '${ms.toStringAsFixed(1)} ms';
    }
    return '$micros µs';
  }
}
