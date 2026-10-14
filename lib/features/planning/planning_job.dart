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

/// One saved plan: a `salemaster` row of select-planning, or the header of `GET /api/planing/edit`.
class PlanSummary {
  const PlanSummary({
    required this.number,
    this.display = '',
    this.date = '',
    this.employee = '',
    this.totalOrders = 0,
    this.remarks = '',
  });

  /// The plan number (`PLANINGNo` / `CNumber`), what the web's PLAN NO field takes.
  final int number;

  /// `PLANINGNoDisplay` / `CNumberDisplay`, e.g. "810".
  final String display;

  /// The plan date as the server wrote it (`PLANINGDate` dd/MM/yyyy, or `SSaleDate`).
  final String date;
  final String employee;
  final int totalOrders;
  final String remarks;

  String get label => display.isNotEmpty ? display : '$number';

  factory PlanSummary.fromMaster(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    return PlanSummary(
      number: int.tryParse(text('PLANINGNo')) ?? 0,
      display: text('PLANINGNoDisplay').isNotEmpty ? text('PLANINGNoDisplay') : text('CNumberDisplay'),
      date: text('PLANINGDate').isNotEmpty ? text('PLANINGDate') : text('SSaleDate'),
      employee: text('EmployeeName'),
      totalOrders: int.tryParse(text('TotalOrders')) ?? 0,
      remarks: text('Remarks'),
    );
  }
}
