import 'package:flutter/material.dart';

import '../art/glyphs.dart';
import '../data/brain.dart';
import '../format.dart';
import '../native.dart';
import '../theme/tokens.dart';
import 'components.dart' show MonoLabel;

/// A stored frame path (relative to the backend, or a full URL), decoded at the size it's shown
/// and faded in. [fallback] draws while loading, when there is no frame, or on error.
class FrameImage extends StatelessWidget {
  const FrameImage(
      {super.key,
      required this.stored,
      required this.fallback,
      this.fit = BoxFit.cover,
      this.alignment = Alignment.center});
  final String? stored;
  final Widget fallback;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final s = stored;
    if (s == null) return fallback;
    // The demo build bundles its sample photos ("asset:path"); real frames live on the backend.
    if (s.startsWith('asset:')) return _image(AssetImage(s.substring(6)));
    return ValueListenableBuilder<String?>(
      valueListenable: backendUrl,
      builder: (context, _, __) {
        final url = frameUrl(s);
        if (url == null) return fallback;
        return _image(NetworkImage(url));
      },
    );
  }

  Widget _image(ImageProvider provider) =>
      LayoutBuilder(builder: (context, box) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
        return Image(
          image: ResizeImage.resizeIfNeeded(
              (w * dpr).round().clamp(64, 1600), null, provider),
          fit: fit,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
          frameBuilder: (context, child, frame, sync) {
            if (sync || frame != null) {
              return AnimatedOpacity(
                  opacity: frame == null && !sync ? 0 : 1,
                  duration: RbMotion.base,
                  child: child);
            }
            return Stack(fit: StackFit.expand, children: [fallback, child]);
          },
        );
      });
}

/// The specimen card: what a discovery looks like without a frame (typed ideas, links,
/// books and products from a page). Pigment-tinted paper, the category's plate, the catalogue
/// number, and at larger sizes the title typeset like a cover.
class SpecimenCard extends StatelessWidget {
  const SpecimenCard(
      {super.key,
      required this.section,
      this.glyph,
      this.title,
      this.number,
      this.kindLabel});
  final String section;
  final String? glyph, title, kindLabel;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pigment = c.pigment(section);
    final bg = Color.alphaBlend(
        pigment.withValues(alpha: dark ? 0.16 : 0.13), c.surface);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 120.0;
      final h = box.maxHeight.isFinite ? box.maxHeight : w;
      final small = w < 110 || h < 110;
      final cover = !small && title != null && h >= 150;
      return DecoratedBox(
        decoration: BoxDecoration(color: bg),
        child: Stack(fit: StackFit.expand, children: [
          // Fine plate rules, like the border of an engraved plate.
          if (!small)
            Padding(
              padding: EdgeInsets.all(w * 0.05),
              child: DecoratedBox(
                decoration: BoxDecoration(
                    border: Border.all(
                        color: pigment.withValues(alpha: 0.35), width: 0.8)),
              ),
            ),
          Align(
            alignment: cover ? const Alignment(0, -0.38) : Alignment.center,
            child: Glyph(glyph ?? section,
                size: (cover ? h * 0.26 : (small ? w * 0.44 : h * 0.4))
                    .clamp(16.0, 120.0),
                color: pigment,
                weight: small ? 1.6 : 1.0),
          ),
          if (!small && number != null && number! > 0)
            PositionedDirectional(
              top: w * 0.09,
              start: w * 0.09,
              child: MonoLabel(catalogueNo(number!),
                  color: pigment, size: w < 180 ? 9.5 : 11),
            ),
          if (cover)
            PositionedDirectional(
              start: w * 0.1,
              end: w * 0.1,
              bottom: h * 0.09,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (kindLabel != null) ...[
                      MonoLabel(kindLabel!, color: pigment, size: 10),
                      const SizedBox(height: 4),
                    ],
                    Text(title!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: RbType.serif((w * 0.09).clamp(15.0, 26.0),
                            color: c.text, italic: section == 'entertainment')),
                  ]),
            ),
        ]),
      );
    });
  }
}

/// A discovery's image: its key frame, or its specimen card.
class DiscoveryArt extends StatelessWidget {
  const DiscoveryArt(this.d,
      {super.key, this.radius = 0, this.typeset = true, this.frame});
  final Discovery d;
  final double radius;

  /// Show the title on the specimen card (off when the title is printed next to it).
  final bool typeset;

  /// Override the frame (a moment's frame in the viewer).
  final String? frame;

  @override
  Widget build(BuildContext context) {
    final kindLabel = d.noun;
    final fallback = SpecimenCard(
        section: d.section,
        glyph: d.glyph,
        title: typeset ? d.title : null,
        number: d.number,
        kindLabel: kindLabel);
    final img = FrameImage(stored: frame ?? d.frame, fallback: fallback);
    return radius == 0
        ? img
        : ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

/// A paper plate for illustrations (Hudhud, the puzzle on share cards): paper in both themes,
/// a hairline border, and a mono plate caption, like a natural-history plate.
class Plate extends StatelessWidget {
  const Plate(
      {super.key,
      required this.child,
      this.caption,
      this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 10)});
  final Widget child;
  final String? caption;
  final EdgeInsetsGeometry padding;

  static const paper = Color(0xFFF3EEE5);
  static const ink = Color(0xFF1A1714);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
        border: Border.all(color: const Color(0xFFD9D0C1)),
      ),
      padding: padding,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        child,
        if (caption != null) ...[
          const SizedBox(height: 6),
          Container(height: 0.8, color: const Color(0xFFD9D0C1)),
          const SizedBox(height: 6),
          MonoLabel(caption!, color: const Color(0xFF6B6358), size: 9.5),
        ],
      ]),
    );
  }
}
