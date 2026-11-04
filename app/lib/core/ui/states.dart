import 'package:flutter/material.dart';

import '../art/hoopoe.dart';
import '../art/mark.dart';
import '../theme/tokens.dart';
import 'art_frames.dart';
import 'components.dart';

/// An empty state: Hudhud on a plate, one line of what's here, one of what to do, one action.
class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.title,
      this.body,
      this.action,
      this.onAction,
      this.pose = HudhudPose.curious,
      this.plateCaption,
      this.compact = false});
  final String title;
  final String? body, action, plateCaption;
  final VoidCallback? onAction;
  final HudhudPose pose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RbColors.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: compact ? 16 : 28, horizontal: RbSpace.side),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Plate(
          caption: plateCaption,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: Hudhud(width: compact ? 120 : 168, pose: pose, motion: true),
        ),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: RbType.serif(compact ? 20 : 24, color: c.text)),
        if (body != null) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(body!,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: c.muted)),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 18),
          RbButton(action!, onPressed: onAction),
        ],
      ]),
    );
  }
}

/// Something went wrong, in plain words, with a way to try again.
class ErrorNote extends StatelessWidget {
  const ErrorNote({super.key, required this.message, this.onRetry, this.title});
  final String message;
  final String? title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: RbSpace.side, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: c.falseBg,
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: c.falseFg, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title ?? 'Something went wrong',
                style: t.titleSmall?.copyWith(color: c.text)),
            const SizedBox(height: 2),
            Text(message, style: t.bodySmall?.copyWith(color: c.text)),
          ]),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}

/// Loading: the mark lifting its piece, and what is happening in mono.
class LoadingMark extends StatelessWidget {
  const LoadingMark(
      {super.key, this.text = 'Opening your archive', this.size = 56});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BrainMark(size: size, motion: MarkMotion.thinking),
            const SizedBox(height: 14),
            MonoLabel(text),
          ]),
        ),
      );
}

/// A flat placeholder block at the size of what will arrive (no shimmer).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 4});
  final double? width;
  final double height, radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: RbColors.of(context).raised,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// A list row while loading: thumbnail and two lines, at the real size.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: RbSpace.side, vertical: 10),
        child: Row(children: [
          SkeletonBox(width: 64, height: 80, radius: RbSpace.photoRadius),
          SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: 90, height: 10),
              SizedBox(height: 10),
              SkeletonBox(height: 16),
              SizedBox(height: 8),
              SkeletonBox(width: 140, height: 12),
            ]),
          ),
        ]),
      );
}
