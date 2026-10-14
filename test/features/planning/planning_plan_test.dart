import 'dart:convert';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maleva_tv/core/network/api_exception.dart';
import 'package:maleva_tv/core/providers.dart';
import 'package:maleva_tv/features/planning/plan_picker.dart';
import 'package:maleva_tv/features/planning/planning_api.dart';
import 'package:maleva_tv/features/planning/planning_controller.dart';
import 'package:maleva_tv/features/planning/planning_job.dart';
import 'package:maleva_tv/features/planning/planning_live.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../fakes.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('a plan is loaded by its number, as the web\'s PLAN NO field does', () async {
    late http.Request sent;
    final client = signedIn(MockClient((r) async {
      sent = r;
      return http.Response(
          jsonEncode({
            'Id': 1820,
            'CNumber': 810,
            'CNumberDisplay': '810',
            'SSaleDate': '14/10/2026',
            'Remarks': 'FRIDAY',
            'SaleDetails': [
              {'Id': 1, 'JobNo': 'MY1', 'TruckName': 'BPR 7151', 'DriverName': 'MUHAMMAD'},
              {'Id': 2, 'JobNo': 'MY2', 'TruckName': '', 'TruckNameD': 'UMS 7151'},
            ],
          }),
          200);
    }));

    final one = await PlanningApi(client).plan(companyId: 6, planningNo: 810);

    expect(sent.method, 'GET');
    expect(sent.url.path, '/api/planing/edit');
    expect(sent.url.queryParameters, {'planningNo': '810', 'companyId': '6'});
    expect(one.plan.label, '810');
    expect(one.plan.remarks, 'FRIDAY');
    expect(one.jobs.map((j) => j.truck), ['BPR 7151', 'UMS 7151']);
  });

  group('live plan saves', () {
    late StreamChannelController<dynamic> server;
    late List<String> sentFrames;
    late List<LiveStatus> statuses;
    late int saves;
    late PlanningLiveUpdates live;

    setUp(() {
      server = StreamChannelController<dynamic>();
      sentFrames = [];
      statuses = [];
      saves = 0;
      server.foreign.stream.listen((f) => sentFrames.add(f as String));
      live = PlanningLiveUpdates(
        onPlanSaved: () => saves++,
        onStatus: statuses.add,
        connect: (_) async => _Socket(server.local),
        uri: Uri.parse('ws://test/api/ws'),
      );
    });
    tearDown(() => live.stop());

    test('the socket address is the server\'s /api/ws', () {
      expect(PlanningLiveUpdates.wsUri('https://maleva.mydriverszone.com').toString(),
          'wss://maleva.mydriverszone.com/api/ws');
    });

    test('connects, subscribes to /topic/planning, and reloads once per save', () {
      fakeAsync((async) {
        live.start();
        async.flushMicrotasks();
        expect(sentFrames.first, startsWith('CONNECT\n'));

        server.foreign.sink.add('CONNECTED\nversion:1.2\n\n\x00');
        async.flushMicrotasks();
        expect(sentFrames.last, contains('destination:/topic/planning'));
        expect(statuses.last, LiveStatus.live);

        // one save, sent as two frames close together
        server.foreign.sink.add(
            'MESSAGE\ndestination:/topic/planning\n\nUPDATE\x00\nMESSAGE\ndestination:/topic/planning\n\nUPDATE\x00');
        async.elapse(const Duration(seconds: 1));
        expect(saves, 1);
      });
    });

    test('a dropped connection is reported and tried again', () {
      fakeAsync((async) {
        var connects = 0;
        final again = PlanningLiveUpdates(
          onPlanSaved: () {},
          onStatus: statuses.add,
          connect: (_) async {
            connects++;
            final c = StreamChannelController<dynamic>();
            c.foreign.sink.close(); // the server closes at once
            return _Socket(c.local);
          },
          uri: Uri.parse('ws://test/api/ws'),
        );
        again.start();
        async.flushMicrotasks();
        expect(statuses, contains(LiveStatus.offline));
        async.elapse(const Duration(seconds: 3));
        expect(connects, greaterThanOrEqualTo(2));
        again.stop();
      });
    });
  });

  group('the plan list', () {
    Future<PlanPick?> open(WidgetTester tester, {required bool planExists}) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      PlanPick? picked;
      final c = ProviderContainer(overrides: [
        companyIdProvider.overrideWithValue(6),
        dayPlansProvider.overrideWith((ref) async => const [PlanSummary(number: 810, display: '810', totalOrders: 11)]),
        planningApiProvider.overrideWithValue(_FakePlans(planExists)),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked =
                  await showDialog<PlanPick>(context: context, builder: (_) => const PlanPicker(current: null)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final d in ['8', '1', '0']) {
        await tester.sendKeyEvent(LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(d)), character: d);
      }
      await tester.pump();
      expect(find.text('810'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('number keys and OK open that plan', (tester) async {
      expect(await open(tester, planExists: true), isA<OnePlan>().having((p) => p.number, 'number', 810));
    });

    testWidgets('a plan number that does not exist stays in the list with a message', (tester) async {
      expect(await open(tester, planExists: false), isNull);
      expect(find.textContaining('cannot be opened'), findsOneWidget);
    });
  });
}

class _FakePlans extends PlanningApi {
  _FakePlans(this.exists) : super(signedIn(MockClient((_) async => http.Response('', 500))));
  final bool exists;

  @override
  Future<({PlanSummary plan, List<PlanningJob> jobs})> plan({required int companyId, required int planningNo}) async {
    if (!exists) throw const ApiException('Plan not found', statusCode: 404);
    return (plan: PlanSummary(number: planningNo), jobs: const <PlanningJob>[]);
  }
}

class _Socket extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  _Socket(this._inner);
  final StreamChannel<dynamic> _inner;
  @override
  Stream<dynamic> get stream => _inner.stream;
  @override
  WebSocketSink get sink => _Sink(_inner.sink);
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  Future<void> get ready => Future.value();
}

class _Sink extends DelegatingStreamSink<dynamic> implements WebSocketSink {
  _Sink(super.sink);
  @override
  Future<void> close([int? closeCode, String? closeReason]) => super.close();
}
