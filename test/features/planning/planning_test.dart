import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maleva_tv/core/providers.dart';
import 'package:maleva_tv/core/session/tv_auth_controller.dart';
import 'package:maleva_tv/core/session/tv_auth_service.dart';
import 'package:maleva_tv/features/board/job_board_view.dart';
import 'package:maleva_tv/features/home/domain/entities/job_model.dart';
import 'package:maleva_tv/features/home/presentation/home_controller.dart';
import 'package:maleva_tv/features/planning/planning_api.dart';
import 'package:maleva_tv/features/planning/planning_board.dart';
import 'package:maleva_tv/features/planning/planning_controller.dart';
import 'package:maleva_tv/features/planning/planning_job.dart';
import 'package:maleva_tv/main_navigation_screen.dart';

import '../../fakes.dart';

Map<String, dynamic> _row(int id, String truck, String pickup, {String port = 'WESTPORT-B18', String driver = 'ALI'}) =>
    {
      'Id': id,
      'JobNo': 'MY$id',
      'JobStatus': 'ASSIGNED',
      'TruckName': truck,
      'TruckNameD': '',
      'DriverName': driver,
      'CustomerName': 'ACME',
      'Origin': 'KLIA',
      'Destination': 'WESTPORT',
      'VesselName': 'EVER MAGNA',
      'SPickupDate': pickup,
      'SDeliveryDate': '',
      'SPort': port,
      'OPort': '',
      'SortBy': id,
    };

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('asks select-planning for the day, and reads truck and driver (typed names when no master)', () async {
    late http.Request sent;
    final client = signedIn(MockClient((r) async {
      sent = r;
      return http.Response(
          jsonEncode({
            'salemaster': [],
            'saledetails': [
              {..._row(1, '', '2026-10-14 09:00'), 'TruckNameD': 'WXY 1234', 'DriverName': '', 'DriverNameD': 'RAMU'},
            ],
          }),
          200);
    }));

    final jobs = await PlanningApi(client).dayPlan(companyId: 6, date: DateTime(2026, 10, 14));

    expect(sent.url.path, '/api/planing/select-planning');
    expect(jsonDecode(sent.body),
        {'comid': 6, 'employeeid': 0, 'search': '', 'fromdate': '2026-10-14', 'todate': '2026-10-14'});
    expect(jobs.single.truck, 'WXY 1234');
    expect(jobs.single.driver, 'RAMU');
  });

  group('the Planning board rows', () {
    ProviderContainer container(List<Map<String, dynamic>> rows) {
      final client = signedIn(
          MockClient((r) async => http.Response(jsonEncode({'salemaster': [], 'saledetails': rows}), 200)));
      final c = ProviderContainer(overrides: [
        javaApiClientProvider.overrideWithValue(client),
        tvAuthProvider.overrideWith((ref) => _SignedIn()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('are grouped by truck (A-Z, no truck last), by pickup inside a truck', () async {
      final c = container([
        _row(1, 'TRUCK B', '2026-10-14 10:00'),
        _row(2, '', '2026-10-14 07:00'),
        _row(3, 'TRUCK A', '2026-10-14 12:00'),
        _row(4, 'TRUCK B', '2026-10-14 08:00'),
      ]);
      final jobs = await c.read(planningJobsProvider.future);

      expect(jobs.map((j) => j.id), [3, 4, 1, 2]);
      expect(jobs.map((j) => j.firstOfTruck), [true, true, false, true]);
    });

    test('follow the port filter and the search', () async {
      final c = container([
        _row(1, 'TRUCK A', '2026-10-14 10:00', port: 'SOUTHPORT-B11'),
        _row(2, 'TRUCK B', '2026-10-14 11:00', driver: 'MUTHU'),
      ]);
      c.read(portFilterProvider.notifier).select('WESTPORT-B18');
      expect((await c.read(planningJobsProvider.future)).map((j) => j.id), [2]);

      c.read(portFilterProvider.notifier).select('');
      c.read(searchProvider.notifier).state = 'muthu';
      expect((await c.read(planningJobsProvider.future)).map((j) => j.id), [2]);
    });
  });

  testWidgets('Tab (the yellow button on the remote) switches to Planning and back', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: [
      jobsProvider.overrideWith((ref) async => [const JobModel(id: 1, jobNo: 'MY1', jobStatus: 'ASSIGNED')]),
      planningJobsProvider.overrideWith((ref) async => [const PlanningJob(id: 9, jobNo: 'MY9', truck: 'WXY 1234')]),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: MainNavigationScreen())));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.byType(JobBoardView), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await settle();
    expect(find.byType(PlanningBoardView), findsOneWidget);
    expect(find.text('WXY 1234'), findsOneWidget);
    expect(c.read(boardProvider), BoardKind.planning);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await settle();
    expect(find.byType(JobBoardView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _SignedIn extends StateNotifier<TvAuthState> implements TvAuthController {
  _SignedIn() : super(const SignedIn(TvSession(token: token, companyId: 6, companyName: 'Maleva', userName: 'tv')));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
