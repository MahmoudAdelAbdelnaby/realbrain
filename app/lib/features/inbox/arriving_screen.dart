import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/art/hoopoe.dart';
import '../../core/art/mark.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../shared/open.dart';

/// The processing queue (was Inbox): what's being understood right now, step by step, and what
/// needs you: a one-tap category for unsure saves, retry for failed ones.
class ArrivingScreen extends StatelessWidget {
  const ArrivingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrainState>(
      valueListenable: Repo.instance.state,
      builder: (context, s, _) {
        final busy = s.processing, needs = s.attention;
        return Scaffold(
          appBar: AppBar(title: const Text('Arriving')),
          body: busy.isEmpty && needs.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      title: 'Nothing arriving',
                      body:
                          'Everything you share passes through here while Realbrain reads it. '
                          'It usually takes under a minute.',
                      pose: HudhudPose.perched,
                    ),
                  ),
                )
              : ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                  if (needs.isNotEmpty) ...[
                    ShelfHeader(
                        index: count(needs.length, 'save'),
                        title: 'Need you',
                        caption: 'One tap and Realbrain reads it again.'),
                    for (final save in needs) _NeedsYou(save: save),
                    const SizedBox(height: 20),
                  ],
                  if (busy.isNotEmpty) ...[
                    ShelfHeader(
                        index: count(busy.length, 'save'),
                        title: 'Being understood'),
                    for (final save in busy) _Working(save: save),
                  ],
                ]),
        );
      },
    );
  }
}

const _stages = ['Received', 'Getting the video', 'Watching', 'Checking'];

int _stage(String? status) => switch (status) {
      'fetching' => 1,
      'extracting' => 2,
      'enriching' => 3,
      _ => 0,
    };

String _what(Json save) {
  final url = save['source_url'] as String?;
  return save['summary'] as String? ??
      (save['platform'] == 'idea'
          ? '“${(save['caption'] as String? ?? 'An idea').split('\n').first}”'
          : Uri.tryParse(url ?? '')?.host.replaceFirst('www.', '') ?? 'A save');
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.save, this.working = false});
  final Json save;
  final bool working;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(RbSpace.photoRadius),
      child: SizedBox(
        width: 52,
        height: 64,
        child: FrameImage(
          stored: save['key_frame_url'] as String?,
          fallback: ColoredBox(
            color: c.raised,
            child: Center(
                child: working
                    ? const BrainMark(size: 34, motion: MarkMotion.thinking)
                    : Glyph(
                        save['platform'] == 'idea'
                            ? Glyphs.ideas
                            : Glyphs.bookmark,
                        color: c.faint)),
          ),
        ),
      ),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.save});
  final Json save;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final stage = _stage(save['status'] as String?);
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: RbSpace.side, vertical: 10),
      child: Row(children: [
        _Thumb(save: save, working: true),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MonoLabel([
              platformName(save['platform'] as String?),
              ago((save['created_at'] ?? 0) as num)
            ].join(' · ')),
            const SizedBox(height: 4),
            Text(_what(save),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 0; i < _stages.length; i++)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsetsDirectional.only(end: 3),
                    decoration: BoxDecoration(
                      color: i <= stage ? c.brand : c.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 5),
            Text('${save['step_text'] ?? _stages[stage]}…', style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

class _NeedsYou extends StatelessWidget {
  const _NeedsYou({required this.save});
  final Json save;

  Future<void> _run(
      BuildContext context, Future<void> Function() call, String done) async {
    try {
      await call();
      if (context.mounted) toast(context, done);
    } catch (e) {
      if (context.mounted) toast(context, apiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final failed = save['status'] == 'failed';
    return Container(
      margin: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Thumb(save: save),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MonoLabel(
                  failed ? 'Didn’t come through' : 'Not sure what this is',
                  color: failed ? c.falseFg : c.brandText),
              const SizedBox(height: 4),
              Text(_what(save),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall),
              if (failed) ...[
                const SizedBox(height: 4),
                Text(_friendly(save['step_text'] as String?),
                    style: t.bodySmall),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        if (!failed) ...[
          Text('What is it?', style: t.bodySmall),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final id in hintOrder) ...[
                FilterPill(
                  label: categoryOf(id).noun[0].toUpperCase() +
                      categoryOf(id).noun.substring(1),
                  glyph: id,
                  selected: false,
                  onTap: () => _run(
                      context,
                      () => Repo.instance.fileUnder(save, id),
                      'Reading it again as ${categoryOf(id).noun}'),
                ),
                const SizedBox(width: 6),
              ],
              FilterPill(
                label: 'Just keep it',
                selected: false,
                onTap: () => _run(
                    context,
                    () => Repo.instance.fileUnder(save, 'none'),
                    'Kept as a plain save'),
              ),
            ]),
          ),
        ],
        Row(children: [
          if (save['source_url'] != null)
            TextButton(
                onPressed: () => openSave(context, save['save_id'] as String),
                child: const Text('Details')),
          const Spacer(),
          RbButton.quiet('Try again',
              small: true,
              icon: Icons.refresh,
              onPressed: () => _run(
                  context, () => Repo.instance.retry(save), 'Trying again')),
        ]),
      ]),
    );
  }

  /// Backend errors in plain words.
  static String _friendly(String? raw) {
    final r = (raw ?? '').toLowerCase();
    if (r.contains('no video or caption')) {
      return 'The video was private or removed, and there was no caption to read.';
    }
    if (r.contains('busy') || r.contains('quota') || r.contains('503')) {
      return 'The AI was busy. Trying again usually works.';
    }
    return raw == null || raw.isEmpty
        ? 'Something went wrong while reading it.'
        : raw;
  }
}
