import '../categories.dart';

typedef Json = Map<String, dynamic>;

/// Save statuses while the backend is still working on it.
const processingStatuses = {
  'received',
  'uploaded',
  'fetching',
  'extracting',
  'enriching'
};

/// Saves that need the person: unsure of the section, or failed. (Caption-only `partial` saves
/// are readable and live in the library, flagged.)
const attentionStatuses = {'needs_review', 'failed'};

List<Json> listOf(Object? v) => [
      for (final e in (v as List?) ?? const [])
        if (e is Map) e.cast<String, dynamic>()
    ];

String? _str(Object? v) {
  final s = v is String ? v.trim() : null;
  return s == null || s.isEmpty ? null : s;
}

String _more(List<Json> l) => l.length > 1 ? ' +${l.length - 1}' : '';

/// One discovery: an extracted item (a recipe, a place list, a film...) with the save it came
/// from. Wraps the Firestore maps; every screen reads through these getters.
class Discovery {
  Discovery(this.item, this.save, {this.number = 0, this.siblings = const []});

  final Json item, save;

  /// Its place in the collection: No. 1 is the first thing ever saved.
  final int number;

  /// Other items extracted from the same save (a recipe reel that also names a restaurant).
  final List<Json> siblings;

  String get section => item['section'] as String? ?? 'other';
  Category get category => categoryOf(section);
  Json get data => (item['data'] as Map?)?.cast<String, dynamic>() ?? const {};

  String get saveId =>
      save['save_id'] as String? ?? item['save_id'] as String? ?? '';
  String get spaceId =>
      save['space_id'] as String? ?? item['space_id'] as String? ?? '';
  String get itemId => item['item_id'] as String? ?? '';

  /// Stable key across lists: save/item.
  String get key => '$saveId/$itemId';

  String get summary => _str(save['summary']) ?? '';

  /// What the discovery is called, per category.
  String get title {
    final d = data;
    switch (section) {
      case 'recipe':
      case 'ideas':
        return _str(d['title']) ?? summary;
      case 'tools':
        final l = listOf(d['items']);
        return l.isEmpty ? summary : '${l.first['name']}${_more(l)}';
      case 'places':
        final l = listOf(d['items']);
        return l.isEmpty ? summary : '${l.first['name']}${_more(l)}';
      case 'entertainment':
        final l = listOf(d['items']);
        return l.isEmpty ? summary : '${l.first['title']}${_more(l)}';
      case 'products':
        final l = listOf(d['items']);
        return l.isEmpty ? summary : '${l.first['name']}${_more(l)}';
      case 'workout':
        final ex = listOf(d['exercises']);
        final named = _str(d['title']);
        if (named != null) return named;
        return summary.isNotEmpty ? summary : '${ex.length}-exercise workout';
      default:
        return summary.isEmpty
            ? (_str(save['source_url']) ?? 'Saved')
            : summary;
    }
  }

  /// The one line under the title: the facts that matter for this kind of thing.
  String get detail {
    final d = data;
    switch (section) {
      case 'recipe':
        return [
          if (d['total_min'] != null) '${d['total_min']} min',
          if (d['servings'] != null) 'serves ${d['servings']}',
          if (save['difficulty'] != null) '${save['difficulty']}',
        ].join(' · ');
      case 'tools':
        final l = listOf(d['items']);
        if (l.isEmpty) return '';
        final v = (l.first['verified'] as Map?) ?? const {};
        final kind = categoryOf('tools').kinds[l.first['kind']];
        final stars = v['stars'] as num?;
        return [
          if (kind != null) kind,
          if (stars != null) '★ ${compactNumber(stars)}',
          if (_str(l.first['use_shown']) != null && stars == null)
            l.first['use_shown'] as String,
        ].join(' · ');
      case 'places':
        final l = listOf(d['items']);
        if (l.isEmpty) return '';
        return [l.first['area'], l.first['city']]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(', ');
      case 'workout':
        final ex = listOf(d['exercises']);
        final mins = workoutMinutes(ex);
        return [
          '${ex.length} exercise${ex.length == 1 ? '' : 's'}',
          if (mins > 0) 'about $mins min',
        ].join(' · ');
      case 'fact_check':
        final claims = listOf(d['claims']);
        return '${claims.length} claim${claims.length == 1 ? '' : 's'}';
      case 'ideas':
        final steps = (d['next_steps'] as List?)?.length ?? 0;
        return steps == 0 ? '' : '$steps next step${steps == 1 ? '' : 's'}';
      case 'entertainment':
        final l = listOf(d['items']);
        if (l.isEmpty) return '';
        final e = l.first;
        final k = kindNouns[e['kind']];
        return [
          if (k != null) '${k[0].toUpperCase()}${k.substring(1)}',
          if (e['year'] != null) '${e['year']}',
          if (_str(e['creator']) != null) e['creator'],
          if (e['kind'] == 'series' && e['seasons'] != null)
            '${e['seasons']} season${e['seasons'] == 1 ? '' : 's'}',
        ].whereType<String>().join(' · ');
      case 'products':
        final l = listOf(d['items']);
        if (l.isEmpty) return '';
        final p = l.first;
        return [
          if (priceText(p) != null) priceText(p)!,
          if (_str(p['merchant']) != null)
            p['merchant'] as String
          else if (_str(p['brand']) != null)
            p['brand'] as String,
        ].join(' · ');
    }
    return '';
  }

