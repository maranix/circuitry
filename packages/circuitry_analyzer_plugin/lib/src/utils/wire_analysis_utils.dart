import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/element/type.dart';

/// Represents the supported kinds of Circuitry wires.
///
/// Serves as the single source of truth for wire type recognition and validation.
enum WireKind {
  sync('Wire', isSync: true, isAsync: false, isTrigger: false),
  async('AsyncWire', isSync: false, isAsync: true, isTrigger: false),
  trigger('TriggerWire', isSync: false, isAsync: false, isTrigger: true);

  final String typeName;
  final bool isSync;
  final bool isAsync;
  final bool isTrigger;

  const WireKind(
    this.typeName, {
    required this.isSync,
    required this.isAsync,
    required this.isTrigger,
  });

  /// Registry mapping wire type names to their corresponding [WireKind].
  static final Map<String, WireKind> byName = {
    for (final kind in values) kind.typeName: kind,
  };

  /// Set of all supported wire type names.
  static final Set<String> typeNames = {
    for (final kind in values) kind.typeName,
  };

  /// Returns whether [name] is a recognized wire type name.
  static bool isWire(String? name) => byName.containsKey(name);

  /// Resolves a [WireKind] from a type or target name string.
  static WireKind? fromName(String? name) => byName[name];

  /// Resolves a [WireKind] by checking if [source] matches or contains any known wire kind.
  static WireKind? matchSource(String? source) {
    if (source == null) return null;
    final direct = byName[source];
    if (direct != null) return direct;
    for (final kind in values) {
      if (kind != sync && source.contains(kind.typeName)) {
        return kind;
      }
    }
    if (source.contains(sync.typeName)) {
      return sync;
    }
    return null;
  }
}

/// Represents the normalized record tuple key for a wire: `(Type, Enum?)`.
final class WireKeyRecord({required final DartType type, final String? tag}) {
  final String displayString = tag == null
      ? type.getDisplayString()
      : '(${type.getDisplayString()}, $tag)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WireKeyRecord) return false;
    return type == other.type && tag == other.tag;
  }

  @override
  int get hashCode => Object.hash(type, tag);

  @override
  String toString() => displayString;
}

/// Represents a declared dependency of a wire.
final class WireDependencyInfo({
  required final DartType type,
  required final String? tag,
  required final SyntacticEntity sourceNode,
}) {
  WireKeyRecord get key => WireKeyRecord(type: type, tag: tag);
}

/// Represents static information extracted from a wire declaration expression.
final class WireDeclarationInfo({
  required final Expression node,
  required final DartType outputType,
  required final String? tag,
  required final List<WireDependencyInfo> dependencies,
  required final WireKind kind,
  required final Expression? factoryExpression,
}) {
  bool get isSyncWire => kind.isSync;
  bool get isAsyncWire => kind.isAsync;
  bool get isTriggerWire => kind.isTrigger;

  WireKeyRecord get key => WireKeyRecord(type: outputType, tag: tag);
}

/// Extracts a named argument by [name] from an [ArgumentList].
Expression? extractNamedArgument(ArgumentList argumentList, String name) {
  for (final arg in argumentList.arguments) {
    if (arg is NamedArgument && arg.name.lexeme == name) {
      return arg.argumentExpression;
    }
  }
  return null;
}

/// Extracts the first positional argument from an [ArgumentList].
Expression? extractPositionalArgument(ArgumentList argumentList) {
  for (final arg in argumentList.arguments) {
    if (arg is! NamedArgument) {
      return arg.argumentExpression;
    }
  }
  return null;
}

/// Extracts the output [DartType] from an AST [Expression] or fallback [TypeArgumentList].
DartType? extractOutputType(Expression expr, [TypeArgumentList? fallbackArgs]) {
  final staticType = expr.staticType;
  if (staticType is InterfaceType && staticType.typeArguments.isNotEmpty) {
    return staticType.typeArguments.firstOrNull;
  }
  return fallbackArgs?.arguments.firstOrNull?.type;
}

