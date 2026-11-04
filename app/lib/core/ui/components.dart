import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/glyphs.dart';
import '../theme/tokens.dart';

/// Scales to 0.97 under the finger and springs back; a light haptic on tap.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key,
      required this.child,
      this.onTap,
      this.onLongPress,
      this.haptic = false});
  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final (d, curve) = RbMotion.of(context, bounce: !_down);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down && !RbMotion.reduced(context) ? 0.97 : 1,
        duration: _down ? RbMotion.fast : d,
        curve: _down ? Curves.easeOut : curve,
        child: widget.child,
      ),
    );
  }
}

enum RbButtonKind { primary, secondary, quiet, onPhoto }

/// Buttons (V5): **primary** saffron pill (one per view), **secondary** outlined pill, **quiet**
/// text, **onPhoto** for actions laid over a frame. [small] is 36 dp tall, still a 48 dp target
/// through its padding.
class RbButton extends StatelessWidget {
  const RbButton(this.label,
      {super.key,
      required this.onPressed,
      this.icon,
      this.glyph,
      this.kind = RbButtonKind.primary,
      this.small = false,
      this.expand = false,
      this.busy = false});

  const RbButton.secondary(this.label,
      {super.key,
      required this.onPressed,
      this.icon,
      this.glyph,
      this.small = false,
      this.expand = false,
      this.busy = false})
      : kind = RbButtonKind.secondary;

  const RbButton.quiet(this.label,
      {super.key,
      required this.onPressed,
      this.icon,
      this.glyph,
      this.small = false,
      this.expand = false,
      this.busy = false})
      : kind = RbButtonKind.quiet;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? glyph;
  final RbButtonKind kind;
  final bool small, expand, busy;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final (bg, fg, border) = switch (kind) {
      RbButtonKind.primary => (c.brand, c.onBrand, null),
      RbButtonKind.secondary => (Colors.transparent, c.text, c.line),
      RbButtonKind.quiet => (Colors.transparent, c.text, null),
      RbButtonKind.onPhoto => (
          Colors.black.withValues(alpha: 0.42),
          Colors.white,
          Colors.white.withValues(alpha: 0.28)
        ),
    };
    final h = small ? 36.0 : 50.0;
    final enabled = onPressed != null && !busy;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: fg)),
          )
        else if (glyph != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Glyph(glyph!, size: small ? 16 : 18, color: fg, weight: 1.8),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Icon(icon, size: small ? 16 : 19, color: fg),
          ),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: RbType.sans,
                  fontFamilyFallback: RbType.textFallback,
                  fontSize: small ? 13.5 : 15.5,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        haptic: kind == RbButtonKind.primary,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: small ? 44 : RbSpace.touch),
          child: Center(
            widthFactor: expand ? null : 1,
            heightFactor: 1,
            child: AnimatedOpacity(
              duration: RbMotion.fast,
              opacity: enabled || busy ? 1 : 0.45,
              child: Container(
                height: h,
                padding: EdgeInsets.symmetric(
                    horizontal: kind == RbButtonKind.quiet
                        ? 8
                        : small
                            ? 14
                            : 22),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(RbSpace.pill),
                  border: border == null ? null : Border.all(color: border),
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button for chrome laid over photos (back, more, close).
class PhotoIconButton extends StatelessWidget {
  const PhotoIconButton(
      {super.key, required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          child: SizedBox.square(
            dimension: RbSpace.touch,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      );
}

/// A mono catalogue line, upper-cased: "NO. 0142 · RECIPE · TIKTOK".
class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text,
      {super.key, this.color, this.size = 11, this.maxLines = 1});
  final String text;
  final Color? color;
  final double size;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style:
          RbType.label(color: color ?? RbColors.of(context).faint, size: size));
}

/// A shelf or section header: a mono index, a serif title, and an optional action.
class ShelfHeader extends StatelessWidget {
  const ShelfHeader(
      {super.key,
      required this.title,
      this.index,
      this.caption,
      this.action,
      this.onAction,
      this.padding = const EdgeInsets.fromLTRB(RbSpace.side, 0, 8, 12)});
  final String title;
  final String? index, caption, action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Padding(
      padding: padding,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Semantics(
            header: true,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (index != null) ...[
                MonoLabel(index!, color: c.brandText),
                const SizedBox(height: 4),
              ],
              Text(title, style: RbType.serif(22, color: c.text)),
              if (caption != null) ...[
                const SizedBox(height: 3),
                Text(caption!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(action!,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.muted)),
              const SizedBox(width: 2),
              Icon(Icons.arrow_forward, size: 16, color: c.muted),
            ]),
          ),
      ]),
    );
  }
}

