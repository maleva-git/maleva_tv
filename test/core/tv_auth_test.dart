import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maleva_tv/core/network/java_api_client.dart';
import 'package:maleva_tv/core/session/tv_auth_service.dart';

http.Response _session(String token) => http.Response(
    jsonEncode({'IsSuccess': true, 'StatusCode': 200, 'Data1': {'token': token, 'companyId': 6, 'companyName': 'Maleva', 'principalKind': 'EMPLOYEE'}}),
    200);
http.Response _refused() => http.Response(jsonEncode({'IsSuccess': false, 'StatusCode': 401, 'Message': 'Unauthorized'}), 401);
http.Response _board(String token) =>
    http.Response(jsonEncode({'IsSuccess': true, 'StatusCode': 200, 'Data1': {'salemaster': [], 'token': token}}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('signs in once, then a restart restores the saved session without a sign-in', () async {
    final calls = <String>[];
    final client = MockClient((r) async {
      calls.add(r.url.path);
      return _session('t1');
    });
    await TvAuthService(client).signIn('tv', 'pw');

    final restored = await TvAuthService(client).restore();
    expect(restored?.token, 't1');
    expect(calls, ['/api/mobile/auth/login']);
  });

  test('a 401 refreshes the token and repeats the call', () async {
    final calls = <String>[];
    final client = MockClient((r) async {
      calls.add(r.url.path);
      if (r.url.path.endsWith('/login')) return _session('t1');
      if (r.url.path.endsWith('/refresh')) return _session('t2');
      return r.headers['Authorization'] == 'Bearer t2' ? _board('t2') : _refused();
    });
    final auth = TvAuthService(client);
    await auth.signIn('tv', 'pw');

    final data = await JavaApiClient(client, auth).post('/api/sale-orders/tv-search', body: {});
    expect((data as Map)['token'], 't2');
    expect(calls, ['/api/mobile/auth/login', '/api/sale-orders/tv-search', '/api/mobile/auth/refresh', '/api/sale-orders/tv-search']);
  });

  test('when the session has ended (refresh refused) it signs in again with the saved account', () async {
    var logins = 0;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/login')) return _session('t${++logins}');
      if (r.url.path.endsWith('/refresh')) return _refused();
      return r.headers['Authorization'] == 'Bearer t2' ? _board('t2') : _refused();
    });
    final auth = TvAuthService(client);
    await auth.signIn('tv', 'pw');
    String? asked;
    auth.onSignInRequired = (m) => asked = m;

    await JavaApiClient(client, auth).post('/api/sale-orders/tv-search', body: {});
    expect(logins, 2);
    expect(asked, isNull);
  });

  test('when the saved password stops working it asks for a sign-in', () async {
    var logins = 0;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/login')) return ++logins == 1 ? _session('t1') : _refused();
      return _refused();
    });
    final auth = TvAuthService(client);
    await auth.signIn('tv', 'pw');
    String? asked;
    auth.onSignInRequired = (m) => asked = m;

    await expectLater(JavaApiClient(client, auth).post('/x', body: {}), throwsA(isA<SignInRequired>()));
    expect(asked, isNotNull);
    expect(await auth.savedUserName(), 'tv');
    expect(await TvAuthService(client).restore(), isNull);
  });
}
