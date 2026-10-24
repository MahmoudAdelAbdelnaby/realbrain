import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';
import '../feed/feed_screen.dart';
import '../save/save_screen.dart';
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
    // Push (P1-06): a tap opens the save; one arriving while the app is open shows a bar.
    FirebaseMessaging.onMessageOpenedApp.listen(_openSave);
    FirebaseMessaging.instance.getInitialMessage().then(_openSave);
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n.title ?? 'Save ready'),
        action: SnackBarAction(label: 'Open', onPressed: () => _openSave(m)),
      ));
    });
  }

  void _openSave(RemoteMessage? m) {
    final space = m?.data['space_id'] as String?;
    final save = m?.data['save_id'] as String?;
    if (space == null ||
        save == null ||
        FirebaseAuth.instance.currentUser == null) {
      return;
    }
    // After a cold start from a tap, wait for the first frame so the navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) => _nav.currentState?.push(
          MaterialPageRoute(
              builder: (_) => SaveScreen(spaceId: space, saveId: save)),
        ));
  }

  /// Asks once for notification permission, then registers with FCM. The installation ID it
  /// reports (now and whenever it changes) goes to the backend as this phone's push target.
  Future<void> _registerPush() async {
    try {
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      _tokenRefresh ??= fm.onRegistered.listen(
        (fid) => api('POST', '/v1/me', {'fcm_token': fid}).ignore(),
      );
      await fm.register();
      // onRegistered only fires for a new registration; an already registered phone reports
      // its installation ID here.
      final fid = await native.invokeMethod<String>('fid');
      debugPrint('Reelbrain push target ${fid == null ? 'missing' : 'registered'}');
      if (fid != null) await api('POST', '/v1/me', {'fcm_token': fid});
    } catch (e) {
      // No push (permission refused or no Play services): saves still work.
      debugPrint('Reelbrain push registration failed: $e');
    }
  }

  StreamSubscription<String>? _tokenRefresh;

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

  StreamSubscription<Object?>? _config;

  /// The backend publishes its address (it changes with each tunnel start); follow it.
  void _followBackend() {
    _config ??= FirebaseFirestore.instance
        .doc('config/backend')
        .snapshots()
        .listen((snap) async {
      final url = snap.data()?['url'] as String?;
      if (url == null || url == backendUrl.value) return;
      backendUrl.value = url;
      await native.invokeMethod('setBackendUrl', {'url': url});
      await native.invokeMethod('retryWaiting');
      // New backend (or the first address we learn): register with it.
      _bootstrapped = null;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) unawaited(_bootstrap(user));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _config?.cancel();
    _tokenRefresh?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap(User user) async {
    _followBackend();
    // Wait for the backend's address from Firestore; the listener calls back here.
    if (backendUrl.value == null || _bootstrapped == user.uid) return;
    _bootstrapped = user.uid;
    try {
      await api('POST', '/v1/me', {
        'name': user.displayName,
        'lang': WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      });
      unawaited(_registerPush());
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
