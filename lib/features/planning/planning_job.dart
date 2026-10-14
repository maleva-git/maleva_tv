/// One job of a saved plan: a `saledetails` row of `POST /api/planing/select-planning`,
/// read with its Java field names.
class PlanningJob {
  const PlanningJob({
    required this.id,
    required this.jobNo,
    this.jobStatus = '',
    this.truck = '',
    this.driver = '',
    this.customer = '',
    this.origin = '',
    this.destination = '',
    this.vessel = '',
    this.pickup,
    this.delivery,
    this.port,
    this.offPort,
    this.sortBy = 0,
    this.firstOfTruck = true,
  });

  final int id;
  final String jobNo;
  final String jobStatus;

  /// `TruckName` (truck master), else the typed `TruckNameD`.
  final String truck;

  /// `DriverName`, else the typed `DriverNameD`.
  final String driver;
  final String customer;
  final String origin;
  final String destination;

  /// `VesselName`, else `OffVesselName`.
  final String vessel;

  /// `SPickupDate` / `SDeliveryDate`, `yyyy-MM-dd HH:mm` ('' or 1900-01-01 = none).
  final String? pickup;
  final String? delivery;

  /// `SPort` and `OPort`, for the port filter.
  final String? port;
  final String? offPort;

  /// The plan's own order (`SortBy`).
  final int sortBy;

  /// The first row of its truck's group on the board (the truck name is shown in full there).
  final bool firstOfTruck;

  PlanningJob withFirstOfTruck(bool first) => PlanningJob(
        id: id,
        jobNo: jobNo,
        jobStatus: jobStatus,
        truck: truck,
        driver: driver,
        customer: customer,
        origin: origin,
        destination: destination,
        vessel: vessel,
        pickup: pickup,
        delivery: delivery,
        port: port,
        offPort: offPort,
        sortBy: sortBy,
        firstOfTruck: first,
      );

  factory PlanningJob.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    String either(String a, String b) => text(a).isNotEmpty ? text(a) : text(b);
    return PlanningJob(
      id: int.tryParse('${json['Id']}') ?? 0,
      jobNo: text('JobNo'),
      jobStatus: text('JobStatus'),
      truck: either('TruckName', 'TruckNameD'),
      driver: either('DriverName', 'DriverNameD'),
      customer: text('CustomerName'),
      origin: either('OriginD', 'Origin'),
      destination: either('DestinationD', 'Destination'),
      vessel: either('VesselName', 'OffVesselName'),
      pickup: text('SPickupDate'),
      delivery: text('SDeliveryDate'),
      port: text('SPort'),
      offPort: text('OPort'),
      sortBy: int.tryParse('${json['SortBy']}') ?? 0,
    );
  }
}
