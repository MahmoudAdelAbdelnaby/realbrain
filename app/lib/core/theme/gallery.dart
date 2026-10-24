import 'package:flutter/material.dart';

import '../../features/factcheck/fact_check_view.dart'
    show VerdictPill, verdictLabels;
import '../../features/feed/feed_screen.dart' show SaveCard, SkeletonCard;
import '../widgets.dart';
import 'theme.dart';

/// Hidden design gallery (long-press the feed title): every token and core component, with a
/// theme and a direction switch so both themes and both directions can be checked side by side.
class DesignGallery extends StatefulWidget {
  const DesignGallery({super.key});

  @override
  State<DesignGallery> createState() => _DesignGalleryState();
}

class _DesignGalleryState extends State<DesignGallery> {
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
          return Scaffold(
            appBar: AppBar(title: const Text('Design gallery'), actions: [
              IconButton(
                tooltip: 'Theme',
                icon: Icon(b == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () => setState(() => _b =
                    b == Brightness.dark ? Brightness.light : Brightness.dark),
              ),
              TextButton(
                onPressed: () => setState(() => _rtl = !_rtl),
                child: Text(_rtl ? 'LTR' : 'RTL'),
              ),
            ]),
            body: ListView(
              padding: const EdgeInsets.all(RbSpace.side),
              children: [
                _h(t, 'Colour'),
                for (final e in c.all.entries)
                  _Swatch(name: e.key, color: e.value, on: c.ground),
                _h(t, 'Type'),
                for (final (name, style) in [
                  ('28 · 600', t.headlineLarge),
                  ('20 · 600', t.titleLarge),
                  ('16 · 400', t.bodyLarge),
                  ('14 · 400', t.bodyMedium),
                  ('12 · 400', t.bodySmall),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('$name  Reelbrain ريل برين 0123456789',
                        style: style),
                  ),
                Text('0:45',
                    style: t.headlineLarge
                        ?.copyWith(fontSize: RbType.timerDigits)),
                _h(t, 'Shape and motion'),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _Radius('card ${RbSpace.cardRadius.toInt()}',
                      RbSpace.cardRadius, c),
                  _Radius('panel ${RbSpace.panelRadius.toInt()}',
                      RbSpace.panelRadius, c),
                  _Radius('control round', RbSpace.pill, c),
                ]),
                const SizedBox(height: 8),
                Text(
                    'Motion ${RbMotion.fast.inMilliseconds} / ${RbMotion.base.inMilliseconds} / '
                    '${RbMotion.slow.inMilliseconds} ms, ease-out, state changes only',
                    style: t.bodySmall),
                _h(t, 'Components'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in sectionIcons.keys)
                    SectionChip(section: e, label: e, count: 3, onTap: () {}),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final v in verdictLabels.keys) VerdictPill(v),
                  const StatusPill('To try'),
                  const StatusPill('Cooked', selected: true),
                ]),
                const SizedBox(height: 12),
                const SaveCard(space: 'Me', save: {
                  'status': 'ready',
                  'platform': 'tiktok',
                  'creator': '@cairo.eats',
                  'summary':
                      'Koshari at home in 35 minutes, with a crispy onion trick.',
                  'sections': ['recipe'],
                }),
                const SaveCard(space: 'Home', save: {
                  'status': 'ready',
                  'platform': 'instagram',
                  'summary': 'Claims cold showers double your metabolism.',
                  'sections': ['fact_check'],
                  'verdict': 'mostly_false',
                }),
                const SaveCard(space: 'Me', save: {
                  'status': 'extracting',
                  'step_text': 'Watching the video'
                }),
                const SkeletonCard(),
                const EmptyState(
                    title: 'Nothing saved yet',
                    body: 'Share a reel to Reelbrain · Me.',
                    action: 'How to share'),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => showRbSheet<void>(context,
                          title: 'Bottom sheet',
                          children: const [
                            ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Edit')),
                            ListTile(
                                leading: Icon(Icons.share_outlined),
                                title: Text('Share')),
                          ]),
                      child: const Text('Open bottom sheet'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                const LinearProgressIndicator(value: 0.4),
              ],
            ),
          );
        }),
      ),
    );
  }

  static Widget _h(TextTheme t, String s) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(s, style: t.titleMedium),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color, required this.on});
  final String name;
  final Color color, on;

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(RbSpace.panelRadius),
            border: Border.all(color: RbColors.of(context).line),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name)),
        Text('$hex  ${contrast(color, on).toStringAsFixed(1)}:1',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _Radius extends StatelessWidget {
  const _Radius(this.label, this.r, this.c);
  final String label;
  final double r;
  final RbColors c;

  @override
  Widget build(BuildContext context) => Container(
        width: 104,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: c.line),
        ),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      );
}
