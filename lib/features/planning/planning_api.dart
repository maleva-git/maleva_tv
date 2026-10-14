import 'package:maleva_tv/core/network/java_api_client.dart';
import 'planning_job.dart';

/// The day's saved plans, or one plan. All through the shared, read-only Planning APIs (React's
/// /planning/view and /planning/edit): the TV never saves or changes a plan.
class PlanningApi {
  PlanningApi(this._client);

  final JavaApiClient _client;

  /// Every plan dated [date] (`POST /api/planing/select-planning`): the plans (`salemaster`) and all
  /// their jobs (`saledetails`).
  Future<({List<PlanSummary> plans, List<PlanningJob> jobs})> day(
      {required int companyId, required DateTime date}) async {
    final iso = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _client.post('/api/planing/select-planning', body: {
      'comid': companyId,
      'employeeid': 0,
      'search': '',
      'fromdate': iso,
      'todate': iso,
    });
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return (plans: _rows(map['salemaster']).map(PlanSummary.fromMaster).toList(), jobs: _jobs(map['saledetails']));
  }

  /// Every job of every plan dated [date].
  Future<List<PlanningJob>> dayPlan({required int companyId, required DateTime date}) async =>
      (await day(companyId: companyId, date: date)).jobs;

  /// One plan by its number, as the web's PLAN NO field loads it (`GET /api/planing/edit?planningNo=`).
  Future<({PlanSummary plan, List<PlanningJob> jobs})> plan({required int companyId, required int planningNo}) async {
    final data =
        await _client.get('/api/planing/edit', query: {'planningNo': '$planningNo', 'companyId': '$companyId'});
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    String text(String key) => map[key]?.toString().trim() ?? '';
    final jobs = _jobs(map['SaleDetails']);
    return (
      plan: PlanSummary(
        number: int.tryParse(text('CNumber')) ?? planningNo,
        display: text('CNumberDisplay'),
        date: text('SSaleDate'),
        remarks: text('Remarks'),
        totalOrders: jobs.length,
      ),
      jobs: jobs,
    );
  }

  static Iterable<Map<String, dynamic>> _rows(dynamic rows) =>
      rows is List ? rows.whereType<Map<String, dynamic>>() : const [];

  static List<PlanningJob> _jobs(dynamic rows) => _rows(rows).map(PlanningJob.fromJson).toList();
}
