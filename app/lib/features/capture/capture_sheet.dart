import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/art/glyphs.dart';
import '../../core/art/mark.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';

/// The platform a pasted link comes from, as the backend names it.
String? linkPlatform(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  for (final (name, mark) in const [
    ('tiktok', 'tiktok.com'),
    ('instagram', 'instagram.com'),
    ('youtube', 'youtube.com'),
    ('youtube', 'youtu.be'),
    ('facebook', 'facebook.com'),
  ]) {
    if (host == mark || host.endsWith('.$mark')) return name;
  }
  return null;
}

/// A link inside pasted text ("Check this out https://..."), or null.
String? findLink(String text) =>
    RegExp(r'https?://\S+').firstMatch(text)?.group(0);

/// Capture (docs/DESIGN_V5.md §2.6): a link on the clipboard is one tap; otherwise paste a
/// link or type an idea. What it is and where it goes are optional (Auto, Me).
Future<void> openCapture(BuildContext context, {String? clipboard}) async {
  String? clip = clipboard;
  if (clip == null) {
    try {
      clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    } catch (_) {
      clip = null; // the browser may refuse to hand over the clipboard
    }
  }
  if (!context.mounted) return;
  await showRbSheet<void>(context,
      title: 'Save to Realbrain',
      kicker: 'Capture',
      builder: (sheet) =>
          CaptureForm(clipboard: clip == null ? null : findLink(clip)));
}

class CaptureForm extends StatefulWidget {
  const CaptureForm({super.key, this.clipboard});
  final String? clipboard;

  @override
  State<CaptureForm> createState() => _CaptureFormState();
}

class _CaptureFormState extends State<CaptureForm> {
  final _text = TextEditingController();
  String _hint = 'auto', _space = 'me';
  bool _busy = false, _more = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _raw => _text.text.trim();
  String? get _link => findLink(_raw);
  bool get _isIdea => _raw.isNotEmpty && _link == null;

  Future<void> _save(String? link) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final hint = _hint == 'auto' ? null : _hint;
    final nav = Navigator.of(context);
    try {
      if (link != null) {
        await Repo.instance.saveLink(link, space: _space, hint: hint);
      } else {
        await Repo.instance
            .saveIdea(_raw, space: _space, hint: hint ?? 'ideas');
      }
      final root = nav.context;
      if (!mounted || !root.mounted) return;
      nav.pop();
      toast(root, 'Saved. Realbrain is reading it.',
          // The snack bar is inverted (text colour), so the mark takes the ground colour.
          leading: BrainMark(
              size: 26,
              motion: MarkMotion.thinking,
              color: RbColors.of(root).ground));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final s = Repo.instance.now;
    final clip = widget.clipboard;
    final link = _link;
    final canSave = _raw.isNotEmpty && !_busy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (clip != null && _raw.isEmpty) ...[
          _LinkCard(url: clip, label: 'From your clipboard'),
          const SizedBox(height: 10),
          RbButton('Save this link',
              expand: true,
              busy: _busy,
              onPressed: _busy ? null : () => _save(clip)),
          const SizedBox(height: 16),
          const Rule(label: 'Or'),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _text,
          autofocus: clip == null,
          minLines: 1,
          maxLines: 6,
          maxLength: 2000,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
              hintText: 'Paste a link, or type an idea', counterText: ''),
        ),
        if (link != null) ...[
          const SizedBox(height: 10),
          _LinkCard(url: link, label: 'Will save'),
        ] else if (_isIdea) ...[
          const SizedBox(height: 8),
          Row(children: [
            Glyph(Glyphs.ideas, size: 16, color: c.pigment('ideas')),
            const SizedBox(width: 6),
            Text('Saved as an idea; Realbrain adds next steps.',
                style: t.bodySmall),
          ]),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => setState(() => _more = !_more),
            icon: Icon(_more ? Icons.expand_less : Icons.tune, size: 18),
            label: Text(_more
                ? 'Fewer options'
                : [
                    _hint == 'auto' ? 'Auto-detect' : categoryOf(_hint).noun,
                    _space == 'me'
                        ? 'Me'
                        : (s.group(s.spaces[_space] ?? _space)?.name ??
                            'Group'),
                  ].join(' · ')),
          ),
        ),
        if (_more) ...[
          const MonoLabel('What is it?'),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 0, children: [
            FilterPill(
                label: 'Auto',
                selected: _hint == 'auto',
                onTap: () => setState(() => _hint = 'auto')),
            for (final id in hintOrder)
              FilterPill(
                  label: categoryOf(id).name,
                  glyph: id,
                  selected: _hint == id,
                  onTap: () => setState(() => _hint = id)),
          ]),
          if (s.groups.isNotEmpty) ...[
            const SizedBox(height: 10),
            const MonoLabel('Save to'),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              FilterPill(
                  label: 'Me',
                  selected: _space == 'me',
                  onTap: () => setState(() => _space = 'me')),
              for (final g in s.groups)
                FilterPill(
                    label: g.name,
                    glyph: Glyphs.groups,
                    selected:
                        _space == g.id || (_space == 'home' && g.isDefault),
                    onTap: () =>
                        setState(() => _space = g.isDefault ? 'home' : g.id)),
            ]),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: t.bodySmall?.copyWith(color: c.falseFg)),
        ],
        const SizedBox(height: 12),
        if (!(clip != null && _raw.isEmpty))
          RbButton(_isIdea ? 'Save the idea' : 'Save',
              expand: true,
              busy: _busy,
              onPressed: canSave ? () => _save(link) : null),
        const SizedBox(height: 6),
        Text(
            'Tip: share straight from TikTok, Instagram or YouTube to Realbrain. It never asks anything.',
            textAlign: TextAlign.center,
            style: t.bodySmall),
      ]),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.url, required this.label});
  final String url, label;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final platform = linkPlatform(url);
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
      ),
      child: Row(children: [
        Icon(platform == null ? Icons.public : Icons.play_circle_outline,
            color: c.text),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MonoLabel(label),
            const SizedBox(height: 2),
            Text(
                platform == null
                    ? 'A page on $host'
                    : 'A ${platformName(platform)} video',
                style: t.titleSmall),
            Text(url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}
