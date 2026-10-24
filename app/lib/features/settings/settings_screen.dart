import 'package:flutter/material.dart';

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
