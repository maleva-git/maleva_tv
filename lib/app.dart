import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/session/tv_auth_controller.dart';
import 'package:maleva_tv/features/auth/sign_in_screen.dart';
import 'package:maleva_tv/features/board/board_theme.dart';
import 'main_navigation_screen.dart';

class TVApp extends StatelessWidget {
  const TVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maleva TV',
      theme: ThemeData(
        brightness: Brightness.dark,
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
    return switch (ref.watch(tvAuthProvider)) {
      SignedIn() => const MainNavigationScreen(),
      SignedOut(:final message, :final userName) =>
        SignInScreen(key: ValueKey(message), message: message, userName: userName),
      AuthStarting(:final message) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: BoardTheme.accent),
                const SizedBox(height: 20),
                Text(
                  message == null ? 'Starting…' : 'Connecting to the server…\n$message',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: BoardTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
    };
  }
}
