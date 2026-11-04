import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../recipes/cooking_mode.dart';
import '../shared/open.dart';
import '../workouts/workout_mode.dart';
import '../workouts/workout_plan.dart';

/// The category's main action, from any surface (the pick, the viewer, the page).
Future<void> primaryAction(BuildContext context, Discovery d) async {
  final data = d.data;
  switch (d.section) {
    case 'recipe':
      final steps = listOf(data['steps']);
      if (steps.isNotEmpty) {
        final cooked = await Navigator.of(context).push<bool>(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => CookingMode(title: d.title, steps: steps)));
        // "Done cooking" is the answer: stamp it, with Undo rather than a question.
        if (cooked == true && !d.isDone && context.mounted) {
          Repo.instance.setStamp(d, 'cooked').ignore();
          toast(context, 'Cooked. Piece placed.',
              action: 'Undo',
              onAction: () => Repo.instance.setStamp(d, 'to_try').ignore());
        }
        return;
      }
    case 'workout':
      final ex = listOf(data['exercises']);
      if (ex.isNotEmpty) {
        await Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => WorkoutMode(phases: buildPhases(ex), items: [d])));
        return;
      }
    case 'places':
      if (Repo.instance.now.groups.isNotEmpty) {
        await shareToGroup(context, d, kind: 'plan');
        return;
      }
      final places = listOf(data['items']);
      if (places.isNotEmpty) {
        await openUrl(context, mapsUrl(places.first));
        return;
      }
    case 'tools':
      final tools = listOf(data['items']);
      final url = tools.isEmpty ? null : toolUrl(tools.first);
      if (url != null) {
        await openUrl(context, url);
        return;
      }
    case 'entertainment':
      final t = listOf(data['items']);
      if (t.isNotEmpty) {
        final title = '${t.first['title']}';
        await openUrl(
            context,
            t.first['kind'] == 'book'
                ? goodreadsSearch(title)
                : justWatchSearch(title));
        return;
      }
    case 'products':
      final p = listOf(data['items']);
      final url = p.isEmpty ? null : productUrl(p.first);
      if (url != null) {
        await openUrl(context, url);
        return;
      }
  }
  if (context.mounted) await openDiscovery(context, d);
}

/// Where "Try it" goes: the checked link, else the AI's guess.
String? toolUrl(Json tool) {
  final v = (tool['verified'] as Map?) ?? const {};
  return (v['url'] ?? tool['url_guess']) as String?;
}

/// Where "View product" goes: the affiliate link when one is configured, else the link from
/// the video, else a search for it.
String? productUrl(Json p) =>
    p['affiliate_url'] as String? ??
    ((p['verified'] as Map?)?['url'] as String?) ??
    p['url_guess'] as String? ??
    (p['name'] == null
        ? null
        : webSearch('${p['brand'] ?? ''} ${p['name']}'.trim()));

/// The share sheet's activities per category (beyond a plain share).
const _activities = {
  'places': ('plan', 'Plan a visit', 'Pick a time; the group RSVPs.'),
  'recipe': (
    'cook',
    'Cook it together',
    'Set a time; everyone can share a photo.'
  ),
  'workout': (
    'challenge',
    'Challenge the group',
    'Everyone joins and posts proof.'
  ),
};

/// Shares a discovery into a group: pick the group, optionally make it a plan, a cook-along or
/// a challenge with a time, add a line, send. The group gets its own copy.
Future<void> shareToGroup(BuildContext context, Discovery d,
    {String? kind, String? groupId}) async {
  final s = Repo.instance.now;
  if (s.groups.isEmpty) {
    toast(context, 'Create a group first: Groups › New group');
    return;
  }
  await showRbSheet<void>(context,
      title: 'Share to a group',
      kicker: d.title,
      builder: (sheet) => _ShareSheet(
          d: d, groups: s.groups, initialKind: kind, initialGroup: groupId));
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet(
      {required this.d,
      required this.groups,
      this.initialKind,
      this.initialGroup});
  final Discovery d;
  final List<GroupInfo> groups;
  final String? initialKind, initialGroup;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late String _group = widget.initialGroup ??
      (widget.groups.where((g) => g.isDefault).firstOrNull ??
              widget.groups.first)
          .id;
  late String _kind = widget.initialKind ?? 'share';
  DateTime? _when;
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final start = _when ?? DateTime(now.year, now.month, now.day + 1, 19);
    final day = await showDatePicker(
        context: context,
        initialDate: start,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 365)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(start));
    if (time == null) return;
    setState(() =>
        _when = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      await Repo.instance.share(widget.d, _group,
          kind: _kind,
          when: _kind == 'share' ? null : _when,
          text: _text.text.trim());
      final root = nav.context;
      if (!mounted || !root.mounted) return;
      final g = widget.groups.firstWhere((g) => g.id == _group);
      nav.pop();
      toast(root, 'Shared with ${g.name}',
          action: 'Open', onAction: () => openGroup(root, g.id));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is StateError ? e.message : apiError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final activity = _activities[widget.d.section];
    final needsWhen = _kind != 'share';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const MonoLabel('Group'),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 2, children: [
          for (final g in widget.groups)
            FilterPill(
                label: g.name,
                selected: _group == g.id,
                onTap: () => setState(() => _group = g.id),
                glyph: Glyphs.groups),
        ]),
        if (activity != null) ...[
          const SizedBox(height: 14),
          const MonoLabel('As'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 2, children: [
            FilterPill(
                label: 'Just share',
                selected: _kind == 'share',
                onTap: () => setState(() => _kind = 'share')),
            FilterPill(
                label: activity.$2,
                selected: _kind == activity.$1,
                onTap: () => setState(() => _kind = activity.$1)),
          ]),
          if (needsWhen) ...[
            const SizedBox(height: 4),
            Text(activity.$3, style: t.bodySmall),
            const SizedBox(height: 10),
            Pressable(
              onTap: _pickWhen,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(RbSpace.cardRadius)),
                child: Row(children: [
                  Icon(Icons.event_outlined, color: c.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        _when == null
                            ? (_kind == 'challenge'
                                ? 'Finish by…'
                                : 'Pick a day and time')
                            : when(_when!),
                        style: t.bodyLarge),
                  ),
                  Icon(Icons.chevron_right, color: c.faint),
                ]),
              ),
            ),
          ],
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _text,
          maxLength: 280,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Add a line (optional)', counterText: ''),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: t.bodySmall?.copyWith(color: c.falseFg)),
        ],
        const SizedBox(height: 16),
        RbButton(
          _kind == 'share' ? 'Share' : 'Share and invite',
          expand: true,
          glyph: Glyphs.groups,
          busy: _busy,
          onPressed: needsWhen && _when == null ? null : _send,
        ),
      ]),
    );
  }
}
