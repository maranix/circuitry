import 'dart:math' as math;

/// A 2D point used for node coordinates and cubic Bézier spline waypoints.
final class LayoutPoint {
  /// Creates an immutable 2D point at ([x], [y]).
  const LayoutPoint(this.x, this.y);

  /// The horizontal coordinate.
  final double x;

  /// The vertical coordinate.
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutPoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'LayoutPoint($x, $y)';
}

/// A node positioned within the topological Sugiyama DAG layout.
final class LayoutNode {
  /// Creates a layout node with topological rank and dimensional properties.
  LayoutNode({
    required this.id,
    required this.keyLabel,
    required this.waveLevel,
    this.width = 160.0,
    this.height = 60.0,
    this.x = 0.0,
    this.y = 0.0,
    this.status = 'resolved',
  });

  /// Positional factory constructor for convenience.
  factory LayoutNode.positional(
    String id,
    String keyLabel,
    int waveLevel, [
    double width = 160.0,
    double height = 60.0,
    double x = 0.0,
    double y = 0.0,
    String status = 'resolved',
  ]) => LayoutNode(
    id: id,
    keyLabel: keyLabel,
    waveLevel: waveLevel,
    width: width,
    height: height,
    x: x,
    y: y,
    status: status,
  );

  /// Unique identifier for this node (typically formatted WireKey string).
  final String id;

  /// Human-readable label representing the wire type and optional tag.
  final String keyLabel;

  /// The topological rank / wave level of this node (0 for root dependencies).
  final int waveLevel;

  /// Rendered width of the node card.
  final double width;

  /// Rendered height of the node card.
  final double height;

  /// Computed horizontal layout coordinate.
  double x;

  /// Computed vertical layout coordinate.
  double y;

  /// Lifecycle status of the wire (e.g. 'resolved', 'resolving', 'unresolvedLazy', 'failed', 'disposed').
  final String status;

  /// Horizontal position of the right boundary.
  double get right => x + width;

  /// Vertical position of the bottom boundary.
  double get bottom => y + height;

  /// Vertical center of the node card.
  double get centerY => y + (height / 2.0);

  /// Horizontal center of the node card.
  double get centerX => x + (width / 2.0);

  /// Creates a copy of this node with optional overridden properties.
  LayoutNode copyWith({
    String? id,
    String? keyLabel,
    int? waveLevel,
    double? width,
    double? height,
    double? x,
    double? y,
    String? status,
  }) => LayoutNode(
    id: id ?? this.id,
    keyLabel: keyLabel ?? this.keyLabel,
    waveLevel: waveLevel ?? this.waveLevel,
    width: width ?? this.width,
    height: height ?? this.height,
    x: x ?? this.x,
    y: y ?? this.y,
    status: status ?? this.status,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          waveLevel == other.waveLevel &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(id, waveLevel);

  @override
  String toString() =>
      'LayoutNode(id: $id, waveLevel: $waveLevel, x: $x, y: $y, status: $status)';
}

/// A directed edge connecting two [LayoutNode]s with cubic Bézier spline waypoints.
final class LayoutEdge {
  /// Creates a layout edge between [fromId] and [toId].
  LayoutEdge({
    required this.fromId,
    required this.toId,
    this.waypoints = const <LayoutPoint>[],
  });

  /// Positional factory constructor for convenience.
  factory LayoutEdge.positional(
    String fromId,
    String toId, [
    List<LayoutPoint> waypoints = const <LayoutPoint>[],
  ]) => LayoutEdge(fromId: fromId, toId: toId, waypoints: waypoints);

  /// Identifier of the source node where this edge originates.
  final String fromId;

  /// Identifier of the target node where this edge terminates.
  final String toId;

  /// Waypoints describing the spline path.
  ///
  /// For cubic Bézier curves, exactly 4 points are generated:
  /// `[start, controlPoint1, controlPoint2, end]`.
  final List<LayoutPoint> waypoints;

  /// Start waypoint on the source node boundary.
  LayoutPoint? get start => waypoints.isNotEmpty ? waypoints.first : null;

