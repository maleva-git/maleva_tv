import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maleva_tv/core/network/api_exception.dart';

import 'fakes.dart';

void main() {
  test('sends the employee token like maleva_app and returns Data1', () async {
    late http.Request sent;
    final client = signedIn(MockClient((r) async {
      sent = r;
      return http.Response(answer({'x': 1}), 200);
    }));

    expect(await client.post('/api/thing', query: {'a': 'b'}), {'x': 1});
    expect(sent.headers['Authorization'], 'Bearer $token');
    expect(sent.headers.containsKey('X-TV-Board-Key'), isFalse);
    expect(sent.url.toString(), '$base/api/thing?a=b');
  });

  test('a bad request shows the server message', () async {
    final client = signedIn(
        MockClient((_) async => http.Response(answer(null, message: 'Company is required', status: 400), 400)));

    expect(() => client.post('/a'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Company is required')));
  });
}
