import 'dart:async';

import 'package:circuitry_devtools_extension/src/models/circuit_graph_data.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_summary.dart';
import 'package:circuitry_devtools_extension/src/services/circuitry_service_client.dart';
import 'package:vm_service/vm_service.dart';

/// Real VM Service-backed implementation of [CircuitryServiceClient].
final class VmCircuitryServiceClient(final VmService _vmService)
    implements CircuitryServiceClient {
  this : _eventController = .broadcast() {
    _initSubscription();
  }

  final StreamController<Map<String, Object?>> _eventController;
  StreamSubscription<Event>? _eventSubscription;

  void _initSubscription() {
    try {
      unawaited(
        _vmService
            .streamListen(EventStreams.kExtension)
            .catchError((_) => Success()),
      );
    } catch (_) {}

    _eventSubscription = _vmService.onExtensionEvent.listen((event) {
      if (event.extensionKind == 'Circuitry') {
        final data = event.extensionData?.data;
        if (data != null && !_eventController.isClosed) {
          _eventController.add(Map<String, Object?>.from(data));
        }
      }
    });
  }

  @override
  Stream<Map<String, Object?>> get onCircuitryEvent => _eventController.stream;

  @override
  Future<List<CircuitSummary>> getCircuits() async {
    final response = await _vmService.callServiceExtension(
      'ext.circuitry.getCircuits',
    );
    if (response.json case {'circuits': final List<Object?> list}) {
      return <CircuitSummary>[
        for (final item in list)
          if (item case final Map<String, Object?> map)
            .fromJson(map)
          else if (item case final Map<Object?, Object?> map)
            .fromJson(map.cast<String, Object?>()),
      ];
    }
    return const [];
  }

  @override
  Future<CircuitGraphData> getCircuitGraph(String circuitId) async {
    final response = await _vmService.callServiceExtension(
      'ext.circuitry.getCircuitGraph',
      args: {'id': circuitId},
    );
    if (response.json case final Map<String, Object?> json) {
      return .fromJson(json);
    }
    throw StateError('Empty response for circuit "$circuitId".');
  }

  @override
  Future<bool> forceResolveWire(String circuitId, String wireKey) async {
    final response = await _vmService.callServiceExtension(
      'ext.circuitry.forceResolveWire',
      args: {'id': circuitId, 'key': wireKey},
    );
    return switch (response.json) {
      {'success': true} => true,
      _ => false,
    };
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}
