import 'package:circuitry/circuitry.dart';
import 'package:circuitry_flutter/src/circuit_provider.dart';
import 'package:flutter/widgets.dart';

/// Signature for a builder callback that constructs a widget using a resolved [dependency] of type [T].
typedef CircuitDependencyWidgetBuilder<T> = Widget Function(
  BuildContext context,
  T dependency,
);

/// A widget that retrieves a dependency of type [T] from the ambient [Circuit]
/// provided by an enclosing [CircuitProvider] and passes it to [builder].
///
/// [CircuitBuilder] localizes dependency consumption to leaf widgets, avoiding full-screen
/// rebuilds and removing boilerplate calls to `CircuitProvider.of(context).get<T>()`.
///
/// ## Examples
///
/// ### Untagged Dependency
///
/// ```dart
/// CircuitBuilder<UserService>(
///   builder: (context, userService) => Text('User: ${userService.name}'),
/// );
/// ```
///
/// ### Tagged Wire
///
/// ```dart
/// CircuitBuilder<DatabaseService>.tagged(
///   tag: Environment.prod,
///   builder: (context, db) => Text('Host: ${db.host}'),
/// );
/// ```
///
/// ### Ancestor Tagged Circuit
///
/// If the dependency belongs to an ancestor tagged container (e.g. `AppScope.global`):
///
/// ```dart
/// CircuitBuilder<AuthService>(
///   circuitTag: AppScope.global,
///   builder: (context, auth) => Text('Token: ${auth.token}'),
/// );
/// ```
final class const CircuitBuilder<T>({
  super.key,
  final Enum? tag,
  final Enum? circuitTag,
  required final CircuitDependencyWidgetBuilder<T> builder,
}) extends StatelessWidget {
  /// Creates a [CircuitBuilder] that retrieves a tagged dependency of type [T] identified by [tag].
  const CircuitBuilder.tagged({
    Key? key,
    required Enum tag,
    Enum? circuitTag,
    required CircuitDependencyWidgetBuilder<T> builder,
  }) : this(key: key, tag: tag, circuitTag: circuitTag, builder: builder);

  @override
  Widget build(BuildContext context) {
    final circuit = CircuitProvider.of(context, tag: circuitTag);
    final dependency = switch (tag) {
      final t? => circuit.getTagged<T, Enum>(t),
      _ => circuit.get<T>(),
    };
    return builder(context, dependency);
  }
}
