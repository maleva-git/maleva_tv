import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'package:maleva_tv/features/home/data/datasources/vessel_planning_api.dart';

import 'fakes.dart';

void main() {
  Future<(VesselPlanningApi, List<http.Request>)> api(String body) async {
    final sent = <http.Request>[];
    final client = signedIn(MockClient((r) async {
      sent.add(r);
      return http.Response(body, 200);
    }));
    return (VesselPlanningApi(client), sent);
  }

  test('asks Vessel Planning for the selected day only, by ETA on either vessel, finished jobs hidden', () async {
    final (vp, sent) = await api('[]');

    await vp.boardJobs(companyId: 6, date: DateTime(2026, 10, 31));

    expect(sent.single.method, 'POST');
    expect(sent.single.url.path, '/api/vessel-plannings/search');
    expect(jsonDecode(sent.single.body), {
      'comid': 6,
      'fromdate': '2026-10-31',
      'todate': '2026-10-31',
      'search': '',
      'employeeid': 0,
      'etaType': 0,
      'DeliveryDone': true,
    });
  });

  test('reads the plain list with its Java names, ETD included', () async {
    final (vp, _) = await api(jsonEncode([
      {
        'Id': 7,
        'JobNo': 'SO-26-01483',
        'JobStatus': 'IN TRANSIT',
        'EmployeeName': 'Rajesh Kumar',
        'PICName': 'Preetha A',
        'Loadingvesselname': 'MT PACIFIC STAR',
        'Offvesselname': 'MV SEA EAGLE',
        'SPort': 'SOUTHPORT-B11',
        'OPort': 'WESTPORT-B18',
        'SETA': '2026-10-14 10:25:00',
        'SETB': '2026-10-14 12:20:00',
        'SETD': '2026-10-14 20:00:00',
        'SOETA': '1900-01-01 00:00:00',
        'SOETB': '',
        'SOETD': '2026-10-15 06:00:00',
      }
    ]));

    final job = (await vp.boardJobs(companyId: 6, date: DateTime(2026, 10, 14))).single;

    expect(job.jobNo, 'SO-26-01483');
    expect(job.picName, 'Preetha A');
    expect(job.employeeName, 'Rajesh Kumar');
    expect(job.offVesselName, 'MV SEA EAGLE');
    expect(job.port, 'SOUTHPORT-B11');
    expect(job.offPort, 'WESTPORT-B18');
    expect(BoardTheme.parseDateTime(job.setd), DateTime(2026, 10, 14, 20));
    expect(BoardTheme.parseDateTime(job.soetd), DateTime(2026, 10, 15, 6));
    // 1900-01-01 and '' mean "no date"
    expect(BoardTheme.parseDateTime(job.soeta), isNull);
    expect(BoardTheme.parseDateTime(job.soetb), isNull);
  });

  test('the vessel search asks for a date range', () async {
    final (vp, sent) = await api('[]');

    await vp.jobsBetween(companyId: 6, from: DateTime(2026, 10, 7), to: DateTime(2026, 11, 13));

    final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
    expect(body['fromdate'], '2026-10-07');
    expect(body['todate'], '2026-11-13');
  });
}
