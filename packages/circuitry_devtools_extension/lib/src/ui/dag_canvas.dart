// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:circuitry_devtools_extension/src/layout/sugiyama_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Canvas widget for rendering the Directed Acyclic Graph (DAG) with wave columns,
/// cubic Bézier edge splines, and interactive node selection and inspection.
class DagCanvas extends StatefulWidget {
  /// The laid-out DAG graph computed by [SugiyamaLayout].
  final LayoutGraph graph;

  /// Identifier of the currently selected node, if any.
  final String? selectedNodeId;

  /// Callback triggered when a node is clicked or selected.
  final ValueChanged<String>? onNodeSelected;

  /// Horizontal column width allocated for each topological wave.
  final double columnWidth;

  /// Creates a [DagCanvas].
  const DagCanvas({
    super.key,
    required this.graph,
    this.selectedNodeId,
    this.onNodeSelected,
    this.columnWidth = 240.0,
  });

  @override
  State<DagCanvas> createState() => _DagCanvasState();
}

class _DagCanvasState extends State<DagCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final TransformationController _transformationController =
      TransformationController();
  String? _hoveredNodeId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    final hasResolving = widget.graph.nodes.any(
      (n) => n.status.toLowerCase() == 'resolving',
    );
    if (hasResolving) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(DagCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasResolving = widget.graph.nodes.any(
      (n) => n.status.toLowerCase() == 'resolving',
    );
    if (hasResolving && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!hasResolving && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  LayoutNode? _hitTestNode(Offset localPosition) {
    for (final node in widget.graph.nodes) {
      final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
      if (rect.contains(localPosition)) {
        return node;
      }
    }
    return null;
  }

  void _onTapUp(TapUpDetails details) {
    final tapped = _hitTestNode(details.localPosition);
    if (tapped != null) {
      widget.onNodeSelected?.call(tapped.id);
    }
  }

  void _onHover(PointerHoverEvent event) {
    final hovered = _hitTestNode(event.localPosition);
    final hoveredId = hovered?.id;
    if (hoveredId != _hoveredNodeId) {
      setState(() {
        _hoveredNodeId = hoveredId;
      });
    }
  }

  void _onExit(PointerExitEvent event) {
    if (_hoveredNodeId != null) {
      setState(() {
        _hoveredNodeId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.graph.nodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 48.0,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 12.0),
            Text(
              'No wires registered in this circuit.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Determine canvas canvas dimensions
    final canvasWidth = math.max(widget.graph.totalWidth + 120.0, 900.0);
    final canvasHeight = math.max(widget.graph.totalHeight + 140.0, 600.0);

    final activeNodeId = widget.selectedNodeId ?? _hoveredNodeId;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(400.0),
            minScale: 0.2,
            maxScale: 2.5,
            child: MouseRegion(
              onHover: _onHover,
              onExit: _onExit,
              child: GestureDetector(
                onTapUp: _onTapUp,
                child: SizedBox(
                  width: canvasWidth,
                  height: canvasHeight,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(canvasWidth, canvasHeight),
                        painter: _DagPainter(
                          graph: widget.graph,
                          activeNodeId: activeNodeId,
                          selectedNodeId: widget.selectedNodeId,
                          pulseValue: _pulseController.value,
                          colorScheme: colorScheme,
                          columnWidth: widget.columnWidth,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Zoom / Reset Controls floating overlay
          Positioned(
            right: 16.0,
            bottom: 16.0,
            child: Material(
              elevation: 3.0,
              borderRadius: BorderRadius.circular(24.0),
              color: colorScheme.surfaceContainerHigh,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_in, size: 20.0),
                    tooltip: 'Zoom In',
                    onPressed: () {
                      final matrix = _transformationController.value.clone();
                      matrix.scaleByDouble(1.2, 1.2, 1.0, 1.0);
                      _transformationController.value = matrix;
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, size: 20.0),
                    tooltip: 'Zoom Out',
                    onPressed: () {
                      final matrix = _transformationController.value.clone();
                      matrix.scaleByDouble(0.8, 0.8, 1.0, 1.0);
                      _transformationController.value = matrix;
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.center_focus_strong, size: 20.0),
                    tooltip: 'Reset View',
                    onPressed: () {
                      _transformationController.value = Matrix4.identity();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DagPainter extends CustomPainter {
  final LayoutGraph graph;
  final String? activeNodeId;
  final String? selectedNodeId;
  final double pulseValue;
  final ColorScheme colorScheme;
  final double columnWidth;

  late final Set<String> _upstreamEdgeKeys;
  late final Set<String> _downstreamEdgeKeys;

  _DagPainter({
    required this.graph,
    required this.activeNodeId,
    required this.selectedNodeId,
    required this.pulseValue,
    required this.colorScheme,
    required this.columnWidth,
  }) {
    _computeEdgeHighlights();
  }

  void _computeEdgeHighlights() {
    _upstreamEdgeKeys = {};
    _downstreamEdgeKeys = {};

    if (activeNodeId == null || activeNodeId!.isEmpty) return;

    // Upstream dependency traversal (edges leading to active node)
    final visitedUpstream = <String>{activeNodeId!};
    final queueUp = <String>[activeNodeId!];
    while (queueUp.isNotEmpty) {
      final current = queueUp.removeAt(0);
      for (final edge in graph.edges) {
        if (edge.toId == current) {
          _upstreamEdgeKeys.add('${edge.fromId}->${edge.toId}');
          if (visitedUpstream.add(edge.fromId)) {
            queueUp.add(edge.fromId);
          }
        }
      }
    }

    // Downstream dependent traversal (edges originating from active node)
    final visitedDownstream = <String>{activeNodeId!};
    final queueDown = <String>[activeNodeId!];
    while (queueDown.isNotEmpty) {
      final current = queueDown.removeAt(0);
      for (final edge in graph.edges) {
        if (edge.fromId == current) {
          _downstreamEdgeKeys.add('${edge.fromId}->${edge.toId}');
          if (visitedDownstream.add(edge.toId)) {
            queueDown.add(edge.toId);
          }
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawWaveHeaders(canvas, size);
    _drawEdges(canvas);
    _drawNodes(canvas);
  }

  void _drawWaveHeaders(Canvas canvas, Size size) {
    if (graph.nodes.isEmpty) return;

    final maxWave = graph.nodes
        .map((n) => n.waveLevel)
        .fold(0, (prev, elem) => math.max(prev, elem));

    final headerTextPainter = TextPainter(textDirection: TextDirection.ltr);

    final linePaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var wave = 0; wave <= maxWave; wave++) {
      // Find sample node in this wave to get anchor X, or compute from wave level
      final waveNodes = graph.nodes.where((n) => n.waveLevel == wave).toList();
      final double colX = waveNodes.isNotEmpty
          ? waveNodes.first.x
          : (wave * columnWidth);

      final colWidth = waveNodes.isNotEmpty ? waveNodes.first.width : 160.0;

      // Draw subtle vertical column guide line
      final guidePath = Path()
        ..moveTo(colX - 20.0, 50.0)
        ..lineTo(colX - 20.0, size.height);
      _drawDashedPath(
        canvas,
        guidePath,
        linePaint,
        dashWidth: 4.0,
        dashSpace: 6.0,
      );

      // Header pill
      final headerRect = Rect.fromLTWH(
        colX - 10.0,
        10.0,
        colWidth + 20.0,
        30.0,
      );
      final headerRRect = RRect.fromRectAndRadius(
        headerRect,
        const Radius.circular(15.0),
      );

      final headerBgPaint = Paint()
        ..color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(headerRRect, headerBgPaint);

      final headerBorderPaint = Paint()
        ..color = colorScheme.outlineVariant.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(headerRRect, headerBorderPaint);

      // Header text
      headerTextPainter.text = TextSpan(
        text: 'Wave $wave',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          fontSize: 12.0,
          letterSpacing: 0.5,
        ),
      );
      headerTextPainter.layout();
      headerTextPainter.paint(
        canvas,
        Offset(
          headerRect.left + (headerRect.width - headerTextPainter.width) / 2,
          headerRect.top + (headerRect.height - headerTextPainter.height) / 2,
        ),
      );
    }
  }

  void _drawEdges(Canvas canvas) {
    final hasActiveNode = activeNodeId != null && activeNodeId!.isNotEmpty;

    for (final edge in graph.edges) {
      if (edge.waypoints.length < 4) continue;

      final start = edge.waypoints[0];
      final cp1 = edge.waypoints[1];
      final cp2 = edge.waypoints[2];
      final end = edge.waypoints[3];

      final edgeKey = '${edge.fromId}->${edge.toId}';
      final isUpstream = _upstreamEdgeKeys.contains(edgeKey);
      final isDownstream = _downstreamEdgeKeys.contains(edgeKey);

      Color edgeColor;
      double strokeWidth;

      if (!hasActiveNode) {
        edgeColor = colorScheme.outline.withValues(alpha: 0.5);
        strokeWidth = 1.6;
      } else if (isUpstream) {
        // Upstream dependencies highlighted in blue
        edgeColor = const Color(0xFF1976D2);
        strokeWidth = 2.8;
      } else if (isDownstream) {
        // Downstream dependents highlighted in amber
        edgeColor = const Color(0xFFF57C00);
        strokeWidth = 2.8;
      } else {
        // Dim other edges
        edgeColor = colorScheme.outline.withValues(alpha: 0.12);
        strokeWidth = 1.0;
      }

      final splinePath = Path()
        ..moveTo(start.x, start.y)
        ..cubicTo(cp1.x, cp1.y, cp2.x, cp2.y, end.x, end.y);

      final splinePaint = Paint()
        ..color = edgeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(splinePath, splinePaint);

      // Arrowhead at the target endpoint
      _drawArrowHead(canvas, end, edgeColor, strokeWidth);
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    LayoutPoint end,
    Color color,
    double strokeWidth,
  ) {
    const arrowLength = 7.0;
    const arrowWidth = 4.5;

    final arrowPath = Path()
      ..moveTo(end.x, end.y)
      ..lineTo(end.x - arrowLength, end.y - arrowWidth)
      ..lineTo(end.x - arrowLength * 0.7, end.y)
      ..lineTo(end.x - arrowLength, end.y + arrowWidth)
      ..close();

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawNodes(Canvas canvas) {
    for (final node in graph.nodes) {
      final isSelected = node.id == selectedNodeId;
      final isHovered = node.id == activeNodeId && !isSelected;

      final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8.0));

      // Visual styling by status:
      // - Resolved: solid green border/fill, checkmark icon, type & tag label
      // - UnresolvedLazy: dashed purple border, clock icon, 'Lazy'
      // - Resolving: pulsing amber border, spinner, wave index
      // - Failed: crimson alert border, exclamation badge
      final status = node.status.toLowerCase();

      final Color fill;
      final Color border;
      final bool isDashed;
      final bool isPulsing;
      final String statusBadge;
      final IconData statusIcon;

      switch (status) {
        case 'resolved':
          fill = const Color(0xFFE8F5E9);
          border = const Color(0xFF2E7D32);
          isDashed = false;
          isPulsing = false;
          statusBadge = 'Resolved';
          statusIcon = Icons.check_circle;
        case 'unresolvedlazy':
        case 'lazy':
          fill = const Color(0xFFF3E5F5).withValues(alpha: 0.6);
          border = const Color(0xFF7B1FA2);
          isDashed = true;
          isPulsing = false;
          statusBadge = 'Lazy';
          statusIcon = Icons.schedule;
        case 'resolving':
          fill = const Color(0xFFFFF8E1);
          border = const Color(0xFFFFA000);
          isDashed = false;
          isPulsing = true;
          statusBadge = 'Wave ${node.waveLevel}';
          statusIcon = Icons.hourglass_top;
        case 'failed':
        case 'failure':
          fill = const Color(0xFFFFEBEE);
          border = const Color(0xFFD32F2F);
          isDashed = false;
          isPulsing = false;
          statusBadge = 'Failed';
          statusIcon = Icons.error;
        default:
          fill = colorScheme.surfaceContainerHighest;
          border = colorScheme.outline;
          isDashed = false;
          isPulsing = false;
          statusBadge = node.status;
          statusIcon = Icons.circle_outlined;
      }

      // Draw background fill
      final fillPaint = Paint()
        ..color = fill
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, fillPaint);

      // Draw selection/hover glow
      if (isSelected || isHovered) {
        final glowColor = isSelected
            ? colorScheme.primary.withValues(alpha: 0.35)
            : colorScheme.secondary.withValues(alpha: 0.2);
        final glowPaint = Paint()
          ..color = glowColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 4.0 : 2.5;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(isSelected ? 3.0 : 1.5),
            const Radius.circular(10.0),
          ),
          glowPaint,
        );
      }

      // Draw border (solid, dashed, or pulsing)
      final effectiveBorderColor = isPulsing
          ? border.withValues(alpha: 0.6 + 0.4 * pulseValue)
          : border;
      final borderStrokeWidth = isPulsing ? 2.5 + pulseValue : 2.0;

      final borderPaint = Paint()
        ..color = effectiveBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderStrokeWidth;

      if (isDashed) {
        final path = Path()..addRRect(rrect);
        _drawDashedPath(
          canvas,
          path,
          borderPaint,
          dashWidth: 5.0,
          dashSpace: 3.5,
        );
      } else {
        canvas.drawRRect(rrect, borderPaint);
      }

      // Draw node content: Icon, Type & Tag, Status Badge
      _drawNodeContent(canvas, rect, node, statusIcon, statusBadge, border);
    }
  }

  void _drawNodeContent(
    Canvas canvas,
    Rect rect,
    LayoutNode node,
    IconData icon,
    String statusBadge,
    Color accentColor,
  ) {
    // 1. Icon badge on top-left
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 16.0,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: accentColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(canvas, Offset(rect.left + 10.0, rect.top + 10.0));

    // 2. Status pill on top-right
    final badgePainter = TextPainter(
      text: TextSpan(
        text: statusBadge,
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
          color: accentColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromLTWH(
      rect.right - badgePainter.width - 16.0,
      rect.top + 8.0,
      badgePainter.width + 10.0,
      18.0,
    );
    final badgeRRect = RRect.fromRectAndRadius(
      badgeRect,
      const Radius.circular(4.0),
    );

    final badgeBgPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(badgeRRect, badgeBgPaint);

    badgePainter.paint(
      canvas,
      Offset(badgeRect.left + 5.0, badgeRect.top + 2.0),
    );

    // 3. Main Type label in middle
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.keyLabel,
        style: const TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
          color: Color(0xFF212121),
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width - 20.0);

    textPainter.paint(canvas, Offset(rect.left + 10.0, rect.top + 32.0));
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dashWidth = 5.0,
    double dashSpace = 3.5,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DagPainter oldDelegate) {
    return oldDelegate.graph != graph ||
        oldDelegate.activeNodeId != activeNodeId ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.colorScheme != colorScheme;
  }
}
