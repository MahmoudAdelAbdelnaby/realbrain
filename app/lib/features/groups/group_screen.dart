import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/art/hoopoe.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../item/actions.dart';
import '../shared/tiles.dart';
import 'invite_sheet.dart';
import 'post_card.dart';

/// One group: its Wall (shares, plans, cook-alongs, challenges), its Library (the copies shared
/// into it), Plans (what's coming up, with RSVPs) and Members (invite, share target, leave).
class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key, required this.groupId, this.initialTab = 0});
  final String groupId;
  final int initialTab;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late int _tab = widget.initialTab;
  late final Stream<List<Json>> _posts = Repo.instance.posts(widget.groupId);
  String? _section;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrainState>(
      valueListenable: Repo.instance.state,
      builder: (context, s, _) {
        final g = s.group(widget.groupId);
        final c = RbColors.of(context);
        if (g == null) {
          return Scaffold(
              appBar: AppBar(),
              body: s.loaded
                  ? const EmptyState(
                      title: 'You’re not in this group',
                      body: 'It may have been left or removed.')
                  : const LoadingMark());
        }
        final names = [for (final m in g.members) g.nameOf(m)];
        return Scaffold(
          appBar: AppBar(
            title: Text(g.name),
            actions: [
              IconButton(
                  tooltip: 'Invite',
                  onPressed: () => openInvite(context, g),
                  icon: Icon(Icons.person_add_alt, color: c.text)),
            ],
          ),
          body: StreamBuilder<List<Json>>(
            stream: _posts,
            builder: (context, snap) {
              final posts = snap.data ?? const <Json>[];
              final header = <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      RbSpace.side, 0, RbSpace.side, 6),
                  child: Row(children: [
                    AvatarStack(names, size: 30, max: 6),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          '${count(g.members.length, 'member')}${g.isDefault ? ' · where “Realbrain · Home” shares go' : ''}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ]),
                ),
                SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                        RbSpace.side, 8, RbSpace.side, 0),
                    children: [
                      for (final (i, label) in const [
                        'Wall',
                        'Library',
                        'Plans',
                        'Members'
                      ].indexed) ...[
                        FilterPill(
                            label: label,
                            selected: _tab == i,
                            onTap: () => setState(() => _tab = i)),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ];
              final body = switch (_tab) {
                0 => _wall(context, s, g, posts,
                    snap.connectionState == ConnectionState.waiting),
                1 => _library(context, s, g),
                2 => _plans(context, s, g, posts),
                _ => _members(context, s, g),
              };
              return ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [...header, ...body]);
            },
          ),
          floatingActionButton: _tab == 0
              ? FloatingActionButton.extended(
                  backgroundColor: c.brand,
                  foregroundColor: c.onBrand,
                  onPressed: () => _pickToShare(context, s, g),
                  icon: Glyph(Glyphs.groups, color: c.onBrand, size: 20),
                  label: const Text('Share a discovery'),
                )
              : null,
        );
      },
    );
  }

  List<Widget> _wall(BuildContext context, BrainState s, GroupInfo g,
      List<Json> posts, bool waiting) {
    if (waiting && posts.isEmpty) {
      return const [LoadingMark(text: 'Opening the wall')];
    }
    if (posts.isEmpty) {
      return [
        EmptyState(
          title: 'A quiet wall',
          body:
              'Share a recipe to cook together, a place to plan a visit, or a workout to '
              'challenge everyone.',
          pose: HudhudPose.perched,
          action: 'Share a discovery',
          onAction: () => _pickToShare(context, s, g),
        ),
      ];
    }
    return [for (final p in posts) PostCard(post: p, group: g, uid: s.uid)];
  }

  List<Widget> _library(BuildContext context, BrainState s, GroupInfo g) {
    final all = s.inSpace(g.id);
    if (all.isEmpty) {
      return const [
        EmptyState(
            compact: true,
            title: 'Nothing in the shared library yet',
            body: 'Share to the group, or share a reel to “Realbrain · Home”.'),
      ];
    }
    final ids = {for (final d in all) d.section};
    final shown = [
      for (final d in all)
        if (_section == null || d.section == _section) d
    ];
    return [
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
          children: [
            for (final cat in categories)
              if (ids.contains(cat.id)) ...[
                FilterPill(
                    label: cat.name,
                    glyph: cat.id,
                    selected: _section == cat.id,
                    onTap: () => setState(
                        () => _section = _section == cat.id ? null : cat.id)),
                const SizedBox(width: 8),
              ],
          ],
        ),
      ),
      for (final d in shown)
        DiscoveryRow(d,
            within: shown,
            note: d.addedBy != null && d.addedBy != s.uid
                ? '${g.nameOf(d.addedBy!)} · ${d.detail.isEmpty ? ago(d.createdAt) : d.detail}'
                : null),
    ];
  }

  List<Widget> _plans(
      BuildContext context, BrainState s, GroupInfo g, List<Json> posts) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    final plans = [
      for (final p in posts)
        if (p['when'] != null) p
    ]..sort((a, b) => (a['when'] as num).compareTo(b['when'] as num));
    final upcoming = [
      for (final p in plans)
        if ((p['when'] as num) > now - 3 * 3600) p
    ];
    final past = [
      for (final p in plans.reversed)
        if ((p['when'] as num) <= now - 3 * 3600) p
    ];
    if (plans.isEmpty) {
      return const [
        EmptyState(
            compact: true,
            title: 'No plans yet',
            body:
                'Open a place and tap Plan a visit, a recipe and tap Cook it together, or a workout '
                'and challenge the group.'),
      ];
    }
    return [
      if (upcoming.isNotEmpty) ...[
        const Padding(
            padding: EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 8),
            child: MonoLabel('Coming up')),
        for (final p in upcoming) PostCard(post: p, group: g, uid: s.uid),
      ],
      if (past.isNotEmpty) ...[
        const Padding(
            padding: EdgeInsets.fromLTRB(RbSpace.side, 8, RbSpace.side, 8),
            child: MonoLabel('Done and past')),
        for (final p in past.take(10)) PostCard(post: p, group: g, uid: s.uid),
      ],
    ];
  }

  List<Widget> _members(BuildContext context, BrainState s, GroupInfo g) {
    final c = RbColors.of(context);
    return [
      for (final m in g.members)
        SheetRow(
          title: g.nameOf(m) + (m == s.uid ? ' (you)' : ''),
          subtitle: m == g.createdBy ? 'Started the group' : null,
          trailing: Avatar(g.nameOf(m), size: 32),
        ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
        child: RbButton('Invite someone',
            expand: true,
            icon: Icons.person_add_alt,
            onPressed: () => openInvite(context, g)),
      ),
      const SizedBox(height: 20),
      SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
        title: const Text('Share target for “Realbrain · Home”'),
        subtitle: const Text('Reels you share to Home land in this group.'),
        value: g.isDefault,
        onChanged: g.isDefault
            ? null
            : (_) async {
                try {
                  await Repo.instance.setDefaultGroup(g.id);
                  if (context.mounted) {
                    toast(context, 'Home shares now go to ${g.name}');
                  }
                } catch (e) {
                  if (context.mounted) toast(context, apiError(e));
                }
              },
      ),
      SheetRow(
        title: 'Leave ${g.name}',
        icon: Icons.logout,
        destructive: true,
        onTap: () async {
          final sure = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                    title: Text('Leave ${g.name}?'),
                    content: const Text(
                        'You’ll stop seeing its wall and library. Someone can invite you back.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('Stay')),
                      TextButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: Text('Leave',
                              style: TextStyle(color: c.falseFg))),
                    ],
                  ));
          if (sure != true || !context.mounted) return;
          try {
            await Repo.instance.leaveGroup(g.id);
            if (context.mounted) Navigator.of(context).pop();
          } catch (e) {
            if (context.mounted) toast(context, apiError(e));
          }
        },
      ),
    ];
  }

  /// Pick something from your own library to share into this group.
  Future<void> _pickToShare(
      BuildContext context, BrainState s, GroupInfo g) async {
    final mine = [
      for (final d in s.discoveries)
        if (d.spaceId != g.id) d
    ];
    final picked = await showRbSheet<Discovery>(context,
        title: 'Share to ${g.name}',
        kicker: 'From your library',
        builder: (sheet) => mine.isEmpty
            ? const EmptyState(compact: true, title: 'Nothing to share yet')
            : Column(children: [
                for (final d in mine.take(30))
                  DiscoveryRow(d,
                      onTap: () => Navigator.pop(sheet, d),
                      trailing: const SizedBox.shrink()),
              ]));
    if (picked == null || !context.mounted) return;
    final kind = switch (picked.section) {
      'places' => 'plan',
      'recipe' => 'cook',
      'workout' => 'challenge',
      _ => null,
    };
    await shareToGroup(context, picked, kind: kind, groupId: g.id);
  }
}
