import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maleva_tv/core/network/java_api_client.dart';
import 'package:maleva_tv/core/session/tv_auth_service.dart';

const base = 'https://java.test';
const token = 'test-token';

/// A client already signed in with [token].
JavaApiClient signedIn(http.Client client) => JavaApiClient(
    client,
    TvAuthService(client,
        baseUrl: base, session: const TvSession(token: token, companyId: 6, companyName: 'Maleva', userName: 'tv')),
    baseUrl: base);

String answer(dynamic data, {String message = 'Success', int status = 200}) =>
    jsonEncode({'IsSuccess': status < 300, 'StatusCode': status, 'Message': message, 'Data1': data});
