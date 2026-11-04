import 'dart:async';

import 'package:flutter/foundation.dart';

import '../categories.dart';
import 'repo.dart';

/// Sample data in memory, with every action really applied (stamps, notes, shares, RSVPs,
/// comments). Used by widget tests and the screenshot preview (lib/preview); never by the app.
class DemoRepo extends Repo {
  DemoRepo(BrainState initial,
      {Map<String, List<Json>> posts = const {},
      Map<String, List<Json>> comments = const {},
      this.clock})
      : _state = ValueNotifier(initial) {
    for (final e in posts.entries) {
      _posts[e.key] = [
        for (final p in e.value) {...p}
      ];
    }
    for (final e in comments.entries) {
      _comments[e.key] = [
        for (final c in e.value) {...c}
      ];
    }
  }

  final ValueNotifier<BrainState> _state;
  final _posts = <String, List<Json>>{};
  final _comments = <String, List<Json>>{};
  final _postCtl = <String, StreamController<List<Json>>>{};
  final _commentCtl = <String, StreamController<List<Json>>>{};

  /// Fixed "now" for tests; the wall clock otherwise.
  final DateTime Function()? clock;

  /// Every action, in order (tests assert on it).
  final log = <String>[];

  @override
  ValueListenable<BrainState> get state => _state;

  double get _t =>
      ((clock?.call() ?? DateTime.now()).millisecondsSinceEpoch) / 1000;

  void _set(BrainState s) => _state.value = s;

  void _patchItem(Discovery d, Json fields) {
    final s = _state.value;
    _set(s.copyWith(items: [
      for (final i in s.items)
        if (i['save_id'] == d.saveId && i['item_id'] == d.itemId)
          {...i, ...fields}
        else
          i
    ]));
  }

  void _patchSave(String saveId, Json fields) {
    final s = _state.value;
    _set(s.copyWith(saves: [
      for (final sv in s.saves)
        if (sv['save_id'] == saveId) {...sv, ...fields} else sv
    ]));
  }

  @override
  Future<void> setStamp(Discovery d, String state) async {
    log.add('stamp ${d.key} $state');
    final done = d.category.stamp(state)?.done ?? false;
    _patchItem(d, {'user_state': state, 'done_at': done ? _t : null});
  }

  @override
  Future<void> markSeen(Discovery d) async {
    final uid = _state.value.uid;
    final last = d.seenBy(uid);
    if (last != null && _t - last < 3600) return;
    log.add('seen ${d.key}');
    _patchItem(d, {
      'seen': {...((d.item['seen'] as Map?) ?? const {}), uid: _t}
    });
  }

  @override
  Future<void> snooze(Discovery d, DateTime until) async {
    log.add('snooze ${d.key}');
    _patchItem(d, {'recall_after': until.millisecondsSinceEpoch / 1000});
  }

  @override
  Future<void> archive(Discovery d) async {
    log.add('archive ${d.key}');
    _patchItem(d, {'user_state': 'archived', 'recall_after': null});
  }

  @override
  Future<void> setNote(Json save, String? note) async {
    log.add('note ${save['save_id']}');
    _patchSave(save['save_id'] as String, {'note': note});
  }

  @override
  Future<void> fileUnder(Json save, String section) async {
    log.add('file ${save['save_id']} $section');
    _patchSave(save['save_id'] as String, {
      'status': section == 'none' ? 'ready' : 'extracting',
      'step_text': section == 'none' ? null : 'Re-reading the video',
      if (section == 'none') 'sections': <String>[],
    });
  }

  @override
  Future<void> retry(Json save) async {
    log.add('retry ${save['save_id']}');
    _patchSave(save['save_id'] as String,
        {'status': 'received', 'step_text': 'Retrying'});
  }

  @override
  Future<void> deepDive(Json save) async => log.add('deep ${save['save_id']}');

  int _n = 0;

  @override
  Future<void> saveLink(String url, {String space = 'me', String? hint}) async {
    log.add('link $url $space ${hint ?? 'auto'}');
    _addProcessing({'source_url': url, 'platform': _platform(url)}, space);
  }

  @override
  Future<void> saveIdea(String text,
      {String space = 'me', String? hint}) async {
    log.add('idea $space ${hint ?? 'auto'}');
    _addProcessing({'caption': text, 'platform': 'idea'}, space);
  }