  /// First cubic control point exiting the source node horizontally.
  LayoutPoint? get controlPoint1 => waypoints.length >= 2 ? waypoints[1] : null;

  /// Second cubic control point entering the target node horizontally.
  LayoutPoint? get controlPoint2 => waypoints.length >= 3 ? waypoints[2] : null;

  /// End waypoint on the target node boundary.
  LayoutPoint? get end => waypoints.length >= 4 ? waypoints[3] : null;

  /// Creates a copy of this edge with optional updated waypoints.
  LayoutEdge copyWith({
    String? fromId,
    String? toId,
    List<LayoutPoint>? waypoints,
  }) => LayoutEdge(
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    waypoints: waypoints ?? this.waypoints,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutEdge &&
          runtimeType == other.runtimeType &&
          fromId == other.fromId &&
          toId == other.toId;

  @override
  int get hashCode => Object.hash(fromId, toId);

  @override
  String toString() =>
      'LayoutEdge(from: $fromId -> to: $toId, waypoints: ${waypoints.length})';
}

/// The complete laid-out DAG graph containing positioned nodes, routed edges,
/// and calculated canvas bounding box dimensions.
final class LayoutGraph {
  /// Creates a laid-out graph container.
  LayoutGraph({
    required this.nodes,
    required this.edges,
    required this.totalWidth,
    required this.totalHeight,
  });

  /// Positional constructor for convenience.
  LayoutGraph.positional(
    this.nodes,
    this.edges,
    this.totalWidth,
    this.totalHeight,
  );

  /// All positioned nodes in the graph.
  final List<LayoutNode> nodes;

  /// All routed edges in the graph with cubic Bézier waypoints.
  final List<LayoutEdge> edges;

  /// Total width of the graph bounding box including padding.
  final double totalWidth;

  /// Total height of the graph bounding box including padding.
  final double totalHeight;

  /// Fast lookup map by node ID.
  late final Map<String, LayoutNode> _nodeMap = {
    for (final node in nodes) node.id: node,
  };

  /// Returns the node with [id], or `null` if not found.
  LayoutNode? findNode(String id) => _nodeMap[id];
}

/// Layered Sugiyama topological DAG layout engine for Circuitry DevTools.
///
/// Executes the 4-phase Sugiyama workflow tailored to Circuitry topological waves:
/// 1. **Rank Assignment**: Locks each node's X coordinate to `paddingX + waveLevel * columnWidth`.
/// 2. **Crossing Reduction**: Iteratively applies the barycentric heuristic across adjacent
///    wave columns (downsweep and upsweep) to minimize edge crossings.
/// 3. **Coordinate Assignment**: Spaces nodes vertically within each column with a minimum
///    margin, guaranteeing non-overlapping placement.
/// 4. **Spline Routing**: Computes smooth cubic Bézier waypoints `[start, cp1, cp2, end]`
///    for all edges with horizontal tangent constraints.
final class SugiyamaLayout {
  /// Creates a Sugiyama topological layout engine with configurable layout metrics.
  const SugiyamaLayout({
    this.columnWidth = 240.0,
    this.verticalMargin = 40.0,
    this.paddingX = 0.0,
    this.paddingY = 0.0,
    this.maxIterations = 8,
  });

  /// The horizontal column step per wave level.
  final double columnWidth;

  /// The minimum vertical spacing between consecutive nodes in the same column.
  final double verticalMargin;

  /// Initial horizontal padding before wave column 0.
  final double paddingX;

  /// Initial vertical padding before the topmost node in each column.
  final double paddingY;

  /// Maximum number of barycentric crossing reduction sweep iterations.
  final int maxIterations;

