import 'package:circuitry_devtools_extension/src/controllers/circuitry_devtools_controller.dart';
import 'package:circuitry_devtools_extension/src/services/circuitry_service_client.dart';
import 'package:circuitry_devtools_extension/src/widgets/circuit_navigator.dart';
import 'package:circuitry_devtools_extension/src/widgets/dag_canvas.dart';
import 'package:circuitry_devtools_extension/src/widgets/toolbar.dart';
import 'package:circuitry_devtools_extension/src/widgets/wave_waterfall_profiler.dart';
import 'package:circuitry_devtools_extension/src/widgets/wire_detail_drawer.dart';
import 'package:flutter/material.dart';

/// Root DevTools extension screen hosting the Circuit Navigator, Interactive DAG Canvas,
/// Startup Wave Waterfall, and Wire Detail Drawer.
class CircuitryDevToolsScreen extends StatefulWidget {
  const CircuitryDevToolsScreen({super.key, required this.serviceClient});

  final CircuitryServiceClient serviceClient;

  @override
  State<CircuitryDevToolsScreen> createState() =>
      _CircuitryDevToolsScreenState();
}

class _CircuitryDevToolsScreenState extends State<CircuitryDevToolsScreen> {
  late final CircuitryDevToolsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CircuitryDevToolsController(widget.serviceClient);
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          body: Column(
            children: [
              // Top Action & Search Toolbar
              DevToolsToolbar(controller: _controller),

              // Error Banner (if any)
              if (_controller.errorMessage != null)
                MaterialBanner(
                  content: Text(_controller.errorMessage!),
                  leading: const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                  ),
                  backgroundColor: Colors.amber.withValues(alpha: 0.15),
                  actions: [
                    TextButton(
                      child: const Text('Dismiss'),
                      onPressed: () => _controller.loadCircuits(),
                    ),
                  ],
                ),

              // Workspace Tri-Pane Layout
              Expanded(
                child: Row(
                  children: [
                    // Left Sidebar: Circuit Navigator
                    SizedBox(
                      width: 250,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ),
                        child: CircuitNavigator(controller: _controller),
                      ),
                    ),

                    // Center Workspace: DAG Canvas or Waterfall Profiler
                    Expanded(
                      child: _controller.isLoadingGraph
                          ? const Center(child: CircularProgressIndicator())
                          : (_controller.isWaterfallView
                                ? WaveWaterfallProfiler(controller: _controller)
                                : DagCanvas(controller: _controller)),
                    ),

                    // Right Drawer: Wire Detail & Live Actions
                    WireDetailDrawer(controller: _controller),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
