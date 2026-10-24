/// Servings scaling and the grocery list (P1-10). Pure functions, unit tested.
library;

/// qty for [to] servings when the recipe is for [from]. Unknown servings: unchanged.
num? scaleQty(num? qty, int? from, int to) {
  if (qty == null || from == null || from <= 0) return qty;
  return qty * to / from;
}

/// Kitchen-friendly number: whole when close, else one decimal (or ½/¼/¾ for small amounts).
String fmtQty(num q) {
  if ((q - q.round()).abs() < 0.05) return '${q.round()}';
  if (q < 10) {
    final whole = q.floor();
    final frac = q - whole;
    final pretty = {0.25: '¼', 0.5: '½', 0.75: '¾'};
    for (final e in pretty.entries) {
      if ((frac - e.key).abs() < 0.06) {
        return whole == 0 ? e.value : '$whole${e.value}';
      }
    }
  }
  return q.toStringAsFixed(1);
}

/// One ingredient line: "≈ 200 g lentils" (≈ when the AI estimated it).
String ingredientLine(Map<String, dynamic> i, {int? from, int? to}) {
  final q = scaleQty(i['qty'] as num?, from, to ?? from ?? 1);
  final parts = [
    if (q != null) fmtQty(q),
    if (i['unit'] != null) '${i['unit']}',
    '${i['name']}'
  ];
  return '${i['estimated'] == true ? '≈ ' : ''}${parts.join(' ')}';
}

class GroceryLine {
  GroceryLine(this.name, this.unit, this.qty, this.estimated, this.recipes);
  final String name;
  final String? unit;
  num? qty;
  bool estimated;
  final Set<String> recipes;

  String get text => ingredientLine(
      {'name': name, 'unit': unit, 'qty': qty, 'estimated': estimated});
}

/// Merges ingredients across recipes: same name and unit add up (each recipe at its chosen
/// servings); different units stay separate lines rather than guessing a conversion.
List<GroceryLine> groceries(
    Iterable<
            ({
              String title,
              List<Map<String, dynamic>> ingredients,
              int? from,
              int to
            })>
        recipes) {
  final byKey = <String, GroceryLine>{};
  for (final r in recipes) {
    for (final i in r.ingredients) {
      final name = '${i['name']}'.trim();
      final unit = (i['unit'] as String?)?.trim().toLowerCase();
      final key = '${name.toLowerCase()}|${unit ?? ''}';
      final q = scaleQty(i['qty'] as num?, r.from, r.to);
      final line = byKey.putIfAbsent(
          key, () => GroceryLine(name, unit, null, false, {}));
      if (q != null) line.qty = (line.qty ?? 0) + q;
      line.estimated = line.estimated || i['estimated'] == true;
      line.recipes.add(r.title);
    }
  }
  return byKey.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
