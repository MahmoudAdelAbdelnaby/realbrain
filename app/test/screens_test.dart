import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/core/data/demo_repo.dart';
import 'package:reelbrain/core/data/repo.dart';
import 'package:reelbrain/core/ui/nav_bar.dart';
import 'package:reelbrain/features/auth/auth_gate.dart' show SignInScreen;
import 'package:reelbrain/features/capture/capture_sheet.dart';
import 'package:reelbrain/features/gallery/gallery_screen.dart';
import 'package:reelbrain/features/inbox/arriving_screen.dart';
import 'package:reelbrain/features/settings/settings_screen.dart';
import 'package:reelbrain/features/shell/app_shell.dart';
import 'package:reelbrain/features/viewer/viewer_screen.dart';
import 'package:reelbrain/main.dart';
import 'package:reelbrain/preview/sample.dart';

final now = DateTime(2026, 11, 3, 19, 20);

/// The real app on sample data, at the Galaxy S22's 360 × 780 dp (any overflow fails the test),
/// with animations off so pumpAndSettle settles.
Future<DemoRepo> boot(WidgetTester tester,
    {Widget? home,
    Size size = const Size(360, 780),
    String theme = 'dark',
    String lang = 'en',
    BrainState? state}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final st = state ?? sampleState(now);
  final repo = state == null
      ? DemoRepo(st,
          posts: samplePosts(st, now),
          comments: sampleComments(now),
          clock: () => now)
      : DemoRepo(st, clock: () => now);
  Repo.instance = repo;
  appPrefs.value = (lang: lang, theme: theme);
  await tester.pumpWidget(ReelbrainApp(home: home ?? AppShell(now: now)));
  await tester.pumpAndSettle();
  return repo;
}

Finder rich(String text) => find.textContaining(text, findRichText: true);

/// A tab in the tab bar (Today also has "Library" and "Groups" links).
Finder tab(String label) =>
    find.descendant(of: find.byType(RbNavBar), matching: find.text(label));

Future<void> scrollTo(WidgetTester tester, Finder f) => tester
    .scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);

