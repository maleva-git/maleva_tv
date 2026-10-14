import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maleva_tv/core/session/tv_auth_service.dart';
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

/// The port the board is limited to ('' = all ports). Kept on the device, so a TV set to one
/// port stays on it after a restart.
class PortFilterController extends StateNotifier<String> {
  PortFilterController(this._storage) : super('') {
    _storage.read(key: _key).then((saved) {
      if (mounted && saved != null && saved.isNotEmpty) state = saved;
    }).catchError((_) {});
  }

  static const _key = 'tv.port';
  final FlutterSecureStorage _storage;

  void select(String port) {
    state = port;
    (port.isEmpty ? _storage.delete(key: _key) : _storage.write(key: _key, value: port)).catchError((_) {});
  }
}

/// The two boards. Kept on the device like the port, so a TV used for Planning starts on Planning.
enum BoardKind { vesselPlanning, planning }

class BoardChoiceController extends StateNotifier<BoardKind> {
  BoardChoiceController(this._storage) : super(BoardKind.vesselPlanning) {
    _storage.read(key: _key).then((saved) {
      if (mounted && saved == BoardKind.planning.name) state = BoardKind.planning;
    }).catchError((_) {});
  }

  static const _key = 'tv.board';
  final FlutterSecureStorage _storage;

  void show(BoardKind board) {
    state = board;
    _storage.write(key: _key, value: board.name).catchError((_) {});
  }

  void toggle() => show(state == BoardKind.vesselPlanning ? BoardKind.planning : BoardKind.vesselPlanning);
}

final boardProvider = StateNotifierProvider<BoardChoiceController, BoardKind>(
    (ref) => BoardChoiceController(ref.watch(portStorageProvider)));

final portStorageProvider = Provider<FlutterSecureStorage>((ref) => TvAuthService.defaultStorage);

final portFilterProvider =
    StateNotifierProvider<PortFilterController, String>((ref) => PortFilterController(ref.watch(portStorageProvider)));

/// The company's ports for the port picker.
final portsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(portApiProvider).activePorts(ref.watch(companyIdProvider));
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
  final port = ref.watch(portFilterProvider);
  final api = ref.watch(vesselPlanningApiProvider);
  if (query.isEmpty) {
    return api.boardJobs(companyId: companyId, date: selectedDate, port: port);
  }
  final jobs = await api.jobsBetween(
    companyId: companyId,
    from: selectedDate.subtract(const Duration(days: searchDaysBack)),
    to: selectedDate.add(const Duration(days: searchDaysAhead)),
    port: port,
  );
  return jobs.where((job) => matchesSearch(job, query)).toList();
});

/// A job matches when its loading vessel, off vessel or job number contains every word typed,
/// ignoring case and extra spaces ("ever mag" finds "EVER MAGNA").
bool matchesSearch(JobModel job, String query) {
  final haystack = '${job.loadingVesselName ?? ''} ${job.offVesselName ?? ''} ${job.jobNo}'.toUpperCase();
  return query.toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(haystack.contains);
}
