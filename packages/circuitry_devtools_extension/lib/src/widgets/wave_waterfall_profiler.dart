import 'dart:math' as math;

import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:circuitry_devtools_extension/src/models/wire_node.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:material_ui/material_ui.dart';

/// Gantt-style timeline waterfall profiler visualizing parallel topological wave execution,
/// singleton startup durations, and critical path bottlenecks.
class const WaveWaterfallProfiler({
  super.key,
  required final CircuitryDevToolsController controller,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final graph = controller.graphData;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (graph == null) {
      return Center(
        child: Text(
          'Select a circuit to view startup wave waterfall analytics.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Compute cumulative timeline offsets per wave
    // Each wave level starts when the longest async wire in the previous level finishes.
    final waveDurations = <int, int>{};
    final waveStartOffsets = <int, int>{};
    var currentOffset = 0;

    for (var level = 0; level <= graph.maxWaveLevel; level++) {
      waveStartOffsets[level] = currentOffset;
      final waveWires = graph.waves[level] ?? const [];
      var maxWaveDuration = 0;
      for (final wire in waveWires) {
        final duration = wire.durationMs ?? (wire.isAsync ? 80 : 5);
        if (duration > maxWaveDuration) {
          maxWaveDuration = duration;
        }
      }
      waveDurations[level] = maxWaveDuration;
      currentOffset += maxWaveDuration;
    }

    final totalStartupDuration = math.max(currentOffset, 1);
    final criticalPath = controller.criticalPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Header Cards
        Container(
          padding: const .all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMetricCard(
                  'Total Startup Latency',
                  '$totalStartupDuration ms',
                  Icons.timer_outlined,
                  colorScheme.primary,
                  theme,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  'Topological Waves',
                  '${graph.maxWaveLevel + 1} Waves',
                  Icons.waves,
                  Colors.teal,
                  theme,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  'Async Singletons',
                  '${graph.wires.where((w) => w.isAsync).length}',
                  Icons.cloud_sync_outlined,
                  Colors.amber.shade800,
                  theme,
                ),
                const SizedBox(width: 12),
                _buildMetricCard(
                  'Critical Path Nodes',
                  '${criticalPath.length}',
                  Icons.trending_up,
                  Colors.deepOrange,
                  theme,
                ),
              ],
            ),
          ),
        ),

        // Gantt Chart Waterfall List
        Expanded(
          child: ListView.builder(
            padding: const .all(16),
            itemCount: graph.maxWaveLevel + 1,
            itemBuilder: (context, level) {
              final waveWires = graph.waves[level] ?? const [];
              final startOffset = waveStartOffsets[level] ?? 0;
              final waveDuration = waveDurations[level] ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wave Tier Divider
                  Padding(
                    padding: const .symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Wave $level (starts at ${startOffset}ms, duration ${waveDuration}ms)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Divider(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Wire Waterfall Bars
                  for (final wire in waveWires)
                    _buildGanttBar(
                      wire: wire,
                      waveStart: startOffset,
                      totalDuration: totalStartupDuration,
                      isCritical: criticalPath.contains(wire.key),
                      theme: theme,
                    ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGanttBar({
    required WireNode wire,
    required int waveStart,
    required int totalDuration,
    required bool isCritical,
    required ThemeData theme,
  }) {
    final duration = wire.durationMs ?? (wire.isAsync ? 80 : 5);
    final leftPercent = (waveStart / totalDuration).clamp(0.0, 1.0);
    final maxAllowedWidth = math.max(0.01, 1.0 - leftPercent);
    final widthPercent = (duration / totalDuration).clamp(
      0.01,
      maxAllowedWidth,
    );

    final barColor = isCritical
        ? Colors.amber.shade700
        : (wire.isAsync ? Colors.blue.shade600 : Colors.indigo.shade300);

    return Padding(
      padding: const .symmetric(vertical: 3),
      child: InkWell(
        onTap: () => controller.selectWire(wire),
        borderRadius: const .all(.circular(4)),
        child: Padding(
          padding: const .symmetric(vertical: 2),
          child: Row(
            children: [
              // Wire Label
              SizedBox(
                width: 200,
                child: Row(
                  children: [
                    if (isCritical)
                      const Padding(
                        padding: .only(right: 4),
                        child: Icon(Icons.star, size: 12, color: Colors.amber),
                      ),
                    Expanded(
                      child: Text(
                        wire.key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isCritical
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Bar Timeline
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final barLeft = maxW * leftPercent;
                    final barWidth = maxW * widthPercent;

                    return Stack(
                      children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.2),
                            borderRadius: const .all(.circular(4)),
                          ),
                        ),
                        Positioned(
                          left: barLeft,
                          width: math.max(barWidth, 8.0),
                          child: Container(
                            height: 20,
                            padding: const .symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: const .all(.circular(4)),
                              border: isCritical
                                  ? Border.all(color: Colors.white, width: 1.2)
                                  : null,
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${duration}ms',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    ThemeData theme,
  ) {
    return RoundedOutlinedBorder(
      clip: true,
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(denseSpacing),
        color: theme.colorScheme.surfaceContainerLow,
        child: Row(
          children: [
            Icon(icon, size: 20, color: accentColor),
            const SizedBox(width: denseSpacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
