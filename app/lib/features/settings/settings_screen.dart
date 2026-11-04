import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data/repo.dart';
import '../../core/native.dart' show apiError, backendUrl;
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import '../gallery/gallery_screen.dart';

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

/// Settings, grouped by who it's for: how it looks, My Brain, reminders, saving; then usage
/// and diagnostics for the curious, and the account.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _patch(BuildContext context, Json change) async {
    final before = appPrefs.value;
    // Theme and language change at once; the backend confirms through the user doc.
    appPrefs.value = (
      lang: change['lang'] as String? ?? before.lang,
      theme: change['theme'] as String? ?? before.theme
    );
    try {
      await Repo.instance.patchSettings(change);
    } catch (e) {
      appPrefs.value = before;
      if (context.mounted) toast(context, apiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrainState>(
      valueListenable: Repo.instance.state,
      builder: (context, s, _) {
        final c = RbColors.of(context);
        final t = Theme.of(context).textTheme;
        final prefs = appPrefs.value;
        Widget section(String label) => Padding(
              padding:
                  const EdgeInsets.fromLTRB(RbSpace.side, 28, RbSpace.side, 6),
              child: MonoLabel(label, color: c.brandText),
            );
        Widget pills(Map<String, String> options, String value,
                void Function(String) pick) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
              child: Wrap(spacing: 8, children: [
                for (final e in options.entries)
                  FilterPill(
                      label: e.value,
                      selected: value == e.key,
                      onTap: () => pick(e.key)),
              ]),
            );
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
              child: Row(children: [
                s.photoUrl != null
                    ? CircleAvatar(
                        radius: 26, backgroundImage: NetworkImage(s.photoUrl!))
                    : Avatar(s.userName.isEmpty ? 'You' : s.userName, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.userName.isEmpty ? 'Signed in' : s.userName,
                            style: RbType.serif(22, color: c.text)),
                        Text(
                            '${s.discoveries.length} discoveries · ${s.groups.length} groups',
                            style: t.bodySmall),
                      ]),
                ),
              ]),
            ),
            section('Appearance'),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(RbSpace.side, 4, RbSpace.side, 4),
              child: Text('Theme', style: t.titleSmall),
            ),
            pills({'system': 'Phone', 'dark': 'Ink', 'light': 'Paper'},
                prefs.theme, (v) => _patch(context, {'theme': v})),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(RbSpace.side, 14, RbSpace.side, 4),
              child: Text('Language', style: t.titleSmall),
            ),
            pills({'system': 'Phone', 'en': 'English', 'ar': 'العربية'},
                prefs.lang, (v) => _patch(context, {'lang': v})),
            section('My Brain'),
            SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: RbSpace.side),
              title: const Text('Show the puzzle'),
              subtitle: const Text(
                  'Off keeps your progress but hides the brain puzzle.'),
              value: s.settings.puzzle,
              onChanged: (v) => _patch(context, {'puzzle': v}),
            ),
            section('Reminders'),
            SwitchListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: RbSpace.side),
              title: const Text('Remember this?'),
              subtitle: const Text(
                  'One reminder a day, in the evening, for something you saved and never tried.'),
              value: s.settings.recall,
              onChanged: (v) => _patch(context, {'recall': v}),
            ),
            section('Saving'),
            SheetRow(
              title: 'Save from iPhone',
              subtitle:
                  'A Shortcut in the Share button, for the iPhone web app',
              icon: Icons.ios_share,
              trailing: Icon(Icons.chevron_right, color: c.faint),
              onTap: () => showRbSheet<void>(context,
                  title: 'Save from the Share button',
                  kicker: 'iPhone Shortcut',
                  builder: (_) => const ShortcutSheet()),
            ),
            section('Usage'),
            const _Usage(),
            section('Diagnostics'),
            SheetRow(
              title: 'Phone queue',
              subtitle:
                  'What the on-device downloader did with each share (Android)',
              icon: Icons.download_outlined,
              trailing: Icon(Icons.chevron_right, color: c.faint),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PhoneQueueScreen())),
            ),
            SheetRow(
              title: 'Design system',
              subtitle: 'Colours, type, glyphs, Hudhud and components',
              icon: Icons.palette_outlined,
              trailing: Icon(Icons.chevron_right, color: c.faint),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GalleryScreen())),
            ),
            const SizedBox(height: 20),
            SheetRow(
              title: 'Sign out',
              icon: Icons.logout,
              destructive: true,
              onTap: () async {
                Navigator.of(context).popUntil((r) => r.isFirst);
                await Repo.instance.signOut();
              },
            ),
          ]),
        );
      },
    );
  }
}

