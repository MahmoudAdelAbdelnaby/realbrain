import 'package:flutter/material.dart';

import 'theme/tokens.dart';

/// Section icons: one grey outline icon per section, named in words (no section colours).
/// ponytail: Material outlined icons stand in for Phosphor regular; swap if the look needs it.
const sectionIcons = {
  'fact_check': Icons.fact_check_outlined,
  'tools': Icons.terminal_outlined,
  'recipe': Icons.restaurant_outlined,
  'places': Icons.place_outlined,
  'workout': Icons.fitness_center_outlined,
};

/// A section named in words with its grey icon, an optional count, tappable when [onTap] is set.
class SectionChip extends StatelessWidget {
  const SectionChip(
      {super.key,
      required this.section,
      required this.label,
      this.count,
      this.onTap});
  final String section, label;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(sectionIcons[section] ?? Icons.bookmark_outline,
            size: 18, color: RbColors.of(context).muted),
        label: Text(count == null ? label : '$label $count'),
        onPressed: onTap,
      );
}

/// A small status word on a raised pill (To try, Cooked, Visited, Needs review). The selected
/// state takes the accent, the one place outside data where it shows.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return AnimatedContainer(
      duration: RbMotion.fast,
      curve: RbMotion.curve,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(RbSpace.pill),
        border: Border.all(color: selected ? c.accent : c.line),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? c.accent : c.muted)),
    );
  }
}

/// Empty or error state: an icon, one line of what happened, one of what to do, optional action.
class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.title,
      this.body,
      this.icon = Icons.inbox_outlined,
      this.action,
      this.onAction});
  final String title;
  final String? body, action;
  final IconData icon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 32, horizontal: RbSpace.side),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 32, color: c.faint),
        const SizedBox(height: 12),
        Text(title, style: t.titleMedium, textAlign: TextAlign.center),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(body!,
              style: t.bodyMedium?.copyWith(color: c.muted),
              textAlign: TextAlign.center),
        ],
        if (action != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(action!)),
        ],
      ]),
    );
  }
}

/// The app's bottom sheet: themed (radius 20, drag handle, the only shadow), safe-area padded,
/// with an optional title line.
Future<T?> showRbSheet<T>(BuildContext context,
    {String? title, required List<Widget> children}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 8),
                child:
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
            ...children,
          ],
        ),
      ),
    ),
  );
}
