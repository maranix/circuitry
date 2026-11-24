import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_graph_data.dart';
import 'package:circuitry_devtools_extension/src/models/wire_node.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:material_ui/material_ui.dart';

/// Center workspace visualizing the Directed Acyclic Graph (DAG) with topological wave columns,
/// smooth cubic Bézier splines, status styling, and dependency illumination.
class const DagCanvas({
  super.key,
  required final CircuitryDevToolsController controller,
}) extends StatefulWidget {
  @override
  State<DagCanvas> createState() => _DagCanvasState();
}

class _DagCanvasState extends State<DagCanvas> {
  final TransformationController _transformationController =
      TransformationController();

  static const double columnWidth = 230.0;
  static const double nodeWidth = 175.0;
  static const double nodeHeight = 56.0;
  static const double verticalSpacing = 28.0;
  static const double padding = 32.0;

  CircuitGraphData? _lastGraph;
  _DagCanvasLayout? _cachedLayout;

  _DagCanvasLayout _getOrCreateLayout(CircuitGraphData graph) {
    if (_lastGraph == graph && _cachedLayout != null) {
      return _cachedLayout!;
    }
    _lastGraph = graph;
    return _cachedLayout = _DagCanvasLayout.calculate(
      graph: graph,
      columnWidth: columnWidth,
      nodeWidth: nodeWidth,
      nodeHeight: nodeHeight,
      verticalSpacing: verticalSpacing,
      padding: padding,
    );
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final current = _transformationController.value;
    _transformationController.value = current.clone()
      ..scaleByDouble(1.2, 1.2, 1.0, 1.0);
  }