/// A thin editorial rule with an optional mono caption in it.
class Rule extends StatelessWidget {
  const Rule({super.key, this.label, this.padding = EdgeInsets.zero});
  final String? label;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final line = Expanded(child: Container(height: 1, color: c.line));
    return Padding(
      padding: padding,
      child: Row(children: [
        if (label == null)
          line
        else ...[
          SizedBox(width: 0, child: Container()),
          MonoLabel(label!),
          const SizedBox(width: 10),
          line,
        ],
      ]),
    );
  }
}

/// A selectable filter pill (status, kind, source). Selected = ink on text colour.
class FilterPill extends StatelessWidget {
  const FilterPill(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.glyph,
      this.dot,
      this.count});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? glyph;
  final Color? dot;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final fg = selected ? c.ground : c.text;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedContainer(
              duration: RbMotion.fast,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: selected ? c.text : Colors.transparent,
                borderRadius: BorderRadius.circular(RbSpace.pill),
                border: Border.all(color: selected ? c.text : c.line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (dot != null) ...[
                  Container(
                      width: 7,
                      height: 7,
                      decoration:
                          BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                ],
                if (glyph != null) ...[
                  Glyph(glyph!, size: 16, color: fg, weight: 1.7),
                  const SizedBox(width: 6),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: fg)),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text('$count',
                      style: RbType.monoNumber(12,
                          color: selected ? c.ground : c.faint)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A fact on a discovery: "25 min", "Serves 4", "★ 12k" with an icon.
class FactChip extends StatelessWidget {
  const FactChip(this.text, {super.key, this.icon, this.glyph});
  final String text;
  final IconData? icon;
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(RbSpace.tagRadius),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (glyph != null) ...[
          Glyph(glyph!, size: 15, color: c.muted, weight: 1.7),
          const SizedBox(width: 6),
        ] else if (icon != null) ...[
          Icon(icon, size: 15, color: c.muted),
          const SizedBox(width: 6),
        ],
        Text(text,
            style: TextStyle(
                fontSize: 13, color: c.text, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

/// A person's initial on a tone derived from their name.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 32, this.ring});
  final String name;
  final double size;
  final Color? ring;

  static const _tones = [
    Color(0xFFE57B45),
    Color(0xFF46B8A8),
    Color(0xFF68A8F0),
    Color(0xFFA991FF),
    Color(0xFF9BBE5C),
    Color(0xFFCF86D9),
    Color(0xFFE88AA0),
  ];

  @override
  Widget build(BuildContext context) {
    final clean = name.trim();
    final initial = clean.isEmpty ? '?' : clean.characters.first.toUpperCase();
    final tone = _tones[clean.hashCode.abs() % _tones.length];
    return Semantics(
      label: clean,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone,
          shape: BoxShape.circle,
          border:
              Border.all(color: ring ?? RbColors.of(context).ground, width: 2),
        ),
        child: ExcludeSemantics(
          child: Text(initial,
              style: RbType.serif(size * 0.46,
                  color: const Color(0xFF1A1206), height: 1)),
        ),
      ),
    );
  }
}

/// Overlapping avatars, the first [max] then "+n".
class AvatarStack extends StatelessWidget {
  const AvatarStack(this.names, {super.key, this.size = 28, this.max = 4});
  final List<String> names;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    final c = RbColors.of(context);
    return Semantics(
      label: names.join(', '),
      excludeSemantics: true,
      child: SizedBox(
        height: size,
        width: size + (shown.length - 1 + (extra > 0 ? 1 : 0)) * size * 0.62,
        child: Stack(children: [
          for (final (i, n) in shown.indexed)
            PositionedDirectional(
                start: i * size * 0.62, child: Avatar(n, size: size)),
          if (extra > 0)
            PositionedDirectional(
              start: shown.length * size * 0.62,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.raised,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.ground, width: 2)),
                child: Text('+$extra',
                    style: RbType.monoNumber(size * 0.36, color: c.text)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// The app's bottom sheet: paper, radius 16, a grab line, an optional serif title, scrolls
/// when tall, lifts above the keyboard.
Future<T?> showRbSheet<T>(BuildContext context,
    {String? title,
    String? kicker,
    required Widget Function(BuildContext sheet) builder}) {
  final (d, curve) = RbMotion.of(context, bounce: true);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(
        duration: d, curve: curve, reverseDuration: RbMotion.fast),
    builder: (sheet) {
      final c = RbColors.of(sheet);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: SingleChildScrollView(
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: c.line, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        RbSpace.side, 10, RbSpace.side, 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (kicker != null) ...[
                            MonoLabel(kicker, color: c.brandText),
                            const SizedBox(height: 4),
                          ],
                          Text(title, style: RbType.serif(24, color: c.text)),
                        ]),
                  ),
                builder(sheet),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// A row in a sheet or settings list: glyph or icon, title, subtitle, trailing.
class SheetRow extends StatelessWidget {
  const SheetRow(
      {super.key,
      required this.title,
      this.subtitle,
      this.icon,
      this.glyph,
      this.glyphColor,
      this.trailing,
      this.onTap,
      this.destructive = false});
  final String title;
  final String? subtitle, glyph;
  final IconData? icon;
  final Color? glyphColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final fg = destructive ? c.falseFg : c.text;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: RbSpace.side, vertical: 10),
            child: Row(children: [
              if (glyph != null) ...[
                Glyph(glyph!, size: 22, color: glyphColor ?? c.muted),
                const SizedBox(width: 16),
              ] else if (icon != null) ...[
                Icon(icon, size: 22, color: destructive ? c.falseFg : c.muted),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.bodyLarge?.copyWith(color: fg)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: t.bodySmall),
                      ],
                    ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ]),
          ),
        ),
      ),
    );
  }
}

/// A short confirmation at the foot of the screen, with an optional action (Undo, Open).
void toast(BuildContext context, String message,
    {String? action, VoidCallback? onAction, Widget? leading}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        if (leading != null) ...[leading, const SizedBox(width: 12)],
        Expanded(child: Text(message)),
      ]),
      action: action == null
          ? null
          : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      duration: const Duration(milliseconds: 2800),
    ));
}

/// The search field: glyph, hint, clear.
class RbSearchField extends StatelessWidget {
  const RbSearchField(
      {super.key,
      required this.controller,
      this.hint = 'Search',
      this.onChanged,
      this.onTap,
      this.autofocus = false,
      this.readOnly = false,
      this.focusNode});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool autofocus, readOnly;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
          child: Glyph(Glyphs.search, size: 20, color: c.muted),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, v, _) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear',
                  icon: Icon(Icons.close, size: 18, color: c.muted),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
        ),
      ),
    );
  }
}

/// A floating solid panel (what floats casts the one shadow).
class Panel extends StatelessWidget {
  const Panel(
      {super.key,
      required this.child,
      this.radius = RbSpace.cardRadius,
      this.padding = EdgeInsets.zero,
      this.shadow = true,
      this.color});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool shadow;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color ?? c.surface,
      elevation: shadow ? 8 : 0,
      shadowColor: Colors.black.withValues(alpha: dark ? 0.55 : 0.18),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}
