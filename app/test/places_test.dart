import 'package:flutter_test/flutter_test.dart';
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
}
