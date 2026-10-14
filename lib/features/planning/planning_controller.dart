import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/providers.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';
import 'planning_api.dart';
import 'planning_job.dart';

final planningApiProvider = Provider<PlanningApi>((ref) => PlanningApi(ref.watch(javaApiClientProvider)));

/// The Planning board's rows for the selected day: the search applied, then grouped by truck
/// (A-Z, trucks not yet given last) and by pickup time inside each truck.
/// Planning is its own board: Vessel Planning's port filter does not apply here.
final planningJobsProvider = FutureProvider<List<PlanningJob>>((ref) async {
  final date = ref.watch(dateProvider);
  final query = ref.watch(searchProvider).trim();
  final jobs = await ref.watch(planningApiProvider).dayPlan(companyId: ref.watch(companyIdProvider), date: date);
  final shown = jobs.where((j) => query.isEmpty || matchesPlanning(j, query)).toList()..sort(_byTruckThenPickup);
  return [
    for (var i = 0; i < shown.length; i++) shown[i].withFirstOfTruck(i == 0 || shown[i].truck != shown[i - 1].truck),
  ];
});

int _byTruckThenPickup(PlanningJob a, PlanningJob b) {
  if (a.truck.isEmpty != b.truck.isEmpty) return a.truck.isEmpty ? 1 : -1;
  final byTruck = a.truck.toUpperCase().compareTo(b.truck.toUpperCase());
  if (byTruck != 0) return byTruck;
  final pa = BoardTheme.parseDateTime(a.pickup), pb = BoardTheme.parseDateTime(b.pickup);
  if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
  if ((pa == null) != (pb == null)) return pa == null ? 1 : -1;
  return a.sortBy.compareTo(b.sortBy);
}

/// A planned job matches when its truck, driver, vessel, job number or customer contains every
/// word typed, ignoring case ("abc 12" finds truck "ABC 1234").
bool matchesPlanning(PlanningJob job, String query) {
  final haystack = '${job.truck} ${job.driver} ${job.vessel} ${job.jobNo} ${job.customer}'.toUpperCase();
  return query.toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(haystack.contains);
}
