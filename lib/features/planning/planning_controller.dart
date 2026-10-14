import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maleva_tv/core/providers.dart';
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
  final day = await api.day(companyId: companyId, date: ref.watch(dateProvider));
  return (plan: null, jobs: inPlanOrder(day.plans, day.jobs));
});

/// The Planning board's rows, in the order the web shows them: a plan's jobs top to bottom as the plan
/// was saved (S.NO 1, 2, 3 ... as on the web's plan page); for "all plans of the day", plan by plan in
/// the web plan list's order, each plan in its own order. The search only hides rows.
/// Planning is its own board: Vessel Planning's port filter does not apply here.
final planningJobsProvider = FutureProvider<List<PlanningJob>>((ref) async {
  final query = ref.watch(searchProvider).trim();
  final jobs = (await ref.watch(shownPlanningProvider.future)).jobs;
  final shown = jobs.where((j) => query.isEmpty || matchesPlanning(j, query)).toList();
  // A truck's next job straight after its previous one shows the truck dimmed.
  return [
    for (var i = 0; i < shown.length; i++)
      shown[i].withFirstOfTruck(i == 0 || shown[i].truck.isEmpty || shown[i].truck != shown[i - 1].truck),
  ];
});

/// "All plans of the day": the plans in the server's order (newest first, as the web's plan list)
/// and each plan's jobs in the server's order (`SortBy`, then saved order).
List<PlanningJob> inPlanOrder(List<PlanSummary> plans, List<PlanningJob> jobs) {
  final rank = {for (final (i, p) in plans.indexed) p.id: i};
  final indexed = jobs.indexed.toList()
    ..sort((a, b) {
      final ra = rank[a.$2.planId] ?? plans.length, rb = rank[b.$2.planId] ?? plans.length;
      return ra != rb ? ra.compareTo(rb) : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

/// A planned job matches when its truck, driver, vessel, job number or customer contains every
/// word typed, ignoring case ("abc 12" finds truck "ABC 1234").
bool matchesPlanning(PlanningJob job, String query) {
  final haystack = '${job.truck} ${job.driver} ${job.vessel} ${job.jobNo} ${job.customer}'.toUpperCase();
  return query.toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(haystack.contains);
}
