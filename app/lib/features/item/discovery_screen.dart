import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/art/glyphs.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../shared/open.dart';
import '../shared/tiles.dart';
import 'actions.dart';
import 'bodies.dart';

/// A discovery's page: the specimen sheet. Frame, catalogue label and title; why you saved it;
/// the category's own content; doing it with a group; where it came from; related ones. The
/// stamp and the main action sit in a bar at thumb height.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key, required this.discoveryKey, this.within})
      : saveId = null;
  const DiscoveryScreen.forSave({super.key, required String this.saveId})
      : discoveryKey = null,
        within = null;

  final String? discoveryKey, saveId;
  final List<Discovery>? within;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  bool _marked = false;

  Discovery? _find(BrainState s) {
    if (widget.discoveryKey != null) return s.find(widget.discoveryKey!);
    final list = s.forSave(widget.saveId!);
    return list.isEmpty ? null : list.first;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrainState>(
      valueListenable: Repo.instance.state,
      builder: (context, s, _) {
        final d = _find(s);
        if (d == null) {
          return _Missing(
              state: s,
              saveId: widget.saveId ?? widget.discoveryKey!.split('/').first);
        }
        if (!_marked) {
          _marked = true;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Repo.instance.markSeen(d).ignore());
        }
        return _Page(d: d, state: s, within: widget.within);
      },
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.d, required this.state, this.within});
  final Discovery d;
  final BrainState state;
  final List<Discovery>? within;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final heroH = (width * 1.05).clamp(300.0, 520.0);
    final why = d.note ?? d.goodFor;
    final related = [
      for (final o in state.inCategory(d.section))
        if (o.key != d.key) o
    ].take(8).toList();
    final group = state.group(d.spaceId);
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: heroH,
          backgroundColor: c.ground,
          automaticallyImplyLeading: false,
          leading: PhotoIconButton(
              icon: Icons.arrow_back,
              label: 'Back',
              onTap: () => Navigator.of(context).maybePop()),
          actions: [
            PhotoIconButton(
                icon: Icons.ios_share,
                label: 'Share',
                onTap: () => _share(context)),
            PhotoIconButton(
                icon: Icons.more_horiz,
                label: 'More',
                onTap: () => _more(context)),
            const SizedBox(width: 6),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            stretchModes: const [StretchMode.zoomBackground],
            background: Stack(fit: StackFit.expand, children: [
              DiscoveryArt(d),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.22, 0.7, 1],
                    colors: [
                      Color(0x99000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x55000000)
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: RbSpace.column),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    RbSpace.side, 18, RbSpace.side, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CatalogLabel(d),
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        child: Text(d.title,
                            style: RbType.serif(30, color: c.text)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          [
                            'From ${platformName(d.platform)}',
                            if (d.creator != null) d.creator!,
                            'saved ${ago(d.createdAt)}',
                            if (group != null) 'in ${group.name}',
                          ].join(' · '),
                          style: t.bodySmall),
                      if (_facts(d).isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(spacing: 6, runSpacing: 6, children: _facts(d)),
                      ],
                      if (d.isPartial) ...[
                        const SizedBox(height: 14),
                        _Flag(
                            text:
                                'Caption only: the video couldn’t be fetched, so this is from the caption.',
                            action: 'Try again',
                            onAction: () => Repo.instance.retry(d.save)),
                      ],
                      if (d.title != d.summary && d.summary.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(d.summary,
                            style: t.bodyLarge?.copyWith(color: c.muted)),
                      ],
                      _Why(d: d, why: why),
                      const SizedBox(height: 4),
                      DiscoveryBody(d),
                      for (final sib in d.siblings)
                        if (isKnownCategory(sib['section'] as String?)) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 32, bottom: 4),
                            child: Rule(
                                label:
                                    'Also in this reel · ${categoryOf(sib['section'] as String?).name}'),
                          ),
                          DiscoveryBody(
                              Discovery(sib, d.save, number: d.number)),
                        ],
                      if (state.groups.isNotEmpty) ...[
                        BodyHeading('Do it together', kicker: 'Groups'),
                        _Together(d: d),
                      ],
                      if (d.sourceUrl != null) ...[
                        BodyHeading('Where it came from', kicker: 'Source'),
                        Pressable(
                          onTap: () => openUrl(context, d.sourceUrl!),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: c.line),
                              borderRadius:
                                  BorderRadius.circular(RbSpace.cardRadius),
                            ),
                            child: Row(children: [
                              Icon(Icons.play_circle_outline, color: c.text),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Watch the original on ${platformName(d.platform)}',
                                          style: t.titleSmall),
                                      Text(
                                          d.creator ??
                                              Uri.tryParse(d.sourceUrl!)
                                                  ?.host ??
                                              '',
                                          style: t.bodySmall),
                                    ]),
                              ),
                              Icon(Icons.north_east, size: 18, color: c.muted),
                            ]),
                          ),
                        ),
                      ],
                    ]),
              ),
            ),
          ),
        ),
        if (related.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShelfHeader(
                        title: 'More ${d.category.name.toLowerCase()}',
                        action: 'All',
                        onAction: () => openCategory(context, d.section)),
                    SizedBox(
                      height: 250,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: RbSpace.side),
                        itemCount: related.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => DiscoveryTile(related[i],
                            within: related, width: 136),
                      ),
                    ),
                  ]),
            ),
          ),
      ]),
      bottomNavigationBar: _ActionBar(d: d, within: within),
    );
  }

  static List<Widget> _facts(Discovery d) {
    final data = d.data;
    final out = <Widget>[];
    if (d.effortMin != null) {
      out.add(FactChip('${d.effortMin} min', icon: Icons.schedule));
    }
    if (d.difficulty != null) {
      out.add(FactChip(
          '${d.difficulty![0].toUpperCase()}${d.difficulty!.substring(1)}',
          icon: Icons.signal_cellular_alt));
    }
    if (d.section == 'recipe' && data['servings'] != null) {
      out.add(
          FactChip('Serves ${data['servings']}', icon: Icons.people_outline));
    }
    if (d.section == 'fact_check' && d.verdict != null) {
      out.add(VerdictPill(d.verdict!));
    }
    return out;
  }

  void _share(BuildContext context) => shareOut([
        d.title,
        if (d.summary != d.title) d.summary,
        d.sourceUrl
      ].whereType<String>().join('\n'));

  Future<void> _more(BuildContext context) async {
    final choice = await showRbSheet<String>(context,
        title: d.title,
        kicker: catalogueNo(d.number),
        builder: (sheet) => Column(children: [
              if (within != null && within!.length > 1)
                SheetRow(
                    title: 'Browse this list',
                    subtitle: 'Swipe through ${within!.length} discoveries',
                    glyph: Glyphs.browse,
                    onTap: () => Navigator.pop(sheet, 'browse')),
              SheetRow(
                  title: 'File under another category',
                  subtitle: 'Realbrain reads it again for that category',
                  icon: Icons.drive_file_move_outline,
                  onTap: () => Navigator.pop(sheet, 'file')),
              if (d.sourceUrl != null)
                SheetRow(
                    title: 'Copy the link',
                    icon: Icons.link,
                    onTap: () => Navigator.pop(sheet, 'copy')),
              SheetRow(
                  title: 'Details',
                  icon: Icons.info_outline,
                  onTap: () => Navigator.pop(sheet, 'details')),
              if (!d.isArchived)
                SheetRow(
                    title: 'Archive',
                    subtitle: 'Out of Today and Recall; still in your library',
                    icon: Icons.archive_outlined,
                    onTap: () => Navigator.pop(sheet, 'archive')),
            ]));
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'browse':
        final i = within!.indexWhere((o) => o.key == d.key);
        await openViewer(context, within!, start: i < 0 ? 0 : i);
      case 'file':
        await fileUnderSheet(context, d.save);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: d.sourceUrl!));
        if (context.mounted) toast(context, 'Link copied');
      case 'details':
        await showRbSheet<void>(context,
            title: 'Details', builder: (_) => _Details(d: d));
      case 'archive':
        await Repo.instance.archive(d);
        if (context.mounted) toast(context, 'Archived. Still in your library.');
    }
  }
}

