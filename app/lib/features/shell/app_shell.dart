import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/data/repo.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/nav_bar.dart';
import '../brain/my_brain_screen.dart';
import '../capture/capture_sheet.dart';
import '../groups/groups_screen.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/open.dart';
import '../today/today_screen.dart';

/// The app (docs/DESIGN_V5.md §2.5): Today · Library · ( + ) · Groups · My Brain, live from the
/// repo, with what's arriving floating above the tab bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = 0, this.now});
  final int initialTab;

  /// A fixed clock for previews and tests.
  final DateTime? now;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  late int tab = widget.initialTab;

  // A save that was processing a moment ago and just finished: "Ready" flashes for 4 s.
  final _wasProcessing = <String>{};
  Json? _flash;
  Timer? _flashTimer;

  /// Room the tab bar takes at the foot of each tab.
  static const barRoom = 96.0;

  void select(int i) => setState(() => tab = i);

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _track(BrainState s) {
    final busy = {for (final p in s.processing) '${p['save_id']}'};
    for (final id in _wasProcessing.difference(busy)) {
      final save = s.saves.where((x) => x['save_id'] == id).firstOrNull;
      if (save != null &&
          (save['status'] == 'ready' || save['status'] == 'partial')) {
        _flash = save;
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _flash = null);
        });
      }
    }
    _wasProcessing
      ..clear()
      ..addAll(busy);
  }

  /// Only a save that just finished floats above the tab bar, for 4 s. Saves still being
  /// understood live on Today's strip (and a dot on the Today tab), so the bar never sits on top
  /// of the thing you came to do, such as the pick's main button.
  StatusLine? _status(BuildContext context, BrainState s) {
    final f = _flash;
    if (f != null) {
      final d = s.forSave('${f['save_id']}').firstOrNull;
      return StatusLine(
        key: 'ready-${f['save_id']}',
        text: d == null ? 'Saved' : 'Ready: ${d.title}',
        thumb: d == null ? null : DiscoveryArt(d, typeset: false),
        onTap: d == null ? null : () => openDiscovery(context, d),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrainState>(
      valueListenable: Repo.instance.state,
      builder: (context, s, _) {
        _track(s);
        final pad = EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 14, bottom: barRoom + 16);
        final tabs = [
          TodayScreen(
            state: s,
            now: widget.now,
            padding: pad,
            onTab: select,
            onCapture: () => openCapture(context),
            onAccount: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          LibraryScreen(state: s, padding: pad),
          GroupsScreen(state: s, padding: pad),
          MyBrainScreen(state: s, padding: pad, now: widget.now),
        ];
        return PopScope(
          canPop: tab == 0,
          onPopInvokedWithResult: (popped, _) {
            if (!popped) {
              setState(() => tab = 0); // Back from a tab goes to Today first
            }
          },
          child: Scaffold(
            extendBody: true,
            body: IndexedStack(index: tab, children: tabs),
            bottomNavigationBar: RbNavBar(
              selected: tab,
              onSelect: select,
              onCapture: () => openCapture(context),
              status: _status(context, s),
              items: [
                NavItem('Today',
                    glyph: Glyphs.today,
                    dot: s.processing.isNotEmpty && tab != 0
                        ? 'a save is being understood'
                        : null),
                NavItem('Library',
                    glyph: Glyphs.library, badge: s.attention.length),
                const NavItem('Groups', glyph: Glyphs.groups),
                const NavItem('My Brain'),
              ],
            ),
          ),
        );
      },
    );
  }
}
