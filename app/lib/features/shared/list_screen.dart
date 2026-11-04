import 'package:flutter/material.dart';

import '../../core/art/glyphs.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';
import 'open.dart';
import 'tiles.dart';

/// A titled list of discoveries (a Today shelf's "All"), live, with Browse.
class DiscoveryListScreen extends StatelessWidget {
  const DiscoveryListScreen(
      {super.key, required this.title, required this.keys});
  final String title;
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrainState>(
      valueListenable: Repo.instance.state,
      builder: (context, s, _) {
        final list = [
          for (final k in keys)
            if (s.find(k) != null) s.find(k)!
        ];
        return Scaffold(
          appBar: AppBar(title: Text(title), actions: [
            if (list.length > 1)
              IconButton(
                  tooltip: 'Browse',
                  onPressed: () => openViewer(context, list, title: title),
                  icon: Glyph(Glyphs.browse, color: RbColors.of(context).text)),
          ]),
          body: list.isEmpty
              ? const EmptyState(
                  title: 'All caught up', body: 'Nothing left on this shelf.')
              : ListView(padding: const EdgeInsets.only(bottom: 32), children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        RbSpace.side, 0, RbSpace.side, 6),
                    child: MonoLabel(
                        count(list.length, 'discovery', 'discoveries')),
                  ),
                  for (final d in list) DiscoveryRow(d, within: list),
                ]),
        );
      },
    );
  }
}
