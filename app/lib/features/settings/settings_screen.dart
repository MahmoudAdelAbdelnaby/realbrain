import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native.dart';

/// App-wide language and theme, from users/{uid}.settings (AuthGate keeps it in sync).
final appPrefs = ValueNotifier<({String lang, String theme})>(
    (lang: 'system', theme: 'system'));

ThemeMode themeModeOf(String theme) => switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

Locale? localeOf(String lang) => switch (lang) {
      'en' => const Locale('en'),
      'ar' => const Locale('ar'),
      _ => null,
    };

/// P1-16: language, theme, daily cap; today's saves and Gemini use against the free limits.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _s;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await api('GET', '/v1/settings');
      if (mounted) setState(() => _s = s);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    }
  }

  Future<void> _patch(Map<String, dynamic> change) async {
    try {
      await api('PATCH', '/v1/settings', change);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: s == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!))
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Language'),
              _segments(
                {'system': 'Phone', 'en': 'English', 'ar': 'العربية'},
                (s['settings'] as Map)['lang'] as String,
                (v) => _patch({'lang': v}),
              ),
              const SizedBox(height: 16),
              const Text('Theme'),
              _segments(
                {'system': 'Phone', 'light': 'Light', 'dark': 'Dark'},
                (s['settings'] as Map)['theme'] as String,
                (v) => _patch({'theme': v}),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recall reminders'),
                subtitle: const Text(
                    'One "Remember this?" a day, in the evening, for something you never tried'),
                value: (s['settings'] as Map)['recall'] as bool? ?? true,
                onChanged: (v) => _patch({'recall': v}),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.ios_share),
                title: const Text('iPhone Shortcut'),
                subtitle: const Text("Save from any app's Share button"),
                onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => const ShortcutSheet()),
              ),
              const Divider(height: 32),
              Text('Saves today: ${s['saves_today']}'),
              const Divider(height: 32),
              Text(
                  'Gemini · ${(s['gemini'] as Map)['keys']} key(s), tried in order',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final m
                  in ((s['gemini'] as Map)['usage_today'] as List).cast<Map>())
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${m['model']}: ${m['used']}${m['free_per_day'] != null ? ' of ${m['free_per_day']} free today' : ' today'}',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              Text(
                  'Keys live in backend/.env for now; editing them here needs Secret Manager (billing).',
                  style: TextStyle(color: muted, fontSize: 12)),
              const Divider(height: 32),
              Text('${s['billing']}'),
            ]),
    );
  }

  Widget _segments(Map<String, String> options, String value,
          void Function(String) onPick) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SegmentedButton<String>(
          segments: [
            for (final e in options.entries)
              ButtonSegment(value: e.key, label: Text(e.value))
          ],
          selected: {value},
          onSelectionChanged: (v) => onPick(v.first),
        ),
      );
}

/// I2: iOS won't list a home-screen web app in the share sheet, but a Shortcut can be.
/// It posts the shared link with this key to /v1/shortcut/save.
class ShortcutSheet extends StatefulWidget {
  const ShortcutSheet({super.key});

  @override
  State<ShortcutSheet> createState() => _ShortcutSheetState();
}

class _ShortcutSheetState extends State<ShortcutSheet> {
  String? _key;
  String? _error;
  bool _busy = false;

  Future<void> _newKey() async {
    setState(() => _busy = true);
    try {
      final r = await api('POST', '/v1/me/save-key');
      if (mounted) setState(() => _key = r['key'] as String);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _copy(String label, String value) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: SelectableText(value),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$label copied')));
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final url = '${backendUrl.value ?? ''}/v1/shortcut/save';
    return SafeArea(
      child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Save to Realbrain from the Share button',
                style: t.titleMedium),
            const SizedBox(height: 8),
            const Text(
                'Build it once in the Shortcuts app (about 2 minutes). After that, '
                "Share → Save to Realbrain saves without leaving the app you're in."),
            const SizedBox(height: 16),
            if (_key == null)
              FilledButton(
                onPressed: _busy ? null : _newKey,
                child: Text(_busy ? 'Making a key…' : 'Get my save key'),
              )
            else ...[
              _copy('Your save key', _key!),
              Text('Shown once. Getting a new key turns this one off.',
                  style: t.bodySmall),
              const SizedBox(height: 8),
              _copy('Address', url),
            ],
            if (_error != null) Text(_error!),
            const SizedBox(height: 16),
            Text('In the Shortcuts app:', style: t.titleSmall),
            const SizedBox(height: 8),
            for (final step in const [
              '1. Tap + (top right). Tap "New Shortcut" at the top → Rename → Save to Realbrain.',
              '2. Tap ⓘ at the bottom → turn on "Show in Share Sheet" → Done. A "Receive … input '
                  'from Share Sheet" block appears: tap its blue "Images and 18 more", tap Clear, '
                  'pick URLs and Text, then Done.',
              '3. In "Search for apps and actions" at the bottom, add "List". Change its items to Me and Home.',
              '4. Add "Choose from List". Tap its arrow (>) and set Prompt to Save to.',
              '5. Add "Get Contents of URL". Tap the blue URL and paste the Address. Tap the arrow (>): '
                  'Method POST. Headers: Add new header, Key X-Save-Key, Text: paste your save key.',
              '6. Still there, Request Body: JSON. Add new field → Text, key url; for its value tap '
                  '"Shortcut Input" in the bar above the keyboard. Add new field → Text, key space; '
                  'value: tap "Chosen Item".',
              '7. Add "Show Notification", change "Hello World!" to Saved to Realbrain, tap Done.',
              '8. Try it: in Instagram tap Share → "Share to…" (TikTok: Share → More), scroll down, '
                  'tap Save to Realbrain. The first time, tap "Always Allow".',
            ])
              Padding(
                  padding: const EdgeInsets.only(bottom: 8), child: Text(step)),
          ]),
    );
  }
}
