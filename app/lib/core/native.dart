import 'dart:convert';

import 'package:flutter/services.dart';

/// The Android side: downloader, background saves, backend calls (signed in as the Firebase user),
/// the share sheet and invite links. One channel, so the app has one HTTP client and one auth path.
const native = MethodChannel('reelbrain/downloader');

/// Backend call as the signed-in user. Throws [PlatformException] with code NOT_SIGNED_IN,
/// BACKEND_UNREACHABLE or `HTTP_<status>`.
Future<Map<String, dynamic>> api(
  String method,
  String path, [
  Map<String, dynamic>? body,
]) async {
  final text = await native.invokeMethod<String>('api', {
    'method': method,
    'path': path,
    'body': body == null ? null : jsonEncode(body),
  });
  return jsonDecode(text ?? '{}') as Map<String, dynamic>;
}

Future<void> shareText(String text) =>
    native.invokeMethod('share', {'text': text});

/// Plain-language message for an [api] failure.
String apiError(Object e) => switch (e) {
      PlatformException(code: 'BACKEND_UNREACHABLE') =>
        "Can't reach the Reelbrain backend. Is the PC on and on the same Wi-Fi?",
      PlatformException(code: 'NOT_SIGNED_IN') => 'Sign in first.',
      PlatformException(code: 'HTTP_404') =>
        'That invite or space no longer exists.',
      PlatformException(code: 'HTTP_410') =>
        'This invite has expired. Ask for a new link.',
      PlatformException(:final message) => message ?? 'Something went wrong.',
      _ => '$e',
    };

/// Invite code from https://reelbrain-dev.web.app/join/<code>, or null.
String? inviteCode(String? link) {
  final uri = link == null ? null : Uri.tryParse(link);
  if (uri == null ||
      uri.host != 'reelbrain-dev.web.app' ||
      uri.pathSegments.length != 2 ||
      uri.pathSegments[0] != 'join') {
    return null;
  }
  final code = uri.pathSegments[1].toLowerCase();
  return RegExp(r'^[a-z0-9]{8}$').hasMatch(code) ? code : null;
}
