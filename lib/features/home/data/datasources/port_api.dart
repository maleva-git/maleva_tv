import 'package:maleva_tv/core/network/java_api_client.dart';

/// The company's active ports (`GET /api/port-masters/company/{id}/active`), the list React's
/// Vessel Planning page offers in its port filter.
class PortApi {
  PortApi(this._client);

  final JavaApiClient _client;

  /// Port names, trimmed, without blanks or repeats, sorted A-Z.
  Future<List<String>> activePorts(int companyId) async {
    final data = await _client.get('/api/port-masters/company/$companyId/active');
    if (data is! List) return [];
    final names = <String>{
      for (final row in data.whereType<Map<String, dynamic>>())
        if ((row['portName'] ?? row['PortName'])?.toString().trim() case final String name when name.isNotEmpty) name,
    }.toList()
      ..sort();
    return names;
  }
}
