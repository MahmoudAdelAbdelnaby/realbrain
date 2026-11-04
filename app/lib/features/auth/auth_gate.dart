import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/art/hoopoe.dart';
import '../../core/art/mark.dart';
import '../../core/data/firestore_repo.dart';
import '../../core/data/repo.dart';
import '../../core/native.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../shared/open.dart';
import '../shell/app_shell.dart';

/// Signed out: onboarding and sign-in. Signed in: the user and personal space exist, saves that
/// waited for sign-in are sent, invite links and notification taps open where they point.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _nav = GlobalKey<NavigatorState>();
  String? _pendingCode, _bootstrapped, _repoFor;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<Object?>? _config;

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
      final ctx = _nav.currentContext;
      if (n == null || ctx == null || !ctx.mounted) return;
      toast(ctx, n.title ?? 'Ready',
          action: 'Open', onAction: () => _openSave(m));
    });
  }

  void _openSave(RemoteMessage? m) {
    final save = m?.data['save_id'] as String?;
    if (save == null || FirebaseAuth.instance.currentUser == null) return;
    // After a cold start from a tap, wait for the first frame so the navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _nav.currentContext;
      if (ctx != null) openSave(ctx, save);
    });
  }

  /// Asks once for notification permission, then registers with FCM; the installation ID goes
  /// to the backend as this phone's push target.
  Future<void> _registerPush() async {
    try {
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      _tokenRefresh ??= fm.onRegistered
          .listen((fid) => api('POST', '/v1/me', {'fcm_token': fid}).ignore());
      await fm.register();
      final fid = await native.invokeMethod<String>('fid');
      debugPrint(
          'Realbrain push target ${fid == null ? 'missing' : 'registered'}');
      if (fid != null) await api('POST', '/v1/me', {'fcm_token': fid});
    } catch (e) {
      // No push (permission refused or no Play services): saves still work.
      debugPrint('Realbrain push registration failed: $e');
    }
  }

  void _openInvite(String? code) {
    if (code == null) return;
    if (FirebaseAuth.instance.currentUser == null) {
      _pendingCode = code; // opened after sign-in
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _nav.currentContext;
      if (ctx == null) return;
      try {
        final id = await Repo.instance.join(code);
        if (ctx.mounted) {
          toast(ctx, 'You joined the group');
          await openGroup(ctx, id);
        }
      } catch (e) {
        if (ctx.mounted) toast(ctx, apiError(e));
      }
    });
  }

  /// The backend publishes its address (Firestore config/backend); follow it.
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
      _bootstrapped = null; // a new backend: register with it
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) unawaited(_bootstrap(user));
    }, onError: (_) {});
  }

  Future<void> _bootstrap(User user) async {
    _followBackend();
    if (backendUrl.value == null || _bootstrapped == user.uid) return;
    _bootstrapped = user.uid;
    try {
      await api('POST', '/v1/me', {
        'name': user.displayName,
        'lang': WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      });
      unawaited(_registerPush());
    } on PlatformException {
      _bootstrapped =
          null; // backend offline: saves wait on the phone meanwhile
    }
    await native.invokeMethod('retryWaiting');
    final code = _pendingCode;
    _pendingCode = null;
    _openInvite(code);
  }

  @override
  void dispose() {
    _config?.cancel();
    _tokenRefresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingMark(text: 'Realbrain'));
        }
        final user = snap.data;
        if (user == null) {
          _repoFor = null;
          return const SignInScreen();
        }
        if (_repoFor != user.uid) {
          Repo.instance = FirestoreRepo();
          _repoFor = user.uid;
        }
        unawaited(_bootstrap(user));
        return Navigator(
          key: _nav,
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: (_) => const AppShell()),
        );
      },
    );
  }
}

/// Onboarding and sign-in: what Realbrain does in three plates, then one button.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.onSignIn});

  /// Overrides Google sign-in (previews and tests).
  final Future<void> Function()? onSignIn;

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
      if (widget.onSignIn != null) {
        await widget.onSignIn!();
      } else {
        // Web: a redirect, since home-screen apps on iPhone can't open popups.
        await (kIsWeb
            ? FirebaseAuth.instance.signInWithRedirect(GoogleAuthProvider())
            : FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider()));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    RbSpace.side, 16, RbSpace.side, 24),
                children: [
                  const Wordmark(size: 22),
                  const SizedBox(height: 24),
                  Plate(
                    caption: 'Pl. 1 · Hudhud, the scout',
                    child: const Hudhud(
                        width: 250, pose: HudhudPose.carrying, motion: true),
                  ),
                  const SizedBox(height: 26),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Everything you discover, '),
                      TextSpan(
                          text: 'finally used.',
                          style: RbType.serif(34, color: c.text, italic: true)),
                    ]),
                    style: RbType.serif(34, color: c.text),
                  ),
                  const SizedBox(height: 22),
                  for (final (n, title, body) in const [
                    (
                      '01',
                      'Save',
                      'Share any reel, link or idea to Realbrain. It never asks you anything.'
                    ),
                    (
                      '02',
                      'Understand',
                      'It comes back as a recipe, a place, a tool, a verdict, a watchlist…'
                    ),
                    (
                      '03',
                      'Use',
                      'Cook it, visit it, try it, together. Everything you finish is a piece of your brain.'
                    ),
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: c.line))),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 40,
                                child: Text(n,
                                    style: RbType.monoNumber(15,
                                        color: c.brandText))),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: RbType.serif(20, color: c.text)),
                                    const SizedBox(height: 2),
                                    Text(body,
                                        style: t.bodyMedium
                                            ?.copyWith(color: c.muted)),
                                  ]),
                            ),
                          ]),
                    ),
                  const SizedBox(height: 22),
                  RbButton(_busy ? 'Signing in…' : 'Get started with Google',
                      expand: true,
                      busy: _busy,
                      onPressed: _busy ? null : _signIn),
                  const SizedBox(height: 10),
                  Text(
                      'Your saves stay private to you and the groups you share with.',
                      textAlign: TextAlign.center,
                      style: t.bodySmall),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorNote(
                        title: 'Couldn’t sign in',
                        message: _error!,
                        onRetry: _signIn),
                  ],
                ]),
          ),
        ),
      ),
    );
  }
}
