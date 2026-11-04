import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/art/hoopoe.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../shared/open.dart';
import 'invite_sheet.dart';
import 'post_card.dart';

/// Groups (docs/DESIGN_V5.md §2.5): the people you discover with. Each group has a wall, a shared
/// library, plans with RSVPs, and members you invite by QR, link or code.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen(
      {super.key, required this.state, this.padding = EdgeInsets.zero});
  final BrainState state;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final s = state;
    return ListView(padding: padding, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MonoLabel('Together · ${count(s.groups.length, 'group')}'),
          const SizedBox(height: 10),
          Semantics(
              header: true,
              child: Text('Groups',
                  style: RbType.serif(RbType.hero, color: c.text))),
          const SizedBox(height: 6),
          Text('Share what you find, plan it, cook it, do it together.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.muted)),
        ]),
      ),
      const SizedBox(height: 20),
      if (!s.loaded)
        const LoadingMark()
      else if (s.groups.isEmpty)
        EmptyState(
          title: 'Discover together',
          body:
              'A group for your household, your friends or a trip: everyone’s finds in one '
              'place, with plans, cook-alongs and challenges.',
          action: 'Create a group',
          onAction: () => createGroupFlow(context),
          pose: HudhudPose.carrying,
          plateCaption: 'Pl. 2 · The scout returns',
        )
      else
        for (final g in s.groups) _GroupCard(g: g, state: s),
      Padding(
        padding: const EdgeInsets.fromLTRB(RbSpace.side, 8, RbSpace.side, 0),
        child: Row(children: [
          if (s.groups.isNotEmpty) ...[
            Expanded(
                child: RbButton.secondary('New group',
                    glyph: Glyphs.groups,
                    onPressed: () => createGroupFlow(context))),
            const SizedBox(width: 10),
          ],
          Expanded(
              child: RbButton.secondary('Join a group',
                  icon: Icons.qr_code_2, onPressed: () => joinFlow(context))),
        ]),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.g, required this.state});
  final GroupInfo g;
  final BrainState state;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final shared = state.inSpace(g.id);
    final names = [for (final m in g.members) g.nameOf(m)];
    return Semantics(
      button: true,
      label: '${g.name}, ${count(g.members.length, 'member')}',
      child: Pressable(
        onTap: () => openGroup(context, g.id),
        child: Container(
          margin: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(RbSpace.cardRadius),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(g.name, style: RbType.serif(26, color: c.text))),
              if (g.isDefault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      border: Border.all(color: c.brandText),
                      borderRadius: BorderRadius.circular(RbSpace.tagRadius)),
                  child:
                      MonoLabel('Share target', color: c.brandText, size: 9.5),
                ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              AvatarStack(names, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    '${count(g.members.length, 'member')} · ${count(shared.length, 'discovery', 'discoveries')}',
                    style: t.bodySmall),
              ),
            ]),
            const SizedBox(height: 12),
            StreamBuilder<List<Json>>(
              stream: Repo.instance.posts(g.id),
              builder: (context, snap) {
                final posts = snap.data ?? const [];
                final now = DateTime.now().millisecondsSinceEpoch / 1000;
                final next = (posts
                        .where((p) =>
                            p['when'] != null &&
                            (p['when'] as num) > now - 3600)
                        .toList()
                      ..sort((a, b) =>
                          (a['when'] as num).compareTo(b['when'] as num)))
                    .firstOrNull;
                final last = posts.firstOrNull;
                if (next == null && last == null) {
                  return Text(
                      'Nothing shared yet. Open it and share something.',
                      style: t.bodySmall);
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (next != null)
                        _Line(
                            icon: Icons.event_outlined,
                            kicker: 'Next',
                            text:
                                '${next['title'] ?? 'Plan'} · ${when(fromEpoch(next['when'] as num))}'),
                      if (last != null && last != next)
                        _Line(
                            icon: Icons.history,
                            kicker: 'Latest',
                            text:
                                '${last['by_name'] ?? 'Someone'} ${postVerb(last)}${last['title'] != null ? ': ${last['title']}' : ''}'),
                    ]);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.kicker, required this.text});
  final IconData icon;
  final String kicker, text;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: c.brandText),
        const SizedBox(width: 8),
        MonoLabel(kicker, size: 10),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
      ]),
    );
  }
}

/// Name a group, create it, then show its invite.
Future<void> createGroupFlow(BuildContext context) async {
  final name = TextEditingController();
  final made = await showRbSheet<String>(context,
      title: 'New group',
      kicker: 'Household, friends, a trip',
      builder: (sheet) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
            child: Column(children: [
              TextField(
                controller: name,
                autofocus: true,
                maxLength: 60,
                decoration: const InputDecoration(
                    hintText: 'Home, Weekend crew, Alex trip…'),
              ),
              const SizedBox(height: 8),
              RbButton('Create',
                  expand: true,
                  onPressed: () => Navigator.pop(sheet, name.text.trim())),
            ]),
          ));
  if (made == null || made.isEmpty || !context.mounted) return;
  try {
    final inv = await Repo.instance.createGroup(made);
    if (!context.mounted) return;
    final g = Repo.instance.now.group(inv.groupId) ??
        GroupInfo(id: inv.groupId, name: made);
    await openInvite(context, g);
  } catch (e) {
    if (context.mounted) toast(context, apiError(e));
  }
}

/// Join with a typed code (or a pasted invite link).
Future<void> joinFlow(BuildContext context) async {
  final code = TextEditingController();
  final typed = await showRbSheet<String>(context,
      title: 'Join a group',
      kicker: 'The 8-letter code from the invite',
      builder: (sheet) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
            child: Column(children: [
              TextField(
                controller: code,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: RbType.monoNumber(22, color: RbColors.of(sheet).text)
                    .copyWith(letterSpacing: 3),
                decoration: const InputDecoration(hintText: 'K7MQ 2XPD'),
              ),
              const SizedBox(height: 12),
              RbButton('Join',
                  expand: true,
                  onPressed: () => Navigator.pop(sheet, code.text)),
            ]),
          ));
  if (typed == null || typed.trim().isEmpty || !context.mounted) return;
  try {
    final id = await Repo.instance.join(typed.replaceAll(' ', ''));
    if (!context.mounted) return;
    toast(context, 'You’re in.');
    await openGroup(context, id);
  } catch (e) {
    if (context.mounted) {
      toast(context, e is StateError ? e.message : apiError(e));
    }
  }
}
