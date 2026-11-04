/// Sample archive for the screenshot preview, the demo build and widget tests: two people's worth
/// of saves across every category and state, two groups with plans, a cook-along and a challenge.
library;

import '../core/data/brain.dart';

const me = 'mahmoud';

/// The demo APK (`--dart-define=RB_DEMO=true`, .github/workflows/demo.yml): sample photos bundled
/// from demo/img and the real clock. Otherwise photos are preview/img/*.jpg, served next to the
/// web preview build, and never part of the app.
const demoBuild = bool.fromEnvironment('RB_DEMO');

/// A sample photo by name.
String img(String name) =>
    demoBuild ? 'asset:demo/img/$name.jpg' : 'preview/img/$name.jpg';

class _B {
  _B(this.now);
  final DateTime now;
  final saves = <Json>[];
  final items = <Json>[];
  int _n = 0;

  double ago({int days = 0, int hours = 0}) =>
      now.subtract(Duration(days: days, hours: hours)).millisecondsSinceEpoch /
      1000;

  /// One save with one item. [state]/[doneDays]/[seenDays] set the person's progress.
  String add(
    String section,
    Json data, {
    required String summary,
    String space = 'p_mahmoud',
    String by = me,
    String platform = 'tiktok',
    String? creator,
    String? frame,
    int days = 0,
    int hours = 0,
    String? state,
    int? doneDays,
    int? seenDays,
    String? goodFor,
    int? effort,
    String? difficulty,
    List<String> topics = const [],
    String? verdict,
    String status = 'ready',
  }) {
    final id = 's${_n++}';
    saves.add({
      'save_id': id,
      'space_id': space,
      'status': status,
      'platform': platform,
      'creator': creator,
      'source_url': platform == 'idea'
          ? null
          : 'https://www.$platform.com/@${creator ?? 'someone'}/$id',
      'summary': summary,
      'key_frame_url': frame == null ? null : img(frame),
      'created_at': ago(days: days, hours: hours),
      'created_by': by,
      if (by != me) 'shared_by': by,
      'sections': [section],
      'good_for': goodFor,
      'effort_min': effort,
      'difficulty': difficulty,
      'topics': topics,
      'verdict': verdict,
      'duration_s': 58.0,
    });
    items.add({
      'item_id': '0-$section',
      'save_id': id,
      'space_id': space,
      'section': section,
      'confidence': 0.93,
      'data': data,
      'user_state': state,
      'created_at': ago(days: days, hours: hours),
      if (doneDays != null) 'done_at': ago(days: doneDays),
      if (seenDays != null) 'seen': {me: ago(days: seenDays, hours: 2)},
    });
    return id;
  }
}

Json _step(String text, double t, {int? timer, String? frame}) => {
      'text': text,
      't': t,
      'timer_s': timer,
      if (frame != null) 'frame': img(frame)
    };

Json _ing(String name, num? qty, String? unit, {bool est = false}) =>
    {'name': name, 'qty': qty, 'unit': unit, 'estimated': est};

