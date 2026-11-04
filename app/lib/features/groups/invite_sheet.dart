import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

import '../../core/art/mark.dart';
import '../../core/data/repo.dart';
import '../../core/links.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../../core/ui/states.dart';

/// A QR code for an invite link: ink modules on paper with a quiet zone (scannable in any
/// light), rounded modules, and the mark in the middle (error correction covers it).
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, this.size = 200});
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.high));
    return Semantics(
      label: 'QR code for the invite link',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.07),
        decoration: BoxDecoration(
            color: Plate.paper,
            borderRadius: BorderRadius.circular(RbSpace.cardRadius)),
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
              size: Size.square(size * 0.86), painter: _QrPainter(image)),
          Container(
            width: size * 0.2,
            height: size * 0.2,
            decoration: BoxDecoration(
                color: Plate.paper, borderRadius: BorderRadius.circular(6)),
            child: Center(
                child: BrainMark(
                    size: size * 0.17,
                    color: Plate.ink,
                    piece: RbColors.light.brand)),
          ),
        ]),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);
  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final m = size.width / n;
    final paint = Paint()..color = Plate.ink;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (!image.isDark(r, c)) continue;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(c * m, r * m, m + 0.3, m + 0.3),
                Radius.circular(m * 0.28)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}

/// Invite to a group: QR to scan, the code to read aloud, the link to send.
Future<void> openInvite(BuildContext context, GroupInfo g) =>
    showRbSheet<void>(context,
        title: 'Invite to ${g.name}',
        kicker: 'Valid for 7 days',
        builder: (_) => _Invite(g: g));

class _Invite extends StatefulWidget {
  const _Invite({required this.g});
  final GroupInfo g;

  @override
  State<_Invite> createState() => _InviteState();
}

class _InviteState extends State<_Invite> {
  late final Future<GroupInvite> _invite = Repo.instance.invite(widget.g.id);

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return FutureBuilder<GroupInvite>(
      future: _invite,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorNote(
              message: apiError(snap.error!), title: 'Couldn’t make an invite');
        }
        final inv = snap.data;
        if (inv == null) return const LoadingMark(text: 'Making an invite');
        final code = inv.code.toUpperCase();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
          child: Column(children: [
            QrView(data: inv.url, size: 210),
            const SizedBox(height: 14),
            const MonoLabel('Or type the code'),
            const SizedBox(height: 4),
            SelectableText(
              '${code.substring(0, 4)} ${code.substring(4)}',
              style:
                  RbType.monoNumber(30, color: c.text, weight: FontWeight.w600)
                      .copyWith(letterSpacing: 4),
            ),
            const SizedBox(height: 4),
            Text('In Realbrain: Groups › Join with a code', style: t.bodySmall),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: RbButton.secondary('Copy link', icon: Icons.link,
                    onPressed: () {
                  Clipboard.setData(ClipboardData(text: inv.url));
                  toast(context, 'Invite link copied');
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RbButton('Send invite',
                    icon: Icons.ios_share,
                    onPressed: () => shareOut(
                        'Join “${widget.g.name}” on Realbrain, where we keep the things we find and actually do them.\n${inv.url}\nCode: $code')),
              ),
            ]),
          ]),
        );
      },
    );
  }
}
