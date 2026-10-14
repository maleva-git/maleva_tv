class AppConfig {
  AppConfig._();

  /// The Java (Spring) backend, the same server React and maleva_app use.
  //static const String javaBaseUrl = 'http://192.168.1.100:8082'; // Local
  static const String javaBaseUrl = 'https://maleva.mydriverszone.com'; // Live

  /// Used only until the signed-in session gives the employee's company.
  static const int companyId = int.fromEnvironment('TV_COMPANY_ID', defaultValue: 6);
}
