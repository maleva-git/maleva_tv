/// One job of the board: a row of the Vessel Planning search (`POST /api/vessel-plannings/search`),
/// read with its Java field names.
class JobModel {
  final int id;
  final String jobNo;
  final String jobStatus;
  final String jobType;
  /// The latest employee on the job (`EmployeeName`: LastEmployeeRefid, else EmployeeRefId).
  final String employeeName;

  /// The person in charge (`PICName`: always EmployeeRefId). The board's EMPLOYEE column shows this.
  final String picName;
  final String customerName;

  /// Loading vessel's port (`SPort`) and off vessel's port (`OPort`).
  final String? port;
  final String? offPort;
  final String? loadingVesselName;
  final String? offVesselName;

  /// Loading vessel: arrival, berthing, departure (`yyyy-MM-dd HH:mm:ss`; '' or 1900-01-01 = none).
  final String? seta;
  final String? setb;
  final String? setd;

  /// Off vessel: arrival, berthing, departure.
  final String? soeta;
  final String? soetb;
  final String? soetd;

  const JobModel({
    required this.id,
    required this.jobNo,
    required this.jobStatus,
    this.jobType = '',
    this.employeeName = '',
    this.picName = '',
    this.customerName = '',
    this.port,
    this.offPort,
    this.loadingVesselName,
    this.offVesselName,
    this.seta,
    this.setb,
    this.setd,
    this.soeta,
    this.soetb,
    this.soetd,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    String? text(String key) => json[key]?.toString();
    return JobModel(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      jobNo: text('JobNo') ?? '',
      jobStatus: text('JobStatus') ?? '',
      jobType: text('JobName') ?? '',
      employeeName: text('EmployeeName') ?? '',
      picName: text('PICName') ?? '',
      customerName: text('CustomerName') ?? '',
      port: text('SPort'),
      offPort: text('OPort'),
      loadingVesselName: text('Loadingvesselname'),
      offVesselName: text('Offvesselname'),
      seta: text('SETA'),
      setb: text('SETB'),
      setd: text('SETD'),
      soeta: text('SOETA'),
      soetb: text('SOETB'),
      soetd: text('SOETD'),
    );
  }
}
