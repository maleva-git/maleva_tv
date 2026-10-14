import 'package:maleva_tv/core/network/java_api_client.dart';
import 'planning_job.dart';

/// The day's saved plans from the shared Planning API (`POST /api/planing/select-planning`, the list
/// behind React's /planning/view), read-only: the TV never saves or changes a plan.
class PlanningApi {
  PlanningApi(this._client);

  final JavaApiClient _client;

  /// Every job of every plan dated [date] (`saledetails`), in the plans' own order.
  Future<List<PlanningJob>> dayPlan({required int companyId, required DateTime date}) async {
    final day = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _client.post('/api/planing/select-planning', body: {
      'comid': companyId,
      'employeeid': 0,
      'search': '',
      'fromdate': day,
      'todate': day,
    });
    final rows = data is Map<String, dynamic> ? data['saledetails'] : null;
    if (rows is! List) return [];
    return rows.whereType<Map<String, dynamic>>().map(PlanningJob.fromJson).toList();
  }
}