BrainState sampleState(DateTime now, {bool puzzle = true}) {
  final b = _B(now);

  // --- older finished things (the archive's history, Sept-Oct) ---
  final old = [
    (
      'tools',
      {
        'items': [
          {
            'name': 'Raycast',
            'kind': 'app',
            'use_shown': 'Launcher with AI commands',
            't': 4.0
          }
        ]
      },
      'Raycast as a Mac launcher',
      'tried',
      62
    ),
    (
      'tools',
      {
        'items': [
          {
            'name': 'tldraw',
            'kind': 'website',
            'use_shown': 'Whiteboard that turns sketches into UI',
            't': 6.0
          }
        ]
      },
      'Sketch to UI with tldraw',
      'tried',
      55
    ),
    (
      'recipe',
      {
        'title': 'Fattah for Eid',
        'servings': 6,
        'total_min': 60,
        'ingredients': [_ing('rice', 2, 'cups')],
        'steps': [_step('Toast the bread', 8)],
        'tags': ['Egyptian']
      },
      'Fattah with garlic vinegar sauce',
      'cooked',
      50
    ),
    (
      'places',
      {
        'items': [
          {
            'name': 'Koshary Abou Tarek',
            'area': 'Downtown',
            'city': 'Cairo',
            'why_go': 'The koshary benchmark',
            't': 3.0
          }
        ]
      },
      'The koshary everyone argues about',
      'visited',
      48
    ),
    (
      'workout',
      {
        'exercises': [
          {'name': 'Plank', 'duration_s': 60, 'sets': 3, 't': 5.0}
        ]
      },
      'Plank ladder',
      'done',
      45
    ),
    (
      'fact_check',
      {
        'claims': [
          {
            'text': 'You only use 10% of your brain',
            't': 3.0,
            'verdict': 'false',
            'correction': 'Imaging shows almost all of it is active over a day.'
          }
        ],
        'overall': 'false',
        'checked_at': b.ago(days: 44)
      },
      'The 10% brain myth',
      'done',
      44
    ),
    (
      'ideas',
      {
        'title': 'Label the spice drawer',
        'idea': 'Same jars, labels on the lids.',
        'next_steps': ['Buy 12 jars']
      },
      'Spice drawer that stays tidy',
      'done',
      40
    ),
    (
      'entertainment',
      {
        'items': [
          {
            'kind': 'movie',
            'title': 'Past Lives',
            'year': 2023,
            'creator': 'Celine Song',
            'genres': ['Drama'],
            't': 2.0
          }
        ]
      },
      'A quiet film about the lives we did not live',
      'done',
      38
    ),
    (
      'products',
      {
        'items': [
          {
            'name': 'Pour-over kettle',
            'brand': 'Fellow',
            'price': 4200,
            'currency': 'EGP',
            't': 7.0
          }
        ]
      },
      'A kettle for pour-over coffee',
      'purchased',
      36
    ),
    (
      'recipe',
      {
        'title': 'Feteer meshaltet',
        'servings': 4,
        'total_min': 90,
        'ingredients': [_ing('flour', 500, 'g')],
        'steps': [_step('Stretch the dough thin', 12)],
        'tags': ['Egyptian', 'baking']
      },
      'Flaky feteer at home',
      'cooked',
      34
    ),
    (
      'tools',
      {
        'items': [
          {
            'name': 'Excalidraw',
            'kind': 'website',
            'use_shown': 'Hand-drawn diagrams in the browser',
            't': 5.0
          }
        ]
      },
      'Diagrams that look hand-drawn',
      'tried',
      33
    ),
    (
      'places',
      {
        'items': [
          {
            'name': 'Bab Zuweila',
            'area': 'Islamic Cairo',
            'city': 'Cairo',
            'why_go': 'Climb the minarets for the view',
            't': 4.0
          }
        ]
      },
      'Climb the gate of Bab Zuweila',
      'visited',
      30
    ),
    (
      'workout',
      {
        'exercises': [
          {'name': 'Kettlebell swing', 'reps': 15, 'sets': 4, 't': 6.0}
        ]
      },
      'Kettlebell swings, 4 rounds',
      'done',
      28
    ),
    (
      'fact_check',
      {
        'claims': [
          {
            'text': 'Cracking knuckles causes arthritis',
            't': 4.0,
            'verdict': 'false'
          }
        ],
        'overall': 'false'
      },
      'Knuckle cracking and arthritis',
      'done',
      27
    ),
    (
      'recipe',
      {
        'title': 'Hawawshi in the oven',
        'servings': 4,
        'total_min': 40,
        'ingredients': [_ing('minced beef', 500, 'g')],
        'steps': [_step('Stuff the bread', 9)],
        'tags': ['Egyptian', 'street food']
      },
      'Oven hawawshi',
      'cooked',
      24
    ),
    (
      'places',
      {
        'items': [
          {
            'name': 'Darb 1718',
            'area': 'Fustat',
            'city': 'Cairo',
            'why_go': 'Art space with rooftop shows',
            't': 3.0
          }
        ]
      },
      'Darb 1718 rooftop shows',
      'visited',
      22
    ),
    (
      'ideas',
      {
        'title': 'One new recipe every Friday',
        'idea': 'Pick it on Thursday from what you saved.',
        'next_steps': ['Pick on Thursday']
      },
      'A recipe a week',
      'done',
      21
    ),
  ];
  for (final (i, (section, data, summary, state, days)) in old.indexed) {
    // One of them was finished more than a month after it was saved (Rediscovery).
    b.add(section, data,
        summary: summary,
        days: days + (i == 2 ? 40 : 3),
        state: state,
        doneDays: days,
        platform: i.isEven ? 'instagram' : 'tiktok',
        creator: 'archive',
        topics: section == 'recipe'
            ? ['egyptian food']
            : section == 'places'
                ? ['cairo', 'history']
                : const []);
  }

  // --- this autumn's saves ---
  b.add(
      'recipe',
      {
        'title': 'Lentil soup, the Cairo way',
        'servings': 4,
        'total_min': 30,
        'ingredients': [
          _ing('red lentils', 250, 'g'),
          _ing('carrot', 1, null),
          _ing('cumin', 1, 'tsp')
        ],
        'steps': [
          _step('Simmer the lentils with the carrot and onion', 6, timer: 1200)
        ],
        'tags': ['Egyptian', 'soup'],
      },
      summary: 'Shorbet ads with crispy pita',
      frame: 'soup',
      days: 26,
      state: 'cooked',
      doneDays: 19,
      platform: 'instagram',
      creator: 'teta.kitchen',
      effort: 30,
      difficulty: 'easy',
      topics: ['egyptian food', 'winter']);

  b.add(
      'places',
      {
        'items': [
          {
            'name': 'Zooba',
            'area': 'Zamalek',
            'city': 'Cairo',
            'why_go': 'Street-food classics done right, open late',
            'what_to_order': 'Ta’ameya sandwich, hawawshi, tahini fries',
            't': 5.0,
            'frame': img('zooba')
          }
        ]
      },
      summary: 'The best ta’ameya sandwich in Zamalek',
      frame: 'zooba',
      days: 18,
      state: 'visited',
      doneDays: 8,
      platform: 'instagram',
      creator: 'cairoeats',
      topics: ['egyptian food', 'cairo', 'street food']);

  b.add(
      'fact_check',
      {
        'claims': [
          {
            'text':
                'Eating fruit right after a meal makes it rot in your stomach',
            't': 4.0,
            'verdict': 'false',
            'correction':
                'Stomach acid and enzymes digest fruit with the rest of the meal; it does not rot.',
            'frame': img('fruits')
          },
        ],
        'overall': 'false',
        'checked_at': b.ago(days: 16),
        'sources': [
          {
            'title': 'Harvard Health: Does fruit rot in your stomach?',
            'url': 'https://www.health.harvard.edu'
          }
        ],
      },
      summary: 'Fruit after meals causes bloating, says a viral reel',
      frame: 'fruits',
      days: 16,
      state: 'done',
      doneDays: 15,
      verdict: 'false',
      creator: 'healthtok',
      topics: ['nutrition']);

  b.add(
      'entertainment',
      {
        'items': [
          {
            'kind': 'movie',
            'title': 'Perfect Days',
            'year': 2023,
            'creator': 'Wim Wenders',
            'genres': ['Drama'],
            'premise':
                'A Tokyo toilet cleaner finds beauty in the routine of his days.',
            'why': 'The calmest film of the decade',
            't': 3.0,
            'estimated': true
          }
        ]
      },
      summary: 'A calm film about routine and small joys',
      days: 14,
      state: 'done',
      doneDays: 6,
      creator: 'filmnotes',
      topics: ['slow living']);

  b.add(
      'products',
      {
        'items': [
          {
            'name': 'Canvas rucksack',
            'brand': 'Buckle & Co',
            'price': 1900,
            'currency': 'EGP',
            'merchant': 'Noon',
            'description': 'Waxed canvas, fits a 14-inch laptop.',
            'specs': ['22 litres', 'Waxed canvas', 'Leather straps'],
            'why': 'Survived three years of daily use',
            't': 5.0
          }
        ]
      },
      summary: 'A rucksack that ages well',
      frame: 'backpack',
      days: 13,
      state: 'purchased',
      doneDays: 4,
      platform: 'instagram',
      creator: 'carrystuff');

  b.add(
      'recipe',
      {
        'title': 'Roast chicken with lemon and sumac',
        'servings': 4,
        'total_min': 70,
        'ingredients': [
          _ing('whole chicken', 1.5, 'kg'),
          _ing('lemons', 2, null),
          _ing('sumac', 2, 'tbsp')
        ],
        'steps': [
          _step('Rub the chicken with sumac, lemon and oil', 8),
          _step('Roast at 220°C', 22, timer: 3600)
        ],
        'tags': ['dinner', 'protein'],
      },
      summary: 'Crispy roast chicken with sumac',
      frame: 'roast',
      days: 12,
      state: 'cooked',
      doneDays: 2,
      platform: 'youtube',
      creator: 'Sahar’s Kitchen',
      effort: 70,
      difficulty: 'medium',
      topics: ['protein', 'dinner']);

  b.add(
      'recipe',
      {
        'title': 'Spinach and feta sambousek',
        'servings': 6,
        'total_min': 45,
        'ingredients': [
          _ing('spinach', 300, 'g'),
          _ing('feta', 200, 'g'),
          _ing('spring roll sheets', 12, null)
        ],
        'steps': [
          _step('Wilt the spinach and squeeze it dry', 5),
          _step('Fold into triangles and bake', 20, timer: 1200)
        ],
        'tags': ['Egyptian', 'Ramadan'],
      },
      summary: 'Crisp spinach sambousek, baked not fried',
      frame: 'sambousek',
      days: 12,
      creator: 'chefaya',
      effort: 45,
      difficulty: 'easy',
      goodFor: 'Iftar starters for a crowd',
      topics: ['egyptian food']);

  b.add(
      'places',
      {
        'items': [
          {
            'name': 'Qaitbay Citadel',
            'area': 'Anfoushi',
            'city': 'Alexandria',
            'why_go':
                'Fortress on the site of the ancient lighthouse, best at sunset',
            'what_to_order': 'Fresh fish at the harbour after',
            't': 6.0
          }
        ]
      },
      summary: 'Sunset at Qaitbay, where the lighthouse stood',
      frame: 'qaitbay',
      days: 9,
      seenDays: 3,
      creator: 'alexwanders',
      topics: ['alexandria', 'history']);

  b.add(
      'tools',
      {
        'items': [
          {
            'name': 'cursor-rules',
            'kind': 'github_repo',
            'use_shown':
                'Generates project rules for AI coding agents from your repo',
            'snippet': 'npx cursor-rules init',
            'verified': {
              'ok': true,
              'source': 'github',
              'stars': 12400,
              'last_commit':
                  now.subtract(const Duration(days: 3)).toIso8601String(),
              'url': 'https://github.com/example/cursor-rules'
            },
            't': 9.0
          }
        ]
      },
      summary: 'Rules files for AI coding agents, generated',
      days: 6,
      seenDays: 2,
      creator: 'devdaily',
      effort: 10,
      topics: ['ai agents']);

  b.add(
      'fact_check',
      {
        'claims': [
          {
            'text': 'Honey found in Egyptian tombs was still edible',
            't': 5.0,
            'verdict': 'mostly_true',
            'correction':
                'Archaeologists report edible honey in tombs, though exact finds are hard to verify.',
            'frame': img('bees')
          },
          {
            'text': 'Honey has no water, so bacteria cannot grow in it',
            't': 14.0,
            'verdict': 'mixed',
            'correction':
                'Honey has about 17% water, but it is too sugary and acidic for most bacteria.'
          },
        ],
        'overall': 'mostly_true',
        'checked_at': b.ago(days: 5),
        'sources': [
          {
            'title':
                'Smithsonian: The science behind honey’s eternal shelf life',
            'url': 'https://www.smithsonianmag.com'
          },
          {'title': 'Britannica: Honey', 'url': 'https://www.britannica.com'},
        ],
      },
      summary: 'Does honey really never spoil?',
      frame: 'bees',
      days: 5,
      verdict: 'mostly_true',
      platform: 'instagram',
      creator: 'sciencebites',
      topics: ['egypt', 'history', 'nutrition']);

  b.add(
      'entertainment',
      {
        'items': [
          {
            'kind': 'series',
            'title': 'Severance',
            'year': 2022,
            'creator': 'Dan Erickson',
            'genres': ['Thriller', 'Sci-fi'],
            'seasons': 2,
            'premise':
                'Office workers have their work memories surgically split from their personal lives.',
            'why': 'A workplace thriller that gets stranger every episode',
            'platforms': ['Apple TV+'],
            't': 4.0,
            'estimated': true
          }
        ]
      },
      summary: 'The workplace thriller everyone is talking about',
      days: 4,
      creator: 'screentalk',
      goodFor: 'A weekend binge',
      topics: ['thriller']);

  b.add(
      'products',
      {
        'items': [
          {
            'name': 'Insulated steel mug',
            'brand': 'Stanley',
            'price': 850,
            'currency': 'EGP',
            'merchant': 'Amazon.eg',
            'description':
                'Keeps coffee hot for hours; fits the car cup holder.',
            'specs': ['590 ml', 'Dishwasher safe', 'Leak-proof lid'],
            'why': 'Still hot after the whole commute',
            'url_guess': 'https://www.amazon.eg/s?k=stanley+mug',
            'affiliate_url':
                'https://www.amazon.eg/s?k=stanley+mug&tag=realbrain-21',
            't': 6.0
          }
        ]
      },
      summary: 'A mug that keeps coffee hot all morning',
      frame: 'mug',
      days: 4,
      creator: 'gearguy',
      topics: ['coffee']);

  b.add(
      'ideas',
      {
        'title': 'A phone-free hour on Friday mornings',
        'idea':
            'One hour after breakfast with phones in a drawer: walk, cook or play something together.',
        'next_steps': [
          'Pick the drawer',
          'Tell the family on Thursday',
          'Try it this Friday'
        ],
      },
      summary: 'A phone-free hour on Friday mornings',
      platform: 'idea',
      days: 3,
      topics: ['family', 'slow living']);

  b.add(
      'products',
      {
        'items': [
          {
            'name': 'Glass teapot with infuser',
            'price_text': 'under 600 pounds',
            'merchant': 'Souq El Fustat',
            'description': 'Borosilicate glass with a steel infuser.',
            'specs': ['900 ml', 'Stovetop safe'],
            'why': 'You can watch the tea steep',
            't': 5.0
          }
        ]
      },
      summary: 'A glass teapot you can put on the stove',
      frame: 'teapot',
      days: 3,
      state: 'compared',
      creator: 'homefinds');

  b.add(
      'recipe',
      {
        'title': 'Molokhia with garlic tasha',
        'servings': 4,
        'total_min': 35,
        'ingredients': [
          _ing('frozen molokhia', 400, 'g'),
          _ing('chicken stock', 1, 'l'),
          _ing('garlic cloves', 8, null),
          _ing('ground coriander', 1, 'tbsp'),
          _ing('ghee', 2, 'tbsp', est: true),
        ],
        'steps': [
          _step('Bring the stock to a simmer and add the molokhia, stirring', 6,
              frame: 'molokhia'),
          _step('Simmer gently; don’t let it boil or it separates', 18,
              timer: 600, frame: 'soup'),
          _step('Fry garlic and coriander in ghee until golden: the tasha', 31,
              timer: 90, frame: 'produce'),
          _step('Pour the tasha in with a gasp (it’s tradition) and stir once',
              44),
        ],
        'tags': ['Egyptian', 'dinner'],
      },
      summary: 'Molokhia with a proper garlic tasha',
      frame: 'molokhia',
      space: 'g_home',
      days: 3,
      seenDays: 1,
      creator: 'chefaya',
      effort: 35,
      difficulty: 'easy',
      goodFor: 'A cosy weeknight dinner',
      topics: ['egyptian food', 'dinner']);

  b.add(
      'places',
      {
        'items': [
          {
            'name': 'Al-Muizz Street',
            'area': 'Islamic Cairo',
            'city': 'Cairo',
            'why_go':
                'A kilometre of Fatimid mosques and madrasas, lit up after dark',
            'what_to_order': 'Sobia from the carts',
            't': 7.0
          }
        ]
      },
      summary: 'Walk Al-Muizz Street at sunset',
      frame: 'muizz',
      space: 'g_home',
      by: 'salma',
      days: 2,
      creator: 'cairoheritage',
      topics: ['cairo', 'history']);

  b.add(
      'entertainment',
      {
        'items': [
          {
            'kind': 'series',
            'title': 'The Bear',
            'year': 2022,
            'creator': 'Christopher Storer',
            'genres': ['Drama', 'Comedy'],
            'seasons': 3,
            'premise':
                'A fine-dining chef comes home to run his family’s Chicago sandwich shop.',
            'why': 'The most stressful kitchen on television',
            'platforms': ['Disney+'],
            't': 3.0,
            'estimated': true
          }
        ]
      },
      summary: 'The kitchen drama that made everyone want to cook',
      space: 'g_home',
      by: 'salma',
      days: 1,
      hours: 4,
      creator: 'screentalk',
      topics: ['food', 'drama']);

  b.add(
      'workout',
      {
        'title': '12-minute stairs HIIT',
        'exercises': [
          {
            'name': 'Stair sprints',
            'duration_s': 30,
            'sets': 4,
            'rest_s': 30,
            'cues': 'Drive the knees, light feet',
            't': 4.0,
            'frame': img('runner')
          },
          {
            'name': 'Step-ups',
            'reps': 12,
            'sets': 3,
            'rest_s': 20,
            'cues': 'Whole foot on the step',
            't': 19.0
          },
          {
            'name': 'Calf raises',
            'reps': 20,
            'sets': 3,
            'rest_s': 15,
            't': 33.0
          },
        ],
      },
      summary: '12-minute HIIT on the stairs at home',
      frame: 'runner',
      space: 'g_crew',
      by: 'omar',
      days: 2,
      creator: 'fitwithfarida',
      effort: 12,
      difficulty: 'medium',
      topics: ['cardio', 'home workout']);

  b.add(
      'places',
      {
        'items': [
          {
            'name': 'Tunis Village glamping',
            'area': 'Fayoum',
            'city': 'Fayoum',
            'why_go': 'Bell tents over Lake Qarun and the pottery village',
            'what_to_order': 'Feteer at the village café',
            't': 5.0
          }
        ]
      },
      summary: 'Glamping in Tunis Village, Fayoum',
      frame: 'fayoum',
      space: 'g_crew',
      by: 'omar',
      days: 1,
      creator: 'weekendegypt',
      topics: ['weekend', 'travel']);

  b.add(
      'recipe',
      {
        'title': 'Pesto pasta in 15 minutes',
        'servings': 2,
        'total_min': 15,
        'ingredients': [
          _ing('spaghetti', 200, 'g'),
          _ing('basil', 1, 'bunch'),
          _ing('parmesan', 40, 'g')
        ],
        'steps': [
          _step('Blitz basil, nuts, cheese and oil', 4),
          _step('Toss with the pasta and a splash of its water', 11)
        ],
        'tags': ['quick', 'dinner'],
      },
      summary: 'Fresh pesto pasta in 15 minutes',
      frame: 'pesto',
      days: 1,
      platform: 'youtube',
      creator: 'pastaprof',
      effort: 15,
      difficulty: 'easy',
      goodFor: 'A fast weeknight dinner',
      topics: ['quick', 'dinner']);

  b.add(
      'entertainment',
      {
        'items': [
          {
            'kind': 'book',
            'title': 'Project Hail Mary',
            'year': 2021,
            'creator': 'Andy Weir',
            'genres': ['Sci-fi'],
            'premise':
                'A schoolteacher wakes alone on a spaceship with no memory and a world to save.',
            'why': 'Funny, nerdy and impossible to put down',
            't': 2.0
          }
        ]
      },
      summary: 'The sci-fi book that’s funny and nerdy',
      days: 0,
      hours: 20,
      state: 'in_progress',
      seenDays: 0,
      creator: 'bookstagram');

  b.add(
      'workout',
      {
        'title': 'Core in 8 minutes',
        'exercises': [
          {'name': 'Dead bug', 'reps': 12, 'sets': 2, 't': 3.0},
          {'name': 'Side plank', 'duration_s': 30, 'sets': 2, 't': 15.0},
          {'name': 'Hollow hold', 'duration_s': 20, 'sets': 2, 't': 28.0},
        ],
      },
      summary: 'An 8-minute core routine, no equipment',
      days: 0,
      hours: 6,
      creator: 'coreclub',
      effort: 8,
      topics: ['home workout']);

  b.add(
      'places',
      {
        'items': [
          {
            'name': 'Lucille’s',
            'area': 'Maadi',
            'city': 'Cairo',
            'why_go': 'The American breakfast institution',
            't': 3.0
          },
          {
            'name': 'Eish + Malh',
            'area': 'Downtown',
            'city': 'Cairo',
            'why_go': 'Fresh pasta in an old ’20s building',
            't': 12.0
          },
          {
            'name': 'Kokio',
            'area': 'Zamalek',
            'city': 'Cairo',
            'why_go': 'Specialty coffee and cardamom buns',
            't': 21.0
          },
        ]
      },
      summary: 'Three brunch spots worth the queue',
      frame: 'brunch',
      days: 0,
      hours: 3,
      platform: 'instagram',
      creator: 'cairobrunch',
      topics: ['cairo', 'coffee']);

  b.add(
      'recipe',
      {
        'title': 'Cherry galette',
        'servings': 6,
        'total_min': 75,
        'ingredients': [_ing('cherries', 500, 'g')],
        'steps': [
          _step('Fold the pastry over the fruit and bake', 30, timer: 2400)
        ],
        'tags': ['dessert', 'baking'],
      },
      summary: 'A rustic cherry galette',
      frame: 'galette',
      days: 41,
      platform: 'instagram',
      creator: 'bakehouse',
      effort: 75,
      topics: ['baking']);

  // --- arriving, needs a look, plain ---
  b.saves.addAll([
    {
      'save_id': 'arriving1',
      'space_id': 'p_mahmoud',
      'status': 'extracting',
      'step_text': 'Watching the video',
      'platform': 'tiktok',
      'source_url': 'https://www.tiktok.com/@kitchen/video/9',
      'created_at': b.ago(hours: 0),
      'created_by': me,
    },
    {
      'save_id': 'unsure1',
      'space_id': 'p_mahmoud',
      'status': 'needs_review',
      'platform': 'tiktok',
      'summary': 'Someone unboxing three pairs of headphones',
      'source_url': 'https://www.tiktok.com/@deals/video/4',
      'key_frame_url': img('sunnies'),
      'created_at': b.ago(days: 1),
      'created_by': me,
      'sections': <String>[],
    },
    {
      'save_id': 'plain1',
      'space_id': 'p_mahmoud',
      'status': 'ready',
      'platform': 'other',
      'summary': 'A long read on how memory works',
      'source_url': 'https://example.com/memory',
      'created_at': b.ago(days: 7),
      'created_by': me,
      'sections': <String>[],
    },
  ]);

  return BrainState(
    loaded: true,
    uid: me,
    userName: 'Mahmoud Adel',
    spaces: const {'me': 'p_mahmoud', 'home': 'g_home'},
    groups: const [
      GroupInfo(
          id: 'g_home',
          name: 'Home',
          members: [me, 'salma'],
          names: {me: 'Mahmoud', 'salma': 'Salma'},
          isDefault: true,
          createdBy: me),
      GroupInfo(
          id: 'g_crew',
          name: 'Weekend crew',
          members: [me, 'omar', 'nour', 'youssef'],
          names: {
            me: 'Mahmoud',
            'omar': 'Omar',
            'nour': 'Nour',
            'youssef': 'Youssef'
          },
          createdBy: 'omar'),
    ],
    saves: b.saves,
    items: b.items,
    lists: [
      {
        'list_id': 'l1',
        'space_id': 'p_mahmoud',
        'section': 'entertainment',
        'name': 'Movie nights',
        'item_refs': [
          for (final i in b.items)
            if (i['section'] == 'entertainment')
              '${i['save_id']}/${i['item_id']}'
        ],
        'path': 'spaces/p_mahmoud/lists/l1',
      },
      {
        'list_id': 'l2',
        'space_id': 'p_mahmoud',
        'section': 'workout',
        'name': 'Morning routine',
        'item_refs': [
          for (final i in b.items)
            if (i['section'] == 'workout') '${i['save_id']}/${i['item_id']}'
        ],
        'overrides': const {},
        'path': 'spaces/p_mahmoud/lists/l2',
      },
    ],
    settings: BrainSettings(theme: 'dark', puzzle: puzzle),
  );
}

