import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maleva_tv/core/session/tv_auth_service.dart';

// Temporary: signs in from the Mac app with a made-up account to see what comes back. Deleted after.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await TvAuthService(http.Client()).signIn('nobody-check', 'wrong-password');
    debugPrint('SIGNIN_CHECK: signed in (unexpected)');
  } catch (e) {
    debugPrint('SIGNIN_CHECK: ${e.runtimeType}: $e');
  }
  runApp(const SizedBox());
}
