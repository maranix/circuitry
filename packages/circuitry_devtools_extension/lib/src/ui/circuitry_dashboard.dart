// ignore_for_file: deprecated_member_use

import 'package:circuitry_devtools_extension/src/layout/sugiyama_layout.dart';
import 'package:circuitry_devtools_extension/src/model/circuit_devtools_models.dart';
import 'package:circuitry_devtools_extension/src/service/circuitry_client.dart';
import 'package:circuitry_devtools_extension/src/ui/circuit_navigator.dart';
import 'package:circuitry_devtools_extension/src/ui/dag_canvas.dart';
import 'package:circuitry_devtools_extension/src/ui/wave_profiler.dart';
import 'package:circuitry_devtools_extension/src/ui/wire_drawer.dart';
import 'package:flutter/material.dart';

/// The main dashboard integrating the [CircuitNavigator], [DagCanvas],
/// [WireDrawer], and [WaveProfiler] into a unified inspection workbench.
class CircuitryDashboard extends StatefulWidget {
  /// The client communicating with the target application.
  final CircuitryClient? client;

  /// Creates a [CircuitryDashboard].
  const CircuitryDashboard({super.key, this.client});

  @override
  State<CircuitryDashboard> createState() => _CircuitryDashboardState();
}

class _CircuitryDashboardState extends State<CircuitryDashboard> {
  late final CircuitryClient _client;

  List<CircuitSummary> _circuits = [];
  CircuitSummary? _selectedCircuit;
  CircuitGraphData? _graphData;
  LayoutGraph? _layoutGraph;
  String? _selectedWireKey;
  bool _isLoading = false;
  bool _isInitializingWire = false;
  bool _isWaveProfilerExpanded = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? MockCircuitryClient();
    _refreshCircuits();
  }

  Future<void> _refreshCircuits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final circuits = await _client.getCircuits();
      setState(() {
        _circuits = circuits;
      });

      if (circuits.isNotEmpty) {
        final currentId = _selectedCircuit?.id;
        final target = circuits.firstWhere(
          (c) => c.id == currentId,
          orElse: () => circuits.first,
        );
        await _selectCircuit(target);
      } else {
        setState(() {
          _selectedCircuit = null;
          _graphData = null;
          _layoutGraph = null;
          _selectedWireKey = null;
        });
      }
    } catch (e, st) {
      setState(() {
        _errorMessage = 'Failed to load circuits: $e';
      });
      debugPrint('Error refreshing circuits: $e\n$st');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectCircuit(CircuitSummary circuit) async {
    setState(() {
      _selectedCircuit = circuit;
      _isLoading = true;
      _selectedWireKey = null;
    });

    try {
      final graphData = await _client.getCircuitGraph(circuit.id);
      if (graphData != null) {
        final layoutGraph = graphData.buildLayoutGraph();
        setState(() {
          _graphData = graphData;
          _layoutGraph = layoutGraph;
        });
      }
    } catch (e, st) {
      setState(() {
        _errorMessage = 'Failed to load graph for ${circuit.id}: $e';
      });
      debugPrint('Error inspecting circuit ${circuit.id}: $e\n$st');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _forceInitializeWire(String wireKey) async {
    if (_selectedCircuit == null) return;

    setState(() {
      _isInitializingWire = true;
    });

    try {
      await _client.forceResolveWire(_selectedCircuit!.id, wireKey);
      // Re-fetch graph to reflect newly resolved status
      final graphData = await _client.getCircuitGraph(_selectedCircuit!.id);
      if (graphData != null) {
        final layoutGraph = graphData.buildLayoutGraph();
        setState(() {
          _graphData = graphData;
          _layoutGraph = layoutGraph;
        });
      }
    } catch (e, st) {
      debugPrint('Error force-resolving wire $wireKey: $e\n$st');
    } finally {
      setState(() {
        _isInitializingWire = false;
      });
    }
  }

  void _onWireSelected(String wireKey) {
    setState(() {
      _selectedWireKey = wireKey.isEmpty ? null : wireKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selectedWire = _selectedWireKey != null && _graphData != null
        ? _graphData!.wireMap[_selectedWireKey!]
        : null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16.0,
        backgroundColor: colorScheme.surface,
        elevation: 1.0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Icon(
                Icons.account_tree,
                size: 20.0,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10.0),
            Text(
              'Circuitry DAG Inspector',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_selectedCircuit != null) ...[
              const SizedBox(width: 12.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 3.0,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  _selectedCircuit!.id,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isWaveProfilerExpanded
                  ? Icons.waterfall_chart
                  : Icons.waterfall_chart_outlined,
            ),
            tooltip: _isWaveProfilerExpanded
                ? 'Hide Wave Profiler'
                : 'Show Wave Profiler',
            color: _isWaveProfilerExpanded ? colorScheme.primary : null,
            onPressed: () {
              setState(() {
                _isWaveProfilerExpanded = !_isWaveProfilerExpanded;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Circuits & Graphs',
            onPressed: _refreshCircuits,
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      body: _isLoading && _layoutGraph == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _circuits.isEmpty
          ? _buildErrorView(context)
          : Row(
              children: [
                // Left Panel: CircuitNavigator
                SizedBox(
                  width: 270.0,
                  child: CircuitNavigator(
                    circuits: _circuits,
                    selectedCircuitId: _selectedCircuit?.id,
                    onSelect: _selectCircuit,
                    onRefresh: _refreshCircuits,
                  ),
                ),

                // Center & Bottom: DagCanvas & WaveProfiler
                Expanded(
                  child: Column(
                    children: [
                      // Center DAG Canvas
                      Expanded(
                        child: _layoutGraph == null
                            ? Center(
                                child: Text(
                                  'Select a circuit on the left to inspect its DAG.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                              )
                            : DagCanvas(
                                graph: _layoutGraph!,
                                selectedNodeId: _selectedWireKey,
                                onNodeSelected: _onWireSelected,
                              ),
                      ),

                      // Bottom Drawer: WaveProfiler
                      if (_isWaveProfilerExpanded && _graphData != null)
                        SizedBox(
                          height: 220.0,
                          child: WaveProfiler(
                            wires: _graphData!.wires,
                            criticalPath: _graphData!.criticalPath,
                            totalDuration: _graphData!.totalDuration,
                            onSelectWire: _onWireSelected,
                            selectedWireKey: _selectedWireKey,
                          ),
                        ),
                    ],
                  ),
                ),

                // Right Panel: WireDrawer
                SizedBox(
                  width: 300.0,
                  child: WireDrawer(
                    wire: selectedWire,
                    onSelectWire: _onWireSelected,
                    onForceInitialize: _forceInitializeWire,
                    isInitializing: _isInitializingWire,
                    onClose: () => setState(() => _selectedWireKey = null),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48.0, color: Colors.red),
            const SizedBox(height: 16.0),
            Text(
              _errorMessage ?? 'An error occurred',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _refreshCircuits,
            ),
          ],
        ),
      ),
    );
  }
}
