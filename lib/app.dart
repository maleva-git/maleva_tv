import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maleva_tv/core/session/tv_auth_controller.dart';
import 'package:maleva_tv/features/auth/sign_in_screen.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'main_navigation_screen.dart';

class TVApp extends StatelessWidget {
  const TVApp({this.interFont = true, super.key});

  /// maleva_app's font (Inter, from Google Fonts, kept on the device after the first start). Tests
  /// switch it off: they have no network.
  final bool interFont;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maleva TV',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: interFont ? GoogleFonts.inter().fontFamily : null,
        scaffoldBackgroundColor: BoardTheme.background,
        colorScheme: ColorScheme.fromSeed(seedColor: BoardTheme.accent, brightness: Brightness.dark),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Board when signed in, sign-in screen when not.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(tvAuthProvider);
    // The sign-in and start screens use the navy colours; the boards set their own.
    if (auth is! SignedIn) BoardTheme.palette = BoardPalette.navy;
    return switch (auth) {
      SignedIn() => const MainNavigationScreen(),
      SignedOut(:final message, :final userName) =>
        SignInScreen(key: ValueKey(message), message: message, userName: userName),
      AuthStarting(:final message) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: BoardTheme.accent),
                const SizedBox(height: 20),
                Text(
                  message == null ? 'Starting…' : 'Connecting to the server…\n$message',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: BoardTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
    };
  }
}
