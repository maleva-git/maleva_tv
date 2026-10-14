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
import 'package:maleva_tv/features/planning/planning_live.dart';
import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
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
      final client =
          signedIn(MockClient((r) async => http.Response(jsonEncode({'salemaster': [], 'saledetails': rows}), 200)));
      final c = ProviderContainer(overrides: [
        javaApiClientProvider.overrideWithValue(client),
        tvAuthProvider.overrideWith((ref) => _SignedIn()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('keep the order the web shows: as saved, S.NO 1, 2, 3 ... (no re-sorting)', () async {
      final c = container([
        _row(1, 'TRUCK B', '2026-10-14 10:00'),
        _row(2, '', '2026-10-14 07:00'),
        _row(3, 'TRUCK A', '2026-10-14 12:00'),
        _row(4, 'TRUCK A', '2026-10-14 08:00'),
      ]);
      final jobs = await c.read(planningJobsProvider.future);

      expect(jobs.map((j) => j.id), [1, 2, 3, 4]);
      // TRUCK A's second job right after its first shows the truck dimmed
      expect(jobs.map((j) => j.firstOfTruck), [true, true, true, false]);
    });

    test('all plans of the day go plan by plan (the web plan list order), each in its own order', () {
      const plans = [PlanSummary(number: 811, id: 21), PlanSummary(number: 810, id: 20)];
      final jobs = [
        const PlanningJob(id: 1, jobNo: 'A', planId: 20),
        const PlanningJob(id: 2, jobNo: 'B', planId: 21),
        const PlanningJob(id: 3, jobNo: 'C', planId: 20),
        const PlanningJob(id: 4, jobNo: 'D', planId: 21),
      ];
      expect(inPlanOrder(plans, jobs).map((j) => j.id), [2, 4, 1, 3]);
    });

    test('follow the search, but not Vessel Planning\'s port filter', () async {
      final c = container([
        _row(1, 'TRUCK A', '2026-10-14 10:00', port: 'SOUTHPORT-B11'),
        _row(2, 'TRUCK B', '2026-10-14 11:00', driver: 'MUTHU'),
      ]);
      c.read(portFilterProvider.notifier).select('WESTPORT-B18');
      expect((await c.read(planningJobsProvider.future)).map((j) => j.id), [1, 2]);

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
      shownPlanningProvider.overrideWith((ref) async => (plan: null, jobs: const <PlanningJob>[])),
      dayPlansProvider.overrideWith((ref) async => const <PlanSummary>[]),
      // a socket that never answers: no network in tests
      planningLiveProvider.overrideWith((ref) => PlanningLiveUpdates(
          onPlanSaved: () {}, onStatus: (_) {}, connect: (_) async => _silentChannel(), uri: Uri.parse('ws://test'))),
    ]);
    addTearDown(c.dispose);
    await tester
        .pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: MainNavigationScreen())));
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
    expect(find.text('ALL PORTS'), findsNothing); // no port filter on Planning

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await settle();
    expect(find.byType(JobBoardView), findsOneWidget);
    expect(find.text('ALL PORTS'), findsOneWidget); // back on Vessel Planning, with its port filter
    await tester.pumpWidget(const SizedBox());
  });
}

class _SignedIn extends StateNotifier<TvAuthState> implements TvAuthController {
  _SignedIn() : super(const SignedIn(TvSession(token: token, companyId: 6, companyName: 'Maleva', userName: 'tv')));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WebSocketChannel _silentChannel() => _FakeSocket(StreamChannelController<dynamic>().local);

class _FakeSocket extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  _FakeSocket(this._inner);
  final StreamChannel<dynamic> _inner;

  @override
  Stream<dynamic> get stream => _inner.stream;

  @override
  WebSocketSink get sink => _FakeSink(_inner.sink);

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();
}

class _FakeSink extends DelegatingStreamSink<dynamic> implements WebSocketSink {
  _FakeSink(super.sink);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => super.close();
}
