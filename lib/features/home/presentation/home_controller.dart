import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';
import 'package:maleva_tv/core/providers.dart';

class DateController extends StateNotifier<DateTime> {
  DateController() : super(DateTime.now());

  void changeDate(int days) {
    state = state.add(Duration(days: days));
  }

  void setDate(DateTime date) {
    state = date;
  }
}

final dateProvider = StateNotifierProvider<DateController, DateTime>((ref) {
  return DateController();
});

/// The vessel search typed on the TV; empty shows the selected day's board.
final searchProvider = StateProvider<String>((ref) => '');

/// How far the vessel search looks around the selected day.
const searchDaysBack = 7;
const searchDaysAhead = 30;

final jobsProvider = FutureProvider<List<JobModel>>((ref) async {
  final selectedDate = ref.watch(dateProvider);
  final companyId = ref.watch(companyIdProvider);
  final query = ref.watch(searchProvider).trim();
  final api = ref.watch(vesselPlanningApiProvider);
  if (query.isEmpty) {
    return api.boardJobs(companyId: companyId, date: selectedDate);
  }
  final jobs = await api.jobsBetween(
    companyId: companyId,
    from: selectedDate.subtract(const Duration(days: searchDaysBack)),
    to: selectedDate.add(const Duration(days: searchDaysAhead)),
  );
  return jobs.where((job) => matchesSearch(job, query)).toList();
});

/// A job matches when its loading vessel, off vessel or job number contains every word typed,
/// ignoring case and extra spaces ("ever mag" finds "EVER MAGNA").
bool matchesSearch(JobModel job, String query) {
  final haystack = '${job.loadingVesselName ?? ''} ${job.offVesselName ?? ''} ${job.jobNo}'.toUpperCase();
  return query.toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(haystack.contains);
}