  void _addProcessing(Json fields, String space) {
    final s = _state.value;
    final id = 'new${_n++}';
    _set(s.copyWith(saves: [
      {
        ...fields,
        'save_id': id,
        'space_id': s.spaces[space] ?? s.spaces['me'],
        'status': 'extracting',
        'step_text': 'Watching the video',
        'created_at': _t,
        'created_by': s.uid,
      },
      ...s.saves,
    ]));
  }

  static String _platform(String url) {
    final h = Uri.tryParse(url)?.host ?? '';
    if (h.contains('tiktok')) return 'tiktok';
    if (h.contains('instagram')) return 'instagram';
    if (h.contains('youtu')) return 'youtube';
    return 'other';
  }

  @override
  Future<void> createCollection(
      {required String section,
      required String name,
      required List<String> refs,
      String space = 'me'}) async {
    log.add('collection $section $name ${refs.length}');
    final s = _state.value;
    final id = 'l${s.lists.length + 1}';
    _set(s.copyWith(lists: [
      ...s.lists,
      {
        'list_id': id,
        'space_id': s.spaces[space] ?? s.spaces['me'],
        'section': section,
        'name': name,
        'item_refs': refs,
        'path': 'spaces/${s.spaces['me']}/lists/$id',
      }
    ]));
  }

  @override
  Future<void> updateCollection(Json list, List<String> refs) async {
    final s = _state.value;
    _set(s.copyWith(lists: [
      for (final l in s.lists)
        if (l['list_id'] == list['list_id']) {...l, 'item_refs': refs} else l
    ]));
  }

  @override
  Future<void> setOverride(Json list, String key, Json fields) async {
    final s = _state.value;
    _set(s.copyWith(lists: [
      for (final l in s.lists)
        if (l['list_id'] == list['list_id'])
          {
            ...l,
            'overrides': {
              ...((l['overrides'] as Map?) ?? const {}),
              key: {
                ...(((l['overrides'] as Map?) ?? const {})[key] as Map? ??
                    const {}),
                ...fields
              },
            }
          }
        else
          l
    ]));
  }

  @override
  Future<GroupInvite> createGroup(String name) async {
    log.add('group $name');
    final s = _state.value;
    final id = 'g_${name.toLowerCase().replaceAll(RegExp('[^a-z]'), '')}';
    _set(s.copyWith(groups: [
      ...s.groups,
      GroupInfo(
          id: id,
          name: name,
          members: [s.uid],
          names: {s.uid: s.userName},
          isDefault: s.groups.isEmpty),
    ]));
    return (
      groupId: id,
      url: 'https://reelbrain-dev.web.app/join/k7mq2xpd',
      code: 'k7mq2xpd'
    );
  }

  @override
  Future<GroupInvite> invite(String groupId) async => (
        groupId: groupId,
        url: 'https://reelbrain-dev.web.app/join/k7mq2xpd',
        code: 'k7mq2xpd'
      );

  @override
  Future<String> join(String code) async {
    log.add('join $code');
    if (code.trim().length < 8) {
      throw StateError('That invite or group no longer exists.');
    }
    return _state.value.groups.first.id;
  }

  @override
  Future<void> setDefaultGroup(String groupId) async {
    final s = _state.value;
    _set(s.copyWith(spaces: {
      ...s.spaces,
      'home': groupId
    }, groups: [
      for (final g in s.groups)
        GroupInfo(
            id: g.id,
            name: g.name,
            members: g.members,
            names: g.names,
            createdBy: g.createdBy,
            isDefault: g.id == groupId)
    ]));
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    log.add('leave $groupId');
    final s = _state.value;
    _set(s.copyWith(groups: [
      for (final g in s.groups)
        if (g.id != groupId) g
    ]));
  }

  StreamController<List<Json>> _ctl(Map<String, StreamController<List<Json>>> m,
          String key, List<Json> Function() now) =>
      m.putIfAbsent(key, () {
        late StreamController<List<Json>> c;
        c = StreamController<List<Json>>.broadcast(
            onListen: () => c.add(now()));
        return c;
      });

  List<Json> _sortedPosts(String g) => [...?_posts[g]]
    ..sort((a, b) => ((b['at'] ?? 0) as num).compareTo((a['at'] ?? 0) as num));

  @override
  Stream<List<Json>> posts(String groupId) async* {
    yield _sortedPosts(groupId);
    yield* _ctl(_postCtl, groupId, () => _sortedPosts(groupId)).stream;
  }

