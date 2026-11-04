import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../native.dart';
import 'repo.dart';

/// The real app: live Firestore listeners for every space you're in (personal, household and
/// groups), writes the rules allow straight to Firestore, everything else through the backend.
class FirestoreRepo extends Repo {
  FirestoreRepo() {
    _start();
  }

  final _state = ValueNotifier(BrainState());
  final _subs = <StreamSubscription<Object?>>[];
  final _spaceSubs = <String, List<StreamSubscription<Object?>>>{};
  final _saves = <String, List<Json>>{};
  final _items = <String, List<Json>>{};
  final _lists = <String, List<Json>>{};
  final _spaceDocs = <String, Json>{};
  Json _user = const {};
  bool _rebuildQueued = false;
  final _loaded = <String>{};

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  User? get _me => FirebaseAuth.instance.currentUser;

  @override
  ValueListenable<BrainState> get state => _state;

  void _start() {
    final uid = _me?.uid;
    if (uid == null) return;
    _subs.add(_db.doc('users/$uid').snapshots().listen((snap) {
      _user = snap.data() ?? const {};
      final s = (_user['settings'] as Map?)?.cast<String, dynamic>();
      appPrefs.value = (
        lang: s?['lang'] as String? ?? 'system',
        theme: s?['theme'] as String? ?? 'system'
      );
      _follow(_spaceIds());
      _queue();
    }, onError: _fail));
  }

  Map<String, String> get _shareTargets =>
      (_user['spaces'] as Map?)?.cast<String, String>() ?? const {};

  /// Group ids: the backend's `groups` list, or the household for accounts made before V5.
  List<String> get _groupIds {
    final listed = [
      for (final g in (_user['groups'] as List?) ?? const []) '$g'
    ];
    final home = _shareTargets['home'];
    return {...listed, if (home != null) home}.toList();
  }

  Set<String> _spaceIds() => {..._shareTargets.values, ..._groupIds};

  void _follow(Set<String> ids) {
    for (final gone in _spaceSubs.keys.toSet().difference(ids)) {
      for (final s in _spaceSubs.remove(gone)!) {
        s.cancel();
      }
      _saves.remove(gone);
      _items.remove(gone);
      _lists.remove(gone);
      _spaceDocs.remove(gone);
    }
    for (final id in ids.difference(_spaceSubs.keys.toSet())) {
      _spaceSubs[id] = [
        _db
            .collection('spaces/$id/saves')
            .orderBy('created_at', descending: true)
            .snapshots()
            .listen((q) {
          _saves[id] = [for (final d in q.docs) d.data()];
          _loaded.add(id);
          _queue();
        }, onError: _fail),
        _db
            .collectionGroup('items')
            .where('space_id', isEqualTo: id)
            .snapshots()
            .listen((q) {
          _items[id] = [for (final d in q.docs) d.data()];
          _queue();
        }, onError: _fail),
        _db.collection('spaces/$id/lists').snapshots().listen((q) {
          _lists[id] = [
            for (final d in q.docs) {...d.data(), 'path': d.reference.path}
          ];
          _queue();
        }, onError: (_) {}),
        _db.doc('spaces/$id').snapshots().listen((s) {
          _spaceDocs[id] = s.data() ?? const {};
          _queue();
        }, onError: (_) {}),
      ];
    }
    if (ids.isEmpty) {
      _queue(); // backend not reached yet: still "loaded", just empty
    }
  }

  void _fail(Object e) {
    debugPrint('Realbrain data: $e');
    _state.value = _state.value.copyWith(error: '$e', loaded: true);
  }

  void _queue() {
    if (_rebuildQueued) return;
    _rebuildQueued = true;
    scheduleMicrotask(() {
      _rebuildQueued = false;
      _rebuild();
    });
  }

  void _rebuild() {
    final me = _me;
    final home = _shareTargets['home'];
    final ids = _spaceIds();
    _state.value = BrainState(
      loaded: ids.isEmpty || ids.every(_loaded.contains),
      error: _state.value.error,
      uid: me?.uid ?? '',
      userName: (me?.displayName ?? _user['name'] as String? ?? '').trim(),
      photoUrl: me?.photoURL,
      spaces: _shareTargets,
      groups: [
        for (final id in _groupIds)
          GroupInfo.fromSpace(id, _spaceDocs[id] ?? const {'name': 'Group'},
              isDefault: id == home),
      ],
      saves: [for (final l in _saves.values) ...l],
      items: [for (final l in _items.values) ...l],
      lists: [for (final l in _lists.values) ...l],
      settings: BrainSettings.from(
          (_user['settings'] as Map?)?.cast<String, dynamic>()),
    );
  }

  DocumentReference<Json> _itemRef(Discovery d) =>
      _db.doc('spaces/${d.spaceId}/saves/${d.saveId}/items/${d.itemId}');

  double _epoch([DateTime? t]) =>
      (t ?? DateTime.now()).millisecondsSinceEpoch / 1000;

  // --- discoveries ---

  @override
  Future<void> setStamp(Discovery d, String state) {
    final done = d.category.stamp(state)?.done ?? false;
    return _itemRef(d).update({
      'user_state': state,
      'done_at': done ? _epoch() : null,
    });
  }

  @override
  Future<void> markSeen(Discovery d) async {
    final uid = _me?.uid;
    if (uid == null || d.itemId.isEmpty) return;
    final last = d.seenBy(uid);
    if (last != null && _epoch() - last < 3600) return;
    await _itemRef(d).update({'seen.$uid': _epoch()});
  }

