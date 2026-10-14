import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:maleva_tv/core/config/app_config.dart';
import 'package:maleva_tv/core/network/java_api_client.dart';
import 'package:maleva_tv/core/session/tv_auth_controller.dart';
import 'package:maleva_tv/core/session/tv_auth_service.dart';
import 'package:maleva_tv/features/home/data/datasources/vessel_planning_api.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final tvAuthServiceProvider = Provider<TvAuthService>((ref) => TvAuthService(ref.watch(httpClientProvider)));

final javaApiClientProvider =
    Provider<JavaApiClient>((ref) => JavaApiClient(ref.watch(httpClientProvider), ref.watch(tvAuthServiceProvider)));

final vesselPlanningApiProvider =
    Provider<VesselPlanningApi>((ref) => VesselPlanningApi(ref.watch(javaApiClientProvider)));

/// The signed-in employee's company.
final companyIdProvider = Provider<int>((ref) {
  final state = ref.watch(tvAuthProvider);
  return state is SignedIn ? state.session.companyId : AppConfig.companyId;
});
