import 'package:circuitry_devtools_extension/src/layout/sugiyama_layout.dart';

/// Represents a summary of a registered Circuit instance detected via VM service.
final class CircuitSummary {
  /// Unique identifier of the circuit (e.g. `'circuit_1'`).
  final String id;

  /// Optional tag associated with the circuit.
  final String? tag;

  /// The lifecycle state of the circuit: `'building'`, `'ready'`, or `'failure'`.
  final String state;

  /// The number of registered wires in this circuit.
  final int wireCount;

  /// Whether this circuit has been disposed.
  final bool isDisposed;

  /// Creates a [CircuitSummary].
  const CircuitSummary({
    required this.id,
    this.tag,
    required this.state,
    required this.wireCount,
    this.isDisposed = false,
  });

  /// Deserializes a [CircuitSummary] from JSON.
  factory CircuitSummary.fromJson(Map<String, Object?> json) {
    return CircuitSummary(
      id: json['id'] as String? ?? 'unknown_circuit',
      tag: json['tag'] as String?,
      state: json['state'] as String? ?? 'ready',
      wireCount: json['wireCount'] as int? ?? 0,
      isDisposed: json['isDisposed'] as bool? ?? false,
    );
  }

  /// Serializes to a JSON map.
  Map<String, Object?> toJson() => {
    'id': id,
    'tag': tag,
    'state': state,
    'wireCount': wireCount,
    'isDisposed': isDisposed,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircuitSummary &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tag == other.tag &&
          state == other.state &&
          wireCount == other.wireCount &&
          isDisposed == other.isDisposed;

  @override
  int get hashCode => Object.hash(id, tag, state, wireCount, isDisposed);

  @override
  String toString() =>
      'CircuitSummary(id: $id, tag: $tag, state: $state, wireCount: $wireCount)';
}

/// Detailed information about a single wire within an inspected circuit.
final class WireModel {
  /// The full wire key string (e.g. `'AuthService'` or `'ApiClient(tag: api)'`).
  final String key;

  /// The extracted type name (e.g. `'AuthService'`).
  final String typeName;

  /// The extracted tag label, if any.
  final String? tag;

  /// The list of dependency wire keys.
  final List<String> dependencies;

  /// The list of dependent wire keys.
  final List<String> dependents;

  /// Whether this wire resolves asynchronously.
  final bool isAsync;

  /// The topological wave level of this wire (0 for root dependencies).
  final int waveLevel;

  /// Runtime status: `'resolved'`, `'unresolvedLazy'`, `'resolving'`, `'failed'`, `'disposed'`.
  final String status;

  /// The duration taken to resolve this wire, if recorded.
  final Duration? resolutionDuration;

  /// Whether this wire is part of the DAG critical path.
  final bool isCriticalPath;

  /// Creates a [WireModel].
  const WireModel({
    required this.key,
    required this.typeName,
    this.tag,
    this.dependencies = const [],
    this.dependents = const [],
    required this.isAsync,
    required this.waveLevel,
    required this.status,
    this.resolutionDuration,
    this.isCriticalPath = false,
  });

  /// Deserializes a [WireModel] from a JSON map.
  factory WireModel.fromJson(Map<String, Object?> json) {
    final keyStr = json['key'] as String? ?? 'UnknownWire';
    final isAsync = json['isAsync'] as bool? ?? false;
    final waveLevel = json['topologicalLevel'] as int? ?? 0;
    final statusStr = json['status'] as String? ?? 'resolved';

    final durationMicros = json['resolutionDurationMicros'] as int?;
    final duration = durationMicros != null
        ? Duration(microseconds: durationMicros)
        : null;

    final rawDeps = json['dependencies'] as List<Object?>? ?? const [];
    final dependencies = rawDeps.map((e) => e.toString()).toList();

    final rawDependents = json['dependents'] as List<Object?>? ?? const [];
    final dependents = rawDependents.map((e) => e.toString()).toList();

    // Parse type name and optional tag from formatted key string:
    // e.g. "MyService(tag: primary)" -> type "MyService", tag "primary"
    String type = keyStr;
    String? tag;
    final match = RegExp(r'^([^(]+)(?:\(tag:\s*([^)]+)\))?$')
        .firstMatch(keyStr);
    if (match != null) {
      type = match.group(1)?.trim() ?? keyStr;
      tag = match.group(2)?.trim();
    }

    return WireModel(
      key: keyStr,
      typeName: type,
      tag: tag,
      dependencies: dependencies,
      dependents: dependents,
      isAsync: isAsync,
      waveLevel: waveLevel,
      status: statusStr,
      resolutionDuration: duration,
      isCriticalPath: json['isCriticalPath'] as bool? ?? false,
    );
  }

