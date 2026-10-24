import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/places/places_map.dart';
import 'package:reelbrain/features/places/places_view.dart';

void main() {
  test('maps links search by name, area and city', () {
    expect(
      mapsUrl({'name': 'Abou Tarek', 'area': 'Downtown', 'city': 'Cairo'}),
      'https://www.google.com/maps/search/?api=1&query=Abou+Tarek%2C+Downtown%2C+Cairo',
    );
    expect(mapsUrl({'name': 'كروز أرويا', 'city': 'الإسكندرية'}),
        contains('query=%D9%83'));
  });

  test('only geocoded places become pins, in order', () {
    final pins = placePins([
      {
        'item_id': 'a',
        'data': {
          'items': [
            {
              'name': 'Aroya',
              'geo': {'lat': 30.05, 'lng': 31.22, 'matched': 'place'}
            },
            {'name': 'Unfound'},
          ]
        }
      },
      {
        'item_id': 'b',
        'data': {
          'items': [
            {
              'name': 'Koshary',
              'geo': {'lat': 30, 'lng': 31}
            }
          ]
        }
      },
      {'item_id': 'c', 'data': null},
    ]);
    expect([for (final p in pins) p.place['name']], ['Aroya', 'Koshary']);
    expect(pins.last.at.latitude, 30.0);
    expect(pins.last.item['item_id'], 'b');
  });
}
