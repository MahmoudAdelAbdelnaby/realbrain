/// Library search (P1-15, kept): every word of the query must appear in the discovery's text,
/// Arabic-normalised the same way as backend/app/search.py.
library;

import '../../core/data/brain.dart';

/// Lowercase, Arabic diacritics (U+0610-061A, U+064B-065F, U+0670) and tatweel (U+0640) dropped,
/// alef/ya/ta-marbuta variants folded. Escaped code points: bidi text can't reorder them.
String normalise(String text) {
  final stripped = text
      .toLowerCase()
      .replaceAll(RegExp('[\\u0610-\\u061A\\u064B-\\u065F\\u0670\\u0640]'), '');
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

/// The searchable text of a save: the backend's search_text when present, else what the save
/// itself carries.
String saveText(Json save) =>
    save['search_text'] as String? ??
    normalise([
      save['summary'],
      save['caption'],
      save['creator'],
      save['source_url'],
      save['note']
    ].whereType<String>().join(' '));

/// Names inside an item that search should find (dishes, tools, places, titles, products).
String itemText(Discovery d) {
  final data = d.data;
  final parts = <String>[d.title, d.detail, d.category.name, d.category.noun];
  for (final key in const ['items', 'exercises', 'claims', 'ingredients']) {
    for (final e in listOf(data[key])) {
      for (final f in const [
        'name',
        'title',
        'text',
        'creator',
        'brand',
        'area',
        'city'
      ]) {
        if (e[f] is String) parts.add(e[f] as String);
      }
      for (final g in (e['genres'] as List?) ?? const []) {
        parts.add('$g');
      }
    }
  }
  for (final t in (data['tags'] as List?) ?? const []) {
    parts.add('$t');
  }
  if (d.note != null) parts.add(d.note!);
  return normalise(parts.join(' '));
}

bool matches(Discovery d, String query) {
  final q = normalise(query);
  if (q.isEmpty) return true;
  final hay = '${saveText(d.save)} ${itemText(d)}';
  return q.split(' ').every(hay.contains);
}

bool saveMatches(Json save, String query) {
  final q = normalise(query);
  if (q.isEmpty) return true;
  final hay = saveText(save);
  return q.split(' ').every(hay.contains);
}

/// Status filter ids and their test.
const statusFilters = {
  'open': 'Open',
  'active': 'In progress',
  'done': 'Finished',
  'archived': 'Archived',
};

bool statusMatches(Discovery d, String? status) => switch (status) {
      null => !d.isArchived,
      'open' => d.isOpen && !d.isActive,
      'active' => d.isActive,
      'done' => d.isDone,
      'archived' => d.isArchived,
      _ => true,
    };
