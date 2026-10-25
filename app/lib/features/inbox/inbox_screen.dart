import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/surface.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets.dart';
import '../feed/feed_screen.dart';
import '../feed/lanes.dart' show FrameImage;
import '../save/save_screen.dart';

/// Saves that need you (P1-07): unsure, caption-only or failed.
const inboxStatuses = {'needs_review', 'partial', 'failed'};

bool inInbox(Map<String, dynamic> save) =>
    inboxStatuses.contains(save['status']);

/// Files a save under a section: the backend logs the correction and re-reads the video.
Future<void> fileUnder(
        BuildContext context, Map<String, dynamic> save, String section) =>
    _run(
        context,
        () => api('POST', '/v1/saves/${save['save_id']}/section',
            {'section': section}),
        section == 'none'
            ? 'Kept as a plain save'
            : 'Re-reading it as ${sectionLabels[section]}');

Future<void> retrySave(BuildContext context, Map<String, dynamic> save) => _run(
    context,
    () => api('POST', '/v1/saves/${save['save_id']}/retry'),
    'Trying again');

Future<void> _run(
    BuildContext context, Future<Object?> Function() call, String done) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await call();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(apiError(e))));
  }
}

/// Live list from the feed (no second Firestore subscription).
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key, required this.saves, required this.spaceLabel});
  final ValueListenable<List<Map<String, dynamic>>> saves;
  final String Function(String spaceId) spaceLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: saves,
        builder: (context, list, _) =>
            InboxList(saves: list, spaceLabel: spaceLabel),
      ),
    );
  }
}

/// Statuses of a save still on its way in (design v4: Processing, then Understanding).
const arrivingStatuses = {
  'received',
  'uploaded',
  'fetching',
  'extracting',
  'enriching'
};

/// Everything in the Inbox: saves still arriving, and saves that need you.
bool inInboxList(Map<String, dynamic> save) =>
    inInbox(save) || arrivingStatuses.contains(save['status']);

const _videoPlatforms = {'tiktok', 'instagram', 'youtube', 'facebook'};

const platformLabels = {
  'tiktok': 'TikTok',
  'instagram': 'Instagram',
  'youtube': 'YouTube',
  'facebook': 'Facebook',
};

/// The Inbox as a processing queue (design v4 revision 2): one compact row per save with its
/// source, kind and status, filtered by All · Videos · Links.
class InboxList extends StatefulWidget {
  const InboxList({super.key, required this.saves, required this.spaceLabel});
  final List<Map<String, dynamic>> saves;
  final String Function(String spaceId) spaceLabel;

  @override
  State<InboxList> createState() => _InboxListState();
}

class _InboxListState extends State<InboxList> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (widget.saves.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(RbSpace.side),
        child: Text(
            'Nothing to sort. Everything you share passes through here while it is understood; '
            'saves the AI was unsure about, or could not fully read, stay until you file them.',
            style: t.bodyMedium),
      );
    }
    bool video(Map<String, dynamic> s) =>
        _videoPlatforms.contains(s['platform']);
    final shown = [
      for (final s in widget.saves)
        if (_filter == 'all' || (_filter == 'videos') == video(s)) s
    ];
    return ListView(
      padding:
          const EdgeInsets.symmetric(horizontal: RbSpace.side, vertical: 8),
      children: [
        Wrap(spacing: 8, children: [
          for (final (id, label) in const [
            ('all', 'All'),
            ('videos', 'Videos'),
            ('links', 'Links')
          ])
            ChoiceChip(
              label: Text(label),
              selected: _filter == id,
              showCheckmark: false,
              onSelected: (_) => setState(() => _filter = id),
            ),
        ]),
        const SizedBox(height: 12),
        for (final s in shown)
          _Row(
              save: s,
              space: widget.spaceLabel(s['space_id'] as String? ?? '')),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.save, required this.space});
  final Map<String, dynamic> save;
  final String space;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final status = save['status'] as String? ?? 'received';
    final arriving = arrivingStatuses.contains(status);
    final platform = save['platform'] as String?;
    final video = _videoPlatforms.contains(platform);
    final secs = (save['duration_s'] as num?)?.round();
    final source = save['source_url'] as String? ?? '';
    final title = save['summary'] as String? ??
        (Uri.tryParse(source)?.host.replaceFirst('www.', '') ?? source);
    final (statusText, statusColor) = switch (status) {
      'needs_review' => ('Needs a section', c.mixedFg),
      'partial' => ('Caption only', c.muted),
      'failed' => ('Failed', c.falseFg),
      'enriching' => ('Understanding…', c.muted),
      _ => (save['step_text'] as String? ?? 'Processing…', c.muted),
    };
    final saveId = save['save_id'] as String?,
        spaceId = save['space_id'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: arriving
            ? (saveId == null || spaceId == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SaveScreen(
                        spaceId: spaceId, saveId: saveId, initial: save))))
            : () => _sort(context, save),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(RbSpace.panelRadius),
            border: Border.all(color: c.line),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: save['key_frame_url'] != null
                    ? FrameImage(save: save)
                    : ColoredBox(
                        color: c.raised,
                        child: Icon(
                            video ? Icons.play_circle_outline : Icons.link,
                            color: c.muted,
                            size: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                        [
                          platformLabels[platform] ?? platform ?? 'Link',
                          space,
                          if (secs != null)
                            secs < 60 ? '${secs}s' : '${secs ~/ 60}m',
                        ].join(' · '),
                        style: t.bodySmall),
                  ]),
            ),
            const SizedBox(width: 8),
            if (arriving) ...[
              SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: c.muted)),
              const SizedBox(width: 6),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium?.copyWith(color: statusColor)),
            ),
            if (!arriving) Icon(Icons.chevron_right, size: 18, color: c.faint),
          ]),
        ),
      ),
    );
  }
}

/// What a save that needs you can do: file it under a section, or retry (failed ones can only
/// retry).
Future<void> _sort(BuildContext context, Map<String, dynamic> save) async {
  final failed = save['status'] == 'failed';
  final choice = await showRbSheet<String>(context,
      title: failed ? 'This save failed' : 'File this under',
      children: [
        if (failed)
          ListTile(
              dense: true,
              title: Text('${save['step_text'] ?? 'Something went wrong.'}')),
        if (!failed) ...[
          for (final e in sectionLabels.entries)
            ListTile(
              leading: Icon(sectionIcons[e.key]),
              title: Text(e.value),
              onTap: () => Navigator.pop(context, e.key),
            ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('None of these'),
            subtitle: const Text('Keep it as a plain save'),
            onTap: () => Navigator.pop(context, 'none'),
          ),
        ],
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Retry'),
          onTap: () => Navigator.pop(context, 'retry'),
        ),
        const SizedBox(height: 8),
      ]);
  if (choice == null || !context.mounted) return;
  if (choice == 'retry') {
    await retrySave(context, save);
  } else {
    await fileUnder(context, save, choice);
  }
}
