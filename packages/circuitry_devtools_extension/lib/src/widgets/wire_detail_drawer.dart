import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:circuitry_devtools_extension/src/models/wire_node.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:material_ui/material_ui.dart';

/// Right drawer panel inspecting a selected [WireNode], its dependency links,
/// and live on-demand initialization actions.
class const WireDetailDrawer({
  super.key,
  required final CircuitryDevToolsController controller,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final wire = controller.selectedWire;
        final theme = Theme.of(context);

        if (wire == null) {
          return DevToolsAreaPane(
            header: const AreaPaneHeader(title: Text('Wire Inspector')),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(defaultSpacing),
                child: Text(
                  'Select a wire node in the canvas to inspect its metadata, dependencies, and live controls.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }

        final isResolving = controller.forceResolvingWires.contains(wire.key);

        return DevToolsAreaPane(
          header: AreaPaneHeader(
            title: Text(
              wire.typeName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              DevToolsButton(
                icon: Icons.close,
                tooltip: 'Close Drawer',
                onPressed: () => controller.selectWire(null),
              ),
            ],
          ),
          child: ListView(
            padding: const EdgeInsets.all(densePadding),
            children: [
              // Wire Tag & Type
              _buildSectionHeader('Wire Metadata', theme),
              _buildInfoRow('Identifier', wire.key, theme),
              _buildInfoRow('Type', wire.typeName, theme),
              _buildInfoRow('Tag', wire.tag ?? 'None (untagged)', theme),
              _buildInfoRow(
                'Wire Mode',
                wire.isAction
                    ? 'TriggerWire<T> (Action Singleton)'
                    : (wire.isAsync
                          ? 'AsyncWire<T> (Topological)'
                          : 'Wire<T> (Lazy Synchronous)'),
                theme,
              ),
              _buildInfoRow(
                'Wave Level',
                'Wave ${wire.topologicalLevel}',
                theme,
              ),
              _buildInfoRow(
                'Status',
                wire.isInitialized
                    ? (wire.isAction
                          ? '🟢 Initialized (Active Action Singleton)'
                          : '🟢 Initialized (Active Singleton)')
                    : (wire.hasFailed
                          ? '🔴 Failed during compilation'
                          : (wire.isResolving
                                ? '🟡 Resolving async factory...'
                                : (wire.isAction
                                      ? '🟣 Unresolved (Sleeping Action)'
                                      : '🟣 Unresolved (Sleeping Lazy)'))),
                theme,
              ),
              if (wire.durationMs != null)
                _buildInfoRow(
                  'Startup Duration',
                  '${wire.durationMs} ms',
                  theme,
                ),

              const PaddedDivider(
                padding: EdgeInsets.symmetric(vertical: denseSpacing),
              ),

              // Live Actions Section
              _buildSectionHeader('Live Actions', theme),
              const SizedBox(height: denseSpacing),
              if (wire.isUnresolvedLazy) ...[
                DevToolsButton(
                  icon: isResolving
                      ? null
                      : (wire.isAction
                            ? Icons.play_circle_outline
                            : Icons.bolt),
                  label: isResolving
                      ? 'Resolving...'
                      : (wire.isAction
                            ? 'Force Initialize Action'
                            : 'Force Initialize Singleton'),
                  elevated: true,
                  onPressed: isResolving
                      ? null
                      : () => controller.forceResolveWire(wire.key),
                ),
                const SizedBox(height: densePadding),
                Text(
                  'Triggers on-demand factory execution via VM Service extension (ext.circuitry.forceResolveWire).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else if (wire.isInitialized) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: denseSpacing),
                    Expanded(
                      child: Text(
                        'Active instance resides in heap memory.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Cannot force initialize async wire outside of circuit startup.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              const PaddedDivider(
                padding: EdgeInsets.symmetric(vertical: denseSpacing),
              ),

              // Dependencies List
              _buildSectionHeader('Upstream Dependencies', theme),
              const SizedBox(height: 6),
              if (wire.dependencies.isEmpty)
                Text(
                  'None (Root Dependency)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final dep in wire.dependencies)
                      ActionChip(
                        avatar: const Icon(Icons.arrow_upward, size: 12),
                        label: Text(dep),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => controller.selectWireByKey(dep),
                      ),
                  ],
                ),

              const PaddedDivider(
                padding: EdgeInsets.symmetric(vertical: denseSpacing),
              ),

              // Dependents List
              _buildSectionHeader('Downstream Dependents', theme),
              const SizedBox(height: 6),
              _buildDependentsList(wire, theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDependentsList(WireNode wire, ThemeData theme) {
    final dependents =
        controller.graphData?.dependentsOf(wire.key) ?? const <String>{};
    if (dependents.isEmpty) {
      return Text(
        'None (Leaf Consumer)',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final dep in dependents)
          ActionChip(
            avatar: const Icon(Icons.arrow_downward, size: 12),
            label: Text(dep),
            labelStyle: theme.textTheme.labelSmall?.copyWith(fontSize: 11),
            visualDensity: VisualDensity.compact,
            onPressed: () => controller.selectWireByKey(dep),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const .symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
