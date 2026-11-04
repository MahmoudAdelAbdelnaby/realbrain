import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/art/glyphs.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../brain/progress.dart';
import 'open.dart';

/// "◆ NO. 0142 · RECIPE · TIKTOK": the catalogue line every discovery carries.
class CatalogLabel extends StatelessWidget {
  const CatalogLabel(this.d,
      {super.key,
      this.source = true,
      this.onPhoto = false,
      this.number = true});
  final Discovery d;
  final bool source, onPhoto, number;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final pigment = onPhoto ? Colors.white : c.pigment(d.section);
    final text = [
      if (number && d.number > 0) catalogueNo(d.number),
      d.noun,
      if (source && d.platform != null && d.platform != 'other')
        platformName(d.platform),
    ].join(' · ');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Glyph(d.glyph, size: 14, color: pigment, weight: 1.9),
      const SizedBox(width: 6),
      Flexible(
        child: MonoLabel(text,
            color: onPhoto ? Colors.white.withValues(alpha: 0.92) : c.faint,
            size: 10.5),
      ),
    ]);
  }
}

/// A compact discovery row: frame, label, title, detail, and its stamp state.
class DiscoveryRow extends StatelessWidget {
  const DiscoveryRow(this.d,
      {super.key, this.within, this.note, this.trailing, this.onTap});
  final Discovery d;
  final List<Discovery>? within;

  /// Replaces the detail line ("Opened yesterday", "Waiting 6 weeks").
  final String? note;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final line = note ?? d.detail;
    return Semantics(
      button: true,
      label: '${d.noun}: ${d.title}${d.isDone ? ', ${d.stamp.label}' : ''}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap ?? () => openDiscovery(context, d, within: within),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: RbSpace.side, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Hero(
              tag: 'art-${d.key}-${identityHashCode(within)}',
              child: SizedBox(
                  width: 64,
                  height: 80,
                  child: DiscoveryArt(d,
                      radius: RbSpace.photoRadius, typeset: false)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CatalogLabel(d),
                    const SizedBox(height: 5),
                    Text(d.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: RbType.serif(18, color: c.text, height: 1.2)),
                    if (line.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall),
                    ],
                  ]),
            ),
            const SizedBox(width: 8),
            trailing ?? StampDot(d),
          ]),
        ),
      ),
    );
  }
}

/// A grid tile: the frame at 4:5, then the label and title.
class DiscoveryTile extends StatelessWidget {
  const DiscoveryTile(this.d, {super.key, this.within, this.width});
  final Discovery d;
  final List<Discovery>? within;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${d.noun}: ${d.title}',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => openDiscovery(context, d, within: within),
        child: SizedBox(
          width: width,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(fit: StackFit.expand, children: [
                DiscoveryArt(d, radius: RbSpace.photoRadius),
                if (d.isDone)
                  PositionedDirectional(
                      top: 8, end: 8, child: StampDot(d, onPhoto: true)),
              ]),
            ),
            const SizedBox(height: 8),
            CatalogLabel(d, source: false),
            const SizedBox(height: 4),
            Text(d.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RbType.serif(16.5, color: c.text, height: 1.2)),
            if (d.detail.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(d.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall),
            ],
          ]),
        ),
      ),
    );
  }
}

/// A numbered catalogue row ("Recently saved"): the collection number large in mono.
class CatalogueRow extends StatelessWidget {
  const CatalogueRow(this.d, {super.key, this.within});
  final Discovery d;
  final List<Discovery>? within;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Number ${d.number}, ${d.noun}: ${d.title}',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => openDiscovery(context, d, within: within),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration:
              BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(children: [
            SizedBox(
              width: 58,
              child: Text(d.number.toString().padLeft(4, '0'),
                  style: RbType.monoNumber(15, color: c.faint)),
            ),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium),
                    const SizedBox(height: 2),
                    Row(children: [
                      Glyph(d.glyph,
                          size: 13, color: c.pigment(d.section), weight: 1.9),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                            [
                              d.noun,
                              platformName(d.platform),
                              ago(d.createdAt),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall),
                      ),
                    ]),
                  ]),
            ),
            SizedBox(
                width: 40,
                height: 40,
                child:
                    DiscoveryArt(d, radius: RbSpace.tagRadius, typeset: false)),
          ]),
        ),
      ),
    );
  }
}

/// A small mark of the discovery's state: a saffron piece when done, a ring while active.
class StampDot extends StatelessWidget {
  const StampDot(this.d, {super.key, this.onPhoto = false});
  final Discovery d;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    if (d.isDone) {
      return Tooltip(
        message: d.stamp.label,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: onPhoto ? Colors.black.withValues(alpha: 0.45) : null,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Glyph(Glyphs.piece,
              size: 18, color: c.brand, fill: c.brand, weight: 1.2),
        ),
      );
    }
    if (d.isActive) {
      return Tooltip(
        message: d.stamp.label,
        child: Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.brand, width: 2)),
        ),
      );
    }
    return const SizedBox(width: 26);
  }
}

