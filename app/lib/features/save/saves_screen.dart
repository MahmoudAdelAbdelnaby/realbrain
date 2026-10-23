import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const downloader = MethodChannel('reelbrain/downloader');

/// Phase 0 spike screen: every share and what the on-device downloader did with it.
/// ponytail: polls the native save list every 2 s; becomes a Firestore listener in P1-05.
class SavesScreen extends StatefulWidget {
  const SavesScreen({super.key});

  @override
  State<SavesScreen> createState() => _SavesScreenState();
}

class _SavesScreenState extends State<SavesScreen> {
  final _url = TextEditingController();
  List<Map<String, dynamic>>? _saves;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _url.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await downloader.invokeMethod<String>('saves') ?? '[]';
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _set(list, null);
    } on PlatformException catch (e) {
      _set(_saves, e.message ?? e.code);
    } on MissingPluginException {
      _set(_saves, 'Downloader is Android-only for now.');
    }
  }

  void _set(List<Map<String, dynamic>>? saves, String? error) {
    if (!mounted) return;
    setState(() {
      _saves = saves;
      _error = error;
    });
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    if (!url.startsWith('http')) return;
    await downloader.invokeMethod('enqueue', {'url': url, 'space': 'me'});
    _url.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final saves = _saves;
    return Scaffold(
      appBar: AppBar(title: const Text('Reelbrain')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Paste a reel link',
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ),
            Expanded(
              child: switch ((saves, _error)) {
                (_, final String e) => _Message(e),
                (null, _) => const Center(child: CircularProgressIndicator()),
                (final List<Map<String, dynamic>> s, _) when s.isEmpty =>
                  const _Message(
                    'No saves yet. Share a reel to Reelbrain · Me or Home.',
                  ),
                (final List<Map<String, dynamic>> s, _) => ListView.separated(
                    itemCount: s.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _SaveTile(s[i]),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

/// The yt-dlp ERROR line behind a failure code, so a wrong code can't hide the real cause.
String _errorLine(Map<String, dynamic> save) {
  final lines = (save['error_detail'] as String? ?? '').split('\n');
  final error = lines.where((l) => l.startsWith('ERROR')).lastOrNull;
  return error == null ? '' : '\n$error';
}

class _SaveTile extends StatelessWidget {
  const _SaveTile(this.save);
  final Map<String, dynamic> save;

  @override
  Widget build(BuildContext context) {
    final status = save['status'] as String? ?? '?';
    final size = save['size_bytes'] as num?;
    final dur = save['duration_s'] as num?;
    final detail = switch (status) {
      'downloaded' => '${((size ?? 0) / 1e6).toStringAsFixed(1)} MB · '
          '${dur?.toStringAsFixed(0) ?? '?'} s · ${save['download_ms']} ms',
      'failed' || 'upload_failed' => '${save['error']}${_errorLine(save)}',
      _ => status,
    };
    return ListTile(
      title: Text(
        save['url'] as String? ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${save['space']} · $detail',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: switch (status) {
        'queued' || 'downloading' || 'uploading' => const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        'failed' || 'upload_failed' => const Icon(Icons.error_outline),
        _ => const Icon(Icons.check),
      },
    );
  }
}