void main() {
  testWidgets(
      'Today: the greeting, the pick with its reason, and five kinds of shelf',
      (tester) async {
    await boot(tester);
    expect(rich('Good evening'), findsOneWidget);
    expect(rich('Mahmoud.'), findsOneWidget);
    expect(find.text('A 35-minute dinner, opened yesterday.'), findsOneWidget);
    expect(find.text('Cook it'), findsOneWidget);
    expect(
        find.text('One save being understood · 1 needs you'), findsOneWidget);
    // The strip says it; nothing floats over the pick's button.
    expect(find.textContaining('Watching the video'), findsNothing);
    for (final shelf in [
      'Left off',
      'Not tried yet',
      'From your groups',
      'Recently saved',
      'Worth revisiting'
    ]) {
      await scrollTo(tester, find.text(shelf));
      expect(find.text(shelf), findsOneWidget);
    }
  });

  testWidgets('Today in paper, in Arabic (right to left) and on a tablet',
      (tester) async {
    await boot(tester, theme: 'light');
    expect(Theme.of(tester.element(find.text('Cook it'))).brightness,
        Brightness.light);
    await boot(tester, lang: 'ar');
    expect(Directionality.of(tester.element(find.text('Cook it'))),
        TextDirection.rtl);
    await boot(tester, size: const Size(1024, 1366));
    expect(find.text('Cook it'), findsOneWidget);
  });

  testWidgets('an empty archive says what Realbrain does and offers one action',
      (tester) async {
    await boot(tester,
        state: BrainState(
            loaded: true,
            uid: 'new',
            userName: 'Nour',
            spaces: const {'me': 'p'}));
    await scrollTo(tester, find.text('Save something'));
    expect(find.text('Your archive is empty'), findsOneWidget);
    expect(find.text('Save something'), findsOneWidget);
  });

  testWidgets('a discovery page: the stamp places a piece and says so',
      (tester) async {
    final repo = await boot(tester);
    await tester.tap(find.text('Molokhia with garlic tasha').first);
    await tester.pumpAndSettle();
    expect(find.text('COOKED'), findsOneWidget); // the stamp, not done yet
    await scrollTo(tester, find.text('Ingredients'));
    expect(find.text('400 g frozen molokhia'), findsOneWidget);
    await tester.tap(find.text('COOKED'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        repo.log.where((l) => l.startsWith('stamp ') && l.endsWith(' cooked')),
        isNotEmpty);
    expect(repo.log.where((l) => l.startsWith('seen ')),
        isNotEmpty); // opening it counts
    expect(find.textContaining('Piece placed'), findsOneWidget);
  });

  testWidgets(
      'Library: search everything, then a category with its own filters',
      (tester) async {
    await boot(tester);
    await tester.tap(tab('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'garlic');
    await tester.pumpAndSettle();
    expect(find.text('Molokhia with garlic tasha'), findsOneWidget);
    expect(
        find.text('Fattah for Eid'), findsOneWidget); // "garlic vinegar sauce"
    expect(find.text('2 MATCHES'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Watch & Read').hitTestable());
    await tester.tap(find.text('Watch & Read').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Want to'), findsOneWidget);
    // The facets row scrolls sideways; Series may start beyond the edge.
    await tester.drag(find.text('Want to'), const Offset(-260, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Series'));
    await tester.pumpAndSettle();
    expect(find.text('Severance'), findsOneWidget);
    expect(find.text('Project Hail Mary'), findsNothing);
  });

  testWidgets('the viewer: moments, Up next, swipe to the next discovery',
      (tester) async {
    final st = sampleState(now);
    final open = [
      for (final d in st.discoveries)
        if (d.isOpen) d.key
    ];
    await boot(tester,
        state: st, home: ViewerScreen(keys: open, title: 'Not tried yet'));
    expect(find.text('Not tried yet · 1 of ${open.length}'.toUpperCase()),
        findsOneWidget);
    expect(find.text('Up next'.toUpperCase()), findsOneWidget);
    await tester.fling(
        find.byType(PageView).first, const Offset(0, -600), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Not tried yet · 2 of ${open.length}'.toUpperCase()),
        findsOneWidget);
  });

  testWidgets('My Brain: level, achievements, and the puzzle can be hidden',
      (tester) async {
    final repo = await boot(tester);
    await tester.tap(tab('My Brain'));
    await tester.pumpAndSettle();
    expect(find.text('Explorer'), findsOneWidget);
    await tester.tap(find.text('Hide the puzzle'));
    await tester.pumpAndSettle();
    expect(repo.log.last, contains('puzzle: false'));
    expect(find.text('The puzzle is hidden. Your progress still counts.'),
        findsOneWidget);
    await scrollTo(tester, find.text('Achievements'));
    expect(find.text('First piece'), findsOneWidget);
  });

  testWidgets('Groups: a wall with a plan you can RSVP to', (tester) async {
    final repo = await boot(tester);
    await tester.tap(tab('Groups'));
    await tester.pumpAndSettle();
    expect(find.text('Weekend crew'), findsOneWidget);
    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
    expect(rich('is cooking this'), findsOneWidget);
    await tester.tap(find.text('Maybe').first);
    await tester.pumpAndSettle();
    expect(repo.log.last, startsWith('react h2 rsvp'));
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    expect(find.text('COMING UP'), findsOneWidget);
  });

  testWidgets('capture: a link on the clipboard is one tap', (tester) async {
    final repo = await boot(tester,
        home: Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () => openCapture(context,
                            clipboard: 'https://www.tiktok.com/@a/video/1'),
                        child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('A TikTok video'), findsOneWidget);
    await tester.tap(find.text('Save this link'));
    await tester.pumpAndSettle();
    expect(repo.log.last, 'link https://www.tiktok.com/@a/video/1 me auto');
    expect(find.text('Saved. Realbrain is reading it.'), findsOneWidget);
  });

  testWidgets('Arriving: one tap files an unsure save', (tester) async {
    final repo = await boot(tester, home: const ArrivingScreen());
    expect(find.text('Need you'), findsOneWidget);
    await tester.tap(find.text('Recipe'));
    await tester.pumpAndSettle();
    expect(repo.log.last, 'file unsure1 recipe');
  });

  testWidgets('Settings: theme, the puzzle, diagnostics', (tester) async {
    final repo = await boot(tester, home: const SettingsScreen());
    await tester.tap(find.text('Paper'));
    await tester.pumpAndSettle();
    expect(appPrefs.value.theme, 'light');
    expect(repo.log.last, contains('theme: light'));
    await scrollTo(tester, find.text('Phone queue'));
    expect(find.text('Phone queue'), findsOneWidget);
  });

  testWidgets('sign-in explains Realbrain in three steps', (tester) async {
    var signedIn = false;
    await boot(tester,
        home: SignInScreen(onSignIn: () async => signedIn = true));
    expect(rich('finally used.'), findsOneWidget);
    await scrollTo(tester, find.text('Get started with Google'));
    await tester.tap(find.text('Get started with Google'));
    await tester.pumpAndSettle();
    expect(signedIn, isTrue);
  });

  testWidgets('the design gallery renders in both themes and directions',
      (tester) async {
    await boot(tester, home: const GalleryScreen());
    expect(find.text('The Curiosity Archive'), findsOneWidget);
    await tester.tap(find.byTooltip('Flip direction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Flip theme'));
    await tester.pumpAndSettle();
    expect(find.text('The Curiosity Archive'), findsOneWidget);
  });
}
