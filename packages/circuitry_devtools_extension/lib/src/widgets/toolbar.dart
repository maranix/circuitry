import 'dart:convert';

import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Top action and search toolbar for filtering, highlighting, and exporting graph data.
class const DevToolsToolbar({
  super.key,
  required final CircuitryDevToolsController controller,
}) extends StatefulWidget {
  @override
  State<DevToolsToolbar> createState() => _DevToolsToolbarState();
}

class _DevToolsToolbarState extends State<DevToolsToolbar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.controller.searchQuery,
    );
  }

  @override
  void didUpdateWidget(covariant DevToolsToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller.searchQuery != _searchController.text) {
      _searchController.text = widget.controller.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = widget.controller;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: defaultSpacing,
        vertical: densePadding,
      ),
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
            const SizedBox(width: defaultSpacing),

            // Search Field
            SizedBox(
              width: 260,
              height: 28,
              child: TextField(
                controller: _searchController,
                onChanged: controller.setSearchQuery,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: denseSpacing,
                    vertical: 4,
                  ),
                  hintText: 'Filter by type or tag (e.g. Database, Auth)...',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _searchController.clear();
                            controller.setSearchQuery('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
              ),
            ),
            const SizedBox(width: defaultSpacing),

            // Filter Toggles using official DevToolsToggleButton
            DevToolsToggleButton(
              isSelected: controller.showUnresolvedOnly,
              onPressed: controller.toggleUnresolvedOnly,
              message: 'Filter to show unresolved lazy wires only',
              icon: Icons.hourglass_empty,
              label: 'Unresolved Only',
            ),
            const SizedBox(width: denseSpacing),
            DevToolsToggleButton(
              isSelected: controller.showAsyncOnly,
              onPressed: controller.toggleAsyncOnly,
              message: 'Filter to show asynchronous wires only',
              icon: Icons.bolt,
              label: 'Async Only',
            ),
            const SizedBox(width: denseSpacing),
            DevToolsToggleButton(
              isSelected: controller.highlightCriticalPath,
              onPressed: controller.toggleCriticalPath,
              message: 'Highlight longest initialization sequence',
              icon: Icons.route,
              label: 'Critical Path',
            ),
            const SizedBox(width: defaultSpacing),

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
    final graph = widget.controller.graphData;
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
