import 'package:maleva_tv/core/network/java_api_client.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';

/// The board's jobs from the shared Vessel Planning search (`POST /api/vessel-plannings/search`),
/// the same list React shows on the Vessel Planning page.
///
/// Asks for the jobs whose loading or off-vessel ETA falls on [date] (that one day; the remote's ◀▶
/// pick another), without the finished ones (`DeliveryDone`), sorted by the earliest ETA.
/// The answer is a plain list.
class VesselPlanningApi {
  VesselPlanningApi(this._client);

  final JavaApiClient _client;

  Future<List<JobModel>> boardJobs({required int companyId, required DateTime date, String port = ''}) =>
      jobsBetween(companyId: companyId, from: date, to: date, port: port);

  /// The same search over [from]..[to], for the vessel search (a vessel due on another day).
  /// [port] ('' for all) is sent as `search`, which the server matches against the loading port
  /// (`SPort`) and the off-vessel port (`OPort`) - the way React's Vessel Planning port filter works.
  Future<List<JobModel>> jobsBetween(
      {required int companyId, required DateTime from, required DateTime to, String port = ''}) async {
    final data = await _client.post('/api/vessel-plannings/search', body: {
      'comid': companyId,
      'fromdate': _isoDate(from),
      'todate': _isoDate(to),
      'search': port,
      'employeeid': 0,
      'etaType': 0, // ETA on either vessel
      'DeliveryDone': true, // hide delivered / closed jobs
    });
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(JobModel.fromJson).toList();
  }

  /// The search's date format, `yyyy-MM-dd`.
  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
