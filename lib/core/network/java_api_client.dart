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
  Future<dynamic> post(String path, {Map<String, String>? query, Object? body}) =>
      _withSession((token) => _send(path, token, query, body));

  /// GETs [path] and returns the answer's data.
  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _withSession((token) => _send(path, token, query, null, get: true));

  Future<dynamic> _withSession(Future<dynamic> Function(String token) call) async {
    final session = _auth.session ?? await _auth.renew();
    try {
      return await call(session.token);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      final renewed = await _auth.renew();
      return call(renewed.token);
    }
  }

  Future<dynamic> _send(String path, String token, Map<String, String>? query, Object? body, {bool get = false}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = {'Content-Type': 'application/json; charset=UTF-8', 'Authorization': 'Bearer $token'};
    try {
      final response =
          await (get ? _http.get(uri, headers: headers) : _http.post(uri, headers: headers, body: jsonEncode(body)))
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
    debugPrint('┌─ API ${body == null ? 'GET' : 'POST'} $path  →  ${response.statusCode}');
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
