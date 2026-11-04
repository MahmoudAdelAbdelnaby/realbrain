import 'package:flutter/material.dart';

import '../art/glyphs.dart';
import '../art/mark.dart';
import '../theme/tokens.dart';
import 'components.dart';

/// One tab: its glyph (or the brain mark), label, and a count badge.
class NavItem {
  const NavItem(this.label, {this.glyph, this.badge = 0});
  final String label;

  /// Null draws the brain mark (My Brain).
  final String? glyph;
  final int badge;
}

/// What sits above the tab bar: a save being understood, or one that just arrived.
class StatusLine {
  const StatusLine(
      {required this.key,
      required this.text,
      this.working = false,
      this.thumb,
      this.onTap});
  final String key, text;
  final bool working;
  final Widget? thumb;
  final VoidCallback? onTap;
}

/// The V5 tab bar (docs/DESIGN_V5.md §2.5): Today · Library · ( + ) · Groups · My Brain, with a
/// saffron index tab on the selected slot and the status line floating above.
class RbNavBar extends StatelessWidget {
  const RbNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onCapture,
    this.status,
  });

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onCapture;
  final StatusLine? status;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final (d, curve) = RbMotion.of(context, bounce: true);
    final slots = <Widget>[
      for (final (i, item) in items.indexed)
        Expanded(
          child: _Slot(
              item: item, selected: i == selected, onTap: () => onSelect(i)),
        ),
    ];
    slots.insert(
        (slots.length / 2).ceil(), Expanded(child: _Capture(onTap: onCapture)));
    final s = status;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedSize(
        duration: d,
        curve: curve,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: RbMotion.fast,
          child: s == null
              ? const SizedBox(key: ValueKey('none'), width: double.infinity)
              : Padding(
                  key: ValueKey(s.key),
                  padding: const EdgeInsets.fromLTRB(
                      RbSpace.side, 0, RbSpace.side, 10),
                  child: _Status(line: s),
                ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          color: c.ground.withValues(alpha: 0.97),
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(height: 66, child: Row(children: slots)),
        ),
      ),
    ]);
  }
}

class _Slot extends StatelessWidget {
  const _Slot(
      {required this.item, required this.selected, required this.onTap});
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final fg = selected ? c.text : c.faint;
    final icon = item.glyph == null
        ? BrainMark(
            size: 30,
            color: fg,
            piece: selected ? c.brand : c.faint.withValues(alpha: 0.5))
        : Glyph(item.glyph!, size: 24, color: fg, weight: selected ? 1.9 : 1.6);
    return Semantics(
      selected: selected,
      button: true,
      label: item.badge > 0 ? '${item.label}, ${item.badge} new' : item.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        child: Stack(alignment: Alignment.topCenter, children: [
          // The index tab: a short saffron bar on the selected destination.
          AnimatedContainer(
            duration: RbMotion.base,
            curve: RbMotion.curve,
            width: selected ? 22 : 0,
            height: 3,
            decoration: BoxDecoration(
                color: c.brand,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(2))),
          ),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              height: 30,
              child: Center(
                child: item.badge > 0
                    ? Badge(
                        label: Text('${item.badge}'),
                        backgroundColor: c.brand,
                        textColor: c.onBrand,
                        child: icon)
                    : icon,
              ),
            ),
            const SizedBox(height: 3),
            Text(item.label,
                maxLines: 1,
                style: TextStyle(
                    fontFamily: RbType.sans,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: fg)),
          ]),
        ]),
      ),
    );
  }
}

class _Capture extends StatelessWidget {
  const _Capture({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Semantics(
      button: true,
      label: 'Save something',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        child: Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.brand,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: c.brand.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(Icons.add_rounded, color: c.onBrand, size: 30),
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.line});
  final StatusLine line;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Pressable(
      onTap: line.onTap,
      child: Panel(
        radius: RbSpace.pill,
        padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 16, 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RbSpace.pill),
              child: SizedBox.square(
                dimension: 34,
                child: line.thumb ??
                    ColoredBox(
                      color: c.raised,
                      child: Center(
                          child: BrainMark(
                              size: 26,
                              motion: line.working
                                  ? MarkMotion.thinking
                                  : MarkMotion.still)),
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(line.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            if (line.onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: c.faint),
            ],
          ]),
        ),
      ),
    );
  }
}
