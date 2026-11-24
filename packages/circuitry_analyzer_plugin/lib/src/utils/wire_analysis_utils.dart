import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/element/type.dart';

/// Represents the normalized record tuple key for a wire: `(Type, Enum?)`.
final class WireKeyRecord {
  final DartType type;
  final String? tag;
  final String displayString;

  WireKeyRecord({required this.type, this.tag})
    : displayString = tag == null
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
final class WireDependencyInfo {
  final DartType type;
  final String? tag;
  final SyntacticEntity sourceNode;

  WireDependencyInfo({
    required this.type,
    required this.tag,
    required this.sourceNode,
  });

  WireKeyRecord get key => WireKeyRecord(type: type, tag: tag);
}

/// Represents static information extracted from a wire declaration expression.
final class WireDeclarationInfo {
  final Expression node;
  final DartType outputType;
  final String? tag;
  final List<WireDependencyInfo> dependencies;
  final bool isSyncWire;
  final bool isAsyncWire;
  final bool isTriggerWire;
  final Expression? factoryExpression;

  WireDeclarationInfo({
    required this.node,
    required this.outputType,
    required this.tag,
    required this.dependencies,
    required this.isSyncWire,
    required this.isAsyncWire,
    required this.isTriggerWire,
    required this.factoryExpression,
  });

  WireKeyRecord get key => WireKeyRecord(type: outputType, tag: tag);
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
  // Case 1: Direct instance creation
  if (expr is InstanceCreationExpression) {
    final constructor = expr.constructorName;
    final typeElement = constructor.type.type?.element;
    final targetName = typeElement?.name ?? constructor.type.name.lexeme;

    if (targetName == 'Wire' ||
        targetName == 'AsyncWire' ||
        targetName == 'TriggerWire') {
      final isSync = targetName == 'Wire';
      final isAsync = targetName == 'AsyncWire';
      final isTrigger = targetName == 'TriggerWire';

      final staticType = expr.staticType;
      final outputType = staticType is InterfaceType
          ? staticType.typeArguments.firstOrNull
          : constructor.type.typeArguments?.arguments.firstOrNull?.type;

      if (outputType == null) return null;

      String? tag;
      if (constructor.name?.name == 'tag') {
        for (final arg in expr.argumentList.arguments) {
          if (arg is NamedArgument && arg.name.lexeme == 'tag') {
            tag = extractTagString(arg.argumentExpression);
            break;
          }
        }
      }

      Expression? factoryExpression;
      for (final arg in expr.argumentList.arguments) {
        if (arg is! NamedArgument) {
          factoryExpression = arg.argumentExpression;
          break;
        }
      }

      return WireDeclarationInfo(
        node: expr,
        outputType: outputType,
        tag: tag,
        dependencies: const [],
        isSyncWire: isSync,
        isAsyncWire: isAsync,
        isTriggerWire: isTrigger,
        factoryExpression: factoryExpression,
      );
    }
  }

