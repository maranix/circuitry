// ignore_for_file: deprecated_member_use

import 'package:circuitry_devtools_extension/src/model/circuit_devtools_models.dart';
import 'package:flutter/material.dart';

/// Displays a navigable list/tree of detected Circuit instances with their
/// ID, tag, lifecycle state badge (Building, Ready, Failure), and wire count.
class CircuitNavigator extends StatefulWidget {
  /// The list of circuits detected in the running application.
  final List<CircuitSummary> circuits;

  /// The ID of the currently selected circuit, if any.
  final String? selectedCircuitId;

  /// Callback triggered when the user selects a circuit.
  final ValueChanged<CircuitSummary>? onSelect;

  /// Optional callback to manually refresh the list of circuits.
  final VoidCallback? onRefresh;

  /// Creates a [CircuitNavigator].
  const CircuitNavigator({
    super.key,
    required this.circuits,
    this.selectedCircuitId,
    this.onSelect,
    this.onRefresh,
  });

  @override
  State<CircuitNavigator> createState() => _CircuitNavigatorState();
}

class _CircuitNavigatorState extends State<CircuitNavigator> {
  String _filterText = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredCircuits = widget.circuits.where((circuit) {
      if (_filterText.isEmpty) return true;
      final q = _filterText.toLowerCase();
      return circuit.id.toLowerCase().contains(q) ||
          (circuit.tag?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header toolbar
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
                  Icons.hub_outlined,
                  size: 20.0,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8.0),
                Text(
                  'Circuits',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Text(
                    '${widget.circuits.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18.0),
                    tooltip: 'Refresh Circuits',
                    onPressed: widget.onRefresh,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // Search / filter bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filter circuits...',
                prefixIcon: const Icon(Icons.search, size: 18.0),
                isDense: true,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 8.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _filterText = value),
            ),
          ),

          // Circuits list
          Expanded(
            child: filteredCircuits.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    itemCount: filteredCircuits.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    itemBuilder: (context, index) {
                      final circuit = filteredCircuits[index];
                      final isSelected = circuit.id == widget.selectedCircuitId;
                      return _buildCircuitCard(context, circuit, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isSearching = _filterText.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.inbox_outlined,
              size: 40.0,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12.0),
            Text(
              isSearching
                  ? 'No circuits match "$_filterText"'
                  : 'No active circuits detected',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 8.0),
              Text(
                'Mount CircuitProvider in your Flutter widget tree or register a Circuit with CircuitRegistry.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircuitCard(
    BuildContext context,
    CircuitSummary circuit,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.45)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () => widget.onSelect?.call(circuit),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        circuit.id,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    _buildStateBadge(circuit.state),
                  ],
                ),
                const SizedBox(height: 8.0),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: [
                    if (circuit.tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          'tag: ${circuit.tag}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cable,
                            size: 12.0,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            '${circuit.wireCount} ${circuit.wireCount == 1 ? 'wire' : 'wires'}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (circuit.isDisposed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          'Disposed',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateBadge(String state) {
    final (label, bgColor, fgColor, icon) = switch (state.toLowerCase()) {
      'ready' => (
        'Ready',
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
        Icons.check_circle_outline,
      ),
      'building' => (
        'Building',
        const Color(0xFFFFF8E1),
        const Color(0xFFF57F17),
        Icons.hourglass_empty,
      ),
      'failure' || 'failed' => (
        'Failure',
        const Color(0xFFFFEBEE),
        const Color(0xFFC62828),
        Icons.error_outline,
      ),
      _ => (
        state,
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
}