  @override
  Stream<List<Json>> comments(String groupId, String postId) async* {
    final key = '$groupId/$postId';
    yield [...?_comments[key]];
    yield* _ctl(_commentCtl, key, () => [...?_comments[key]]).stream;
  }

  void _emitPosts(String g) => _postCtl[g]?.add(_sortedPosts(g));

  @override
  Future<void> share(Discovery d, String groupId,
      {String kind = 'share', DateTime? when, String? text}) async {
    log.add('share ${d.key} $groupId $kind');
    final s = _state.value;
    final post = {
      'post_id': 'p${DateTime.now().microsecondsSinceEpoch}',
      'kind': kind,
      'by': s.uid,
      'by_name': s.userName,
      'at': _t,
      'section': d.section,
      'noun': d.noun,
      'title': d.title,
      'detail': d.detail,
      'frame': d.frame,
      'save_id': d.saveId,
      'item_id': d.itemId,
      if (when != null) 'when': when.millisecondsSinceEpoch / 1000,
      if (text != null) 'text': text,
      'rsvp': {
        if (kind != 'share') s.uid: kind == 'challenge' ? 'in' : 'going'
      },
      'likes': <String, Object>{},
      'comment_count': 0,
    };
    (_posts[groupId] ??= []).add(post);
    _emitPosts(groupId);
  }

  @override
  Future<void> react(
      String groupId, String postId, String field, Object? value) async {
    log.add('react $postId $field $value');
    final uid = _state.value.uid;
    for (final p in _posts[groupId] ?? <Json>[]) {
      if (p['post_id'] == postId) {
        final m = {...((p[field] as Map?) ?? const {})};
        if (value == null) {
          m.remove(uid);
        } else {
          m[uid] = value;
        }
        p[field] = m;
      }
    }
    _emitPosts(groupId);
  }

  @override
  Future<void> comment(String groupId, String postId,
      {String? text, Uint8List? photo, String kind = 'comment'}) async {
    log.add('comment $postId $kind');
    final s = _state.value;
    final key = '$groupId/$postId';
    (_comments[key] ??= []).add({
      'by': s.uid,
      'by_name': s.userName,
      'text': text,
      'kind': kind,
      'at': _t,
      if (photo != null) 'photo': 'preview/img/proof.jpg',
    });
    for (final p in _posts[groupId] ?? <Json>[]) {
      if (p['post_id'] == postId) {
        p['comment_count'] = ((p['comment_count'] ?? 0) as num) + 1;
        if (kind == 'proof' || kind == 'result') {
          p['rsvp'] = {...((p['rsvp'] as Map?) ?? const {}), s.uid: 'done'};
        }
      }
    }
    _commentCtl[key]?.add([...?_comments[key]]);
    _emitPosts(groupId);
  }

  @override
  Future<Json> settingsDetail() async => {
        'settings': {
          'lang': _state.value.settings.lang,
          'theme': _state.value.settings.theme,
          'recall': _state.value.settings.recall,
          'puzzle': _state.value.settings.puzzle,
        },
        'saves_today': 3,
        'gemini': {
          'keys': 2,
          'usage_today': [
            {'model': 'gemini-3.6-flash', 'used': 3, 'free_per_day': 20},
            {'model': 'gemini-3.5-flash-lite', 'used': 1, 'free_per_day': 500},
          ],
        },
      };

  @override
  Future<void> patchSettings(Json change) async {
    log.add('settings $change');
    final s = _state.value.settings;
    _set(_state.value.copyWith(
        settings: BrainSettings(
      lang: change['lang'] as String? ?? s.lang,
      theme: change['theme'] as String? ?? s.theme,
      recall: change['recall'] as bool? ?? s.recall,
      puzzle: change['puzzle'] as bool? ?? s.puzzle,
    )));
    appPrefs.value =
        (lang: _state.value.settings.lang, theme: _state.value.settings.theme);
  }

  @override
  Future<String> newSaveKey() async => 'demo-key-3f9a';

  @override
  Future<List<Json>> phoneQueue() async => [
        {
          'url': 'https://www.tiktok.com/@chefaya/video/1',
          'space': 'me',
          'status': 'downloaded',
          'size_bytes': 8400000,
          'duration_s': 48,
          'download_ms': 4100
        },
      ];

  @override
  Future<void> refresh() async => log.add('refresh');

  @override
  Future<void> signOut() async => log.add('sign out');

  /// Every state a category allows (sanity check for tests).
  static Set<String> get states => allStates;
}