class _Usage extends StatefulWidget {
  const _Usage();

  @override
  State<_Usage> createState() => _UsageState();
}

class _UsageState extends State<_Usage> {
  late final Future<Json> _f = Repo.instance.settingsDetail();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    return FutureBuilder<Json>(
      future: _f,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
            child: Text(apiError(snap.error!), style: t.bodySmall),
          );
        }
        final s = snap.data;
        if (s == null) {
          return const Padding(
              padding: EdgeInsets.all(RbSpace.side),
              child: SkeletonBox(height: 40));
        }
        final gemini = (s['gemini'] as Map?) ?? const {};
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s['saves_today'] ?? 0} saves today', style: t.bodyLarge),
            const SizedBox(height: 8),
            Text('AI reading · ${gemini['keys'] ?? 0} key(s), tried in order',
                style: t.bodySmall),
            for (final m
                in ((gemini['usage_today'] as List?) ?? const []).cast<Map>())
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    '${m['model']}: ${m['used']}${m['free_per_day'] != null ? ' of ${m['free_per_day']} free today' : ' today'}',
                    style: RbType.monoNumber(12.5, color: c.muted)),
              ),
          ]),
        );
      },
    );
  }
}

/// Phone queue (Android): every share and what the on-device download and upload did with it.
class PhoneQueueScreen extends StatefulWidget {
  const PhoneQueueScreen({super.key});

  @override
  State<PhoneQueueScreen> createState() => _PhoneQueueScreenState();
}

class _PhoneQueueScreenState extends State<PhoneQueueScreen> {
  late Future<List<Json>> _f = Repo.instance.phoneQueue();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Phone queue'), actions: [
        IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() => _f = Repo.instance.phoneQueue()),
            icon: const Icon(Icons.refresh)),
      ]),
      body: FutureBuilder<List<Json>>(
        future: _f,
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return const LoadingMark(text: 'Reading the queue');
          if (list.isEmpty) {
            return const EmptyState(
                title: 'Nothing in the phone queue',
                body:
                    'Shares from the Android share sheet show here while they download and upload.');
          }
          return ListView(children: [
            for (final s in list)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: RbSpace.side, vertical: 4),
                title: Text('${s['url']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium),
                subtitle: Text(
                    '${s['space']} · ${switch (s['status']) {
                      'downloaded' =>
                        '${(((s['size_bytes'] ?? 0) as num) / 1e6).toStringAsFixed(1)} MB · ${s['duration_s']} s · ${s['download_ms']} ms',
                      'waiting' => s['error'] == 'NOT_SIGNED_IN'
                          ? 'waiting for sign-in'
                          : 'waiting for Realbrain to be reachable',
                      'failed' || 'upload_failed' => '${s['error']}',
                      _ => '${s['status']}',
                    }}',
                    style: RbType.monoNumber(12, color: c.muted)),
              ),
          ]);
        },
      ),
    );
  }
}

/// I2: iOS won't list a home-screen web app in the share sheet, but a Shortcut can be. It posts
/// the shared link with this key to /v1/shortcut/save.
class ShortcutSheet extends StatefulWidget {
  const ShortcutSheet({super.key});

  @override
  State<ShortcutSheet> createState() => _ShortcutSheetState();
}

class _ShortcutSheetState extends State<ShortcutSheet> {
  String? _key, _error;
  bool _busy = false;

  Future<void> _newKey() async {
    setState(() => _busy = true);
    try {
      final k = await Repo.instance.newSaveKey();
      if (mounted) setState(() => _key = k);
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _copy(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MonoLabel(label),
              SelectableText(value,
                  style:
                      RbType.monoNumber(13, color: RbColors.of(context).text)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              toast(context, '$label copied');
            },
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final url = '${backendUrl.value ?? ''}/v1/shortcut/save';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            'Build it once in the Shortcuts app (about 2 minutes). After that, Share → Save to '
            'Realbrain saves without leaving the app you’re in.',
            style: t.bodyMedium),
        const SizedBox(height: 14),
        if (_key == null)
          RbButton(_busy ? 'Making a key…' : 'Get my save key',
              busy: _busy, onPressed: _busy ? null : _newKey)
        else ...[
          _copy('Your save key', _key!),
          Text('Shown once. Getting a new key turns this one off.',
              style: t.bodySmall),
          _copy('Address', url),
        ],
        if (_error != null) Text(_error!, style: t.bodySmall),
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
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(step, style: t.bodyMedium)),
      ]),
    );
  }
}
