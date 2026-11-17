import 'dart:convert';

import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Top action and search toolbar for filtering, highlighting, and exporting graph data.
class DevToolsToolbar extends StatelessWidget {
  const DevToolsToolbar({super.key, required this.controller});

  final CircuitryDevToolsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const .symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // View Switcher (DAG Canvas vs Waterfall)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.account_tree_outlined, size: 16),
                  label: Text('DAG Canvas'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.waterfall_chart, size: 16),
                  label: Text('Startup Waterfall'),
                ),
              ],
              selected: {controller.isWaterfallView},
              onSelectionChanged: (set) =>
                  controller.setWaterfallView(set.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 14),

            // Search Field
            SizedBox(
              width: 250,
              height: 36,
              child: TextField(
                onChanged: controller.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Filter by type or tag (e.g. .prod, Auth)...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: controller.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => controller.setSearchQuery(''),
                        )
                      : null,
                  contentPadding: const .symmetric(horizontal: 12, vertical: 8),
                  border: const OutlineInputBorder(
                    borderRadius: .all(.circular(6)),
                    borderSide: BorderSide(width: 0.8),
                  ),
                  isDense: true,
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 12),

            // Filter Toggles
            FilterChip(
              label: const Text('Unresolved Only'),
              selected: controller.showUnresolvedOnly,
              onSelected: (_) => controller.toggleUnresolvedOnly(),
              visualDensity: VisualDensity.compact,
              labelStyle: theme.textTheme.labelSmall,
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Async Only'),
              selected: controller.showAsyncOnly,
              onSelected: (_) => controller.toggleAsyncOnly(),
              visualDensity: VisualDensity.compact,
              labelStyle: theme.textTheme.labelSmall,
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Critical Path'),
              selected: controller.highlightCriticalPath,
              onSelected: (_) => controller.toggleCriticalPath(),
              visualDensity: VisualDensity.compact,
              labelStyle: theme.textTheme.labelSmall,
            ),
            const SizedBox(width: 12),

            // Export Actions Menu
            PopupMenuButton<String>(
              tooltip: 'Export Graph',
              icon: const Icon(Icons.file_download_outlined, size: 20),
              onSelected: (action) => _handleExportAction(context, action),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mermaid',
                  child: Row(
                    children: [
                      Icon(Icons.code, size: 18),
                      SizedBox(width: 8),
                      Text('Copy Mermaid Diagram'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'json',
                  child: Row(
                    children: [
                      Icon(Icons.data_object, size: 18),
                      SizedBox(width: 8),
                      Text('Copy JSON Schema'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'svg',
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Copy SVG Markup'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleExportAction(BuildContext context, String action) async {
    final graph = controller.graphData;
    if (graph == null) return;

    switch (action) {
      case 'mermaid':
        final mermaid = graph.toMermaid();
        await Clipboard.setData(ClipboardData(text: mermaid));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mermaid diagram copied to clipboard.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      case 'json':
        final jsonMap = {
          'id': graph.id,
          'debugTag': graph.debugTag,
          'isDisposed': graph.isDisposed,
          'wireCount': graph.wireCount,
          'maxWaveLevel': graph.maxWaveLevel,
          'topologicalOrder': graph.topologicalOrder,
          'wires': graph.wires.map((w) => w.toJson()).toList(),
        };
        final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
        await Clipboard.setData(ClipboardData(text: jsonString));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('JSON schema copied to clipboard.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      case 'svg':
        final svg = graph.toSvg();
        await Clipboard.setData(ClipboardData(text: svg));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SVG markup copied to clipboard.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
    }
  }
}
