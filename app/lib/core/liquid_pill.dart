import 'package:flutter/material.dart';

import 'glass.dart';
import 'theme/tokens.dart';

/// One destination in the pill.
typedef PillDestination = ({
  IconData icon,
  IconData selectedIcon,
  String label,
  int badge
});

/// What the pill shows above its destinations: a save processing or just ready.
typedef PillStatus = ({
  String key,
  Widget? thumb,
  String text,
  VoidCallback? onTap
});

/// Design v3 signature: the floating glass pill. It is the navigation, and it grows (a spring
/// morph of its size and content) to show a save processing or ready; in cooking and workout
/// mode a screen passes [replace] and the pill becomes its timer.
class LiquidPill extends StatelessWidget {
  const LiquidPill({
    super.key,
    this.destinations = const [],
    this.selected = 0,
    this.onSelect,
    this.status,
    this.replace,
  });

  final List<PillDestination> destinations;
  final int selected;
  final ValueChanged<int>? onSelect;
  final PillStatus? status;
  final Widget? replace;

  @override
  Widget build(BuildContext context) {
    final (d, curve) = RbMotion.of(context, bounce: true);
    final s = status;
    final body = replace ??
        Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: d,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SizeTransition(
                    sizeFactor: a,
                    alignment: Alignment.bottomCenter,
                    child: child)),
            child: s == null
                ? const SizedBox.shrink(key: ValueKey('none'))
                : _StatusRow(key: ValueKey(s.key), status: s),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (i, dest) in destinations.indexed)
              _Destination(
                  dest: dest,
                  selected: i == selected,
                  onTap: () => onSelect?.call(i)),
          ]),
        ]);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 12),
      child: Center(
        heightFactor: 1,
        child: Glass(
          radius: 32,
          padding: const EdgeInsets.all(6),
          child: AnimatedSize(
            duration: d,
            curve: curve,
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: RbMotion.fast,
              child: KeyedSubtree(key: ValueKey(replace == null), child: body),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({super.key, required this.status});
  final PillStatus status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Pressable(
      onTap: status.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 12, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (status.thumb != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 32, height: 40, child: status.thumb),
              ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(status.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelLarge),
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
  final PillDestination dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final (d, curve) = RbMotion.of(context, bounce: true);
    final icon = Icon(selected ? dest.selectedIcon : dest.icon,
        size: 22, color: selected ? c.text : c.muted);
    return Semantics(
      selected: selected,
      button: true,
      label: dest.label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: d,
          curve: curve,
          height: RbSpace.touch,
          padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 14),
          decoration: BoxDecoration(
            color:
                selected ? c.text.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(RbSpace.pill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            dest.badge > 0
                ? Badge(label: Text('${dest.badge}'), child: icon)
                : icon,
            // The selected destination shows its name; the rest stay icons.
            AnimatedSize(
              duration: d,
              curve: curve,
              child: selected
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: Text(dest.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: c.text)),
                    )
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
      ),
    );
  }
}
