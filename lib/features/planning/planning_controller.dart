import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maleva_tv/core/providers.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';
import 'planning_api.dart';
import 'planning_job.dart';

final planningApiProvider = Provider<PlanningApi>((ref) => PlanningApi(ref.watch(javaApiClientProvider)));

/// The plan the Planning board shows: a plan number, or null for all plans of the selected day.
/// Kept on the device, so the TV stays on the plan that is running.
class PlanChoiceController extends StateNotifier<int?> {
  PlanChoiceController(this._storage) : super(null) {
    _storage.read(key: _key).then((saved) {
      final number = int.tryParse(saved ?? '');
      if (mounted && number != null) state = number;
    }).catchError((_) {});
  }

  static const _key = 'tv.plan';
  final FlutterSecureStorage _storage;

  void show(int? planningNo) {
    state = planningNo;
    (planningNo == null ? _storage.delete(key: _key) : _storage.write(key: _key, value: '$planningNo'))
        .catchError((_) {});
  }
}

final planChoiceProvider =
    StateNotifierProvider<PlanChoiceController, int?>((ref) => PlanChoiceController(ref.watch(portStorageProvider)));

/// The selected day's plans (`salemaster`), for the plan list.
final dayPlansProvider = FutureProvider<List<PlanSummary>>((ref) async {
  final day =
      await ref.watch(planningApiProvider).day(companyId: ref.watch(companyIdProvider), date: ref.watch(dateProvider));
  return day.plans;
});

/// What the board shows: the chosen plan (by number), or every plan of the selected day.
final shownPlanningProvider = FutureProvider<({PlanSummary? plan, List<PlanningJob> jobs})>((ref) async {
  final api = ref.watch(planningApiProvider);
  final companyId = ref.watch(companyIdProvider);
  final planningNo = ref.watch(planChoiceProvider);
  if (planningNo != null) {
    final one = await api.plan(companyId: companyId, planningNo: planningNo);
    return (plan: one.plan, jobs: one.jobs);
  }
  return (plan: null, jobs: await api.dayPlan(companyId: companyId, date: ref.watch(dateProvider)));
});

/// The Planning board's rows: the shown plan(s) with the search applied, then grouped by truck
/// (A-Z, trucks not yet given last) and by pickup time inside each truck.
/// Planning is its own board: Vessel Planning's port filter does not apply here.
final planningJobsProvider = FutureProvider<List<PlanningJob>>((ref) async {
  final query = ref.watch(searchProvider).trim();
  final jobs = (await ref.watch(shownPlanningProvider.future)).jobs;
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