/// Normalizes a tag expression into a consistent string representation.
String? extractTagString(Expression? expression) {
  if (expression == null) return null;

  if (expression is PrefixedIdentifier) {
    return expression.toSource();
  }
  if (expression is PropertyAccess) {
    return expression.toSource();
  }

  final source = expression.toSource();
  if (source.startsWith('.')) {
    final typeName = expression.staticType?.element?.name;
    if (typeName != null) {
      return '$typeName$source';
    }
  }
  return source;
}

/// Extracts [WireDeclarationInfo] from an AST [Expression].
WireDeclarationInfo? extractWireDeclaration(Expression expr) {
  // Case 1: Direct instance creation (e.g., Wire(() => ...), Wire.tag(...))
  if (expr is InstanceCreationExpression) {
    final constructor = expr.constructorName;
    final typeElement = constructor.type.type?.element;
    final targetName = typeElement?.name ?? constructor.type.name.lexeme;
    final kind = WireKind.fromName(targetName);
    if (kind == null) return null;

    final outputType = extractOutputType(expr, constructor.type.typeArguments);
    if (outputType == null) return null;

    final tag = constructor.name?.name == 'tag'
        ? extractTagString(extractNamedArgument(expr.argumentList, 'tag'))
        : null;
    final factoryExpression = extractPositionalArgument(expr.argumentList);

    return WireDeclarationInfo(
      node: expr,
      outputType: outputType,
      tag: tag,
      dependencies: const [],
      kind: kind,
      factoryExpression: factoryExpression,
    );
  }

  // Case 2: MethodInvocation
  if (expr is MethodInvocation) {
    final methodName = expr.methodName.name;

    // Sub-case 2a: Wire(...) / AsyncWire(...) / TriggerWire(...) constructor invocation as MethodInvocation
    if (expr.target == null) {
      final kind = WireKind.fromName(methodName);
      if (kind != null) {
        final outputType = extractOutputType(expr, expr.typeArguments);
        if (outputType == null) return null;

        final factoryExpression = extractPositionalArgument(expr.argumentList);
        return WireDeclarationInfo(
          node: expr,
          outputType: outputType,
          tag: null,
          dependencies: const [],
          kind: kind,
          factoryExpression: factoryExpression,
        );
      }
    }

    // Sub-case 2b: Wire.tag(...) / AsyncWire.tag(...) / TriggerWire.tag(...)
    if (expr.target != null && methodName == 'tag') {
      final targetSource = expr.target!.toSource();
      final kind = WireKind.fromName(targetSource);
      if (kind != null) {
        final outputType = extractOutputType(expr, expr.typeArguments);
        if (outputType == null) return null;

        final tag = extractTagString(
          extractNamedArgument(expr.argumentList, 'tag'),
        );
        final factoryExpression = extractPositionalArgument(expr.argumentList);

        return WireDeclarationInfo(
          node: expr,
          outputType: outputType,
          tag: tag,
          dependencies: const [],
          kind: kind,
          factoryExpression: factoryExpression,
        );
      }
    }

    // Sub-case 2c: Fluent builder chain ending in `.to(...)`
    if (methodName == 'to') {
      var target = expr.target;
      final dependencies = <WireDependencyInfo>[];

      while (target is MethodInvocation) {
        final targetMethodName = target.methodName.name;
        if (targetMethodName == 'takes') {
          final typeArg = target.typeArguments?.arguments.firstOrNull?.type;
          if (typeArg != null) {
            dependencies.add(
              WireDependencyInfo(
                type: typeArg,
                tag: null,
                sourceNode: target.typeArguments ?? target,
              ),
            );
          }
          target = target.target;
        } else if (targetMethodName == 'takesTagged') {
          final typeArg = target.typeArguments?.arguments.firstOrNull?.type;
          final tagArg = target.argumentList.arguments.firstOrNull;
          final tagExpr = tagArg?.argumentExpression;
          final tag = extractTagString(tagExpr);
          if (typeArg != null) {
            dependencies.add(
              WireDependencyInfo(
                type: typeArg,
                tag: tag,
                sourceNode: target.typeArguments ?? target,
              ),
            );
          }
          target = target.target;
        } else {
          break;
        }
      }

      // Determine the root wire kind from static type or root target source
      final staticType = expr.staticType;
      WireKind? kind;
      if (staticType is InterfaceType) {
        kind = WireKind.fromName(staticType.element.name);
      }
      kind ??= WireKind.matchSource(target?.toSource());

      if (kind != null) {
        final outputType = extractOutputType(expr, expr.typeArguments);
        if (outputType == null) return null;

        final tag = extractTagString(
          extractNamedArgument(expr.argumentList, 'tag'),
        );
        final factoryExpression = extractPositionalArgument(expr.argumentList);

        return WireDeclarationInfo(
          node: expr,
          outputType: outputType,
          tag: tag,
          dependencies: dependencies.reversed.toList(),
          kind: kind,
          factoryExpression: factoryExpression,
        );
      }
    }
  }

  return null;
}