/// Re-file a save: a category re-reads the video with that hint; "None" keeps it plain.
Future<void> fileUnderSheet(BuildContext context, Json save) async {
  final current = (save['sections'] as List?)?.cast<String>() ?? const [];
  final section = await showRbSheet<String>(context,
      title: 'File it under',
      kicker: 'Realbrain reads it again for that category',
      builder: (sheet) => Column(children: [
            for (final cat in categories)
              SheetRow(
                title: cat.name,
                glyph: cat.id,
                glyphColor: RbColors.of(sheet).pigment(cat.id),
                trailing: current.contains(cat.id)
                    ? Icon(Icons.check, color: RbColors.of(sheet).brandText)
                    : null,
                onTap: () => Navigator.pop(sheet, cat.id),
              ),
            SheetRow(
              title: 'None of these',
              subtitle: 'Keep it as a plain save',
              glyph: Glyphs.bookmark,
              onTap: () => Navigator.pop(sheet, 'none'),
            ),
          ]));
  if (section == null || !context.mounted) return;
  try {
    await Repo.instance.fileUnder(save, section);
    if (context.mounted) {
      toast(
          context,
          section == 'none'
              ? 'Kept as a plain save'
              : 'Reading it again as ${categoryOf(section).noun}');
    }
  } catch (e) {
    if (context.mounted) toast(context, apiError(e));
  }
}