  /// Copies this [WireModel] with updated fields.
  WireModel copyWith({
    String? key,
    String? typeName,
    String? tag,
    List<String>? dependencies,
    List<String>? dependents,
    bool? isAsync,
    int? waveLevel,
    String? status,
    Duration? resolutionDuration,
    bool? isCriticalPath,
  }) => WireModel(
    key: key ?? this.key,
    typeName: typeName ?? this.typeName,
    tag: tag ?? this.tag,
    dependencies: dependencies ?? this.dependencies,
    dependents: dependents ?? this.dependents,
    isAsync: isAsync ?? this.isAsync,
    waveLevel: waveLevel ?? this.waveLevel,
    status: status ?? this.status,
    resolutionDuration: resolutionDuration ?? this.resolutionDuration,
    isCriticalPath: isCriticalPath ?? this.isCriticalPath,
  );
}

/// The complete introspected DAG graph and metadata of a circuit.
final class CircuitGraphData {
  /// The ID of the inspected circuit.
  final String circuitId;

  /// Map of wire key to [WireModel].
  final Map<String, WireModel> wireMap;

  /// The maximum topological wave level in the circuit.
  final int maxWaveLevel;

  /// List of wire keys on the critical execution path.
  final List<String> criticalPath;

  /// Total duration of the circuit build/resolution, if known.
  final Duration? totalDuration;

  /// Creates a [CircuitGraphData].
  const CircuitGraphData({
    required this.circuitId,
    required this.wireMap,
    required this.maxWaveLevel,
    this.criticalPath = const [],
    this.totalDuration,
  });

  /// All wires in this graph.
  List<WireModel> get wires => wireMap.values.toList();

  /// Deserializes a [CircuitGraphData] from JSON.
  factory CircuitGraphData.fromJson(
    String circuitId,
    Map<String, Object?> json,
  ) {
    final rawWires = json['wires'] as List<Object?>? ?? const [];
    final rawCriticalPath = json['criticalPath'] as List<Object?>? ?? const [];
    final criticalPath = rawCriticalPath.map((e) => e.toString()).toList();
    final criticalPathSet = criticalPath.toSet();

    final maxWave = json['maxWaveLevel'] as int? ?? 0;
    final totalDurationMicros = json['totalDurationMicros'] as int?;
    final totalDuration = totalDurationMicros != null
        ? Duration(microseconds: totalDurationMicros)
        : null;

    final wireMap = <String, WireModel>{};
    for (final raw in rawWires) {
      if (raw is Map<String, Object?>) {
        final model = WireModel.fromJson(raw);
        wireMap[model.key] = model.copyWith(
          isCriticalPath: criticalPathSet.contains(model.key),
        );
      }
    }

    // Populate reverse dependents if not already present in the JSON.
    for (final wire in wireMap.values) {
      for (final depKey in wire.dependencies) {
        final depModel = wireMap[depKey];
        if (depModel != null && !depModel.dependents.contains(wire.key)) {
          final updatedDependents = [...depModel.dependents, wire.key];
          wireMap[depKey] = depModel.copyWith(dependents: updatedDependents);
        }
      }
    }

    return CircuitGraphData(
      circuitId: circuitId,
      wireMap: wireMap,
      maxWaveLevel: maxWave,
      criticalPath: criticalPath,
      totalDuration: totalDuration,
    );
  }

  /// Builds a [LayoutGraph] using [SugiyamaLayout] for canvas rendering.
  LayoutGraph buildLayoutGraph({
    SugiyamaLayout layout = const SugiyamaLayout(),
  }) {
    final nodes = <LayoutNode>[];
    final edges = <LayoutEdge>[];

    for (final wire in wires) {
      nodes.add(
        LayoutNode(
          id: wire.key,
          keyLabel: wire.key,
          waveLevel: wire.waveLevel,
          status: wire.status,
        ),
      );

      for (final depKey in wire.dependencies) {
        edges.add(LayoutEdge(fromId: depKey, toId: wire.key));
      }
    }

    return layout.execute(nodes, edges);
  }
}
