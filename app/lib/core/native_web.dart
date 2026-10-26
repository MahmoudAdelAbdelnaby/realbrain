import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// Web build (I1: the iPhone home-screen app). The `reelbrain/downloader` channel in Dart, so
/// the screens don't change. Nothing downloads here: a save goes as a link and the backend
/// fetches the video itself (fetch.py: mirror, then yt-dlp on the VM).
Future<FirebaseOptions?> platformSetup() async {
  MethodChannel('reelbrain/downloader', const StandardMethodCodec(),
          webPluginRegistrar)
      .setMethodCallHandler(_handle);
  // Firebase Hosting serves the project's web config, so no key lives in the repo.
  final res = await web.window.fetch('/__/firebase/init.json'.toJS).toDart;
  final c =
      jsonDecode((await res.text().toDart).toDart) as Map<String, dynamic>;
  final host = web.window.location.host;
  return FirebaseOptions(
    apiKey: c['apiKey'] as String,
    appId: c['appId'] as String,
    messagingSenderId: c['messagingSenderId'] as String,
    projectId: c['projectId'] as String,
    storageBucket: c['storageBucket'] as String?,
    // Sign-in on our own domain: Safari blocks the cross-site redirect through firebaseapp.com.
    authDomain: host.endsWith('.web.app') ? host : c['authDomain'] as String?,
  );
}

String? _base;

Future<Object?> _handle(MethodCall call) async {
  final a = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
  switch (call.method) {
    case 'api':
      return _call(
          a['method']! as String, a['path']! as String, a['body'] as String?);
    case 'setBackendUrl':
      _base = (a['url']! as String).replaceFirst(RegExp(r'/+$'), '');
      return null;
    case 'enqueue':
      return _enqueue(a['url']! as String, a['space'] as String? ?? 'me',
          a['hint'] as String?);
    case 'saves':
      return jsonEncode(_saves());
    case 'retryWaiting':
      final waiting = _saves().where((s) => s['status'] == 'waiting').toList();
      for (final s in waiting) {
        unawaited(_send(s));
      }
      return waiting.length;
    case 'openUrl':
      web.window.open(a['url']! as String, '_blank');
      return null;
    case 'share':
      final text = a['text']! as String;
      try {
        await web.window.navigator.share(web.ShareData(text: text)).toDart;
      } catch (_) {
        // No share sheet (desktop) or the user closed it: the clipboard is the fallback.
        await Clipboard.setData(ClipboardData(text: text));
      }
      return null;
    case 'fid': // ponytail: no web push yet (I3)
    case 'initialLink': // invites: she types the code from the join page
      return null;
    default:
      throw MissingPluginException(call.method);
  }
}

/// Same contract as Backend.call in Kotlin: NOT_SIGNED_IN, BACKEND_UNREACHABLE or HTTP_<4xx>.
Future<String> _call(String method, String path, String? body) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw PlatformException(code: 'NOT_SIGNED_IN', message: 'not signed in');
  }
  final base = _base;
  if (base == null) {
    throw PlatformException(
        code: 'BACKEND_UNREACHABLE', message: 'no backend address yet');
  }
  final web.Response res;
  final String text;
  try {
    final token = await user.getIdToken();
    res = await web.window
        .fetch(
            '$base$path'.toJS,
            web.RequestInit(
              method: method,
              headers: {
                'Authorization': 'Bearer $token',
                if (body != null) 'Content-Type': 'application/json',
              }.jsify()! as JSObject,
              body: body?.toJS,
            ))
        .toDart;
    text = (await res.text().toDart).toDart;
  } catch (e) {
    throw PlatformException(code: 'BACKEND_UNREACHABLE', message: '$e');
  }
  final detail =
      '$method $path HTTP ${res.status}: ${text.substring(0, text.length.clamp(0, 200))}';
  if (res.status >= 400 && res.status < 500) {
    throw PlatformException(code: 'HTTP_${res.status}', message: detail);
  }
  if (!res.ok) {
    throw PlatformException(code: 'BACKEND_UNREACHABLE', message: detail);
  }
  return text;
}

// The device's list of saves (the Phone queue screen reads it), newest first.
const _key = 'rb_saves';

List<Map<String, dynamic>> _saves() =>
    (jsonDecode(web.window.localStorage.getItem(_key) ?? '[]') as List)
        .cast<Map<String, dynamic>>();

void _upsert(String id, Map<String, Object?> fields) {
  final list = _saves();
  final i = list.indexWhere((s) => s['id'] == id);
  if (i < 0) {
    list.insert(0, {'id': id, ...fields});
  } else {
    list[i].addAll(fields);
  }
  web.window.localStorage.setItem(_key, jsonEncode(list.take(100).toList()));
}

String _enqueue(String url, String space, String? hint) {
  final id = web.window.crypto.randomUUID();
  final save = {
    'url': url,
    'space': space,
    'hint': hint,
    'status': 'queued',
    'at': DateTime.now().millisecondsSinceEpoch,
  };
  _upsert(id, save);
  unawaited(_send({'id': id, ...save}));
  return id;
}

/// POST /v1/saves, then /no-video so the backend fetches it. The queue id is the client_id,
/// so a resend gets the same save back instead of a duplicate.
Future<void> _send(Map<String, dynamic> s) async {
  final id = s['id'] as String;
  try {
    final created = jsonDecode(await _call(
        'POST',
        '/v1/saves',
        jsonEncode({
          'source_url': s['url'],
          'space_id': s['space'],
          'client_id': id,
          if (s['hint'] != null) 'section_hint': s['hint'],
        }))) as Map<String, dynamic>;
    final saveId = created['save_id'] as String;
    if ((created['status'] ?? 'received') == 'received') {
      await _call('POST', '/v1/saves/$saveId/no-video',
          jsonEncode({'reason': 'WEB_NO_DOWNLOAD'}));
    }
    _upsert(
        id, {'status': 'sent_without_video', 'save_id': saveId, 'error': null});
  } on PlatformException catch (e) {
    final rejected = e.code.startsWith('HTTP_');
    _upsert(id, {
      'status': rejected ? 'upload_failed' : 'waiting',
      'error': e.code,
      'error_detail': e.message,
    });
  }
}