class _Why extends StatelessWidget {
  const _Why({required this.d, required this.why});
  final Discovery d;
  final String? why;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final mine = d.note != null;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Semantics(
        button: true,
        label: why == null
            ? 'Add why you saved this'
            : 'Why you saved this: $why. Edit',
        excludeSemantics: true,
        child: Pressable(
          onTap: () => _edit(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(RbSpace.cardRadius),
              border: Border.all(color: c.line),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Glyph(Glyphs.quote, size: 20, color: c.brandText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoLabel(mine || why == null
                          ? 'Why you saved this'
                          : 'Why you might have saved this'),
                      const SizedBox(height: 4),
                      Text(why ?? 'Add a line in your own words',
                          style: RbType.serif(17,
                              color: why == null ? c.faint : c.text,
                              italic: true,
                              height: 1.3)),
                      if (!mine && why != null) ...[
                        const SizedBox(height: 4),
                        Text('Realbrain’s guess · tap to put it in your words',
                            style: t.bodySmall),
                      ],
                    ]),
              ),
              Icon(Icons.edit_outlined, size: 18, color: c.faint),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final field = TextEditingController(text: d.note ?? '');
    final text = await showRbSheet<String>(context,
        title: 'Why you saved this',
        builder: (sheet) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
              child: Column(children: [
                TextField(
                  controller: field,
                  autofocus: true,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 5,
                  decoration:
                      InputDecoration(hintText: d.goodFor ?? 'In your words'),
                ),
                const SizedBox(height: 8),
                RbButton('Save',
                    expand: true,
                    onPressed: () => Navigator.pop(sheet, field.text.trim())),
              ]),
            ));
    field.dispose();
    if (text != null) {
      await Repo.instance.setNote(d.save, text.isEmpty ? null : text);
    }
  }
}

class _Together extends StatelessWidget {
  const _Together({required this.d});
  final Discovery d;

