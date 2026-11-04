import 'package:flutter/foundation.dart';

import 'brain.dart';

export 'brain.dart';

/// App-wide language and theme (users/{uid}.settings). MaterialApp listens to this.
final appPrefs = ValueNotifier<({String lang, String theme})>(
    (lang: 'system', theme: 'system'));

/// An invite to a group: the link to share and the code to read aloud.
typedef GroupInvite = ({String groupId, String url, String code});

/// Every read and write the screens make. [FirestoreRepo] talks to Firestore and the backend;
/// [DemoRepo] keeps sample data in memory (tests, previews, screenshots).
abstract class Repo {
  /// Set once at start-up (main.dart, the preview entry point, or a test).
  static late Repo instance;

  /// The live snapshot every screen draws from.
  ValueListenable<BrainState> get state;

  BrainState get now => state.value;

  // --- discoveries ---

  /// Sets the item's status (Firestore `user_state`); done states also stamp `done_at`.
  Future<void> setStamp(Discovery d, String state);

  /// Records that you opened it (`seen.{uid}`), at most once an hour.
  Future<void> markSeen(Discovery d);

  /// Out of Today and Recall until [until] (Recall's "Not now").
  Future<void> snooze(Discovery d, DateTime until);

  /// Out of Recall for good; still in the library.
  Future<void> archive(Discovery d);

  /// "Why you saved this" in your words (the save's `note`).
  Future<void> setNote(Json save, String? note);

  /// Re-file under another category ("none" keeps it as a plain save).
  Future<void> fileUnder(Json save, String section);
  Future<void> retry(Json save);

  /// Fact Check "Dive deeper".
  Future<void> deepDive(Json save);

  // --- capture ---

  Future<void> saveLink(String url, {String space = 'me', String? hint});
  Future<void> saveIdea(String text, {String space = 'me', String? hint});

  // --- collections (routines, grocery lists, watchlists) ---

  Future<void> createCollection(
      {required String section,
      required String name,
      required List<String> refs,
      String space = 'me'});
  Future<void> updateCollection(Json list, List<String> refs);

  /// A routine's per-exercise edit (P1-13): `overrides.{save/item#n}.{field}`.
  Future<void> setOverride(Json list, String key, Json fields);

  // --- groups ---

  Future<GroupInvite> createGroup(String name);
  Future<GroupInvite> invite(String groupId);

  /// Joins with a code (or a full invite link); returns the group id.
  Future<String> join(String code);
  Future<void> setDefaultGroup(String groupId);
  Future<void> leaveGroup(String groupId);

  /// The group's wall, newest first.
  Stream<List<Json>> posts(String groupId);
  Stream<List<Json>> comments(String groupId, String postId);

  /// Shares a discovery into a group (the group gets a copy) with a post of [kind]: `share`,
  /// `plan` (places), `cook` (recipes), `challenge` (workouts).
  Future<void> share(Discovery d, String groupId,
      {String kind = 'share', DateTime? when, String? text});

  /// Your RSVP, join or like on a post (`rsvp` / `likes`), null to take it back.
  Future<void> react(
      String groupId, String postId, String field, Object? value);
  Future<void> comment(String groupId, String postId,
      {String? text, Uint8List? photo, String kind = 'comment'});

  // --- settings and account ---

  /// GET /v1/settings: settings plus today's saves and model usage.
  Future<Json> settingsDetail();
  Future<void> patchSettings(Json change);
  Future<String> newSaveKey();

  /// Android only: what the on-device downloader did with each share.
  Future<List<Json>> phoneQueue();

  /// Pull to refresh: resend saves that waited on the phone.
  Future<void> refresh();
  Future<void> signOut();
}
