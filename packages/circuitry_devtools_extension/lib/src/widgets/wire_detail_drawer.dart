import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:circuitry_devtools_extension/src/models/wire_node.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

/// Right drawer panel inspecting a selected [WireNode], its dependency links,
/// and live on-demand initialization actions.
class WireDetailDrawer extends StatelessWidget {
  const WireDetailDrawer({super.key, required this.controller});

  final CircuitryDevToolsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final wire = controller.selectedWire;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        if (wire == null) {
          return Container(
            width: 320,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                left: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Center(
              child: Padding(
                padding: const .all(24.0),
                child: Text(
                  'Select a wire node in the canvas to inspect its metadata, dependencies, and live controls.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }

        final isResolving = controller.forceResolvingWires.contains(wire.key);

        return Container(
          width: 330,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              left: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              AreaPaneHeader(
                title: Text(
                  wire.typeName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close Drawer',
                    onPressed: () => controller.selectWire(null),
                  ),
                ],
              ),

              // Content
              Expanded(
                child: ListView(
                  padding: const .all(14.0),
                  children: [
                    // Wire Tag & Type
                    _buildSectionHeader('Wire Metadata', theme),
                    _buildInfoRow('Identifier', wire.key, theme),
                    _buildInfoRow('Type', wire.typeName, theme),
                    _buildInfoRow('Tag', wire.tag ?? 'None (untagged)', theme),
                    _buildInfoRow(
                      'Wire Mode',
                      wire.isAsync
                          ? 'AsyncWire<T> (Topological)'
                          : 'Wire<T> (Lazy Synchronous)',
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
                          ? '🟢 Initialized (Active Singleton)'
                          : (wire.hasFailed
                                ? '🔴 Failed during compilation'
                                : (wire.isResolving
                                      ? '🟡 Resolving async factory...'
                                      : '🟣 Unresolved (Sleeping Lazy)')),
                      theme,
                    ),
                    if (wire.durationMs != null)
                      _buildInfoRow(
                        'Startup Duration',
                        '${wire.durationMs} ms',
                        theme,
                      ),

                    const Divider(height: 24),

                    // Live Actions Section
                    _buildSectionHeader('Live Actions', theme),
                    const SizedBox(height: 8),
                    if (wire.isUnresolvedLazy) ...[
                      ElevatedButton.icon(
                        icon: isResolving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bolt, size: 16),
                        label: Text(
                          isResolving
                              ? 'Resolving...'
                              : 'Force Initialize Singleton',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const .symmetric(vertical: 10),
                          textStyle: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: isResolving
                            ? null
                            : () => controller.forceResolveWire(wire.key),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Triggers on-demand factory execution via VM Service extension (ext.circuitry.forceResolveWire).',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ] else if (wire.isInitialized) ...[
                      Container(
                        padding: const .all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: const .all(.circular(6)),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Active instance resides in heap memory.',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Cannot force initialize async wire outside of circuit startup.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],

                    const Divider(height: 24),

                    // Dependencies List
                    _buildSectionHeader('Upstream Dependencies', theme),
                    const SizedBox(height: 6),
                    if (wire.dependencies.isEmpty)
                      Text(
                        'None (Root Dependency)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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

                    const Divider(height: 24),

                    // Dependents List
                    _buildSectionHeader('Downstream Dependents', theme),
                    const SizedBox(height: 6),
                    _buildDependentsList(wire, theme),
                  ],
                ),
              ),
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
