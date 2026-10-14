import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:maleva_tv/core/network/java_api_client.dart';
import 'package:maleva_tv/core/session/tv_auth_service.dart';
import 'package:maleva_tv/features/planning/planning_api.dart';
import 'package:maleva_tv/features/planning/planning_controller.dart';
import 'package:maleva_tv/features/planning/planning_job.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';
import 'package:maleva_tv/main_navigation_screen.dart';

/// Design preview with sample jobs, no server call:
/// `flutter run -d chrome -t lib/preview/board_preview.dart`.
void main() {
  runApp(ProviderScope(
    overrides: [
      jobsProvider.overrideWith((ref) async {
        final query = ref.watch(searchProvider);
        final port = ref.watch(portFilterProvider);
        final jobs = _sampleJobs().where((j) => port.isEmpty || j.port == port || j.offPort == port).toList();
        return query.isEmpty ? jobs : jobs.where((job) => matchesSearch(job, query)).toList();
      }),
      planningApiProvider.overrideWithValue(_SamplePlanningApi()),
      portsProvider.overrideWith((ref) async => ['NORTHPORT-W5', 'PTP-J33', 'SOUTHPORT-B11', 'WESTPORT-B18']),
    ],
    child: const MaterialApp(debugShowCheckedModeBanner: false, home: MainNavigationScreen()),
  ));
}

List<JobModel> _sampleJobs() {
  final now = DateTime.now();
  // The Vessel Planning format, `yyyy-MM-dd HH:mm:ss`.
  String at(int minutes) {
    final t = now.add(Duration(minutes: minutes));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:00';
  }

  final rows = [
    ('NEW AMBITION STAR EXPRESS', 'MV SEA EAGLE', 'MY002605898', 'PREETHA A', 'ASSIGNED', 20, 50),
    ('EVER MAGNA', 'EVER BREED', 'MY002605899', 'KAMATCHI', 'WAITING FOR L-VESSEL', 30, 40),
    ('NEW AMBITION STAR EXPRESS', '', 'MY00260512', 'PREETHA A', 'ASSIGNED', -90, 30),
    ('SHIJING', 'MV SEA EAGLE', 'MY00260513', 'HELEN MINOLTA EDWARD', 'AT WAREHOUSE', 45, 160),
    ('', 'MV KOTA HARUM', 'MY00260514', '', 'WAITING FOR O-VESSEL', 300, 420),
    ('MTT HAIPHONG', '', 'MY00260615', 'KAMATCHI', 'WAITING FOR L-VESSEL', -400, -200),
    ('BOURBON LIBERTY 312', '', 'MY00260616', 'DHARSHINI', 'ASSIGNED', 500, 600),
    ('MV ORIENTAL JADE', 'MT GOLDEN BAY', 'MY00260617', 'Siti Nurhaliza', 'IN TRANSIT', 100, 200),
    ('PSV SWIRE PACIFIC', '', 'MY00260618', 'Daniel Tan', 'PENDING', 440, 500),
    ('MV CAPE ENDEAVOUR', '', 'MY00260619', 'Hafiz Rahman', 'ASSIGNED', 600, 700),
  ];
  var id = 1;
  return [
    for (final r in rows)
      JobModel(
        id: id++,
        jobNo: r.$3,
        jobStatus: r.$5,
        picName: r.$4,
        loadingVesselName: r.$1,
        offVesselName: r.$2,
        port: 'SOUTHPORT-B11',
        offPort: r.$2.isEmpty ? null : 'WESTPORT-B18',
        seta: r.$1.isEmpty ? null : at(r.$6),
        setb: r.$1.isEmpty ? null : at(r.$7),
        setd: r.$1.isEmpty ? null : at(r.$7 + 480),
        soeta: r.$2.isEmpty ? '1900-01-01 00:00:00' : at(r.$6 + 60),
        soetb: r.$2.isEmpty ? null : at(r.$7 + 60),
        soetd: r.$2.isEmpty ? null : at(r.$7 + 540),
      ),
  ];
}


/// Sample plans for the preview; the real board's grouping, port filter and search still run on them.
class _SamplePlanningApi extends PlanningApi {
  _SamplePlanningApi() : super(JavaApiClient(http.Client(), TvAuthService(http.Client())));

  @override
  Future<List<PlanningJob>> dayPlan({required int companyId, required DateTime date}) async {
    final now = DateTime.now();
    String at(int minutes) {
      final t = now.add(Duration(minutes: minutes));
      String two(int v) => v.toString().padLeft(2, '0');
      return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
    }

    final rows = [
      ('WXY 1234', 'RAMU', 'MY002605899', 'PETRONAS DAGANGAN', 'KLIA CARGO', 'WESTPORT-B18', 'EVER MAGNA', 'ASSIGNED', -60, 30),
      ('WXY 1234', 'RAMU', 'MY002605901', 'SHELL MALAYSIA', 'WESTPORT-B18', 'PORT KLANG WAREHOUSE', 'SHIJING', 'IN TRANSIT', 45, 120),
      ('BKA 5521', 'MUTHU SAMY', 'MY002605902', 'MAERSK LINE', 'SOUTHPORT-B11', 'SHAH ALAM DEPOT', 'MTT HAIPHONG', 'PENDING', 90, 200),
      ('BKA 5521', 'MUTHU SAMY', 'MY002605910', 'ACME SHIP SUPPLY', 'SHAH ALAM DEPOT', 'NORTHPORT-W5', 'MV ORIENTAL JADE', 'ASSIGNED', 240, 330),
      ('JHB 777', 'HAFIZ RAHMAN', 'MY002605915', 'KONTENA NASIONAL', 'PTP-J33', 'JOHOR WAREHOUSE', 'PSV SWIRE PACIFIC', 'COMPLETED', -300, -200),
      ('', '', 'MY002605920', 'TOTAL ENERGIES', 'KL OFFICE', 'WESTPORT-B18', 'BOURBON LIBERTY 312', 'PENDING', 400, 480),
    ];
    var id = 1;
    return [
      for (final r in rows)
        PlanningJob(
          id: id,
          jobNo: r.$3,
          jobStatus: r.$8,
          truck: r.$1,
          driver: r.$2,
          customer: r.$4,
          origin: r.$5,
          destination: r.$6,
          vessel: r.$7,
          pickup: at(r.$9),
          delivery: at(r.$10),
          port: 'WESTPORT-B18',
          sortBy: id++,
        ),
    ];
  }
}
