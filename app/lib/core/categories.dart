/// The category registry (docs/DESIGN_V5.md §2.4): one place for everything the app knows about a
/// kind of discovery. Section ids match the AI contract (backend/app/schemas). Adding a category
/// is one entry here plus its schema and body widget; nothing else hard-codes the list.
library;

/// A status a discovery can be in, with the category's own words.
class Stamp {
  const Stamp(this.state, this.label, {this.done = false, this.active = false});

  /// The `user_state` value written to Firestore (rules list every allowed value).
  final String state;
  final String label;

  /// Finished: the piece is placed.
  final bool done;

  /// Started but not finished (in progress, trying it, compared).
  final bool active;
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.noun,
    required this.action,
    required this.stamps,
    required this.verb,
    this.kinds = const {},
    this.slot = const {},
    this.weekend = 0,
    this.collection,
  });

  /// Section id (`recipe`, `entertainment`...).
  final String id;

  /// Shown as a heading: "Recipes", "Watch & Read".
  final String name;

  /// One of them: "recipe", "title".
  final String noun;

  /// The card's main action: "Cook it", "Plan a visit".
  final String action;

  /// The past tense for progress lines: "cooked", "visited".
  final String verb;

  /// In order; the first is the open state (`to_try`).
  final List<Stamp> stamps;

  /// Sub-kinds by id (entertainment: movie/series/book; tools: repo, app...).
  final Map<String, String> kinds;

  /// How well this category fits each part of the day, 0..1 (Today's pick).
  final Map<DaySlot, double> slot;

  /// Extra fit on the weekend (places, long recipes, films).
  final double weekend;

  /// What a collection of these is called ("Routine"), if the category has collections.
  final String? collection;

  Stamp get open => stamps.first;
  Stamp get finished => stamps.firstWhere((s) => s.done);
  Stamp? stamp(String? state) {
    for (final s in stamps) {
      if (s.state == (state ?? 'to_try')) return s;
    }
    return null;
  }
}

enum DaySlot { morning, midday, afternoon, evening, night }

DaySlot slotOf(DateTime t) => switch (t.hour) {
      >= 5 && < 11 => DaySlot.morning,
      >= 11 && < 15 => DaySlot.midday,
      >= 15 && < 18 => DaySlot.afternoon,
      >= 18 && < 22 => DaySlot.evening,
      _ => DaySlot.night,
    };

const slotNames = {
  DaySlot.morning: 'morning',
  DaySlot.midday: 'midday',
  DaySlot.afternoon: 'afternoon',
  DaySlot.evening: 'evening',
  DaySlot.night: 'night',
};

const _toTry = Stamp('to_try', 'To try');

