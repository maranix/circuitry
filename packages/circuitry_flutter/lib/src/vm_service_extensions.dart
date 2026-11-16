import 'dart:convert';
import 'dart:developer' as developer;

import 'package:circuitry/circuitry.dart';
import 'package:circuitry_flutter/src/circuit_registry.dart';
import 'package:flutter/foundation.dart';

/// Extension method name for retrieving all registered circuits.
const String getCircuitsExtension = 'ext.circuitry.getCircuits';

/// Extension method name for retrieving the introspected DAG graph of a specific circuit.
const String getCircuitGraphExtension = 'ext.circuitry.getCircuitGraph';

/// Extension method name for triggering instantiation of a specific wire in a circuit.
const String forceResolveWireExtension = 'ext.circuitry.forceResolveWire';

bool _extensionsRegistered = false;

/// Registers Circuitry VM service extensions with the Dart VM service.
///
/// Extensions:
/// * `ext.circuitry.getCircuits`: returns list of registered circuits.
/// * `ext.circuitry.getCircuitGraph`: returns circuit.inspect().toJson() for requested circuit id.
/// * `ext.circuitry.forceResolveWire`: triggers wire instantiation.
///
/// Guarded by [kDebugMode] so release builds tree-shake extension handlers completely.
void registerCircuitryVmServiceExtensions() {
  if (!kDebugMode) return;
  if (_extensionsRegistered) return;
  _extensionsRegistered = true;

  _registerSafe(getCircuitsExtension, _handleGetCircuits);
  _registerSafe(getCircuitGraphExtension, _handleGetCircuitGraph);
  _registerSafe(forceResolveWireExtension, _handleForceResolveWire);
}

void _registerSafe(
  String method,
  Future<developer.ServiceExtensionResponse> Function(
    String method,
    Map<String, String> parameters,
  )
  handler,
) {
  try {
    developer.registerExtension(method, handler);
  } on ArgumentError catch (_) {
    // Already registered in the VM service.
  }
}

/// Dispatches a service extension call to the corresponding handler.
///
/// Exposed for testing where an active Dart VM service connection is not available.
Future<developer.ServiceExtensionResponse> handleCircuitryServiceExtension(
  String method,
  Map<String, String> parameters, {
  CircuitRegistry? registry,
}) async {
  final reg = registry ?? CircuitRegistry.instance;
  return switch (method) {
    getCircuitsExtension => _handleGetCircuits(
      method,
      parameters,
      registry: reg,
    ),
    getCircuitGraphExtension => _handleGetCircuitGraph(
      method,
      parameters,
      registry: reg,
    ),
    forceResolveWireExtension => _handleForceResolveWire(
      method,
      parameters,
      registry: reg,
    ),
    _ => developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      'Unknown service extension method: $method',
    ),
  };
}

Future<developer.ServiceExtensionResponse> _handleGetCircuits(
  String method,
  Map<String, String> parameters, {
  CircuitRegistry? registry,
}) async {
  final reg = registry ?? CircuitRegistry.instance;
  final circuits = reg.circuits.values.map((entry) => entry.toJson()).toList();
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'type': 'CircuitList', 'circuits': circuits}),
  );
}

Future<developer.ServiceExtensionResponse> _handleGetCircuitGraph(
  String method,
  Map<String, String> parameters, {
  CircuitRegistry? registry,
}) async {
  final reg = registry ?? CircuitRegistry.instance;
  final circuitId = parameters['id'] ?? parameters['circuitId'];
  if (circuitId == null || circuitId.isEmpty) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.invalidParams,
      'Missing required parameter: id',
    );
  }

  final entry = reg.getCircuitById(circuitId);
  if (entry == null) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      'Circuit not found: $circuitId',
    );
  }

  try {
    final graph = entry.circuit.inspect().toJson();
    return developer.ServiceExtensionResponse.result(jsonEncode(graph));
  } catch (e, st) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      'Failed to inspect circuit $circuitId: $e\n$st',
    );
  }
}

Future<developer.ServiceExtensionResponse> _handleForceResolveWire(
  String method,
  Map<String, String> parameters, {
  CircuitRegistry? registry,
}) async {
  final reg = registry ?? CircuitRegistry.instance;
  final circuitId = parameters['id'] ?? parameters['circuitId'];
  if (circuitId == null || circuitId.isEmpty) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.invalidParams,
      'Missing required parameter: id',
    );
  }

  final entry = reg.getCircuitById(circuitId);
  if (entry == null) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      'Circuit not found: $circuitId',
    );
  }

  if (entry.circuit.isDisposed) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      'Circuit $circuitId is disposed',
    );
  }

  final keyParam =
      parameters['key'] ?? parameters['wireKey'] ?? parameters['type'];
  if (keyParam == null || keyParam.isEmpty) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.invalidParams,
      'Missing required parameter: key',
    );
  }

  final tagParam = parameters['tag'];
  final matchedKey = _findWireKey(entry.circuit, keyParam, tagParam);

  if (matchedKey == null) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      'Wire not found in circuit $circuitId for key: $keyParam',
    );
  }

  try {
    final wire = entry.circuit.wires[matchedKey]!;
    Object? instance;
    if (entry.circuit.isKeyInitialized(matchedKey)) {
      instance = entry.circuit.instances[matchedKey];
    } else if (wire is Wire<Object?>) {
      instance = wire.connect(entry.circuit);
      entry.circuit.instances[matchedKey] = instance;
    } else {
      instance = entry.circuit.instances[matchedKey];
    }

    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'success': true,
        'key': keyParam,
        'resolved': true,
        'instanceType': instance?.runtimeType.toString(),
      }),
    );
  } catch (e, st) {
    return developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.extensionError,
      'Failed to resolve wire $keyParam: $e\n$st',
    );
  }
}

WireKey? _findWireKey(Circuit circuit, String keyParam, String? tagParam) {
  for (final key in circuit.wires.keys) {
    final (type, tag) = key;
    final typeName = type.toString();
    final tagString = tag?.toString();
    final tagName = tag?.name;

    // Composite match: "Type#Tag" or "Type#TagName"
    if (keyParam == '$typeName#$tagString' ||
        (tagName != null && keyParam == '$typeName#$tagName')) {
      return key;
    }

    // Format match: "Type(tag: Tag)" or "Type(tag: TagName)"
    if (keyParam == '$typeName(tag: $tagString)' ||
        (tagName != null && keyParam == '$typeName(tag: $tagName)')) {
      return key;
    }

    // Type name match
    if (keyParam == typeName) {
      if (tagParam == null && tag == null) {
        return key;
      }
      if (tagParam != null && (tagParam == tagName || tagParam == tagString)) {
        return key;
      }
    }
  }
  return null;
}
