import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_status.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_summary.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:material_ui/material_ui.dart';

/// Sidebar navigator displaying the detected [Circuit] containers running in the app.
class const CircuitNavigator({
  super.key,
  required final CircuitryDevToolsController controller,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DevToolsAreaPane(
      header: AreaPaneHeader(
        title: const Text('Circuits'),
        actions: [
          DevToolsButton(
            icon: Icons.refresh,
            tooltip: 'Refresh circuit registry',
            onPressed: controller.isLoadingCircuits
                ? null
                : controller.loadCircuits,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.isLoadingCircuits)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          Expanded(
            child: controller.circuits.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(defaultSpacing),
                      child: Text(
                        'No circuits detected.\nEnsure debug assertions are enabled.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(densePadding),
                    itemCount: controller.circuits.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: denseSpacing),
                    itemBuilder: (context, index) {
                      final circuit = controller.circuits[index];
                      final isSelected =
                          circuit.id == controller.selectedCircuitId;
                      return _CircuitCard(
                        circuit: circuit,
                        isSelected: isSelected,
                        onTap: () => controller.selectCircuit(circuit.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class const _CircuitCard({
  required final CircuitSummary circuit,
  required final bool isSelected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (statusColor, statusBg) = switch (circuit.status) {
      CircuitLifecycleStatus.building => (
        Colors.amber.shade800,
        Colors.amber.shade50,
      ),
      CircuitLifecycleStatus.ready => (
        Colors.green.shade700,
        Colors.green.shade50,
      ),
      CircuitLifecycleStatus.failed => (
        Colors.red.shade700,
        Colors.red.shade50,
      ),
      CircuitLifecycleStatus.disposed => (
        Colors.grey.shade700,
        Colors.grey.shade100,
      ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: const .all(.circular(8.0)),
      child: Container(
        padding: const .all(10.0),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.surface,
          borderRadius: const .all(.circular(8.0)),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    circuit.debugTag != null && circuit.debugTag!.isNotEmpty
                        ? circuit.debugTag!
                        : circuit.id,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const .symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: const .all(.circular(4.0)),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    circuit.status.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (circuit.debugTag != null && circuit.debugTag!.isNotEmpty)
              Text(
                circuit.id,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _counterBadge('Wires', '${circuit.wireCount}', theme),
                _counterBadge(
                  'Resolved',
                  '${circuit.initializedWireCount}',
                  theme,
                  Colors.green.shade700,
                ),
                _counterBadge(
                  'Uninit',
                  '${circuit.uninitializedWireCount}',
                  theme,
                  Colors.orange.shade800,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterBadge(
    String label,
    String value,
    ThemeData theme, [
    Color? color,
  ]) {
    return Text(
      '$label: $value',
      style: theme.textTheme.labelSmall?.copyWith(
        fontSize: 10,
        color: color ?? theme.colorScheme.onSurfaceVariant,
        fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