  /// Executes the 4-phase Sugiyama layout algorithm on [nodes] and [edges],
  /// returning an immutable [LayoutGraph] with computed coordinates and splines.
  LayoutGraph execute(List<LayoutNode> nodes, List<LayoutEdge> edges) {
    if (nodes.isEmpty) {
      return LayoutGraph(
        nodes: const <LayoutNode>[],
        edges: const <LayoutEdge>[],
        totalWidth: 0.0,
        totalHeight: 0.0,
      );
    }

    // Clone input nodes so execute is idempotent and non-destructive.
    final layoutNodes = nodes.map((node) => node.copyWith()).toList();
    final nodeMap = <String, LayoutNode>{
      for (final node in layoutNodes) node.id: node,
    };

    // Phase 1: Rank Assignment (Group by waveLevel and lock X coordinate)
    final layers = <int, List<LayoutNode>>{};
    for (final node in layoutNodes) {
      layers.putIfAbsent(node.waveLevel, () => <LayoutNode>[]).add(node);
      node.x = paddingX + (node.waveLevel * columnWidth);
    }

    final waveLevels = layers.keys.toList()..sort();

    // Phase 2: Crossing Reduction via Iterative Barycentric Sweep
    _reduceCrossings(layers, waveLevels, edges, nodeMap);

    // Phase 3: Coordinate Assignment (Vertical spacing with minimum margin)
    for (final wave in waveLevels) {
      final columnNodes = layers[wave]!;
      double currentY = paddingY;
      for (final node in columnNodes) {
        node.x = paddingX + (node.waveLevel * columnWidth);
        node.y = currentY;
        currentY += node.height + verticalMargin;
      }
    }

    // Mirror calculated coordinates back to original input nodes if present.
    final originalNodeMap = <String, LayoutNode>{
      for (final node in nodes) node.id: node,
    };
    for (final layoutNode in layoutNodes) {
      final original = originalNodeMap[layoutNode.id];
      if (original != null) {
        original.x = layoutNode.x;
        original.y = layoutNode.y;
      }
    }

    // Phase 4: Spline Routing (Cubic Bézier waypoints: start, cp1, cp2, end)
    final routedEdges = <LayoutEdge>[];
    for (final edge in edges) {
      final fromNode = nodeMap[edge.fromId];
      final toNode = nodeMap[edge.toId];

      if (fromNode == null || toNode == null) {
        routedEdges.add(edge.copyWith(waypoints: const <LayoutPoint>[]));
        continue;
      }

      final waypoints = _computeBezierSpline(fromNode, toNode);
      routedEdges.add(edge.copyWith(waypoints: waypoints));
    }

    // Compute bounding canvas dimensions.
    double maxRight = 0.0;
    double maxBottom = 0.0;
    for (final node in layoutNodes) {
      final right = node.right;
      final bottom = node.bottom;
      if (right > maxRight) maxRight = right;
      if (bottom > maxBottom) maxBottom = bottom;
    }

    final totalWidth = maxRight + paddingX;
    final totalHeight = maxBottom + paddingY;

    final orderedNodes = <LayoutNode>[
      for (final wave in waveLevels) ...layers[wave]!,
    ];

    return LayoutGraph(
      nodes: orderedNodes,
      edges: routedEdges,
      totalWidth: totalWidth,
      totalHeight: totalHeight,
    );
  }

  /// Reduces edge crossings between adjacent wave columns using the barycentric heuristic.
  void _reduceCrossings(
    Map<int, List<LayoutNode>> layers,
    List<int> waveLevels,
    List<LayoutEdge> edges,
    Map<String, LayoutNode> nodeMap,
  ) {
    if (waveLevels.length <= 1) return;

    int bestCrossings = countCrossings(layers, edges);
    var bestLayers = _cloneLayers(layers);

    if (bestCrossings == 0) return;

    for (int iter = 0; iter < maxIterations; iter++) {
      // Downsweep: Wave 1 to K (order layer based on upstream connected neighbors)
      for (int i = 1; i < waveLevels.length; i++) {
        final currentWave = waveLevels[i];
        final previousWave = waveLevels[i - 1];
        _orderLayerByBarycenter(
          layerNodes: layers[currentWave]!,
          referenceNodes: layers[previousWave]!,
          isUpstream: true,
          edges: edges,
        );
      }

      final downCrossings = countCrossings(layers, edges);
      if (downCrossings < bestCrossings) {
        bestCrossings = downCrossings;
        bestLayers = _cloneLayers(layers);
      }
      if (bestCrossings == 0) break;

      // Upsweep: Wave K-1 down to 0 (order layer based on downstream connected neighbors)
      for (int i = waveLevels.length - 2; i >= 0; i--) {
        final currentWave = waveLevels[i];
        final nextWave = waveLevels[i + 1];
        _orderLayerByBarycenter(
          layerNodes: layers[currentWave]!,
          referenceNodes: layers[nextWave]!,
          isUpstream: false,
          edges: edges,
        );
      }

      final upCrossings = countCrossings(layers, edges);
      if (upCrossings < bestCrossings) {
        bestCrossings = upCrossings;
        bestLayers = _cloneLayers(layers);
      }
      if (bestCrossings == 0) break;
    }

    // Apply the best ordering found.
    for (final wave in waveLevels) {
      layers[wave] = bestLayers[wave]!;
    }
  }

