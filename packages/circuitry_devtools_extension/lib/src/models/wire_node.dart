/// Immutable representation of a single dependency wire node in the DAG.
final class WireNode {
  const WireNode({
    required this.key,
    required this.dependencies,
    required this.isAsync,
    required this.topologicalLevel,
    required this.isInitialized,
    this.isResolving = false,
    this.hasFailed = false,
    this.durationMs,
  });

  /// The unique formatted wire identifier (e.g. `ApiService` or `Database#primary`).
  final String key;

  /// Formatted keys of upstream wires that this wire directly depends upon.
  final List<String> dependencies;

  /// Whether this wire resolves asynchronously during [Circuit.build].
  final bool isAsync;

  /// The topological wave depth (0 = root dependencies without parents).
  final int topologicalLevel;

  /// Whether this wire has been instantiated in the running circuit.
  final bool isInitialized;

  /// Whether this wire is currently executing its asynchronous factory.
  final bool isResolving;

  /// Whether this wire failed during compilation or factory execution.
  final bool hasFailed;

  /// Recorded or estimated initialization latency in milliseconds.
  final int? durationMs;

  /// The underlying Dart type name extracted from [key].
  String get typeName {
    final hashIndex = key.indexOf('#');
    return hashIndex == -1 ? key : key.substring(0, hashIndex);
  }

  /// The optional tag extracted from [key] (e.g. `primary` or `auth`).
  String? get tag {
    final hashIndex = key.indexOf('#');
    return hashIndex == -1 ? null : key.substring(hashIndex + 1);
  }

  /// Whether this wire is a synchronous wire that has not yet been resolved.
  bool get isUnresolvedLazy =>
      !isAsync && !isInitialized && !isResolving && !hasFailed;

  /// Parses a [WireNode] from a JSON wire descriptor.
  factory WireNode.fromJson(Map<String, Object?> json) {
    final key = json['key'] as String? ?? '';
    final rawDeps = json['dependencies'] as List<dynamic>? ?? const [];
    final dependencies = rawDeps.map((e) => e.toString()).toList();
    final isAsync = json['isAsync'] as bool? ?? false;
    final topologicalLevel = (json['topologicalLevel'] as num?)?.toInt() ?? 0;
    final isInitialized = json['isInitialized'] as bool? ?? false;
    final isResolving = json['isResolving'] as bool? ?? false;
    final hasFailed = json['hasFailed'] as bool? ?? false;
    final durationMs = (json['durationMs'] as num?)?.toInt();

    return WireNode(
      key: key,
      dependencies: dependencies,
      isAsync: isAsync,
      topologicalLevel: topologicalLevel,
      isInitialized: isInitialized,
      isResolving: isResolving,
      hasFailed: hasFailed,
      durationMs: durationMs,
    );
  }

  /// Converts this node into a JSON-compatible map.
  Map<String, Object?> toJson() => {
    'key': key,
    'dependencies': dependencies,
    'isAsync': isAsync,
    'topologicalLevel': topologicalLevel,
    'isInitialized': isInitialized,
    'isResolving': isResolving,
    'hasFailed': hasFailed,
    if (durationMs != null) 'durationMs': durationMs,
  };

  /// Creates a copy of this wire node with updated fields.
  WireNode copyWith({
    String? key,
    List<String>? dependencies,
    bool? isAsync,
    int? topologicalLevel,
    bool? isInitialized,
    bool? isResolving,
    bool? hasFailed,
    int? durationMs,
  }) => WireNode(
    key: key ?? this.key,
    dependencies: dependencies ?? this.dependencies,
    isAsync: isAsync ?? this.isAsync,
    topologicalLevel: topologicalLevel ?? this.topologicalLevel,
    isInitialized: isInitialized ?? this.isInitialized,
    isResolving: isResolving ?? this.isResolving,
    hasFailed: hasFailed ?? this.hasFailed,
    durationMs: durationMs ?? this.durationMs,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WireNode &&
          key == other.key &&
          isAsync == other.isAsync &&
          topologicalLevel == other.topologicalLevel &&
          isInitialized == other.isInitialized &&
          isResolving == other.isResolving &&
          hasFailed == other.hasFailed &&
          durationMs == other.durationMs;

  @override
  int get hashCode => Object.hash(
    key,
    isAsync,
    topologicalLevel,
    isInitialized,
    isResolving,
    hasFailed,
    durationMs,
  );
}