  /// The sub-kind (entertainment: movie/series/book), for the glyph and filters.
  String? get kind {
    if (section == 'entertainment' || section == 'tools') {
      final l = listOf(data['items']);
      return l.isEmpty ? null : l.first['kind'] as String?;
    }
    return null;
  }

  String get glyph =>
      section == 'entertainment' && kind != null ? kind! : section;

  /// The main action's words for this one (books are found, films are watched).
  String get action => switch (section) {
        'entertainment' => kind == 'book' ? 'Find the book' : 'Where to watch',
        _ => category.action,
      };

  /// What one of these is called: the category's noun, or the sub-kind's ("film", "book").
  String get noun => section == 'entertainment'
      ? (kindNouns[kind] ?? category.noun)
      : category.noun;

  /// Stored key-frame path (resolved against the backend by FrameImage).
  String? get frame => _str(save['key_frame_url']);

  /// Frames cut at each extracted moment, in reel order.
  List<String> get momentFrames => [
        for (final key in const ['steps', 'exercises', 'claims', 'items'])
          for (final m in listOf(data[key]))
            if (_str(m['frame']) != null) m['frame'] as String,
      ];

  String? get state => item['user_state'] as String?;
  Stamp get stamp => category.stamp(state) ?? category.open;
  bool get isDone => stamp.done && state != null && state != 'to_try';
  bool get isActive => stamp.active;
  bool get isArchived => state == 'archived';
  bool get isOpen => !isDone && !isArchived;

  num? seenBy(String uid) => ((item['seen'] as Map?) ?? const {})[uid] as num?;
  num? get doneAt => item['done_at'] as num?;
  num get createdAt => (save['created_at'] ?? item['created_at'] ?? 0) as num;
  num? get recallAfter => item['recall_after'] as num?;

  String get status => save['status'] as String? ?? 'ready';
  bool get isPartial => status == 'partial';
  String? get platform => save['platform'] as String?;
  String? get creator => _str(save['creator']);
  String? get sourceUrl => _str(save['source_url']);
  String? get note => _str(save['note']);
  String? get goodFor => _str(save['good_for']);
  int? get effortMin => (save['effort_min'] as num?)?.toInt();
  String? get difficulty => _str(save['difficulty']);
  String? get verdict => _str(save['verdict']);
  String? get addedBy => _str(save['shared_by']) ?? _str(save['created_by']);
  List<String> get topics =>
      [for (final t in (save['topics'] as List?) ?? const []) '$t'];

  /// Seconds of every extracted moment, for the moment strip.
  List<double> get moments => [
        for (final v in data.values)
          if (v is List)
            for (final e in v)
              if (e is Map && e['t'] is num) (e['t'] as num).toDouble(),
      ]..sort();

