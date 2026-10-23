import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';
import '../feed/feed_screen.dart';
import '../spaces/household_screen.dart';

/// Signed out: the sign-in screen. Signed in: make sure the user and personal space exist,
/// send any saves that waited for sign-in, and open invite links.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _nav = GlobalKey<NavigatorState>();
  String? _pendingCode;
  String? _bootstrapped;

  @override
  void initState() {
    super.initState();
    native.setMethodCallHandler((call) async {
      if (call.method == 'link') {
        _openInvite(inviteCode(call.arguments as String?));
      }
    });
    native
        .invokeMethod<String>('initialLink')
        .then((link) => _openInvite(inviteCode(link)));
  }

  void _openInvite(String? code) {
    if (code == null) return;
    if (FirebaseAuth.instance.currentUser == null) {
      _pendingCode = code; // opened after sign-in
      return;
    }
    _nav.currentState?.push(
      MaterialPageRoute(builder: (_) => JoinScreen(code: code)),
    );
  }

  Future<void> _bootstrap(User user) async {
    if (_bootstrapped == user.uid) return;
    _bootstrapped = user.uid;
    try {
      await api('POST', '/v1/me', {
        'name': user.displayName,
        'lang': WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      });
    } on PlatformException {
      // Backend offline: the next call retries; saves wait on the phone meanwhile.
      _bootstrapped = null;
    }
    await native.invokeMethod('retryWaiting');
    final code = _pendingCode;
    _pendingCode = null;
    _openInvite(code);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const SignInScreen();
        unawaited(_bootstrap(user));
        return Navigator(
          key: _nav,
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: (_) => const FeedScreen()),
        );
      },
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reelbrain', style: t.headlineMedium),
              const SizedBox(height: 8),
              const Text('Sign in to keep your saves and share a Home space.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _signIn,
                child: Text(_busy ? 'Signing in…' : 'Sign in with Google'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