  // Case 2: MethodInvocation
  if (expr is MethodInvocation) {
    final methodName = expr.methodName.name;

    // Sub-case 2a: Wire(...) / AsyncWire(...) / TriggerWire(...) constructor invocation as MethodInvocation
    if (expr.target == null &&
        (methodName == 'Wire' ||
            methodName == 'AsyncWire' ||
            methodName == 'TriggerWire')) {
      final isSync = methodName == 'Wire';
      final isAsync = methodName == 'AsyncWire';
      final isTrigger = methodName == 'TriggerWire';

      final staticType = expr.staticType;
      final outputType = staticType is InterfaceType
          ? staticType.typeArguments.firstOrNull
          : expr.typeArguments?.arguments.firstOrNull?.type;

      if (outputType == null) return null;

      Expression? factoryExpression;
      for (final arg in expr.argumentList.arguments) {
        if (arg is! NamedArgument) {
          factoryExpression = arg.argumentExpression;
          break;
        }
      }

      return WireDeclarationInfo(
        node: expr,
        outputType: outputType,
        tag: null,
        dependencies: const [],
        isSyncWire: isSync,
        isAsyncWire: isAsync,
        isTriggerWire: isTrigger,
        factoryExpression: factoryExpression,
      );
    }

    // Sub-case 2b: Wire.tag(...) / AsyncWire.tag(...) / TriggerWire.tag(...)
    if (expr.target != null && methodName == 'tag') {
      final targetSource = expr.target!.toSource();
      if (targetSource == 'Wire' ||
          targetSource == 'AsyncWire' ||
          targetSource == 'TriggerWire') {
        final isSync = targetSource == 'Wire';
        final isAsync = targetSource == 'AsyncWire';
        final isTrigger = targetSource == 'TriggerWire';

        final staticType = expr.staticType;
        final outputType = staticType is InterfaceType
            ? staticType.typeArguments.firstOrNull
            : expr.typeArguments?.arguments.firstOrNull?.type;

        if (outputType == null) return null;

        String? tag;
        for (final arg in expr.argumentList.arguments) {
          if (arg is NamedArgument && arg.name.lexeme == 'tag') {
            tag = extractTagString(arg.argumentExpression);
            break;
          }
        }

        Expression? factoryExpression;
        for (final arg in expr.argumentList.arguments) {
          if (arg is! NamedArgument) {
            factoryExpression = arg.argumentExpression;
            break;
          }
        }

        return WireDeclarationInfo(
          node: expr,
          outputType: outputType,
          tag: tag,
          dependencies: const [],
          isSyncWire: isSync,
          isAsyncWire: isAsync,
          isTriggerWire: isTrigger,
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

      // Determine the root wire kind
      final staticType = expr.staticType;
      String? wireKind;
      if (staticType is InterfaceType) {
        wireKind = staticType.element.name;
      } else if (target != null) {
        final rootSource = target.toSource();
        if (rootSource.contains('AsyncWire')) {
          wireKind = 'AsyncWire';
        } else if (rootSource.contains('TriggerWire')) {
          wireKind = 'TriggerWire';
        } else if (rootSource.contains('Wire')) {
          wireKind = 'Wire';
        }
      }

      if (wireKind == 'Wire' ||
          wireKind == 'AsyncWire' ||
          wireKind == 'TriggerWire') {
        final isSync = wireKind == 'Wire';
        final isAsync = wireKind == 'AsyncWire';
        final isTrigger = wireKind == 'TriggerWire';

        final outputType = staticType is InterfaceType
            ? staticType.typeArguments.firstOrNull
            : expr.typeArguments?.arguments.firstOrNull?.type;

        if (outputType == null) return null;

        String? tag;
        for (final arg in expr.argumentList.arguments) {
          if (arg is NamedArgument && arg.name.lexeme == 'tag') {
            tag = extractTagString(arg.argumentExpression);
            break;
          }
        }

        Expression? factoryExpression;
        for (final arg in expr.argumentList.arguments) {
          if (arg is! NamedArgument) {
            factoryExpression = arg.argumentExpression;
            break;
          }
        }

        return WireDeclarationInfo(
          node: expr,
          outputType: outputType,
          tag: tag,
          dependencies: dependencies.reversed.toList(),
          isSyncWire: isSync,
          isAsyncWire: isAsync,
          isTriggerWire: isTrigger,
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

/// Checks whether [type] is a [Future] or [FutureOr].
bool isFutureType(DartType? type) {
  if (type is! InterfaceType) return false;
  return type.isDartAsyncFuture ||
      type.isDartAsyncFutureOr ||
      type.element.name == 'Future' ||
      type.element.name == 'FutureOr';
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
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedArgument && arg.name.lexeme == 'wires') {
          if (arg.argumentExpression is ListLiteral) {
            return arg.argumentExpression as ListLiteral;
          }
        } else if (arg is! NamedArgument &&
            arg.argumentExpression is ListLiteral) {
          return arg.argumentExpression as ListLiteral;
        }
      }
    }
  } else if (node is InstanceCreationExpression) {
    final targetElement = node.constructorName.type.type?.element;
    final typeName =
        targetElement?.name ?? node.constructorName.type.name.lexeme;

    if (typeName == 'CircuitProvider') {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedArgument && arg.name.lexeme == 'wires') {
          if (arg.argumentExpression is ListLiteral) {
            return arg.argumentExpression as ListLiteral;
          }
        }
      }
    }
  }
  return null;
}