  @override
  Future<void> snooze(Discovery d, DateTime until) =>
      _itemRef(d).update({'recall_after': _epoch(until)});

  @override
  Future<void> archive(Discovery d) =>
      _itemRef(d).update({'user_state': 'archived', 'recall_after': null});

  @override
  Future<void> setNote(Json save, String? note) => _db
      .doc('spaces/${save['space_id']}/saves/${save['save_id']}')
      .update({'note': note == null || note.isEmpty ? null : note});

  @override
  Future<void> fileUnder(Json save, String section) =>
      api('POST', '/v1/saves/${save['save_id']}/section', {'section': section});

  @override
  Future<void> retry(Json save) =>
      api('POST', '/v1/saves/${save['save_id']}/retry');

  @override
  Future<void> deepDive(Json save) =>
      api('POST', '/v1/saves/${save['save_id']}/deep-dive');

  // --- capture ---

  @override
  Future<void> saveLink(String url, {String space = 'me', String? hint}) =>
      native
          .invokeMethod('enqueue', {'url': url, 'space': space, 'hint': hint});

  @override
  Future<void> saveIdea(String text, {String space = 'me', String? hint}) =>
      api('POST', '/v1/saves',
          {'idea': text, 'space_id': space, 'section_hint': hint});

  // --- collections ---

  @override
  Future<void> createCollection(
      {required String section,
      required String name,
      required List<String> refs,
      String space = 'me'}) async {
    final r = await api(
        'POST', '/v1/spaces/$space/lists', {'section': section, 'name': name});
    await _db
        .doc('spaces/${r['space_id']}/lists/${r['list_id']}')
        .update({'item_refs': refs});
  }

  @override
  Future<void> updateCollection(Json list, List<String> refs) =>
      _db.doc(list['path'] as String).update({'item_refs': refs});

  @override
  Future<void> setOverride(Json list, String key, Json fields) =>
      _db.doc(list['path'] as String).update({
        for (final e in fields.entries)
          FieldPath(['overrides', key, e.key]): e.value
      });

  // --- groups ---

  GroupInvite _invite(Json r, String id) => (
        groupId: r['space_id'] as String? ?? id,
        url: r['invite_url'] as String? ?? '',
        code: r['code'] as String? ??
            (r['invite_url'] as String? ?? '').split('/').last,
      );

  @override
  Future<GroupInvite> createGroup(String name) async =>
      _invite(await api('POST', '/v1/groups', {'name': name}), '');

  @override
  Future<GroupInvite> invite(String groupId) async =>
      _invite(await api('POST', '/v1/spaces/$groupId/invite'), groupId);

  @override
  Future<String> join(String code) async {
    final c = inviteCode(code) ?? code.trim().toLowerCase();
    final r = await api('POST', '/v1/invites/$c/accept');
    return r['space_id'] as String;
  }

  @override
  Future<void> setDefaultGroup(String groupId) =>
      api('POST', '/v1/groups/$groupId/default');

  @override
  Future<void> leaveGroup(String groupId) =>
      api('POST', '/v1/groups/$groupId/leave');

  @override
  Stream<List<Json>> posts(String groupId) => _db
      .collection('spaces/$groupId/posts')
      .orderBy('at', descending: true)
      .limit(60)
      .snapshots()
      .map((q) => [
            for (final d in q.docs) {...d.data(), 'post_id': d.id}
          ]);

  @override
  Stream<List<Json>> comments(String groupId, String postId) => _db
      .collection('spaces/$groupId/posts/$postId/comments')
      .orderBy('at')
      .snapshots()
      .map((q) => [for (final d in q.docs) d.data()]);

  @override
  Future<void> share(Discovery d, String groupId,
          {String kind = 'share', DateTime? when, String? text}) =>
      api('POST', '/v1/saves/${d.saveId}/share', {
        'space_id': groupId,
        'item_id': d.itemId,
        'kind': kind,
        if (when != null) 'when': _epoch(when),
        if (text != null && text.isNotEmpty) 'text': text,
      });

  @override
  Future<void> react(
      String groupId, String postId, String field, Object? value) {
    final uid = _me!.uid;
    return _db
        .doc('spaces/$groupId/posts/$postId')
        .update({'$field.$uid': value ?? FieldValue.delete()});
  }

  @override
  Future<void> comment(String groupId, String postId,
          {String? text, Uint8List? photo, String kind = 'comment'}) =>
      api('POST', '/v1/spaces/$groupId/posts/$postId/comments', {
        'kind': kind,
        if (text != null && text.isNotEmpty) 'text': text,
        if (photo != null) 'photo_b64': base64Encode(photo),
      });

  // --- settings and account ---

  @override
  Future<Json> settingsDetail() => api('GET', '/v1/settings');

  @override
  Future<void> patchSettings(Json change) =>
      api('PATCH', '/v1/settings', change);

  @override
  Future<String> newSaveKey() async =>
      (await api('POST', '/v1/me/save-key'))['key'] as String;

  @override
  Future<List<Json>> phoneQueue() async {
    try {
      final raw = await native.invokeMethod<String>('saves') ?? '[]';
      return (jsonDecode(raw) as List).cast<Json>();
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> refresh() async {
    await native.invokeMethod('retryWaiting');
  }

  @override
  Future<void> signOut() async {
    for (final s in _subs) {
      await s.cancel();
    }
    for (final l in _spaceSubs.values) {
      for (final s in l) {
        await s.cancel();
      }
    }
    _subs.clear();
    _spaceSubs.clear();
    await FirebaseAuth.instance.signOut();
  }
}