const categories = <Category>[
  Category(
    id: 'recipe',
    name: 'Recipes',
    noun: 'recipe',
    action: 'Cook it',
    verb: 'cooked',
    stamps: [Stamp('to_try', 'To cook'), Stamp('cooked', 'Cooked', done: true)],
    slot: {
      DaySlot.morning: .25,
      DaySlot.midday: .55,
      DaySlot.afternoon: .7,
      DaySlot.evening: 1,
      DaySlot.night: .2,
    },
    weekend: .2,
    collection: 'Grocery list',
  ),
  Category(
    id: 'workout',
    name: 'Workouts',
    noun: 'workout',
    action: 'Start',
    verb: 'done',
    stamps: [Stamp('to_try', 'To do'), Stamp('done', 'Done', done: true)],
    slot: {
      DaySlot.morning: 1,
      DaySlot.midday: .45,
      DaySlot.afternoon: .7,
      DaySlot.evening: .55,
      DaySlot.night: .1,
    },
    collection: 'Routine',
  ),
  Category(
    id: 'places',
    name: 'Places',
    noun: 'place',
    action: 'Plan a visit',
    verb: 'visited',
    stamps: [
      Stamp('to_try', 'To visit'),
      Stamp('visited', 'Visited', done: true)
    ],
    slot: {
      DaySlot.morning: .35,
      DaySlot.midday: .8,
      DaySlot.afternoon: .75,
      DaySlot.evening: .7,
      DaySlot.night: .2,
    },
    weekend: .5,
    collection: 'Place list',
  ),
  Category(
    id: 'tools',
    name: 'Tools',
    noun: 'tool',
    action: 'Try it',
    verb: 'tried',
    stamps: [
      _toTry,
      Stamp('using', 'Using', active: true),
      Stamp('tried', 'Tried', done: true),
      Stamp('not_useful', 'Not useful', done: true),
    ],
    kinds: {
      'github_repo': 'Repo',
      'website': 'Website',
      'app': 'App',
      'cli': 'CLI',
      'library': 'Library',
      'extension': 'Extension',
      'other': 'Other',
    },
    slot: {
      DaySlot.morning: .7,
      DaySlot.midday: .8,
      DaySlot.afternoon: .9,
      DaySlot.evening: .4,
      DaySlot.night: .35,
    },
    weekend: -.2,
  ),
  Category(
    id: 'fact_check',
    name: 'Fact checks',
    noun: 'fact check',
    action: 'Read the verdict',
    verb: 'read',
    stamps: [Stamp('to_try', 'To read'), Stamp('done', 'Read', done: true)],
    slot: {
      DaySlot.morning: .75,
      DaySlot.midday: .5,
      DaySlot.afternoon: .45,
      DaySlot.evening: .45,
      DaySlot.night: .7,
    },
  ),
  Category(
    id: 'ideas',
    name: 'Ideas',
    noun: 'idea',
    action: 'Act on it',
    verb: 'acted on',
    stamps: [Stamp('to_try', 'Open'), Stamp('done', 'Acted on', done: true)],
    slot: {
      DaySlot.morning: .8,
      DaySlot.midday: .5,
      DaySlot.afternoon: .6,
      DaySlot.evening: .4,
      DaySlot.night: .6,
    },
  ),
  Category(
    id: 'entertainment',
    name: 'Watch & Read',
    noun: 'title',
    action: 'Find where to watch',
    verb: 'finished',
    stamps: [
      Stamp('to_try', 'Want to'),
      Stamp('in_progress', 'In progress', active: true),
      Stamp('done', 'Finished', done: true),
    ],
    kinds: {'movie': 'Movies', 'series': 'Series', 'book': 'Books'},
    slot: {
      DaySlot.morning: .15,
      DaySlot.midday: .2,
      DaySlot.afternoon: .35,
      DaySlot.evening: .85,
      DaySlot.night: 1,
    },
    weekend: .35,
    collection: 'Watchlist',
  ),
  Category(
    id: 'products',
    name: 'Products',
    noun: 'product',
    action: 'View product',
    verb: 'bought',
    stamps: [
      Stamp('to_try', 'Interested'),
      Stamp('compared', 'Compared', active: true),
      Stamp('purchased', 'Purchased', done: true),
      Stamp('not_useful', 'Not for me', done: true),
    ],
    slot: {
      DaySlot.morning: .2,
      DaySlot.midday: .55,
      DaySlot.afternoon: .5,
      DaySlot.evening: .45,
      DaySlot.night: .35,
    },
    weekend: .2,
    collection: 'Wishlist',
  ),
];

final _byId = {for (final c in categories) c.id: c};

/// The category for a section id; unknown ids get a plain fallback so old or future sections
/// still render.
Category categoryOf(String? id) =>
    _byId[id] ??
    Category(
        id: id ?? 'other',
        name: 'Saved',
        noun: 'save',
        action: 'Open',
        verb: 'done',
        stamps: const [_toTry, Stamp('done', 'Done', done: true)]);

bool isKnownCategory(String? id) => _byId.containsKey(id);

/// Every user_state any category can write, plus Recall's archive (mirrors firestore.rules).
final allStates = {
  for (final c in categories)
    for (final s in c.stamps) s.state,
  'archived',
  // Older saves wrote these before the V5 stamps.
  'tried', 'done',
};

/// One of a sub-kind, in words: "film", "series", "book" (Watch & Read).
const kindNouns = {'movie': 'film', 'series': 'series', 'book': 'book'};

/// Section ids the Create sheet offers as hints, in a sensible order.
const hintOrder = [
  'recipe',
  'places',
  'tools',
  'workout',
  'entertainment',
  'products',
  'fact_check',
  'ideas',
];