  /// Orders [layerNodes] based on the barycentric average position of connected [referenceNodes].
  void _orderLayerByBarycenter({
    required List<LayoutNode> layerNodes,
    required List<LayoutNode> referenceNodes,
    required bool isUpstream,
    required List<LayoutEdge> edges,
  }) {
    if (layerNodes.length <= 1) return;

    final refIndexMap = <String, int>{
      for (int i = 0; i < referenceNodes.length; i++) referenceNodes[i].id: i,
    };

    // Build connections between layer nodes and reference nodes.
    final connections = <String, List<int>>{
      for (final node in layerNodes) node.id: <int>[],
    };

    for (final edge in edges) {
      final String layerNodeId;
      final String refNodeId;

      if (isUpstream) {
        // layerNodes are downstream; referenceNodes are upstream.
        // Edge can go from upstream to downstream (fromId -> toId) or vice versa.
        if (connections.containsKey(edge.toId) &&
            refIndexMap.containsKey(edge.fromId)) {
          layerNodeId = edge.toId;
          refNodeId = edge.fromId;
        } else if (connections.containsKey(edge.fromId) &&
            refIndexMap.containsKey(edge.toId)) {
          layerNodeId = edge.fromId;
          refNodeId = edge.toId;
        } else {
          continue;
        }
      } else {
        // layerNodes are upstream; referenceNodes are downstream.
        if (connections.containsKey(edge.fromId) &&
            refIndexMap.containsKey(edge.toId)) {
          layerNodeId = edge.fromId;
          refNodeId = edge.toId;
        } else if (connections.containsKey(edge.toId) &&
            refIndexMap.containsKey(edge.fromId)) {
          layerNodeId = edge.toId;
          refNodeId = edge.fromId;
        } else {
          continue;
        }
      }

      final refPos = refIndexMap[refNodeId];
      if (refPos != null) {
        connections[layerNodeId]!.add(refPos);
      }
    }

    final initialIndex = <String, int>{
      for (int i = 0; i < layerNodes.length; i++) layerNodes[i].id: i,
    };

    final barycenters = <String, double>{};
    for (final node in layerNodes) {
      final neighborPositions = connections[node.id]!;
      if (neighborPositions.isNotEmpty) {
        final sum = neighborPositions.reduce((a, b) => a + b);
        barycenters[node.id] = sum / neighborPositions.length;
      } else {
        // Retain relative initial position when disconnected from adjacent layer.
        barycenters[node.id] = initialIndex[node.id]!.toDouble();
      }
    }

    layerNodes.sort((a, b) {
      final bcA = barycenters[a.id]!;
      final bcB = barycenters[b.id]!;
      final cmp = bcA.compareTo(bcB);
      if (cmp != 0) return cmp;
      return initialIndex[a.id]!.compareTo(initialIndex[b.id]!);
    });
  }

