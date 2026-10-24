import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/library/library_screen.dart';

void main() {
  final koshari = {
    'platform': 'tiktok',
    'sections': ['recipe'],
    'search_text': normalise('طريقة عمل الكشري عدس أرز claude code'),
  };
  final cruise = {
    'platform': 'instagram',
    'sections': ['places'],
    'summary': 'Aroya cruise from Alexandria to Istanbul',
  };

  test('normalise matches the backend (diacritics, folded letters, case)', () {
    expect(normalise('طَماطِم  مُقَشَّرة'), 'طماطم مقشره');
    expect(normalise('إسكندرية'), normalise('اسكندريه'));
    expect(normalise('Claude CODE'), 'claude code');
  });

  test('every word must match, across languages', () {
    expect(saveMatches(koshari, 'كشري عدس'), isTrue);
    expect(saveMatches(koshari, 'الكشرى'), isTrue, reason: 'ى folds to ي');
    expect(saveMatches(koshari, 'Claude'), isTrue);
    expect(saveMatches(koshari, 'كشري lasagna'), isFalse);
    expect(saveMatches(cruise, 'alexandria'), isTrue,
        reason: 'falls back to the summary');
  });

  test('platform and section filters', () {
    expect(saveMatches(koshari, '', platform: 'tiktok', section: 'recipe'),
        isTrue);
    expect(saveMatches(koshari, '', platform: 'instagram'), isFalse);
    expect(saveMatches(cruise, '', section: 'recipe'), isFalse);
  });
}
