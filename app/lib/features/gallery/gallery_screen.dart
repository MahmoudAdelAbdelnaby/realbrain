import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/art/hoopoe.dart';
import '../../core/art/mark.dart';
import '../../core/art/puzzle.dart';
import '../../core/categories.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../item/bodies.dart' show VerdictPill;

/// The design system on one page (docs/DESIGN_V5.md §2.7): mark, Hudhud, colour, type, glyphs,
/// components and the puzzle, in either theme and direction.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  Brightness? _b;
  bool _rtl = false;

  @override
  Widget build(BuildContext context) {
    final b = _b ?? Theme.of(context).brightness;
    return Theme(
      data: rbTheme(b),
      child: Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Builder(builder: (context) {
          final c = RbColors.of(context);
          final t = Theme.of(context).textTheme;
          Widget h(String kicker, String title) => Padding(
                padding: const EdgeInsets.only(top: 36, bottom: 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoLabel(kicker, color: c.brandText),
                      const SizedBox(height: 4),
                      Text(title, style: RbType.serif(24, color: c.text)),
                    ]),
              );
          return Scaffold(
            backgroundColor: c.ground,
            appBar: AppBar(title: const Text('Design system'), actions: [
              IconButton(
                tooltip: 'Flip theme',
                icon: Icon(b == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () => setState(() => _b =
                    b == Brightness.dark ? Brightness.light : Brightness.dark),
              ),
              IconButton(
                tooltip: 'Flip direction',
                icon: const Icon(Icons.format_textdirection_r_to_l),
                onPressed: () => setState(() => _rtl = !_rtl),
              ),
            ]),
            body: ListView(
                padding: const EdgeInsets.fromLTRB(
                    RbSpace.side, 0, RbSpace.side, 48),
                children: [
                  Text('The Curiosity Archive',
                      style: RbType.serif(RbType.hero, color: c.text)),
                  const SizedBox(height: 6),
                  Text(
                      'A modern natural-history editorial: ink and paper, one saffron piece, a pigment per kind of discovery.',
                      style: t.bodyMedium?.copyWith(color: c.muted)),
                  h('01 · Mark', 'The brain and the piece'),
                  Wrap(
                      spacing: 20,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: const [
                        BrainMark(size: 132, lifted: true),
                        BrainMark(size: 96),
                        BrainMark(size: 56),
                        BrainMark(size: 32),
                        BrainMark(size: 24),
                        BrainMark(size: 56, motion: MarkMotion.thinking),
                      ]),
                  const SizedBox(height: 16),
                  const Wordmark(size: 26),
                  h('02 · Mascot', 'Hudhud, the scout'),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final p in HudhudPose.values)
                      Plate(
                        caption: p.name,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Hudhud(width: 140, pose: p),
                      ),
                  ]),
                  h('03 · Colour', 'Ink, paper and pigments'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in c.all.entries)
                      Container(
                        width: 100,
                        height: 62,
                        padding: const EdgeInsets.all(6),
                        alignment: AlignmentDirectional.bottomStart,
                        decoration: BoxDecoration(
                          color: e.value,
                          border: Border.all(color: c.line),
                          borderRadius:
                              BorderRadius.circular(RbSpace.tagRadius),
                        ),
                        child: Text(e.key,
                            style: RbType.label(
                                color: e.value.computeLuminance() > 0.4
                                    ? const Color(0xFF1A1714)
                                    : const Color(0xFFF2ECE1),
                                size: 9.5)),
                      ),
                  ]),
                  h('04 · Type', 'Fraunces, Plex Sans, Plex Mono'),
                  Text('Hero 34 · Good evening, Mahmoud.',
                      style: RbType.serif(34, color: c.text)),
                  Text('Title 28 · The archive',
                      style: RbType.serif(28, color: c.text)),
                  Text('Card 22 · Molokhia with garlic tasha',
                      style: RbType.serif(22, color: c.text)),
                  Text('Voice · A 25-minute dinner you saved yesterday.',
                      style: RbType.serif(18, color: c.muted, italic: true)),
                  const SizedBox(height: 8),
                  Text(
                      'Body 15 · Plex Sans for everything you read and tap. ملوخية بالتقلية',
                      style: t.bodyMedium),
                  const SizedBox(height: 4),
                  const MonoLabel('Label 11 · No. 0142 · Recipe · TikTok'),
                  Text('ملوخية بالتقلية على الطريقة البطيئة',
                      style: RbType.serif(26, color: c.text)),
                  h('05 · Glyphs', 'Categories and navigation'),
                  Wrap(spacing: 18, runSpacing: 18, children: [
                    for (final e in Glyphs.all.entries)
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Glyph(e.value,
                            size: 30, color: c.pigments[e.key] ?? c.text),
                        const SizedBox(height: 4),
                        MonoLabel(e.key, size: 8.5),
                      ]),
                  ]),
                  h('06 · Components', 'Buttons, stamps, labels'),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RbButton('Cook it', onPressed: () {}),
                        RbButton.secondary('Plan a visit',
                            glyph: Glyphs.groups, onPressed: () {}),
                        RbButton.quiet('Not now', onPressed: () {}),
                        RbButton('Disabled', onPressed: null),
                        RbButton('Small', small: true, onPressed: () {}),
                      ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilterPill(label: 'Open', selected: true, onTap: () {}),
                    FilterPill(
                        label: 'Finished',
                        selected: false,
                        onTap: () {},
                        count: 14),
                    FilterPill(
                        label: 'Recipes',
                        glyph: 'recipe',
                        selected: false,
                        onTap: () {}),
                    const FactChip('25 min', icon: Icons.schedule),
                    const VerdictPill('mostly_true'),
                    const VerdictPill('false'),
                    const VerdictPill('mixed'),
                  ]),
                  const SizedBox(height: 14),
                  const ShelfHeader(
                      index: '01',
                      title: 'Left off',
                      caption: 'A shelf header',
                      action: 'All',
                      padding: EdgeInsets.zero),
                  h('07 · Specimens', 'When there is no frame'),
                  SizedBox(
                    height: 200,
                    child:
                        ListView(scrollDirection: Axis.horizontal, children: [
                      for (final cat in categories) ...[
                        SizedBox(
                          width: 150,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(RbSpace.photoRadius),
                            child: SpecimenCard(
                                section: cat.id,
                                title: cat.id == 'entertainment'
                                    ? 'Severance'
                                    : cat.name,
                                number: 142),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ]),
                  ),
                  h('08 · My Brain', 'The puzzle, filling'),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final (n, placed) in const [
                      (9, 0),
                      (16, 6),
                      (25, 18),
                      (36, 36)
                    ])
                      PuzzleBrain(
                        count: n,
                        size: 150,
                        placed: [
                          for (var i = 0; i < placed; i++)
                            c.pigment(categories[i % categories.length].id)
                        ],
                        found: placed == n ? 0 : 3,
                      ),
                  ]),
                ]),
          );
        }),
      ),
    );
  }
}
