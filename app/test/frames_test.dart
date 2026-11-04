import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/native.dart';
import 'package:reelbrain/core/ui/art_frames.dart';
import 'package:reelbrain/preview/sample.dart';

void main() {
  Future<ImageProvider> providerOf(WidgetTester tester, String stored) async {
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
                width: 120,
                height: 150,
                child:
                    FrameImage(stored: stored, fallback: const SizedBox())))));
    final image = tester.widget<Image>(find.byType(Image));
    return (image.image as ResizeImage).imageProvider;
  }

  testWidgets('demo photos load from the app bundle, frames from the backend',
      (tester) async {
    final asset = await providerOf(tester, 'asset:demo/img/mug.jpg');
    expect((asset as AssetImage).assetName, 'demo/img/mug.jpg');

    addTearDown(() => backendUrl.value = null);
    backendUrl.value = 'https://api.example';
    final frame = await providerOf(tester, '/frames/abc.jpg');
    expect((frame as NetworkImage).url, 'https://api.example/frames/abc.jpg');
  });

  test('every sample photo exists in demo/img, for the demo build', () {
    expect(
        demoBuild, isFalse); // tests and the web preview use preview/img paths
    final now = DateTime(2026, 11, 3, 19, 20);
    final s = sampleState(now);
    final names = <String>{};
    void walk(Object? x) {
      if (x is Map) x.values.forEach(walk);
      if (x is List) x.forEach(walk);
      final m = x is String
          ? RegExp(r'^preview/img/(\w+)\.jpg$').firstMatch(x)
          : null;
      if (m != null) names.add(m.group(1)!);
    }

    walk(s.saves);
    walk(s.items);
    walk(samplePosts(s, now));
    walk(sampleComments(now));
    expect(names, isNotEmpty);
    for (final n in names) {
      expect(File('demo/img/$n.jpg').existsSync(), isTrue, reason: n);
    }
  });
}
