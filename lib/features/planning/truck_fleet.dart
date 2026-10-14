import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/network/java_api_client.dart';
import 'package:maleva_tv/core/providers.dart';
import 'planning_controller.dart';
import 'planning_job.dart';

/// One planning truck of the company's fleet.
class FleetTruck {
  const FleetTruck({required this.id, required this.name, this.type = ''});
  final int id;
  final String name;
  final String type;
}

/// The trucks the web's Planning page counts ("2/20 trucks"): `GET /api/truck-orders/trucks?companyRefId=`,
/// the company's active, orderable Maleva trucks (shared API, employee token).
class FleetApi {
  FleetApi(this._client);
  final JavaApiClient _client;

  Future<List<FleetTruck>> planningTrucks(int companyId) async {
    final data = await _client.get('/api/truck-orders/trucks', query: {'companyRefId': '$companyId'});
    if (data is! List) return [];
    return [
      for (final row in data.whereType<Map<String, dynamic>>())
        if ((int.tryParse('${row['id'] ?? row['Id'] ?? ''}') ?? 0) > 0 &&
            (row['truckName'] ?? row['TruckName'] ?? '').toString().trim().isNotEmpty)
          FleetTruck(
            id: int.parse('${row['id'] ?? row['Id']}'),
            name: (row['truckName'] ?? row['TruckName']).toString().trim(),
            type: (row['truckType'] ?? '').toString().trim(),
          ),
    ];
  }
}

/// A truck on the plan, with how many of the plan's jobs it carries.
class AssignedTruck {
  const AssignedTruck({required this.id, required this.name, required this.jobs, this.outsideFleet = false});
  final int id;
  final String name;
  final int jobs;

  /// On the plan but not one of the fleet's planning trucks (e.g. a hired truck).
  final bool outsideFleet;
}

/// The web Planning page's truck summary (TruckAllocationSummary / truckAllocation.ts), for the
/// plan(s) on the board.
class TruckAllocation {
  const TruckAllocation({
    required this.assigned,
    required this.available,
    required this.fleetSize,
    required this.fleetAssigned,
    required this.jobsWithoutTruck,
  });

  /// Trucks on the plan, most jobs first.
  final List<AssignedTruck> assigned;

  /// Fleet trucks no job uses yet, A-Z.
  final List<FleetTruck> available;
  final int fleetSize;
  final int fleetAssigned;
  final int jobsWithoutTruck;

  double get share => fleetSize == 0 ? 0 : fleetAssigned / fleetSize;

  /// Counts by truck id (`TruckRefid`), like the web; a job without one is "without truck".
  factory TruckAllocation.of(List<PlanningJob> jobs, List<FleetTruck> fleet) {
    final byId = {for (final t in fleet) t.id: t};
    final counts = <int, int>{};
    final names = <int, String>{};
    var withoutTruck = 0;
    for (final job in jobs) {
      if (job.truckId <= 0) {
        withoutTruck++;
        continue;
      }
      counts[job.truckId] = (counts[job.truckId] ?? 0) + 1;
      names.putIfAbsent(job.truckId, () => job.truck);
    }
    final assigned = [
      for (final e in counts.entries)
        AssignedTruck(
          id: e.key,
          name: byId[e.key]?.name ?? (names[e.key]?.isNotEmpty == true ? names[e.key]! : 'Truck ${e.key}'),
          jobs: e.value,
          outsideFleet: !byId.containsKey(e.key),
        ),
    ]..sort((a, b) => b.jobs != a.jobs ? b.jobs.compareTo(a.jobs) : a.name.compareTo(b.name));
    final available = fleet.where((t) => !counts.containsKey(t.id)).toList()..sort((a, b) => a.name.compareTo(b.name));
    return TruckAllocation(
      assigned: assigned,
      available: available,
      fleetSize: fleet.length,
      fleetAssigned: assigned.where((t) => !t.outsideFleet).length,
      jobsWithoutTruck: withoutTruck,
    );
  }
}

final fleetApiProvider = Provider<FleetApi>((ref) => FleetApi(ref.watch(javaApiClientProvider)));

/// The company's planning trucks; they change rarely, so the board's refresh does not reload them.
final fleetProvider = FutureProvider<List<FleetTruck>>((ref) {
  return ref.watch(fleetApiProvider).planningTrucks(ref.watch(companyIdProvider));
});

/// The truck summary of the plan(s) on the board (before the search, like the web's).
final truckAllocationProvider = FutureProvider<TruckAllocation>((ref) async {
  final shown = await ref.watch(shownPlanningProvider.future);
  final fleet = await ref.watch(fleetProvider.future);
  return TruckAllocation.of(shown.jobs, fleet);
});