  @override
  Widget build(BuildContext context) {
    final (kind, label) = switch (d.section) {
      'places' => ('plan', 'Plan a visit'),
      'recipe' => ('cook', 'Cook it together'),
      'workout' => ('challenge', 'Challenge the group'),
      _ => ('share', 'Share to a group'),
    };
    return Wrap(spacing: 8, runSpacing: 4, children: [
      RbButton.secondary(label,
          glyph: Glyphs.groups,
          small: true,
          onPressed: () => shareToGroup(context, d, kind: kind)),
      if (kind != 'share')
        RbButton.quiet('Just share',
            small: true, onPressed: () => shareToGroup(context, d)),
    ]);
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
          color: c.mixedBg,
          borderRadius: BorderRadius.circular(RbSpace.cardRadius)),
      child: Row(children: [
        Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: c.text))),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.d});
  final Discovery d;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = [
      ('Number', catalogueNo(d.number)),
      ('Category', d.category.name),
      ('Status', d.stamp.label),
      if (d.effortMin != null) ('Time', '${d.effortMin} minutes'),
      if (d.difficulty != null) ('Difficulty', d.difficulty!),
      if (d.goodFor != null) ('Good for', d.goodFor!),
      if (d.topics.isNotEmpty) ('Topics', d.topics.join(', ')),
      if (d.save['language'] != null) ('Language', '${d.save['language']}'),
      (
        'Saved',
        '${dayMonth(fromEpoch(d.createdAt))} ${fromEpoch(d.createdAt).year}'
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
      child: Column(children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 100, child: MonoLabel(k)),
              Expanded(child: Text(v, style: t.bodyMedium)),
            ]),
          ),
      ]),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.d, this.within});
  final Discovery d;
  final List<Discovery>? within;

  /// On its own page, a fact check's next step is the explainer and an idea's is passing it on;
  /// everything else keeps its category action.
  Widget _primary(BuildContext context) {
    if (d.section == 'fact_check') {
      final has = d.data['explainer'] != null;
      return RbButton(has ? 'Share the verdict' : 'Dive deeper', expand: true,
          onPressed: () async {
        if (has) {
          await shareOut(
              '${d.title}: ${verdictLabels[d.verdict] ?? ''}\n${d.sourceUrl ?? ''}'
                  .trim());
          return;
        }
        try {
          await Repo.instance.deepDive(d.save);
          if (context.mounted) {
            toast(
                context, 'Writing the explainer. It appears here when ready.');
          }
        } catch (e) {
          if (context.mounted) toast(context, apiError(e));
        }
      });
    }
    if (d.section == 'ideas') {
      return RbButton('Share it',
          expand: true,
          icon: Icons.ios_share,
          onPressed: () => shareOut(
              [d.title, d.data['idea']].whereType<String>().join('\n')));
    }
    return RbButton(d.action,
        expand: true, onPressed: () => primaryAction(context, d));
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
          color: c.ground, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RbSpace.side, 8, RbSpace.side, 8),
          child: Row(children: [
            StampButton(d, large: true),
            const SizedBox(width: 12),
            Expanded(child: _primary(context)),
          ]),
        ),
      ),
    );
  }
}

/// A save that isn't readable (yet): still arriving, needs a category, failed, or gone.
class _Missing extends StatelessWidget {
  const _Missing({required this.state, required this.saveId});
  final BrainState state;
  final String saveId;

  @override
  Widget build(BuildContext context) {
    final save = state.saves.where((s) => s['save_id'] == saveId).firstOrNull;
    Widget body;
    if (save == null) {
      body = state.loaded
          ? const EmptyState(
              title: 'This discovery is gone',
              body: 'It may have been removed from its group.')
          : const LoadingMark();
    } else if (processingStatuses.contains(save['status'])) {
      body = LoadingMark(
          text: '${save['step_text'] ?? 'Understanding'}…', size: 72);
    } else if (save['status'] == 'failed') {
      body = EmptyState(
        title: 'This one didn’t come through',
        body:
            '${save['step_text'] ?? 'Something went wrong while reading it.'}',
        action: 'Try again',
        onAction: () => Repo.instance.retry(save),
      );
    } else {
      body = EmptyState(
        title: 'Realbrain wasn’t sure what this is',
        body: 'Tell it which category fits and it reads the video again.',
        action: 'Choose a category',
        onAction: () => fileUnderSheet(context, save),
      );
    }
    return Scaffold(
        appBar: AppBar(),
        body: Center(child: SingleChildScrollView(child: body)));
  }
}
