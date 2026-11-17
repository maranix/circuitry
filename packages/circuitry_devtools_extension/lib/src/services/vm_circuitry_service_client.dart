import 'dart:async';

import 'package:circuitry_devtools_extension/src/models/circuit_graph_data.dart';
import 'package:circuitry_devtools_extension/src/models/circuit_summary.dart';
import 'package:circuitry_devtools_extension/src/services/circuitry_service_client.dart';
import 'package:vm_service/vm_service.dart';

/// Real VM Service-backed implementation of [CircuitryServiceClient].
final class VmCircuitryServiceClient implements CircuitryServiceClient {
  VmCircuitryServiceClient(this._vmService)
    : _eventController = StreamController<Map<String, Object?>>.broadcast() {
    _initSubscription();
  }

  final VmService _vmService;
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
    final json = response.json;
    if (json == null) return const [];

    final list = json['circuits'] as List<dynamic>? ?? const [];
    return list
        .map((c) => CircuitSummary.fromJson((c as Map).cast<String, Object?>()))
        .toList();
  }

  @override
  Future<CircuitGraphData> getCircuitGraph(String circuitId) async {
    final response = await _vmService.callServiceExtension(
      'ext.circuitry.getCircuitGraph',
      args: {'id': circuitId},
    );
    final json = response.json;
    if (json == null) {
      throw StateError('Empty response for circuit "$circuitId".');
    }

    return CircuitGraphData.fromJson(json.cast<String, Object?>());
  }

  @override
  Future<bool> forceResolveWire(String circuitId, String wireKey) async {
    final response = await _vmService.callServiceExtension(
      'ext.circuitry.forceResolveWire',
      args: {'id': circuitId, 'key': wireKey},
    );
    final json = response.json;
    if (json == null) return false;

    return json['success'] == true;
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}
