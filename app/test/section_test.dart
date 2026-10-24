import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelbrain/features/section/section_screen.dart';
import 'package:reelbrain/main.dart';

Map<String, dynamic> toolsItem(List<Map<String, dynamic>> tools,
        {String? state}) =>
    {
      'section': 'tools',
      'item_id': '0-tools',
      'save_id': 's',
      'space_id': 'p',
      'user_state': state,
      'data': {'items': tools},
    };

Widget section(List<Map<String, dynamic>> items) => ReelbrainApp(
    home: Scaffold(body: SectionList(section: 'tools', items: items)));

void main() {
  final uv = {
    'name': 'uv',
    'kind': 'github_repo',
    'snippet': 'pip install uv',
    'verified': {
      'ok': true,
      'source': 'github',
      'matched_by': 'url',
      'stars': 91091,
      'last_commit': DateTime.now().toIso8601String()
    },
  };
  final site = {
    'name': 'Blender',
    'kind': 'app',
    'verified': {
      'ok': true,
      'source': 'http',
      'url': 'https://www.blender.org/'
    },
  };
  final named = {
    'name': 'VoiceStudio',
    'kind': 'github_repo',
    'verified': {
      'ok': true,
      'source': 'github',
      'matched_by': 'name',
      'stars': 83466
    },
  };

  testWidgets('tool cards show the link check, snippet copy and status',
      (tester) async {
    await tester.pumpWidget(section([
      toolsItem([uv, site, named], state: 'using')
    ]));
    expect(find.textContaining('★ 91k'), findsOneWidget);
    expect(find.text('Link checked'), findsOneWidget);
    expect(find.textContaining('by name'), findsOneWidget);
    expect(find.text('pip install uv'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    final using =
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Using'));
    expect(using.selected, isTrue);
  });

  testWidgets('category filter narrows the tools', (tester) async {
    await tester.pumpWidget(section([
      toolsItem([uv, site])
    ]));
    await tester.tap(find.widgetWithText(ChoiceChip, 'App'));
    await tester.pump();
    expect(find.text('Blender'), findsOneWidget);
    expect(find.text('uv'), findsNothing);
  });
}
