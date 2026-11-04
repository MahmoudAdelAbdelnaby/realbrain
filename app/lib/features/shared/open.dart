import 'package:flutter/material.dart';

import '../../core/data/repo.dart';
import '../groups/group_screen.dart';
import '../inbox/arriving_screen.dart';
import '../item/discovery_screen.dart';
import '../library/category_screen.dart';
import '../viewer/viewer_screen.dart';

/// Opens a discovery's page. [within] is the list it was opened from (the page offers "Browse"
/// through it, and the viewer starts there).
Future<void> openDiscovery(BuildContext context, Discovery d,
        {List<Discovery>? within}) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DiscoveryScreen(discoveryKey: d.key, within: within)));

/// Opens a save's page by id (notifications, group posts); waits for it to load.
Future<void> openSave(BuildContext context, String saveId) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DiscoveryScreen.forSave(saveId: saveId)));

/// Full-screen vertical browse through [list], starting at [start].
Future<void> openViewer(BuildContext context, List<Discovery> list,
    {int start = 0, String title = 'Browse'}) {
  if (list.isEmpty) return Future.value();
  return Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => ViewerScreen(
        keys: [for (final d in list) d.key], start: start, title: title),
    transitionsBuilder: (_, a, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child),
    ),
  ));
}

Future<void> openCategory(BuildContext context, String section) =>
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CategoryScreen(section: section)));

Future<void> openArriving(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => const ArrivingScreen()));

Future<void> openGroup(BuildContext context, String groupId, {int tab = 0}) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GroupScreen(groupId: groupId, initialTab: tab)));