  @override
  bool operator ==(Object other) => other is Discovery && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Rough minutes for a workout: work + rest across sets (defaults where the video is silent).
int workoutMinutes(List<Json> exercises) {
  var secs = 0;
  for (final (n, e) in exercises.indexed) {
    final sets = ((e['sets'] as num?)?.toInt() ?? 1).clamp(1, 10);
    final reps = (e['reps'] as num?)?.toInt();
    final work =
        (e['duration_s'] as num?)?.toInt() ?? (reps != null ? reps * 3 : 40);
    final rest = (e['rest_s'] as num?)?.toInt() ?? 20;
    secs += sets * work + (n == exercises.length - 1 ? sets - 1 : sets) * rest;
  }
  return (secs / 60).ceil();
}

String compactNumber(num n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

/// "EGP 450", "$29", "under 500 pounds", as said; null when the video gave no price.
String? priceText(Json p) {
  final said = _str(p['price_text']);
  final price = p['price'] as num?;
  if (price != null) {
    final cur = _str(p['currency']);
    final amount = price == price.roundToDouble()
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    return cur == null ? amount : '$cur $amount';
  }
  return said;
}

/// A group (or the household space) as the app shows it.
class GroupInfo {
  const GroupInfo({
    required this.id,
    required this.name,
    this.members = const [],
    this.names = const {},
    this.isDefault = false,
    this.createdBy,
  });

  final String id, name;
  final List<String> members;
  final Map<String, String> names;
  final bool isDefault;
  final String? createdBy;

  String nameOf(String uid) => names[uid] ?? 'Someone';

  factory GroupInfo.fromSpace(String id, Json space,
          {bool isDefault = false}) =>
      GroupInfo(
        id: id,
        name: _str(space['name']) ?? 'Group',
        members: [
          for (final m in (space['members'] as List?) ?? const []) '$m'
        ],
        names: {
          for (final e in ((space['member_names'] as Map?) ?? const {}).entries)
            '${e.key}': '${e.value}'
        },
        isDefault: isDefault,
        createdBy: space['created_by'] as String?,
      );
}

/// Settings the app reads (users/{uid}.settings).
class BrainSettings {
  const BrainSettings(
      {this.lang = 'system',
      this.theme = 'system',
      this.recall = true,
      this.puzzle = true});
  final String lang, theme;
  final bool recall, puzzle;

  factory BrainSettings.from(Json? s) => BrainSettings(
        lang: s?['lang'] as String? ?? 'system',
        theme: s?['theme'] as String? ?? 'system',
        recall: s?['recall'] as bool? ?? true,
        puzzle: s?['puzzle'] as bool? ?? true,
      );
}

/// Everything the app shows, at one moment. Built by a [Repo] from Firestore (or sample data)
/// and handed to every screen; derived lists are computed once per snapshot.
class BrainState {
  BrainState({
    this.loaded = false,
    this.error,
    this.uid = '',
    this.userName = '',
    this.photoUrl,
    this.spaces = const {},
    this.groups = const [],
    List<Json> saves = const [],
    this.items = const [],
    this.lists = const [],
    this.settings = const BrainSettings(),
  }) : saves = [...saves]..sort((a, b) => ((b['created_at'] ?? 0) as num)
            .compareTo((a['created_at'] ?? 0) as num));

  final bool loaded;
  final String? error;
  final String uid, userName;
  final String? photoUrl;

  /// Share targets: `me` and (if any) `home` → space ids.
  final Map<String, String> spaces;
  final List<GroupInfo> groups;

  /// Newest first.
  final List<Json> saves;
  final List<Json> items;
  final List<Json> lists;
  final BrainSettings settings;

  String? get meSpace => spaces['me'];

  GroupInfo? group(String? id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  bool isGroupSpace(String id) => groups.any((g) => g.id == id);

  /// No. 1 is the oldest save.
  late final Map<String, int> numbers = () {
    final asc = [...saves]..sort((a, b) => ((a['created_at'] ?? 0) as num)
        .compareTo((b['created_at'] ?? 0) as num));
    return {
      for (final (i, s) in asc.indexed) '${s['save_id']}': i + 1,
    };
  }();

  /// Every readable discovery (ready or caption-only saves, known categories), newest first.
  late final List<Discovery> discoveries = () {
    final bySave = <String, List<Json>>{};
    for (final i in items) {
      if (!isKnownCategory(i['section'] as String?)) continue;
      (bySave[i['save_id'] as String? ?? ''] ??= []).add(i);
    }
    return [
      for (final s in saves)
        if (s['status'] == 'ready' || s['status'] == 'partial')
          for (final i in bySave[s['save_id']] ?? const <Json>[])
            Discovery(i, s, number: numbers['${s['save_id']}'] ?? 0, siblings: [
              for (final o in bySave[s['save_id']]!)
                if (!identical(o, i)) o
            ]),
    ];
  }();

  /// Saves still being understood, newest first.
  late final List<Json> processing = [
    for (final s in saves)
      if (processingStatuses.contains(s['status'])) s
  ];

  /// Saves that need the person (unsure section, failed).
  late final List<Json> attention = [
    for (final s in saves)
      if (attentionStatuses.contains(s['status'])) s
  ];

  /// Plain saves with no section (filed as "none"), still findable in search.
  late final List<Json> plain = [
    for (final s in saves)
      if ((s['status'] == 'ready' || s['status'] == 'partial') &&
          ((s['sections'] as List?) ?? const []).isEmpty)
        s
  ];

  Discovery? find(String key) {
    for (final d in discoveries) {
      if (d.key == key) return d;
    }
    return null;
  }

  List<Discovery> forSave(String saveId) => [
        for (final d in discoveries)
          if (d.saveId == saveId) d
      ];

  List<Discovery> inCategory(String id) => [
        for (final d in discoveries)
          if (d.section == id) d
      ];

  List<Discovery> inSpace(String spaceId) => [
        for (final d in discoveries)
          if (d.spaceId == spaceId) d
      ];

  BrainState copyWith({
    bool? loaded,
    String? error,
    String? uid,
    String? userName,
    String? photoUrl,
    Map<String, String>? spaces,
    List<GroupInfo>? groups,
    List<Json>? saves,
    List<Json>? items,
    List<Json>? lists,
    BrainSettings? settings,
  }) =>
      BrainState(
        loaded: loaded ?? this.loaded,
        error: error ?? this.error,
        uid: uid ?? this.uid,
        userName: userName ?? this.userName,
        photoUrl: photoUrl ?? this.photoUrl,
        spaces: spaces ?? this.spaces,
        groups: groups ?? this.groups,
        saves: saves ?? this.saves,
        items: items ?? this.items,
        lists: lists ?? this.lists,
        settings: settings ?? this.settings,
      );
}