/// The status stamp (V5 signature): mono words in a rounded frame; when done it reads like a
/// saffron rubber stamp, slightly askew. Tap: done/undone (two-state categories) or choose
/// (tools, products, watch & read). Finishing places a piece, with a haptic.
class StampButton extends StatelessWidget {
  const StampButton(this.d, {super.key, this.large = false});
  final Discovery d;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final s = d.stamp;
    final done = d.isDone;
    final color = done
        ? c.brandText
        : s.active
            ? c.text
            : c.muted;
    final label = done || s.active ? s.label : d.category.finished.label;
    final body = AnimatedContainer(
      duration: RbMotion.base,
      curve: RbMotion.curve,
      height: large ? 46 : 38,
      padding: EdgeInsets.symmetric(horizontal: large ? 16 : 12),
      decoration: BoxDecoration(
        color: done ? c.brand.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: done ? c.brandText : c.line, width: done ? 1.6 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (done)
          Glyph(Glyphs.piece,
              size: large ? 20 : 17, color: color, fill: c.brand, weight: 1.2)
        else
          Icon(s.active ? Icons.timelapse : Icons.radio_button_unchecked,
              size: large ? 18 : 15, color: color),
        const SizedBox(width: 8),
        Text(label.toUpperCase(),
            style: RbType.label(
                color: color,
                size: large ? 12.5 : 11.5,
                weight: FontWeight.w600)),
      ]),
    );
    return Semantics(
      button: true,
      toggled: done,
      label:
          done ? '${s.label}. Tap to change' : 'Mark as ${label.toLowerCase()}',
      excludeSemantics: true,
      child: Pressable(
        onTap: () => cycleStamp(context, d),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: RbSpace.touch),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Transform.rotate(
                angle: done && !RbMotion.reduced(context) ? -0.035 : 0,
                child: body),
          ),
        ),
      ),
    );
  }
}

/// Applies the next stamp: two-state categories toggle, others offer the full set.
Future<void> cycleStamp(BuildContext context, Discovery d) async {
  final cat = d.category;
  String? next;
  if (cat.stamps.length == 2) {
    next = d.isDone ? cat.open.state : cat.finished.state;
  } else {
    next = await showRbSheet<String>(context,
        title: d.title,
        kicker: 'Where is it at?',
        builder: (sheet) => Column(children: [
              for (final s in cat.stamps)
                SheetRow(
                  title: s.label,
                  icon: s.done
                      ? Icons.check_circle_outline
                      : s.active
                          ? Icons.timelapse
                          : Icons.radio_button_unchecked,
                  trailing: d.stamp.state == s.state &&
                          (d.state != null || s.state == 'to_try')
                      ? Icon(Icons.check, color: RbColors.of(sheet).brandText)
                      : null,
                  onTap: () => Navigator.pop(sheet, s.state),
                ),
            ]));
  }
  if (next == null || !context.mounted) return;
  final wasDone = d.isDone;
  applyStamp(context, d, next);
  final nowDone = cat.stamp(next)?.done ?? false;
  if (!wasDone && nowDone && context.mounted) {
    HapticFeedback.mediumImpact();
    // Firestore applies the write locally first; give the snapshot a beat to arrive.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!context.mounted) return;
    final p = progressOf(Repo.instance.now);
    toast(context,
        'Piece placed · ${p.placedInLevel} of ${p.levelSize} in level ${p.level}',
        leading: Glyph(Glyphs.piece,
            size: 20,
            color: RbColors.of(context).brand,
            fill: RbColors.of(context).brand,
            weight: 1.2),
        action: 'Undo',
        onAction: () => applyStamp(context, d, cat.open.state));
  }
}

/// Writes the stamp without waiting for the server (Firestore shows it at once and syncs when
/// it can); a refused write says so.
void applyStamp(BuildContext context, Discovery d, String state) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  Repo.instance.setStamp(d, state).catchError((Object e) {
    messenger?.showSnackBar(const SnackBar(
        content: Text("Couldn't save that. Try again in a moment.")));
  });
}

/// A rotated rubber-stamp impression for share cards and achievements.
class StampMark extends StatelessWidget {
  const StampMark(this.text, {super.key, this.color, this.angle = -0.08});
  final String text;
  final Color? color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final k = color ?? RbColors.of(context).brandText;
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: k, width: 1.8),
        ),
        child: Text(text.toUpperCase(),
            style: RbType.label(color: k, size: 12, weight: FontWeight.w600)),
      ),
    );
  }
}

/// Picks a stable but varied subset (round-robin across categories) for previews.
List<Discovery> varied(List<Discovery> list, int n) {
  final by = <String, List<Discovery>>{};
  for (final d in list) {
    (by[d.section] ??= []).add(d);
  }
  final out = <Discovery>[];
  var i = 0;
  while (out.length < math.min(n, list.length)) {
    for (final l in by.values) {
      if (i < l.length && out.length < n) out.add(l[i]);
    }
    i++;
  }
  return out;
}

/// Category stamp words as a compact row of choices (detail screen).
class StampChoices extends StatelessWidget {
  const StampChoices(this.d, {super.key});
  final Discovery d;

  @override
  Widget build(BuildContext context) {
    final cat = categoryOf(d.section);
    return Wrap(spacing: 8, runSpacing: 4, children: [
      for (final s in cat.stamps)
        FilterPill(
          label: s.label,
          selected: d.stamp.state == s.state,
          onTap: () {
            final wasDone = d.isDone;
            applyStamp(context, d, s.state);
            if (!wasDone && s.done) HapticFeedback.mediumImpact();
          },
        ),
    ]);
  }
}
