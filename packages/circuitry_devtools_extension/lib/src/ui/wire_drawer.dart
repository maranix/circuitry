// ignore_for_file: deprecated_member_use

import 'package:circuitry_devtools_extension/src/model/circuit_devtools_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Drawer / sidebar widget displaying comprehensive metadata, dependencies,
/// and dependents for a selected wire node in the Circuit DAG.
class WireDrawer extends StatelessWidget {
  /// The currently selected wire details, or `null` if no wire is selected.
  final WireModel? wire;

  /// Callback to navigate and focus on another wire (e.g. from dependencies or dependents).
  final ValueChanged<String>? onSelectWire;

  /// Callback triggered when user clicks 'Force Initialize' for an unresolved lazy wire.
  final ValueChanged<String>? onForceInitialize;

  /// Whether a force initialization request is actively executing.
  final bool isInitializing;

  /// Callback to close or deselect the current wire.
  final VoidCallback? onClose;

  /// Creates a [WireDrawer].
  const WireDrawer({
    super.key,
    this.wire,
    this.onSelectWire,
    this.onForceInitialize,
    this.isInitializing = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20.0,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'Wire Inspector',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onClose != null && wire != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18.0),
                    tooltip: 'Close Inspector',
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: wire == null
                ? _buildEmptyPlaceholder(context)
                : _buildWireDetails(context, wire!),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 40.0,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 12.0),
            Text(
              'No Wire Selected',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Click any node in the DAG canvas to inspect its key, dependencies, wave level, and status.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWireDetails(BuildContext context, WireModel model) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLazy =
        model.status.toLowerCase() == 'unresolvedlazy' ||
        model.status.toLowerCase() == 'lazy';

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Wire Key card
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      model.typeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16.0),
                    tooltip: 'Copy Key',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: model.key));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied "${model.key}" to clipboard'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (model.tag != null) ...[
                const SizedBox(height: 4.0),
                Row(
                  children: [
                    Text(
                      'Tag: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 1.0,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        model.tag!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16.0),

        // Status & Metadata Badges
        Text(
          'PROPERTIES',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.outline,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8.0),

        _buildPropertyRow(
          context,
          label: 'Status',
          trailing: _buildStatusBadge(model.status),
        ),
        _buildPropertyRow(
          context,
          label: 'Wave Level',
          trailing: Text(
            'Wave ${model.waveLevel}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        _buildPropertyRow(
          context,
          label: 'Resolution Type',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: model.isAsync
                  ? Colors.blue.shade50
                  : Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(
                color: model.isAsync
                    ? Colors.blue.shade300
                    : Colors.indigo.shade200,
              ),
            ),
            child: Text(
              model.isAsync ? 'Asynchronous' : 'Synchronous',
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
                color: model.isAsync
                    ? Colors.blue.shade800
                    : Colors.indigo.shade800,
              ),
            ),
          ),
        ),
        _buildPropertyRow(
          context,
          label: 'Resolution Duration',
          trailing: Text(
            model.resolutionDuration != null
                ? _formatDuration(model.resolutionDuration!)
                : (isLazy ? 'Deferred (Lazy)' : 'N/A'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: model.resolutionDuration != null
                  ? Colors.green.shade800
                  : colorScheme.outline,
            ),
          ),
        ),
        if (model.isCriticalPath)
          _buildPropertyRow(
            context,
            label: 'Critical Path',
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: Colors.deepOrange.shade300),
              ),
              child: Text(
                'Critical Path Node',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange.shade800,
                ),
              ),
            ),
          ),

        const SizedBox(height: 16.0),

        // Force Initialize Button (for unresolvedLazy wires)
        if (isLazy) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: isInitializing
                  ? const SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt, size: 18.0),
              label: Text(
                isInitializing ? 'Initializing...' : 'Force Initialize',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                foregroundColor: Colors.white,
              ),
              onPressed: isInitializing
                  ? null
                  : () => onForceInitialize?.call(model.key),
            ),
          ),
          const SizedBox(height: 16.0),
        ],

        const Divider(),
        const SizedBox(height: 8.0),

        // Dependencies List (Upstream)
        Row(
          children: [
            const Icon(Icons.arrow_back, size: 16.0, color: Color(0xFF1976D2)),
            const SizedBox(width: 6.0),
            Text(
              'Dependencies (${model.dependencies.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6.0),
        if (model.dependencies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'No upstream dependencies (Root Wire)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...model.dependencies.map((depKey) {
            return _buildWireLinkChip(
              context,
              keyName: depKey,
              isUpstream: true,
            );
          }),

        const SizedBox(height: 16.0),

        // Dependents List (Downstream)
        Row(
          children: [
            const Icon(
              Icons.arrow_forward,
              size: 16.0,
              color: Color(0xFFF57C00),
            ),
            const SizedBox(width: 6.0),
            Text(
              'Dependents (${model.dependents.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6.0),
        if (model.dependents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'No downstream dependents (Leaf Wire)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...model.dependents.map((depKey) {
            return _buildWireLinkChip(
              context,
              keyName: depKey,
              isUpstream: false,
            );
          }),
      ],
    );
  }

  Widget _buildPropertyRow(
    BuildContext context, {
    required String label,
    required Widget trailing,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildWireLinkChip(
    BuildContext context, {
    required String keyName,
    required bool isUpstream,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = isUpstream
        ? const Color(0xFF1976D2)
        : const Color(0xFFF57C00);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Material(
        color: accent.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6.0),
          side: BorderSide(color: accent.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6.0),
          onTap: () => onSelectWire?.call(keyName),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Icon(
                  isUpstream ? Icons.south_west : Icons.north_east,
                  size: 14.0,
                  color: accent,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    keyName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16.0,
                  color: colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final (label, bgColor, fgColor, icon) = switch (status.toLowerCase()) {
      'resolved' => (
        'Resolved',
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
        Icons.check_circle,
      ),
      'unresolvedlazy' || 'lazy' => (
        'Unresolved Lazy',
        const Color(0xFFF3E5F5),
        const Color(0xFF7B1FA2),
        Icons.schedule,
      ),
      'resolving' => (
        'Resolving...',
        const Color(0xFFFFF8E1),
        const Color(0xFFFFA000),
        Icons.hourglass_top,
      ),
      'failed' || 'failure' => (
        'Failed',
        const Color(0xFFFFEBEE),
        const Color(0xFFD32F2F),
        Icons.error,
      ),
      'disposed' => (
        'Disposed',
        Colors.grey.shade200,
        Colors.grey.shade800,
        Icons.delete_outline,
      ),
      _ => (
        status,
        Colors.grey.shade200,
        Colors.grey.shade800,
        Icons.help_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.0, color: fgColor),
          const SizedBox(width: 4.0),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMilliseconds > 0) {
      final ms = d.inMicroseconds / 1000.0;
      return '${ms.toStringAsFixed(2)} ms';
    }
    return '${d.inMicroseconds} µs';
  }
}
