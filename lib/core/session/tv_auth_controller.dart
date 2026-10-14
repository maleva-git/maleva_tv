import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maleva_tv/core/network/api_exception.dart';
import 'package:maleva_tv/core/providers.dart';
import 'package:maleva_tv/core/session/tv_auth_service.dart';

sealed class TvAuthState {
  const TvAuthState();
}

/// Reading the saved session at start-up.
class AuthStarting extends TvAuthState {
  const AuthStarting({this.message});

  /// Why the start is still waiting (no network), if it is.
  final String? message;
}

class SignedOut extends TvAuthState {
  const SignedOut({this.message, this.userName});
  final String? message;
  final String? userName;
}

class SignedIn extends TvAuthState {
  const SignedIn(this.session);
  final TvSession session;
}

class TvAuthController extends StateNotifier<TvAuthState> {
  TvAuthController(this._service) : super(const AuthStarting()) {
    _service.onSignInRequired = (message) async {
      state = SignedOut(message: message, userName: await _service.savedUserName());
    };
    _start();
  }

  final TvAuthService _service;

  /// Opens the saved session. When the saved account must sign in again but the server cannot be
  /// reached (TV started before the network), keeps trying instead of asking for the password.
  Future<void> _start() async {
    while (mounted) {
      try {
        final session = await _service.restore();
        state = session != null ? SignedIn(session) : SignedOut(userName: await _service.savedUserName());
        return;
      } on ApiException catch (e) {
        state = AuthStarting(message: e.message);
        await Future<void>.delayed(const Duration(seconds: 15));
      }
    }
  }

  /// Throws [ApiException] with the server's message when the sign-in is refused.
  Future<void> signIn(String userName, String password) async {
    state = SignedIn(await _service.signIn(userName.trim(), password));
  }
}

final tvAuthProvider =
    StateNotifierProvider<TvAuthController, TvAuthState>((ref) => TvAuthController(ref.watch(tvAuthServiceProvider)));
