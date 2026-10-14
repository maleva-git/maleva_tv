import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maleva_tv/app.dart';
import 'package:maleva_tv/core/providers.dart';
import 'package:maleva_tv/core/session/tv_auth_service.dart';

import 'fakes.dart';

void main() {
  final server = MockClient((r) async => r.url.path.endsWith('/login')
      ? http.Response(answer({'token': token, 'companyId': 6, 'companyName': 'Maleva'}), 200)
      : http.Response('[]', 200));

  Future<void> open(WidgetTester tester) async {
    // a TV screen: the board is laid out for 1080p
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        httpClientProvider.overrideWithValue(server),
        tvAuthServiceProvider.overrideWithValue(TvAuthService(server, baseUrl: base)),
      ],
      child: const TVApp(interFont: false),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a new TV asks for a sign-in once, then opens the board', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await open(tester);
    expect(find.text('SIGN IN'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'tv');
    await tester.enterText(find.byType(TextField).at(1), 'pw');
    await tester.tap(find.text('SIGN IN'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('VESSEL PLANNING'), findsOneWidget);
    // stop the board's periodic timers before the test ends
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a TV that signed in before opens straight on the board', (tester) async {
    FlutterSecureStorage.setMockInitialValues(
        {'tv.userName': 'tv', 'tv.password': 'pw', 'tv.token': token, 'tv.companyId': '6', 'tv.companyName': 'Maleva'});
    await open(tester);

    expect(find.text('VESSEL PLANNING'), findsOneWidget);
    expect(find.text('SIGN IN'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
