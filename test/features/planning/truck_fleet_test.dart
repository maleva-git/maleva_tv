import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maleva_tv/features/planning/planning_job.dart';
import 'package:maleva_tv/features/planning/truck_fleet.dart';

import '../../fakes.dart';

PlanningJob _job(int id, int truckId, [String truck = '']) =>
    PlanningJob(id: id, jobNo: 'MY$id', truckId: truckId, truck: truck);

void main() {
  test('the fleet is the web\'s planning truck list (GET /api/truck-orders/trucks?companyRefId=)', () async {
    late http.Request sent;
    final client = signedIn(MockClient((r) async {
      sent = r;
      return http.Response(
          jsonEncode({
            'IsSuccess': true,
            'StatusCode': 200,
            'Message': 'Orderable trucks',
            'Data1': [
              {'id': 1, 'truckName': 'BPR 7151 ', 'truckType': 'PRIME MOVER'},
              {'id': 0, 'truckName': 'NO ID'},
              {'id': 3, 'truckName': ''},
            ],
          }),
          200);
    }));

    final fleet = await FleetApi(client).planningTrucks(6);

    expect(sent.url.path, '/api/truck-orders/trucks');
    expect(sent.url.queryParameters, {'companyRefId': '6'});
    expect(fleet.map((t) => t.name), ['BPR 7151']);
  });

  test('assigned, free and jobs without truck are counted as the web does', () {
    const fleet = [
      FleetTruck(id: 1, name: 'BPR 7151'),
      FleetTruck(id: 2, name: 'UMS 7151'),
      FleetTruck(id: 3, name: 'APL7151'),
      FleetTruck(id: 4, name: 'GM 7151'),
    ];
    final a = TruckAllocation.of([
      _job(1, 2),
      _job(2, 1),
      _job(3, 2),
      _job(4, 0),
      _job(5, 0),
      _job(6, 99, 'HIRED 1'), // not one of the fleet's planning trucks
    ], fleet);

    expect(a.assigned.map((t) => '${t.name}:${t.jobs}'), ['UMS 7151:2', 'BPR 7151:1', 'HIRED 1:1']);
    expect(a.assigned.last.outsideFleet, isTrue);
    expect(a.fleetAssigned, 2);
    expect(a.fleetSize, 4);
    expect(a.available.map((t) => t.name), ['APL7151', 'GM 7151']);
    expect(a.jobsWithoutTruck, 2);
    expect(a.share, 0.5);
  });
}
