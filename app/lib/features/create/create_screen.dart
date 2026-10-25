import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';
import '../../core/surface.dart';
import '../../core/theme/tokens.dart';
import '../inbox/inbox_screen.dart' show platformLabels;

/// "What is this?" choices: Auto lets the AI decide; the rest are real section hints.
const createKinds = [
  ('auto', 'Auto', Icons.auto_awesome_outlined),
  ('recipe', 'Recipe', Icons.restaurant_outlined),
  ('tools', 'Tool', Icons.terminal_outlined),
  ('ideas', 'Idea', Icons.lightbulb_outline),
  ('places', 'Place', Icons.place_outlined),
  ('workout', 'Workout', Icons.fitness_center_outlined),
  ('fact_check', 'Fact check', Icons.fact_check_outlined),
];

/// The platform a pasted link comes from, as the backend names it (main.platform).
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

/// Create (design v4 step 3): a link or a typed idea, what it is, which space, then the same
/// path as a share. Photos come later (D5).
class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.hasHome = false, this.link});
  final bool hasHome;

  /// A link already on the clipboard, to start from.
  final String? link;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  late final _link = TextEditingController(text: widget.link ?? '');
  final _idea = TextEditingController();
  bool _isIdea = false;
  String _kind = 'auto', _space = 'me';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _link.addListener(() => setState(() {}));
    _idea.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _link.dispose();
    _idea.dispose();
    super.dispose();
  }

  bool get _valid => _isIdea
      ? _idea.text.trim().isNotEmpty
      : Uri.tryParse(_link.text.trim())?.hasScheme == true;

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    final hint = _kind == 'auto' ? null : _kind;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isIdea) {
        await api('POST', '/v1/saves', {
          'idea': _idea.text.trim(),
          'space_id': _space,
          'section_hint': hint,
        });
      } else {
        await native.invokeMethod('enqueue',
            {'url': _link.text.trim(), 'space': _space, 'hint': hint});
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
          .showSnackBar(const SnackBar(content: Text('Added to your brain')));
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
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    final url = _link.text.trim();
    final platform = linkPlatform(url);
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 24),
        children: [
          Text('Create', style: t.headlineMedium),
          const SizedBox(height: 6),
          Text('Turn anything into a memory.',
              style: t.bodyMedium?.copyWith(color: c.muted)),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: false, icon: Icon(Icons.link), label: Text('Link')),
              ButtonSegment(
                  value: true,
                  icon: Icon(Icons.edit_note),
                  label: Text('Idea')),
            ],
            selected: {_isIdea},
            onSelectionChanged: (v) => setState(() {
              _isIdea = v.first;
              if (_isIdea && _kind == 'auto') _kind = 'ideas';
              if (!_isIdea && _kind == 'ideas') _kind = 'auto';
            }),
          ),
          const SizedBox(height: 16),
          if (_isIdea)
            TextField(
              controller: _idea,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(
                  hintText: 'A thought, a plan, something to try…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                          Radius.circular(RbSpace.panelRadius)),
                      borderSide: BorderSide.none)),
            )
          else ...[
            TextField(
              controller: _link,
              autofocus: url.isEmpty,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'Paste a link to a reel, video or page',
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste),
                  onPressed: () async {
                    final clip =
                        (await Clipboard.getData(Clipboard.kTextPlain))?.text;
                    if (clip != null) _link.text = clip.trim();
                  },
                ),
              ),
            ),
            if (_valid) ...[
              const SizedBox(height: 12),
              // What will be saved: where the link is from.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(RbSpace.panelRadius),
                  border: Border.all(color: c.line),
                ),
                child: Row(children: [
                  Icon(
                      platform == null
                          ? Icons.public
                          : Icons.play_circle_outline,
                      color: c.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              platform == null
                                  ? 'Page on $host'
                                  : 'From ${platformLabels[platform]}',
                              style: t.titleSmall),
                          Text(url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall),
                        ]),
                  ),
                ]),
              ),
            ],
          ],
          const SizedBox(height: 24),
          Text('What is this?', style: t.titleSmall),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.4,
            children: [
              for (final (id, label, icon) in createKinds)
                _Kind(
                  label: label,
                  icon: icon,
                  hue: id == 'auto' ? c.accent : c.section(id),
                  selected: _kind == id,
                  onTap: () => setState(() => _kind = id),
                ),
            ],
          ),
          if (widget.hasHome) ...[
            const SizedBox(height: 24),
            Text('Save to', style: t.titleSmall),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'me', label: Text('Me')),
                ButtonSegment(value: 'home', label: Text('Home')),
              ],
              selected: {_space},
              onSelectionChanged: (v) => setState(() => _space = v.first),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: c.falseFg)),
          ],
          const SizedBox(height: 28),
          PillButton(
            action: true,
            icon: Icons.add,
            label: _busy ? 'Adding…' : 'Create memory',
            onPressed: _valid && !_busy ? _create : null,
          ),
        ],
      ),
    );
  }
}

class _Kind extends StatelessWidget {
  const _Kind(
      {required this.label,
      required this.icon,
      required this.hue,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color hue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: RbMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? c.raised : c.surface,
            borderRadius: BorderRadius.circular(RbSpace.panelRadius),
            border: Border.all(color: selected ? c.text : c.line),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: hue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: hue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1, style: Theme.of(context).textTheme.labelLarge),
            ),
            if (selected) Icon(Icons.check, size: 16, color: c.text),
          ]),
        ),
      ),
    );
  }
}
