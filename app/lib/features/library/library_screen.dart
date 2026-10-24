import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../feed/feed_screen.dart' show SaveCard, sectionLabels;

/// Same normalisation as backend/app/search.py: lowercase, Arabic diacritics and tatweel
/// dropped, alef/ya/ta-marbuta variants folded.
String normalise(String text) {
  final stripped = text.toLowerCase().replaceAll(RegExp('[ؐ-ًؚ-ٰٟـ]'), '');
  const fold = {
    'أ': 'ا',
    'إ': 'ا',
    'آ': 'ا',
    'ى': 'ي',
    'ة': 'ه',
    'ؤ': 'و',
    'ئ': 'ي'
  };
  final folded = stripped.split('').map((c) => fold[c] ?? c).join();
  return folded.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
}

/// Every word of the query must appear somewhere in the save's text.
bool saveMatches(Map<String, dynamic> save, String query,
    {String? platform, String? section}) {
  if (platform != null && save['platform'] != platform) return false;
  if (section != null &&
      !((save['sections'] as List?) ?? const []).contains(section)) {
    return false;
  }
  final q = normalise(query);
  if (q.isEmpty) return true;
  final hay = save['search_text'] as String? ??
      normalise([
        save['summary'],
        save['caption'],
        save['creator'],
        save['source_url']
      ].whereType<String>().join(' '));
  return q.split(' ').every(hay.contains);
}

const platforms = {
  'tiktok': 'TikTok',
  'instagram': 'Instagram',
  'youtube': 'YouTube'
};

/// P1-15: all saves in your spaces, searchable and filterable on the phone.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _query = TextEditingController();
  final _subs = <StreamSubscription<Object?>>[];
  final _saves = <String, List<Map<String, dynamic>>>{};
  Map<String, String> _labels = {};
  String? _platform, _section;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance.doc('users/$uid').get().then((u) {
      final spaces =
          (u.data()?['spaces'] as Map?)?.cast<String, String>() ?? {};
      _labels = {
        for (final e in spaces.entries) e.value: e.key == 'home' ? 'Home' : 'Me'
      };
      for (final id in spaces.values.toSet()) {
        // ponytail: whole collection on the phone; fine for hundreds of saves, page it past that.
        _subs.add(FirebaseFirestore.instance
            .collection('spaces/$id/saves')
            .snapshots()
            .listen(
              (q) => setState(
                  () => _saves[id] = [for (final d in q.docs) d.data()]),
            ));
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = [for (final l in _saves.values) ...l]..sort((a, b) =>
        ((b['created_at'] ?? 0) as num)
            .compareTo((a['created_at'] ?? 0) as num));
    final found = all
        .where((s) =>
            saveMatches(s, _query.text, platform: _platform, section: _section))
        .toList();
    return Scaffold(
      backgroundColor: Colors.transparent, // the liquid shows through
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TextField(
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Search your saves', border: InputBorder.none),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final e in platforms.entries)
              FilterChip(
                label: Text(e.value),
                selected: _platform == e.key,
                onSelected: (on) =>
                    setState(() => _platform = on ? e.key : null),
              ),
            for (final e in sectionLabels.entries)
              FilterChip(
                label: Text(e.value),
                selected: _section == e.key,
                onSelected: (on) =>
                    setState(() => _section = on ? e.key : null),
              ),
          ]),
          const SizedBox(height: 8),
          if (_saves.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()))
          else if (found.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No saves match.'))
          else
            for (final s in found)
              SaveCard(save: s, space: _labels[s['space_id']] ?? ''),
        ],
      ),
    );
  }
}
