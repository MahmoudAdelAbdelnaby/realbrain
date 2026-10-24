import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/recipes/recipe_math.dart';

void main() {
  test('scaling keeps proportions and leaves unknown servings alone', () {
    expect(scaleQty(200, 4, 2), 100);
    expect(scaleQty(1, 4, 6), 1.5);
    expect(scaleQty(200, null, 2), 200);
    expect(scaleQty(null, 4, 2), isNull);
  });

  test('quantities read like a cook would write them', () {
    expect(fmtQty(2), '2');
    expect(fmtQty(1.98), '2');
    expect(fmtQty(0.5), '½');
    expect(fmtQty(1.25), '1¼');
    expect(fmtQty(2.75), '2¾');
    expect(fmtQty(133.33), '133.3');
  });

  test('ingredient lines scale and mark estimates', () {
    expect(
        ingredientLine({'name': 'عدس', 'qty': 200, 'unit': 'g'},
            from: 4, to: 2),
        '100 g عدس');
    expect(ingredientLine({'name': 'salt', 'estimated': true}), '≈ salt');
  });

  test('the grocery list adds the same ingredient across recipes, per unit',
      () {
    final list = groceries([
      (
        title: 'Koshari',
        from: 4,
        to: 4,
        ingredients: [
          {'name': 'Onion', 'qty': 2, 'unit': null},
          {'name': 'rice', 'qty': 200, 'unit': 'g'},
        ]
      ),
      (
        title: 'Mahshi',
        from: 2,
        to: 4,
        ingredients: [
          {'name': 'onion', 'qty': 1, 'unit': null},
          {'name': 'Rice', 'qty': 1, 'unit': 'cup'},
          {'name': 'salt', 'estimated': true},
        ]
      ),
    ]);
    expect([for (final l in list) l.text],
        ['4 Onion', '200 g rice', '2 cup Rice', '≈ salt']);
    expect(list.first.recipes, {'Koshari', 'Mahshi'});
  });
}
