import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:maleva_tv/core/config/app_config.dart';
import 'package:maleva_tv/core/network/api_exception.dart';
import 'package:maleva_tv/core/network/java_answer.dart';

/// The employee session the TV signed in with (`Data1` of `POST /api/mobile/auth/login`).
class TvSession {
  const TvSession({required this.token, required this.companyId, required this.companyName, required this.userName});

  final String token;
  final int companyId;
  final String companyName;
  final String userName;
}

/// The saved account no longer signs in (password changed, account disabled): someone has to sign in again.
class SignInRequired implements Exception {
  const SignInRequired(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Signs the TV in the way maleva_app does (`/api/mobile/auth/login`, `/refresh`), but keeps the TV signed in
/// for good: the account is saved in Android's encrypted storage, the token is refreshed on a 401, and when the
/// server ends the session (30 days) the TV signs in again with the saved account. There is no sign-out.
class TvAuthService {
  TvAuthService(this._http, {FlutterSecureStorage? storage, String? baseUrl, TvSession? session})
      : _storage = storage ?? defaultStorage,
        _baseUrl = baseUrl ?? AppConfig.javaBaseUrl,
        _session = session;

  /// Android: the Keystore. macOS: the classic keychain, which works for an app signed without an Apple
  /// team (the data-protection keychain refuses it: -34018). Windows: its own encrypted credential store.
  static const defaultStorage = FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));

  static const _kUser = 'tv.userName';
  static const _kPassword = 'tv.password';
  static const _kToken = 'tv.token';
  static const _kCompanyId = 'tv.companyId';
  static const _kCompanyName = 'tv.companyName';
  static const _timeout = Duration(seconds: 30);

  final http.Client _http;
  final FlutterSecureStorage _storage;
  final String _baseUrl;

  TvSession? _session;
  Future<TvSession>? _renewing;

  /// Called when the saved account stops working; the app then shows the sign-in screen.
  void Function(String message)? onSignInRequired;

  TvSession? get session => _session;

  /// The saved session, or null when the TV has never signed in.
  Future<TvSession?> restore() async {
    final user = await _storage.read(key: _kUser);
    final token = await _storage.read(key: _kToken);
    if (user == null || token == null || token.isEmpty) {
      // Signed in before but the token was dropped: sign in again with the saved account.
      if (user != null && await _storage.read(key: _kPassword) != null) {
        try {
          return await renew();
        } on SignInRequired {
          return null;
        }
      }
      return null;
    }
    return _session = TvSession(
      token: token,
      companyId: int.tryParse(await _storage.read(key: _kCompanyId) ?? '') ?? AppConfig.companyId,
      companyName: await _storage.read(key: _kCompanyName) ?? '',
      userName: user,
    );
  }

  Future<String?> savedUserName() => _storage.read(key: _kUser);

  /// Signs in and saves the account, so the TV never has to be signed in by hand again.
  Future<TvSession> signIn(String userName, String password) async {
    final session = await _login(userName, password);
    await _storage.write(key: _kUser, value: userName);
    await _storage.write(key: _kPassword, value: password);
    return _save(session);
  }

  /// A new token after a 401: refresh first, then sign in again with the saved account.
  /// Calls made while a renewal runs share it.
  Future<TvSession> renew() => _renewing ??= _renew().whenComplete(() => _renewing = null);

  Future<TvSession> _renew() async {
    final current = _session;
    if (current != null) {
      try {
        final data = await _post('/api/mobile/auth/refresh', headers: {'Authorization': 'Bearer ${current.token}'});
        return await _save(_fromData(data, current.userName));
      } on ApiException catch (e) {
        if (e.statusCode != 401 && e.statusCode != 403) rethrow;
      }
    }
    final user = await _storage.read(key: _kUser);
    final password = await _storage.read(key: _kPassword);
    if (user == null || password == null) {
      return _requireSignIn('Please sign in.');
    }
    try {
      return await _save(await _login(user, password));
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return _requireSignIn('The saved account could not sign in (${e.message}). Please sign in again.');
      }
      rethrow; // network or server trouble: keep the account and try again on the next refresh
    }
  }

  Future<TvSession> _requireSignIn(String message) async {
    _session = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kPassword);
    onSignInRequired?.call(message);
    throw SignInRequired(message);
  }

  Future<TvSession> _login(String userName, String password) async {
    try {
      final data =
          await _post('/api/mobile/auth/login', body: {'userName': userName, 'password': password, 'driver': false});
      return _fromData(data, userName);
    } on ApiException catch (e) {
      if (e.statusCode == 401) throw ApiException('Invalid user name or password', statusCode: 401);
      rethrow;
    }
  }

  Future<TvSession> _save(TvSession session) async {
    await _storage.write(key: _kToken, value: session.token);
    await _storage.write(key: _kCompanyId, value: '${session.companyId}');
    await _storage.write(key: _kCompanyName, value: session.companyName);
    return _session = session;
  }

  TvSession _fromData(dynamic data, String userName) {
    if (data is! Map<String, dynamic>) throw const ApiException('The server sent an unreadable session.');
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) throw const ApiException('The server sent no session token.');
    if (data['principalKind']?.toString().toUpperCase() == 'DRIVER') {
      throw const ApiException('Use an employee account, not a driver account.', statusCode: 401);
    }
    return TvSession(
      token: token,
      companyId: int.tryParse('${data['companyId']}') ?? AppConfig.companyId,
      companyName: data['companyName']?.toString() ?? '',
      userName: userName,
    );
  }

  Future<dynamic> _post(String path, {Map<String, String>? headers, Object? body}) async {
    try {
      final response = await _http
          .post(Uri.parse('$_baseUrl$path'),
              headers: {'Content-Type': 'application/json; charset=UTF-8', ...?headers},
              body: body == null ? null : jsonEncode(body))
          .timeout(_timeout);
      return JavaAnswer.data(response);
    } on SocketException {
      throw const ApiException('Check your network connection');
    } on TimeoutException {
      throw const ApiException('The server did not answer in time');
    } on http.ClientException {
      throw const ApiException('Check your network connection');
    }
  }
}
