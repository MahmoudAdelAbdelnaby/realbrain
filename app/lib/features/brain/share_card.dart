import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/art/glyphs.dart';
import '../../core/art/mark.dart';
import '../../core/native.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';

/// A shareable card (achievements, level, the month): always paper, 4:5, rendered off-screen
/// to a PNG and handed to the share sheet with a line of text.
class ShareCard extends StatelessWidget {
  const ShareCard(
      {super.key,
      required this.kicker,
      required this.title,
      required this.line,
      required this.art,
      this.stats = const []});
  final String kicker, title, line;
  final Widget art;
  final List<(String, String)> stats;

  static const size = Size(1080 / 3, 1350 / 3);

  @override
  Widget build(BuildContext context) {
    final c = RbColors.light;
    return Theme(
      data: rbTheme(Brightness.light),
      child: Container(
        width: size.width,
        height: size.height,
        color: Plate.paper,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const BrainMark(
                size: 26, color: Plate.ink, piece: Color(0xFFE39B2C)),
            const SizedBox(width: 6),
            Text('Realbrain', style: RbType.serif(15, color: Plate.ink)),
            const Spacer(),
            MonoLabel(kicker, color: c.brandText, size: 9.5),
          ]),
          const SizedBox(height: 10),
          Container(height: 0.8, color: c.line),
          Expanded(child: Center(child: art)),
          Text(title, style: RbType.serif(28, color: Plate.ink)),
          const SizedBox(height: 4),
          Text(line, style: RbType.serif(14, color: c.muted, italic: true)),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              for (final (v, k) in stats)
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v, style: RbType.serif(22, color: Plate.ink)),
                        MonoLabel(k, color: c.faint, size: 8.5),
                      ]),
                ),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Glyph(Glyphs.piece,
                size: 12, color: c.brandText, fill: c.brand, weight: 1),
            const SizedBox(width: 6),
            MonoLabel('Save less. Use more.', color: c.faint, size: 8.5),
          ]),
        ]),
      ),
    );
  }
}

/// Renders [card] off-screen at 3× and shares the PNG; falls back to sharing [text].
Future<void> shareCard(BuildContext context, Widget card, String text) async {
  final overlay = Overlay.of(context);
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -ShareCard.size.width * 2, // off-screen, but laid out and painted
      top: 0,
      child: RepaintBoundary(key: key, child: Material(child: card)),
    ),
  );
  overlay.insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final image = await boundary?.toImage(pixelRatio: 3);
    final bytes = await image?.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('nothing rendered');
    await shareImage(bytes.buffer.asUint8List(), text);
  } on MissingPluginException {
    await shareText(text);
  } on PlatformException {
    await shareText(text);
  } catch (_) {
    await shareText(text);
  } finally {
    entry.remove();
  }
}