  /// Computes cubic Bézier waypoints `[start, cp1, cp2, end]` connecting [fromNode] to [toNode].
  List<LayoutPoint> _computeBezierSpline(
    LayoutNode fromNode,
    LayoutNode toNode,
  ) {
    final double startX;
    final double startY;
    final double endX;
    final double endY;

    if (fromNode.x <= toNode.x) {
      // Forward direction (left to right): exit right of fromNode, enter left of toNode.
      startX = fromNode.right;
      startY = fromNode.centerY;
      endX = toNode.x;
      endY = toNode.centerY;

      final double span = (endX - startX).abs();
      final double dx = math.max(span * 0.5, 32.0);

      final cp1 = LayoutPoint(startX + dx, startY);
      final cp2 = LayoutPoint(endX - dx, endY);
      return <LayoutPoint>[
        LayoutPoint(startX, startY),
        cp1,
        cp2,
        LayoutPoint(endX, endY),
      ];
    } else {
      // Backward direction (right to left): exit left of fromNode, enter right of toNode.
      startX = fromNode.x;
      startY = fromNode.centerY;
      endX = toNode.right;
      endY = toNode.centerY;

      final double span = (startX - endX).abs();
      final double dx = math.max(span * 0.5, 32.0);

      final cp1 = LayoutPoint(startX - dx, startY);
      final cp2 = LayoutPoint(endX + dx, endY);
      return <LayoutPoint>[
        LayoutPoint(startX, startY),
        cp1,
        cp2,
        LayoutPoint(endX, endY),
      ];
    }
  }

  /// Counts the total number of edge crossings between adjacent wave columns.
  static int countCrossings(
    Map<int, List<LayoutNode>> layers,
    List<LayoutEdge> edges,
  ) {
    final posMap = <String, (int, int)>{};
    for (final entry in layers.entries) {
      final wave = entry.key;
      final nodes = entry.value;
      for (int i = 0; i < nodes.length; i++) {
        posMap[nodes[i].id] = (wave, i);
      }
    }

    final normalizedEdges = <(int, int, int, int)>[];
    for (final edge in edges) {
      final pFrom = posMap[edge.fromId];
      final pTo = posMap[edge.toId];
      if (pFrom == null || pTo == null) continue;
      if (pFrom.$1 == pTo.$1) continue;

      if (pFrom.$1 < pTo.$1) {
        normalizedEdges.add((pFrom.$1, pFrom.$2, pTo.$1, pTo.$2));
      } else {
        normalizedEdges.add((pTo.$1, pTo.$2, pFrom.$1, pFrom.$2));
      }
    }

    int crossings = 0;
    for (int i = 0; i < normalizedEdges.length; i++) {
      final e1 = normalizedEdges[i];
      for (int j = i + 1; j < normalizedEdges.length; j++) {
        final e2 = normalizedEdges[j];
        if (e1.$1 == e2.$1 && e1.$3 == e2.$3) {
          final dSource = e1.$2 - e2.$2;
          final dTarget = e1.$4 - e2.$4;
          if ((dSource < 0 && dTarget > 0) || (dSource > 0 && dTarget < 0)) {
            crossings++;
          }
        }
      }
    }
    return crossings;
  }

  /// Calculates total edge crossings for a flat list of [nodes] grouped by their `waveLevel`.
  ///
  /// If nodes have already been positioned with distinct vertical `y` coordinates,
  /// they are evaluated in their visual vertical order within each wave column.
  static int countEdgeCrossings(
    List<LayoutNode> nodes,
    List<LayoutEdge> edges,
  ) {
    final layers = <int, List<LayoutNode>>{};
    for (final node in nodes) {
      layers.putIfAbsent(node.waveLevel, () => <LayoutNode>[]).add(node);
    }
    for (final list in layers.values) {
      final hasDistinctY = list.any((n) => n.y != list.first.y);
      if (hasDistinctY) {
        list.sort((a, b) => a.y.compareTo(b.y));
      }
    }
    return countCrossings(layers, edges);
  }

  static Map<int, List<LayoutNode>> _cloneLayers(
    Map<int, List<LayoutNode>> source,
  ) {
    return <int, List<LayoutNode>>{
      for (final entry in source.entries)
        entry.key: List<LayoutNode>.of(entry.value),
    };
  }
}