/// Checks whether [type] implements or is [CircuitAction].
bool isCircuitAction(DartType? type) {
  if (type is! InterfaceType) return false;
  if (type.element.name == 'CircuitAction') return true;
  for (final supertype in type.allSupertypes) {
    if (supertype.element.name == 'CircuitAction') return true;
  }
  return false;
}

/// Set of asynchronous future type names.
const Set<String> _futureTypeNames = {'Future', 'FutureOr'};

/// Checks whether [type] is a [Future] or [FutureOr].
bool isFutureType(DartType? type) {
  if (type is! InterfaceType) return false;
  return type.isDartAsyncFuture ||
      type.isDartAsyncFutureOr ||
      _futureTypeNames.contains(type.element.name);
}

/// Unwraps the type argument from [Future<T>] or returns [type].
DartType unwrapFutureType(DartType type) {
  if (type is InterfaceType && isFutureType(type)) {
    return type.typeArguments.firstOrNull ?? type;
  }
  return type;
}

/// Determines whether a wire factory is asynchronous or returns a `Future`.
bool isAsynchronousFactory(Expression? factoryExpr, DartType? outputType) {
  if (outputType != null && isFutureType(outputType)) {
    return true;
  }
  if (factoryExpr == null) return false;

  if (factoryExpr is FunctionExpression && factoryExpr.body.isAsynchronous) {
    return true;
  }

  final staticType = factoryExpr.staticType;
  if (staticType is FunctionType && isFutureType(staticType.returnType)) {
    return true;
  }

  return false;
}

/// Extracts the literal wires [ListLiteral] passed to `Circuit.build` or `CircuitProvider`.
ListLiteral? extractCircuitWiresList(AstNode node) {
  if (node is MethodInvocation) {
    final target = node.target;
    final isCircuitTarget =
        target != null &&
        (target.toSource() == 'Circuit' ||
            target.staticType?.element?.name == 'Circuit');

    if (isCircuitTarget && node.methodName.name == 'build') {
      final namedWires = extractNamedArgument(node.argumentList, 'wires');
      if (namedWires is ListLiteral) return namedWires;

      final positionalWires = extractPositionalArgument(node.argumentList);
      if (positionalWires is ListLiteral) return positionalWires;
    }
  } else if (node is InstanceCreationExpression) {
    final targetElement = node.constructorName.type.type?.element;
    final typeName =
        targetElement?.name ?? node.constructorName.type.name.lexeme;

    if (typeName == 'CircuitProvider') {
      final namedWires = extractNamedArgument(node.argumentList, 'wires');
      if (namedWires is ListLiteral) return namedWires;
    }
  }
  return null;
}