String _saveOf(BrainState s, String title) =>
    s.discoveries.firstWhere((d) => d.title.startsWith(title)).saveId;

/// The groups' walls.
Map<String, List<Json>> samplePosts(BrainState s, DateTime now) {
  double at({int days = 0, int hours = 0}) =>
      now.subtract(Duration(days: days, hours: hours)).millisecondsSinceEpoch /
      1000;
  double on(int day, int hour) =>
      DateTime(now.year, now.month, day, hour).millisecondsSinceEpoch / 1000;
  Json post(String id, String kind, String by, String byName, String section,
          String title, String? frame,
          {String? detail,
          num? when,
          Map<String, Object> rsvp = const {},
          Map<String, Object> likes = const {},
          int comments = 0,
          String? text,
          required double at,
          String? saveTitle}) =>
      {
        'post_id': id,
        'kind': kind,
        'by': by,
        'by_name': byName,
        'section': section,
        'noun': section == 'entertainment' ? 'series' : null,
        'title': title,
        'detail': detail,
        'frame': frame == null ? null : img(frame),
        'save_id': saveTitle == null ? null : _saveOf(s, saveTitle),
        'when': when,
        'rsvp': rsvp,
        'likes': likes,
        'comment_count': comments,
        'text': text,
        'at': at,
      };
  return {
    'g_home': [
      post('h1', 'plan', 'salma', 'Salma', 'places', 'Al-Muizz Street', 'muizz',
          detail: 'Islamic Cairo',
          when: on(now.day + 3, 17),
          rsvp: {'salma': 'going', me: 'going'},
          likes: {me: true},
          comments: 2,
          text: 'Friday before sunset? We can get sobia from the carts.',
          at: at(days: 1, hours: 20),
          saveTitle: 'Al-Muizz'),
      post('h2', 'cook', me, 'Mahmoud', 'recipe', 'Molokhia with garlic tasha',
          'molokhia',
          detail: '35 min · serves 4',
          when: on(now.day + 2, 20),
          rsvp: {me: 'going', 'salma': 'maybe'},
          at: at(hours: 22),
          saveTitle: 'Molokhia'),
      post('h3', 'share', 'salma', 'Salma', 'entertainment', 'The Bear', null,
          detail: 'Series · 2022 · 3 seasons',
          likes: {me: true},
          comments: 1,
          text: 'Watch this with me?',
          at: at(hours: 28),
          saveTitle: 'The Bear'),
    ],
    'g_crew': [
      post('c1', 'challenge', 'omar', 'Omar', 'workout',
          '12-minute stairs HIIT', 'runner',
          detail: '3 exercises · about 12 min',
          when: on(now.day + 5, 21),
          rsvp: {'omar': 'done', 'nour': 'in', me: 'in'},
          comments: 1,
          text: 'Everyone does it once before Sunday.',
          at: at(days: 1, hours: 6),
          saveTitle: '12-minute'),
      post('c2', 'plan', 'nour', 'Nour', 'places', 'Tunis Village glamping',
          'fayoum',
          detail: 'Fayoum',
          when: on(now.day + 11, 10),
          rsvp: {'nour': 'going', 'omar': 'going', 'youssef': 'maybe'},
          comments: 0,
          at: at(hours: 20),
          saveTitle: 'Tunis'),
    ],
  };
}

Map<String, List<Json>> sampleComments(DateTime now) {
  double at({int hours = 0}) =>
      now.subtract(Duration(hours: hours)).millisecondsSinceEpoch / 1000;
  return {
    'g_home/h1': [
      {
        'by': me,
        'by_name': 'Mahmoud',
        'text': 'Yes! I’ll book the parking near Bab El Futuh.',
        'kind': 'comment',
        'at': at(hours: 18)
      },
      {
        'by': 'salma',
        'by_name': 'Salma',
        'text': 'Bring the good camera.',
        'kind': 'comment',
        'at': at(hours: 17)
      },
    ],
    'g_crew/c1': [
      {
        'by': 'omar',
        'by_name': 'Omar',
        'text': 'Done in 11:40. Legs are gone.',
        'kind': 'proof',
        'photo': img('runner'),
        'at': at(hours: 9)
      },
    ],
    'g_home/h3': [
      {
        'by': me,
        'by_name': 'Mahmoud',
        'text': 'Thursday night?',
        'kind': 'comment',
        'at': at(hours: 20)
      },
    ],
  };
}
