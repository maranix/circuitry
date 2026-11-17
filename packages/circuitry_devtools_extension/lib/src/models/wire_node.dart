/// Immutable representation of a single dependency wire node in the DAG.
final class const WireNode({
  /// The unique formatted wire identifier (e.g. `ApiService` or `Database#primary`).
  required final String key,

  /// Formatted keys of upstream wires that this wire directly depends upon.
  required final List<String> dependencies,

  /// Whether this wire resolves asynchronously during [Circuit.build].
  required final bool isAsync,

  /// The topological wave depth (0 = root dependencies without parents).
  required final int topologicalLevel,

  /// Whether this wire has been instantiated in the running circuit.
  required final bool isInitialized,

  /// Whether this wire is currently executing its asynchronous factory.
  final bool isResolving = false,

  /// Whether this wire failed during compilation or factory execution.
  final bool hasFailed = false,

  /// Recorded or estimated initialization latency in milliseconds.
  final int? durationMs,

  /// Optional error message captured if this wire failed.
  final String? errorMessage,
}) {
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

  /// Parses a [WireNode] from a JSON wire descriptor using pattern matching.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'key': final String key,
      'isAsync': final bool isAsync,
      'topologicalLevel': final num topologicalLevel,
      'isInitialized': final bool isInitialized,
    }) {
      final dependencies = switch (json['dependencies']) {
        final List<Object?> deps => deps.whereType<String>().toList(),
        _ => const <String>[],
      };
      final isResolving = json['isResolving'] as bool? ?? false;
      final hasFailed = json['hasFailed'] as bool? ?? false;
      final durationMs = (json['durationMs'] as num?)?.toInt();
      final errorMessage = json['errorMessage'] as String?;

      return WireNode(
        key: key,
        dependencies: dependencies,
        isAsync: isAsync,
        topologicalLevel: topologicalLevel.toInt(),
        isInitialized: isInitialized,
        isResolving: isResolving,
        hasFailed: hasFailed,
        durationMs: durationMs,
        errorMessage: errorMessage,
      );
    }
    throw FormatException('Invalid wire node schema: $json');
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
    if (errorMessage != null) 'errorMessage': errorMessage,
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
    String? errorMessage,
  }) => WireNode(
    key: key ?? this.key,
    dependencies: dependencies ?? this.dependencies,
    isAsync: isAsync ?? this.isAsync,
    topologicalLevel: topologicalLevel ?? this.topologicalLevel,
    isInitialized: isInitialized ?? this.isInitialized,
    isResolving: isResolving ?? this.isResolving,
    hasFailed: hasFailed ?? this.hasFailed,
    durationMs: durationMs ?? this.durationMs,
    errorMessage: errorMessage ?? this.errorMessage,
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
          durationMs == other.durationMs &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    key,
    isAsync,
    topologicalLevel,
    isInitialized,
    isResolving,
    hasFailed,
    durationMs,
    errorMessage,
  );
}
