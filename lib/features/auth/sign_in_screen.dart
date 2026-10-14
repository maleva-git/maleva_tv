import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/network/api_exception.dart';
import 'package:maleva_tv/core/session/tv_auth_controller.dart';
import 'package:maleva_tv/features/board/board_theme.dart';

/// One-time sign-in with an employee account. After this the TV stays signed in.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({this.message, this.userName, super.key});

  final String? message;
  final String? userName;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final _user = TextEditingController(text: widget.userName ?? '');
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.message;
  }

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_user.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter the user name and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(tvAuthProvider.notifier).signIn(_user.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _field(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: BoardTheme.textSecondary, fontSize: 18),
        prefixIcon: Icon(icon, color: BoardTheme.textSecondary),
        filled: true,
        fillColor: BoardTheme.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BoardTheme.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BoardTheme.accent, width: 2.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -1.2),
            radius: 1.8,
            colors: [BoardTheme.backgroundEnd, BoardTheme.background],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 560,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: BoardTheme.panel,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BoardTheme.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 32, offset: const Offset(0, 12))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Image.asset('assets/company/logo.png', width: 72, height: 72, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('MALEVA TV BOARD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900, color: BoardTheme.textPrimary, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  const Text('Sign in once with an employee account.\nThe TV stays signed in after this.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, color: BoardTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _user,
                    autofocus: _user.text.isEmpty,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    style: const TextStyle(color: BoardTheme.textPrimary, fontSize: 20),
                    decoration: _field('User name', Icons.person_rounded),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    focusNode: _passwordFocus,
                    autofocus: _user.text.isNotEmpty,
                    enabled: !_busy,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    style: const TextStyle(color: BoardTheme.textPrimary, fontSize: 20),
                    decoration: _field('Password', Icons.lock_rounded),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF87171).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.6)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 16)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 60,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: BoardTheme.accent,
                        foregroundColor: BoardTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 3, color: BoardTheme.background))
                          : const Text('SIGN IN'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
