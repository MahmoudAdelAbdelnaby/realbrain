import 'package:flutter/material.dart';

import '../core/data/demo_repo.dart';
import '../core/data/repo.dart';
import '../core/native.dart';
import '../features/auth/auth_gate.dart' show SignInScreen;
import '../features/capture/capture_sheet.dart' show openCapture;
import '../features/gallery/gallery_screen.dart';
import '../features/groups/invite_sheet.dart';
import '../features/groups/post_card.dart';
import '../features/item/actions.dart';
import '../features/library/collections.dart';
import '../features/settings/settings_screen.dart';
import '../features/shared/open.dart';
import '../features/shell/app_shell.dart';
import '../main.dart';
import 'sample.dart';

/// The real screens on sample data, no Firebase or backend. Two uses:
/// * the screenshot preview: `flutter build web -t lib/preview/main_preview.dart`, opened with
///   ?theme=dark|light&tab=0..3&route=... (see [_open]), on a fixed clock so shots repeat;
/// * the demo APK: the same with `--dart-define=RB_DEMO=true` (.github/workflows/demo.yml), on
///   the real clock, so the pick and greeting follow the time of day.
/// Neither is the shipped app (lib/main.dart).
void main() {
  final q = Uri.base.queryParameters;
  final now = demoBuild ? DateTime.now() : DateTime(2026, 11, 3, 19, 20);
  final state = sampleState(now, puzzle: q['puzzle'] != 'off');
  Repo.instance = DemoRepo(state,
      posts: samplePosts(state, now),
      comments: sampleComments(now),
      clock: demoBuild ? DateTime.now : () => now);
  appPrefs.value = (lang: q['lang'] ?? 'en', theme: q['theme'] ?? 'dark');
  backendUrl.value = ''; // frames are relative preview/img paths
  runApp(ReelbrainApp(
      home: _PreviewHome(
          route: q['route'],
          tab: int.tryParse(q['tab'] ?? '0') ?? 0,
          now: demoBuild ? null : now)));
}

class _PreviewHome extends StatefulWidget {
  const _PreviewHome(
      {required this.route, required this.tab, required this.now});
  final String? route;
  final int tab;

  /// Null: the live clock (the demo build).
  final DateTime? now;

  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _open(context, widget.route));
  }

  Discovery _find(String prefix) {
    final s = Repo.instance.now;
    return s.discoveries.firstWhere(
        (d) => d.title.toLowerCase().startsWith(prefix.toLowerCase()),
        orElse: () => s.discoveries.first);
  }

  Future<void> _open(BuildContext context, String? route) async {
    if (route == null || route == 'signin') return;
    final parts = route.split(':');
    final arg = parts.length > 1 ? parts[1] : '';
    final s = Repo.instance.now;
    switch (parts.first) {
      case 'detail':
        await openDiscovery(context, _find(arg), within: s.discoveries);
      case 'viewer':
        final list = arg.isEmpty
            ? [
                for (final d in s.discoveries)
                  if (d.isOpen) d
              ]
            : [
                for (final d in s.discoveries)
                  if (d.isOpen && d.section == arg) d
              ];
        await openViewer(context, list, title: 'Not tried yet');
      case 'category':
        await openCategory(context, arg);
      case 'group':
        await openGroup(context, arg,
            tab: int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0);
      case 'arriving':
        await openArriving(context);
      case 'settings':
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      case 'gallery':
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const GalleryScreen()));
      case 'capture':
        // A link already "on the clipboard": the browser won't hand one over unprompted.
        await openCapture(context,
            clipboard: 'https://www.tiktok.com/@chefaya/video/7412');
      case 'comments':
        final g = s.group(arg)!;
        final posts = await Repo.instance.posts(arg).first;
        if (!context.mounted) return;
        await openComments(
            context, g, posts.firstWhere((p) => p['post_id'] == parts[2]));
      case 'invite':
        await openInvite(context, s.group(arg)!);
      case 'collection':
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CollectionScreen(listId: arg)));
      case 'share':
        await shareToGroup(context, _find(arg),
            kind: parts.length > 2 ? parts[2] : null);
      case 'do':
        await primaryAction(context, _find(arg));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.route == 'signin') return SignInScreen(onSignIn: () async {});
    return AppShell(initialTab: widget.tab, now: widget.now);
  }
}
