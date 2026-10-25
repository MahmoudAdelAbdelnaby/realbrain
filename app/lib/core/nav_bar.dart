import 'package:flutter/material.dart';

import 'surface.dart';
import 'theme/tokens.dart';

/// One destination in the tab bar; [icon] is drawn in the slot's colour.
typedef NavDestination = ({
  Widget Function(Color color) icon,
  String label,
  int badge
});

/// What shows above the tab bar: a save processing or just ready.
typedef PillStatus = ({
  String key,
  Widget? thumb,
  String text,
  VoidCallback? onTap
});

/// Design v4 tab bar (docs/DESIGN_V4_PROPOSAL.md §4): labelled destinations with the + button
/// in the middle, a status pill that springs in above it while a save processes, and, in
/// cooking and workout mode, a floating panel holding the screen's controls ([replace]).
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    this.destinations = const [],
    this.selected = 0,
    this.onSelect,
    this.onCreate,
    this.status,
    this.replace,
  });

  final List<NavDestination> destinations;
  final int selected;
  final ValueChanged<int>? onSelect;

  /// The + button, placed after the first half of the destinations.
  final VoidCallback? onCreate;
  final PillStatus? status;
  final Widget? replace;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final (d, curve) = RbMotion.of(context, bounce: true);
    final controls = replace;
    if (controls != null) {
      return SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 12),
        child: Center(
          heightFactor: 1,
          child: Panel(radius: 32, padding: const EdgeInsets.all(6), child: controls),
        ),
      );
    }
    final s = status;
    final slots = <Widget>[
      for (final (i, dest) in destinations.indexed)
        Expanded(
          child: _Destination(
              dest: dest,
              selected: i == selected,
              onTap: () => onSelect?.call(i)),
        ),
    ];
    if (onCreate != null) {
      slots.insert(
          (slots.length / 2).ceil(), Expanded(child: _Create(onTap: onCreate!)));
    }
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
                  padding: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 8),
                  child: _StatusRow(status: s),
                ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          color: c.ground.withValues(alpha: 0.92),
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(height: 64, child: Row(children: slots)),
        ),
      ),
    ]);
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});
  final PillStatus status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Pressable(
      onTap: status.onTap,
      child: Panel(
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (status.thumb != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 32, height: 40, child: status.thumb),
              ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(status.text,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelLarge),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination(
      {required this.dest, required this.selected, required this.onTap});
  final NavDestination dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final color = selected ? c.text : c.faint;
    final icon = SizedBox.square(dimension: 26, child: Center(child: dest.icon(color)));
    return Semantics(
      selected: selected,
      button: true,
      label: dest.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          dest.badge > 0 ? Badge(label: Text('${dest.badge}'), child: icon) : icon,
          const SizedBox(height: 4),
          Text(dest.label,
              maxLines: 1,
              style: TextStyle(
                  fontFamily: RbType.family,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ]),
      ),
    );
  }
}

class _Create extends StatelessWidget {
  const _Create({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Semantics(
      button: true,
      label: 'Add a link',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [c.pill.$1, c.pill.$2],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
            ),
            child: Icon(Icons.add, color: c.primaryLabel, size: 26),
          ),
        ),
      ),
    );
  }
}
