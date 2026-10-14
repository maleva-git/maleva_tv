import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:maleva_tv/core/config/app_config.dart';
import 'package:maleva_tv/core/session/tv_auth_service.dart';

import 'api_exception.dart';
import 'java_answer.dart';

/// The HTTP client for the Java backend. Like maleva_app it sends the employee token
/// (`Authorization: Bearer`); on a 401 it renews the session once and repeats the call.
class JavaApiClient {
  JavaApiClient(this._http, this._auth, {String? baseUrl}) : _baseUrl = baseUrl ?? AppConfig.javaBaseUrl;

  static const _timeout = Duration(seconds: 30);

  final http.Client _http;
  final TvAuthService _auth;
  final String _baseUrl;

  /// POSTs [body] as JSON and returns the answer's `Data1`.
  Future<dynamic> post(String path, {Map<String, String>? query, Object? body}) async {
    final session = _auth.session ?? await _auth.renew();
    try {
      return await _send(path, session.token, query, body);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      final renewed = await _auth.renew();
      return _send(path, renewed.token, query, body);
    }
  }

  Future<dynamic> _send(String path, String token, Map<String, String>? query, Object? body) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    try {
      final response = await _http
          .post(uri,
              headers: {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'},
              body: jsonEncode(body))
          .timeout(_timeout);
      if (kDebugMode) _logAnswer(path, body, response);
      return JavaAnswer.data(response);
    } on SocketException {
      throw const ApiException('Check your network connection');
    } on TimeoutException {
      throw const ApiException('The server did not answer in time');
    } on http.ClientException {
      throw const ApiException('Check your network connection');
    }
  }

  /// Debug runs only (never in the release APK): prints what was asked and what came back, so the
  /// data can be checked in the run console. A list shows its size and its first two rows in full.
  /// The token is never printed.
  static void _logAnswer(String path, Object? body, http.Response response) {
    const encoder = JsonEncoder.withIndent('  ');
    debugPrint('┌─ API POST $path  →  ${response.statusCode}');
    debugPrint('│ request: ${jsonEncode(body)}');
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        debugPrint('│ answer: a list of ${decoded.length} rows. First rows:');
        for (final row in decoded.take(2)) {
          encoder.convert(row).split('\n').forEach((line) => debugPrint('│   $line'));
        }
      } else {
        encoder.convert(decoded).split('\n').take(80).forEach((line) => debugPrint('│ $line'));
      }
    } on FormatException {
      debugPrint('│ answer (not JSON): ${response.body}');
    }
    debugPrint('└─');
  }
}
