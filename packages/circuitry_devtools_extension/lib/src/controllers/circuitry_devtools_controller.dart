import 'dart:async';

import 'package:circuitry_devtools_extension/src/models/circuit_graph_data.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_status.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_summary.dart';
import 'package:circuitry_devtools_extension/src/models/wire_node.dart';
import 'package:circuitry_devtools_extension/src/services/circuitry_service_client.dart';
import 'package:flutter/foundation.dart';

/// Central state controller managing circuits, active DAG graph data, selection,
/// filtering, search, and live action dispatches.
class CircuitryDevToolsController(final CircuitryServiceClient _client)
    extends ChangeNotifier {
  StreamSubscription<Map<String, Object?>>? _eventSubscription;

  List<CircuitSummary> _circuits = [];
  String? _selectedCircuitId;
  CircuitGraphData? _graphData;
  WireNode? _selectedWire;

  String _searchQuery = '';
  bool _showUnresolvedOnly = false;
  bool _showAsyncOnly = false;
  bool _highlightCriticalPath = false;
  bool _isWaterfallView = false;

  bool _isLoadingCircuits = false;
  bool _isLoadingGraph = false;
  String? _errorMessage;

  final Set<String> _forceResolvingWires = {};

  List<CircuitSummary> get circuits => _circuits;
  String? get selectedCircuitId => _selectedCircuitId;
  CircuitGraphData? get graphData => _graphData;
  WireNode? get selectedWire => _selectedWire;

  String get searchQuery => _searchQuery;
  bool get showUnresolvedOnly => _showUnresolvedOnly;
  bool get showAsyncOnly => _showAsyncOnly;
  bool get highlightCriticalPath => _highlightCriticalPath;
  bool get isWaterfallView => _isWaterfallView;

  bool get isLoadingCircuits => _isLoadingCircuits;
  bool get isLoadingGraph => _isLoadingGraph;
  String? get errorMessage => _errorMessage;
  Set<String> get forceResolvingWires => .unmodifiable(_forceResolvingWires);

  CircuitSummary? get selectedCircuit =>
      _circuits.where((c) => c.id == _selectedCircuitId).firstOrNull;

  Set<String> get criticalPath => _highlightCriticalPath
      ? (_graphData?.computeCriticalPath() ?? const <String>{})
      : const <String>{};

  Set<String> get highlightedDependencies => _selectedWire == null
      ? const <String>{}
      : (_graphData?.dependenciesOf(_selectedWire!.key, transitive: true) ??
            const <String>{});

  Set<String> get highlightedDependents => _selectedWire == null
      ? const <String>{}
      : (_graphData?.dependentsOf(_selectedWire!.key, transitive: true) ??
            const <String>{});

  /// Initializes the controller and registers for real-time lifecycle event notifications.
  Future<void> init() async {
    _eventSubscription = _client.onCircuitryEvent.listen(_handleLifecycleEvent);
    await loadCircuits();
  }

  /// Fetches available circuits from the target runtime.
  Future<void> loadCircuits({bool preserveSelection = true}) async {
    _isLoadingCircuits = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _client.getCircuits();
      _circuits = List<CircuitSummary>.from(list);

      if (_circuits.isNotEmpty) {
        if (!preserveSelection ||
            _selectedCircuitId == null ||
            !_circuits.any((c) => c.id == _selectedCircuitId)) {
          await selectCircuit(_circuits.first.id);
        } else if (_selectedCircuitId != null) {
          // Refresh graph for currently selected circuit
          await selectCircuit(_selectedCircuitId!);
        }
      } else {
        _selectedCircuitId = null;
        _graphData = null;
        _selectedWire = null;
      }
    } catch (error) {
      _errorMessage = 'Failed to load circuits: $error';
    } finally {
      _isLoadingCircuits = false;
      notifyListeners();
    }
  }

  /// Selects a circuit by its [id] and downloads its full DAG graph.
  Future<void> selectCircuit(String id) async {
    _selectedCircuitId = id;
    _selectedWire = null;
    _isLoadingGraph = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final graph = await _client.getCircuitGraph(id);
      _graphData = graph;
    } catch (error) {
      _errorMessage = 'Failed to load DAG graph for circuit "$id": $error';
      _graphData = null;
    } finally {
      _isLoadingGraph = false;
      notifyListeners();
    }
  }

  /// Selects or deselects a wire node for inspection and dependency illumination.
  void selectWire(WireNode? wire) {
    if (_selectedWire == wire) {
      _selectedWire = null;
    } else {
      _selectedWire = wire;
    }
    notifyListeners();
  }

  /// Selects a wire node by its formatted [key].
  void selectWireByKey(String key) {
    final node = _graphData?.findNode(key);
    if (node != null) {
      selectWire(node);
    }
  }

  /// Updates the search filter query string.
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Toggles visibility filter for uninitialized lazy wires.
  void toggleUnresolvedOnly() {
    _showUnresolvedOnly = !_showUnresolvedOnly;
    notifyListeners();
  }

  /// Toggles visibility filter for asynchronous wires.
  void toggleAsyncOnly() {
    _showAsyncOnly = !_showAsyncOnly;
    notifyListeners();
  }

  /// Toggles critical path highlighting across the graph and waterfall.
  void toggleCriticalPath() {
    _highlightCriticalPath = !_highlightCriticalPath;
    notifyListeners();
  }

  /// Toggles between DAG visualizer and startup wave waterfall views.
  void setWaterfallView(bool value) {
    _isWaterfallView = value;
    notifyListeners();
  }

  /// Dispatches an on-demand resolution request for an uninitialized lazy wire.
  Future<bool> forceResolveWire(String wireKey) async {
    final circuitId = _selectedCircuitId;
    if (circuitId == null) return false;

    _forceResolvingWires.add(wireKey);
    notifyListeners();

    try {
      final success = await _client.forceResolveWire(circuitId, wireKey);
      if (success && _graphData != null) {
        _markWireInitializedLocally(circuitId, wireKey);
      }
      return success;
    } catch (error) {
      _errorMessage = 'Failed to force resolve "$wireKey": $error';
      return false;
    } finally {
      _forceResolvingWires.remove(wireKey);
      notifyListeners();
    }
  }

  void _markWireInitializedLocally(String circuitId, String wireKey) {
    final graph = _graphData;
    if (graph == null || graph.id != circuitId) return;

    final targetNode = graph.findNode(wireKey);
    if (targetNode == null || targetNode.isInitialized) return;

    final updatedWires = graph.wires.map((w) {
      if (w.key == wireKey) {
        return w.copyWith(isInitialized: true, isResolving: false);
      }
      return w;
    }).toList();

    final updatedWaves = <int, List<WireNode>>{};
    for (final entry in graph.waves.entries) {
      updatedWaves[entry.key] = entry.value.map((w) {
        if (w.key == wireKey) {
          return w.copyWith(isInitialized: true, isResolving: false);
        }
        return w;
      }).toList();
    }

    _graphData = CircuitGraphData(
      id: graph.id,
      debugTag: graph.debugTag,
      isDisposed: graph.isDisposed,
      wireCount: graph.wireCount,
      wires: updatedWires,
      waves: updatedWaves,
      maxWaveLevel: graph.maxWaveLevel,
      topologicalOrder: graph.topologicalOrder,
    );

    if (_selectedWire?.key == wireKey) {
      _selectedWire = _selectedWire?.copyWith(
        isInitialized: true,
        isResolving: false,
      );
    }

    // Update circuit summary counter
    final circuitIndex = _circuits.indexWhere((c) => c.id == circuitId);
    if (circuitIndex != -1) {
      final summary = _circuits[circuitIndex];
      _circuits[circuitIndex] = summary.copyWith(
        initializedWireCount: summary.initializedWireCount + 1,
      );
    }
  }

  void _handleLifecycleEvent(Map<String, Object?> event) {
    if (event case {
      'type': final String type,
      'circuitId': final String circuitId,
    }) {
      switch (type) {
        case 'circuit_building':
          final debugTag = event['debugTag'] as String?;
          final index = _circuits.indexWhere((c) => c.id == circuitId);
          if (index != -1) {
            _circuits[index] = _circuits[index].copyWith(
              status: CircuitLifecycleStatus.building,
            );
          } else {
            _circuits.add(
              CircuitSummary(
                id: circuitId,
                debugTag: debugTag,
                wireCount: 0,
                initializedWireCount: 0,
                maxLevel: 0,
                isDisposed: false,
                status: CircuitLifecycleStatus.building,
              ),
            );
          }
          notifyListeners();

        case 'circuit_ready':
          final index = _circuits.indexWhere((c) => c.id == circuitId);
          if (index != -1) {
            _circuits[index] = _circuits[index].copyWith(
              status: CircuitLifecycleStatus.ready,
            );
          }
          if (_selectedCircuitId == circuitId) {
            selectCircuit(circuitId);
          } else {
            notifyListeners();
          }

        case 'circuit_failed':
          final index = _circuits.indexWhere((c) => c.id == circuitId);
          if (index != -1) {
            _circuits[index] = _circuits[index].copyWith(
              status: CircuitLifecycleStatus.failed,
            );
            notifyListeners();
          }

        case 'wire_resolved':
          if (event['key'] case final String key) {
            _markWireInitializedLocally(circuitId, key);
            notifyListeners();
          }

        case 'circuit_disposed':
          final index = _circuits.indexWhere((c) => c.id == circuitId);
          if (index != -1) {
            _circuits[index] = _circuits[index].copyWith(
              isDisposed: true,
              status: CircuitLifecycleStatus.disposed,
            );
            if (_selectedCircuitId == circuitId) {
              selectCircuit(circuitId);
            } else {
              notifyListeners();
            }
          }
      }
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