  void _zoomOut() {
    final current = _transformationController.value;
    _transformationController.value = current.clone()
      ..scaleByDouble(0.8, 0.8, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final graph = widget.controller.graphData;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (graph == null) {
      return Center(
        child: Text(
          'Select a circuit to view its DAG topology.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final layout = _getOrCreateLayout(graph);
    final positions = layout.positions;

    return Stack(
      children: [
        RepaintBoundary(
          child: InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            boundaryMargin: const .all(400.0),
            minScale: 0.2,
            maxScale: 2.5,
            child: SizedBox(
              width: layout.canvasWidth,
              height: layout.canvasHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Smooth Bézier Spline Edges
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _DagEdgesPainter(
                          layout: layout,
                          selectedKey: widget.controller.selectedWire?.key,
                          dependencies:
                              widget.controller.highlightedDependencies,
                          dependents: widget.controller.highlightedDependents,
                          criticalPath: widget.controller.criticalPath,
                          isDark: theme.brightness == Brightness.dark,
                        ),
                      ),
                    ),
                  ),

                  // Nodes
                  for (final wire in graph.wires)
                    if (positions.containsKey(wire.key))
                      Positioned(
                        left: positions[wire.key]!.dx,
                        top: positions[wire.key]!.dy,
                        child: _buildNodeCard(wire, theme),
                      ),
                ],
              ),
            ),
          ),
        ),

        // Zoom Controls Overlay using DevToolsButton and RoundedOutlinedBorder
        Positioned(
          right: defaultSpacing,
          bottom: defaultSpacing,
          child: RoundedOutlinedBorder(
            clip: true,
            child: Container(
              color: theme.colorScheme.surface,
              padding: const EdgeInsets.all(borderPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DevToolsButton(
                    icon: Icons.add,
                    tooltip: 'Zoom In',
                    outlined: false,
                    onPressed: _zoomIn,
                  ),
                  DevToolsButton(
                    icon: Icons.remove,
                    tooltip: 'Zoom Out',
                    outlined: false,
                    onPressed: _zoomOut,
                  ),
                  DevToolsButton(
                    icon: Icons.center_focus_strong,
                    tooltip: 'Reset Zoom (100%)',
                    outlined: false,
                    onPressed: _resetZoom,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNodeCard(WireNode wire, ThemeData theme) {
    final controller = widget.controller;
    final isSelected = controller.selectedWire?.key == wire.key;
    final isDependency = controller.highlightedDependencies.contains(wire.key);
    final isDependent = controller.highlightedDependents.contains(wire.key);
    final isCritical = controller.criticalPath.contains(wire.key);

    // Filter match evaluation
    var matchesSearch = true;
    if (controller.searchQuery.isNotEmpty) {
      final q = controller.searchQuery.toLowerCase();
      matchesSearch = wire.key.toLowerCase().contains(q);
    }

    var matchesFilter = true;
    if (controller.showUnresolvedOnly && !wire.isUnresolvedLazy) {
      matchesFilter = false;
    }
    if (controller.showAsyncOnly && !wire.isAsync) {
      matchesFilter = false;
    }

    final isDimmed =
        !matchesSearch ||
        !matchesFilter ||
        (controller.selectedWire != null &&
            !isSelected &&
            !isDependency &&
            !isDependent);

    // Status aesthetics
    final (accentColor, bgColor) = _resolveNodeTheme(wire, theme);

    return Opacity(
      opacity: isDimmed ? 0.28 : 1.0,
      child: InkWell(
        onTap: () => controller.selectWire(wire),
        splashFactory: InkRipple.splashFactory,
        borderRadius: const .all(.circular(8)),
        child: Container(
          width: nodeWidth,
          height: nodeHeight,
          padding: const .symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : bgColor,
            borderRadius: const .all(.circular(8)),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDependency
                        ? Colors.lightBlue
                        : (isDependent
                              ? Colors.purpleAccent
                              : (isCritical ? Colors.amber : accentColor))),
              width: isSelected || isDependency || isDependent || isCritical
                  ? 2.0
                  : 1.0,
            ),
            boxShadow: isSelected || isCritical
                ? [
                    BoxShadow(
                      color:
                          (isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.amber)
                              .withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(_resolveNodeIcon(wire), size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      wire.typeName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (wire.durationMs != null)
                    Text(
                      '${wire.durationMs}ms',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const .symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: const .all(.circular(3)),
                        ),
                        child: Text(
                          wire.isAsync ? 'async' : 'lazy',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (wire.tag != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const .symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.6),
                            borderRadius: const .all(.circular(3)),
                          ),
                          child: Text(
                            '#${wire.tag}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    wire.isInitialized
                        ? 'Ready'
                        : (wire.hasFailed
                              ? 'Failed'
                              : (wire.isResolving
                                    ? 'Resolving...'
                                    : 'Sleeping')),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accentColor,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _resolveNodeTheme(WireNode wire, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    if (wire.hasFailed) {
      return (
        Colors.red.shade700,
        isDark ? const Color(0xFF3B1E1E) : Colors.red.shade50,
      );
    }
    if (wire.isResolving) {
      return (
        Colors.amber.shade800,
        isDark ? const Color(0xFF3B331E) : Colors.amber.shade50,
      );
    }
    if (wire.isInitialized) {
      return (
        Colors.green.shade700,
        isDark ? const Color(0xFF1E3B24) : Colors.green.shade50,
      );
    }
    // Unresolved Lazy
    return (
      Colors.indigo.shade400,
      isDark
          ? const Color(0xFF23253A)
          : Colors.indigo.shade50.withValues(alpha: 0.4),
    );
  }

  IconData _resolveNodeIcon(WireNode wire) {
    if (wire.hasFailed) return Icons.error_outline;
    if (wire.isResolving) return Icons.hourglass_top;
    if (wire.isInitialized) return Icons.check_circle_outline;
    return wire.isAsync ? Icons.cloud_queue : Icons.nightlight_outlined;
  }
}

class _CachedEdge {
  final String sourceKey;
  final String targetKey;
  final Path path;

  const _CachedEdge({
    required this.sourceKey,
    required this.targetKey,
    required this.path,
  });
}

class _DagCanvasLayout {
  final Map<String, Offset> positions;
  final double canvasWidth;
  final double canvasHeight;
  final List<_CachedEdge> edges;
  final Path allEdgesCombinedPath;

  const _DagCanvasLayout({
    required this.positions,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.edges,
    required this.allEdgesCombinedPath,
  });

  factory _DagCanvasLayout.calculate({
    required CircuitGraphData graph,
    required double columnWidth,
    required double nodeWidth,
    required double nodeHeight,
    required double verticalSpacing,
    required double padding,
  }) {
    final positions = <String, Offset>{};
    var maxRowCount = 0;

    for (var level = 0; level <= graph.maxWaveLevel; level++) {
      final waveWires = graph.waves[level] ?? const [];
      if (waveWires.length > maxRowCount) {
        maxRowCount = waveWires.length;
      }
      final x = padding + level * columnWidth;
      for (var row = 0; row < waveWires.length; row++) {
        final y = padding + row * (nodeHeight + verticalSpacing);
        positions[waveWires[row].key] = Offset(x, y);
      }
    }

    final canvasWidth = padding * 2 + (graph.maxWaveLevel + 1) * columnWidth;
    final canvasHeight =
        padding * 2 + maxRowCount * (nodeHeight + verticalSpacing) + 60.0;

    final edges = <_CachedEdge>[];
    final combinedPath = Path();

    for (final wire in graph.wires) {
      final targetPos = positions[wire.key];
      if (targetPos == null) continue;

      for (final depKey in wire.dependencies) {
        final sourcePos = positions[depKey];
        if (sourcePos == null) continue;

        final sx = sourcePos.dx + nodeWidth;
        final sy = sourcePos.dy + nodeHeight / 2;
        final tx = targetPos.dx;
        final ty = targetPos.dy + nodeHeight / 2;
        final mx = (sx + tx) / 2;

        final edgePath = Path()
          ..moveTo(sx, sy)
          ..cubicTo(mx, sy, mx, ty, tx, ty);

        combinedPath.moveTo(sx, sy);
        combinedPath.cubicTo(mx, sy, mx, ty, tx, ty);

        edges.add(
          _CachedEdge(sourceKey: depKey, targetKey: wire.key, path: edgePath),
        );
      }
    }

    return _DagCanvasLayout(
      positions: positions,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      edges: edges,
      allEdgesCombinedPath: combinedPath,
    );
  }
}

class _DagEdgesPainter extends CustomPainter {
  final _DagCanvasLayout layout;
  final String? selectedKey;
  final Set<String> dependencies;
  final Set<String> dependents;
  final Set<String> criticalPath;
  final bool isDark;

  const _DagEdgesPainter({
    required this.layout,
    required this.selectedKey,
    required this.dependencies,
    required this.dependents,
    required this.criticalPath,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedKey == null) {
      // FAST PATH: All edges styled identically - draw everything in a single draw call.
      final defaultPaint = Paint()
        ..color = isDark ? const Color(0xFF606060) : const Color(0xFFB0B0B0)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(layout.allEdgesCombinedPath, defaultPaint);
      return;
    }

    // Partition edges and batch dimmed edges into one single path.
    final dimmedPath = Path();
    var hasDimmed = false;

    final selectedDepPaint = Paint()
      ..color = Colors.lightBlue
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final selectedDependentPaint = Paint()
      ..color = Colors.purpleAccent
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final criticalPaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dimmedPaint = Paint()
      ..color = isDark ? const Color(0xFF404040) : const Color(0xFFD0D0D0)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final edge in layout.edges) {
      final isUpstream =
          selectedKey == edge.targetKey &&
          dependencies.contains(edge.sourceKey);
      final isDownstream =
          selectedKey == edge.sourceKey && dependents.contains(edge.targetKey);
      final isCritical =
          criticalPath.contains(edge.sourceKey) &&
          criticalPath.contains(edge.targetKey);

      if (isUpstream) {
        canvas.drawPath(edge.path, selectedDepPaint);
      } else if (isDownstream) {
        canvas.drawPath(edge.path, selectedDependentPaint);
      } else if (isCritical) {
        canvas.drawPath(edge.path, criticalPaint);
      } else {
        dimmedPath.addPath(edge.path, Offset.zero);
        hasDimmed = true;
      }
    }

    if (hasDimmed) {
      canvas.drawPath(dimmedPath, dimmedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DagEdgesPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.selectedKey != selectedKey ||
      oldDelegate.dependencies != dependencies ||
      oldDelegate.dependents != dependents ||
      oldDelegate.criticalPath != criticalPath ||
      oldDelegate.isDark != isDark;
}
