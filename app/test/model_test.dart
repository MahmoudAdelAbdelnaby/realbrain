import 'dart:io';

import 'package:flutter_test/flutter_test.dart' hide matches;
import 'package:reelbrain/core/categories.dart';
import 'package:reelbrain/core/data/brain.dart';
import 'package:reelbrain/core/native.dart';
import 'package:reelbrain/features/capture/capture_sheet.dart';
import 'package:reelbrain/features/library/search.dart';
import 'package:reelbrain/features/places/places_map.dart';
import 'package:reelbrain/core/links.dart';
import 'package:reelbrain/features/viewer/viewer_screen.dart';
import 'package:reelbrain/preview/sample.dart';

final now = DateTime(2026, 11, 3, 19, 20);
final s = sampleState(now);
Discovery find(String prefix) =>
    s.discoveries.firstWhere((d) => d.title.startsWith(prefix));

void main() {
  group('categories', () {
    test('each has an open first stamp and a finishing one', () {
      for (final c in categories) {
        expect(c.stamps.first.state, 'to_try', reason: c.id);
        expect(c.finished.done, isTrue, reason: c.id);
        expect(c.slot.length, DaySlot.values.length, reason: c.id);
      }
      expect(categories.length, 8);
      expect(categoryOf('horoscope').name, 'Saved');
    });

    test('every stamp the app can write is allowed by the Firestore rules', () {
      final rules = File('../infra/firestore.rules').readAsStringSync();
      final allowed = RegExp(r"user_state', null\) in \[([^\]]*)\]")
          .firstMatch(rules)!
          .group(1)!;
      final states = RegExp(r"'([a-z_]+)'")
          .allMatches(allowed)
          .map((m) => m.group(1))
          .toSet();
      expect(states.containsAll(allStates), isTrue,
          reason: 'missing: ${allStates.difference(states)}');
    });

    test('the day has five parts', () {
      expect(slotOf(DateTime(2026, 1, 1, 7)), DaySlot.morning);
      expect(slotOf(DateTime(2026, 1, 1, 13)), DaySlot.midday);
      expect(slotOf(DateTime(2026, 1, 1, 16)), DaySlot.afternoon);
      expect(slotOf(DateTime(2026, 1, 1, 20)), DaySlot.evening);
      expect(slotOf(DateTime(2026, 1, 1, 2)), DaySlot.night);
    });
  });

  group('discoveries', () {
    test('each category names its discoveries by what they are', () {
      expect(find('Molokhia').detail, '35 min · serves 4 · easy');
      expect(find('cursor-rules').detail, 'Repo · ★ 12k');
      expect(find('Qaitbay').detail, 'Anfoushi, Alexandria');
      expect(
          find('Severance').detail, 'Series · 2022 · Dan Erickson · 2 seasons');
      expect(find('Severance').noun, 'series');
      expect(find('Project Hail Mary').noun, 'book');
      expect(find('Insulated steel mug').detail, 'EGP 850 · Amazon.eg');
      expect(find('Glass teapot').detail, 'under 600 pounds · Souq El Fustat');
      expect(find('12-minute').detail, startsWith('3 exercises · about'));
      expect(find('Lucille').title, 'Lucille’s +2');
      expect(find('Severance').action, 'Where to watch');
      expect(find('Project Hail Mary').action, 'Find the book');
    });

    test('stamps: done, active, open, archived', () {
      expect(find('Roast chicken').isDone, isTrue);
      expect(find('Glass teapot').isActive, isTrue);
      expect(find('Glass teapot').isDone, isFalse);
      expect(find('Molokhia').isOpen, isTrue);
      expect(find('Molokhia').seenBy(me), isNotNull);
    });

    test('catalogue numbers count up from the first save', () {
      final numbers = [for (final x in s.saves) s.numbers['${x['save_id']}']!];
      expect(numbers.toSet().length, s.saves.length);
      expect(numbers.reduce((a, b) => a > b ? a : b), s.saves.length);
      // Newest save, highest number.
      expect(s.numbers['${s.saves.first['save_id']}'], s.saves.length);
    });

    test('the archive splits into readable, arriving, needing you and plain',
        () {
      expect(s.processing.map((x) => x['save_id']), ['arriving1']);
      expect(s.attention.map((x) => x['save_id']), ['unsure1']);
      expect(s.plain.map((x) => x['save_id']), ['plain1']);
      expect(
          s.discoveries
              .every((d) => d.status == 'ready' || d.status == 'partial'),
          isTrue);
      expect(s.inSpace('g_crew').length, 2);
    });

    test('prices and workout minutes', () {
      expect(priceText({'price': 29.5, 'currency': 'USD'}), 'USD 29.50');
      expect(priceText({'price': 850}), '850');
      expect(priceText({'price_text': 'about 300'}), 'about 300');
      expect(priceText({}), isNull);
      expect(
          workoutMinutes([
            {'duration_s': 60, 'sets': 2, 'rest_s': 30}
          ]),
          3);
    });
  });

  group('search', () {
    test('Arabic is normalised the same way as the backend', () {
      expect(normalise('  طَماطِم   مَشْوِيّة '), 'طماطم مشويه');
      expect(normalise('أحمد إبراهيم آمال'), 'احمد ابراهيم امال');
    });

    test('every word must appear: titles, ingredients, creators, genres, notes',
        () {
      expect(matches(find('Molokhia'), 'garlic stock'), isTrue);
      expect(matches(find('Severance'), 'thriller'), isTrue);
      expect(matches(find('Insulated'), 'stanley'), isTrue);
      expect(matches(find('Molokhia'), 'garlic pizza'), isFalse);
    });

    test('status filters', () {
      expect(statusMatches(find('Roast chicken'), 'done'), isTrue);
      expect(statusMatches(find('Glass teapot'), 'active'), isTrue);
      expect(statusMatches(find('Molokhia'), 'open'), isTrue);
      expect(statusMatches(find('Molokhia'), 'done'), isFalse);
    });
  });

  group('links and capture', () {
    test('a pasted link: its platform, and a link inside shared text', () {
      expect(linkPlatform('https://vm.tiktok.com/x'), 'tiktok');
      expect(linkPlatform('https://youtu.be/x'), 'youtube');
      expect(linkPlatform('https://example.com'), isNull);
      expect(findLink('Look at this https://www.instagram.com/reel/a/ wow'),
          'https://www.instagram.com/reel/a/');
      expect(findLink('no link here'), isNull);
    });

    test('invite links carry an 8-letter code', () {
      expect(inviteCode('https://reelbrain-dev.web.app/join/k7mq2xpd'),
          'k7mq2xpd');
      expect(inviteCode('https://evil.example/join/k7mq2xpd'), isNull);
      expect(inviteCode('https://reelbrain-dev.web.app/join/short'), isNull);
    });

    test('maps, title searches and the calendar link', () {
      expect(mapsUrl({'name': 'Zooba', 'area': 'Zamalek', 'city': 'Cairo'}),
          'https://www.google.com/maps/search/?api=1&query=Zooba%2C+Zamalek%2C+Cairo');
      final cal = Uri.parse(calendarUrl(
          title: 'Visit Al-Muizz',
          start: DateTime.utc(2026, 11, 6, 15),
          location: 'Cairo'));
      expect(cal.host, 'calendar.google.com');
      expect(cal.queryParameters['dates'], '20261106T150000Z/20261106T170000Z');
      expect(cal.queryParameters['location'], 'Cairo');
      expect(imdbSearch('Perfect Days'), contains('Perfect+Days'));
    });

    test('only geocoded places become pins, in order', () {
      final d = Discovery({
        'save_id': 's',
        'item_id': '0-places',
        'section': 'places',
        'data': {
          'items': [
            {
              'name': 'A',
              'geo': {'lat': 30.0, 'lng': 31.2}
            },
            {'name': 'B'},
            {
              'name': 'C',
              'geo': {'lat': 30.1, 'lng': 31.3}
            },
          ]
        }
      }, {
        'save_id': 's',
        'status': 'ready'
      });
      expect([
        for (final p in placePins([d])) p.place['name']
      ], [
        'A',
        'C'
      ]);
    });
  });

  test('the viewer steps through every moment in reel order', () {
    final m = momentsOf(find('Molokhia'));
    expect(m.length, 4);
    expect(m.first.t, lessThan(m.last.t));
    expect(m[1].detail, 'Timer 10:00');
    final claims = momentsOf(find('Does honey'));
    expect(claims.map((c) => c.verdict), ['mostly_true', 'mixed']);
    expect(frameUrl('preview/img/a.jpg'), 'preview/img/a.jpg');
  });
}
