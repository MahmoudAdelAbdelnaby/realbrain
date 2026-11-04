import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/art/glyphs.dart';
import '../../core/categories.dart';
import '../../core/data/repo.dart';
import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/native.dart' show apiError;
import '../../core/theme/tokens.dart';
import '../../core/ui/art_frames.dart';
import '../../core/ui/components.dart';
import '../shared/open.dart';

/// What each kind of post says, in the group's voice.
String postVerb(Json p) => switch (p['kind']) {
      'plan' => 'is planning a visit',
      'cook' => 'is cooking this',
      'challenge' => 'challenged the group',
      'note' => 'wrote',
      _ =>
        'shared ${_a(p['noun'] as String? ?? categoryOf(p['section'] as String?).noun)}',
    };

String _a(String noun) => '${'aeiou'.contains(noun[0]) ? 'an' : 'a'} $noun';

/// A post on a group's wall. Shares get likes and comments; plans and cook-alongs get RSVPs, a
/// time and Add to calendar; challenges get joining and photo proof.
class PostCard extends StatelessWidget {
  const PostCard(
      {super.key, required this.post, required this.group, required this.uid});
  final Json post;
  final GroupInfo group;
  final String uid;

  Map<String, dynamic> _map(String k) =>
      ((post[k] as Map?) ?? const {}).cast<String, dynamic>();

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    final kind = post['kind'] as String? ?? 'share';
    final who =
        post['by_name'] as String? ?? group.nameOf(post['by'] as String? ?? '');
    final likes = _map('likes');
    final liked = likes.containsKey(uid);
    final rsvp = _map('rsvp');
    final whenAt = post['when'] as num?;
    final pid = post['post_id'] as String;
    final section = post['section'] as String?;
    return Container(
      margin: const EdgeInsets.fromLTRB(RbSpace.side, 0, RbSpace.side, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(RbSpace.cardRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
          child: Row(children: [
            Avatar(who, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: who, style: t.titleSmall),
                  TextSpan(
                      text: ' ${postVerb(post)}',
                      style: t.bodyMedium?.copyWith(color: c.muted)),
                ]),
              ),
            ),
            MonoLabel(ago((post['at'] ?? 0) as num), size: 10),
          ]),
        ),
        if ((post['text'] as String?)?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text('${post['text']}',
                style:
                    RbType.serif(17, color: c.text, italic: true, height: 1.3)),
          ),
        if (post['title'] != null)
          Pressable(
            onTap: post['save_id'] == null
                ? null
                : () => openSave(context, post['save_id'] as String),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(RbSpace.photoRadius),
                  child: SizedBox(
                    width: 64,
                    height: 76,
                    child: FrameImage(
                        stored: post['frame'] as String?,
                        fallback: SpecimenCard(section: section ?? 'ideas')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Glyph(section ?? 'bookmark',
                              size: 13, color: c.pigment(section), weight: 1.9),
                          const SizedBox(width: 5),
                          MonoLabel(
                              post['noun'] as String? ??
                                  categoryOf(section).noun,
                              size: 10),
                        ]),
                        const SizedBox(height: 4),
                        Text('${post['title']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: RbType.serif(17, color: c.text)),
                        if ((post['detail'] as String?)?.isNotEmpty ?? false)
                          Text('${post['detail']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall),
                      ]),
                ),
              ]),
            ),
          ),
        if (whenAt != null && kind != 'share')
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: c.raised,
                  borderRadius: BorderRadius.circular(RbSpace.photoRadius)),
              child: Row(children: [
                Icon(
                    kind == 'challenge'
                        ? Icons.flag_outlined
                        : Icons.event_outlined,
                    color: c.brandText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      '${kind == 'challenge' ? 'By ' : ''}${when(fromEpoch(whenAt))}',
                      style: RbType.serif(17, color: c.text)),
                ),
                if (kind != 'challenge')
                  IconButton(
                    tooltip: 'Add to calendar',
                    onPressed: () => openUrl(
                        context,
                        calendarUrl(
                            title:
                                '${kind == 'cook' ? 'Cook: ' : ''}${post['title'] ?? 'Plan'}',
                            start: fromEpoch(whenAt),
                            details: 'From ${group.name} on Realbrain',
                            location: post['place'] as String?)),
                    icon: Icon(Icons.edit_calendar_outlined, color: c.text),
                  ),
              ]),
            ),
          ),
        if (kind == 'plan' || kind == 'cook')
          _Rsvp(
              groupId: group.id,
              postId: pid,
              rsvp: rsvp,
              uid: uid,
              group: group),
        if (kind == 'challenge')
          _Challenge(
              groupId: group.id,
              post: post,
              rsvp: rsvp,
              uid: uid,
              group: group),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(children: [
            IconButton(
              tooltip: liked ? 'Unlike' : 'Like',
              onPressed: () => Repo.instance
                  .react(group.id, pid, 'likes', liked ? null : true),
              icon: Icon(liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? c.falseFg : c.muted, size: 22),
            ),
            if (likes.isNotEmpty)
              Text('${likes.length}',
                  style: RbType.monoNumber(13, color: c.muted)),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => openComments(context, group, post),
              icon: Icon(Icons.chat_bubble_outline, size: 19, color: c.muted),
              label: Text(
                  ((post['comment_count'] ?? 0) as num) > 0
                      ? '${post['comment_count']}'
                      : kind == 'cook'
                          ? 'Share how it went'
                          : 'Comment',
                  style: t.labelMedium?.copyWith(color: c.muted)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Rsvp extends StatelessWidget {
  const _Rsvp(
      {required this.groupId,
      required this.postId,
      required this.rsvp,
      required this.uid,
      required this.group});
  final String groupId, postId, uid;
  final Map<String, dynamic> rsvp;
  final GroupInfo group;

  @override
  Widget build(BuildContext context) {
    final mine = rsvp[uid] as String?;
    final going = [
      for (final e in rsvp.entries)
        if (e.value == 'going') group.nameOf(e.key)
    ];
    final maybe = rsvp.values.where((v) => v == 'maybe').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, children: [
          for (final (v, label) in const [
            ('going', 'Going'),
            ('maybe', 'Maybe'),
            ('no', 'Can’t')
          ])
            FilterPill(
              label: label,
              selected: mine == v,
              onTap: () => Repo.instance
                  .react(groupId, postId, 'rsvp', mine == v ? null : v),
            ),
        ]),
        if (going.isNotEmpty || maybe > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              if (going.isNotEmpty) AvatarStack(going, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    [
                      if (going.isNotEmpty) '${going.length} going',
                      if (maybe > 0) '$maybe maybe'
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Challenge extends StatelessWidget {
  const _Challenge(
      {required this.groupId,
      required this.post,
      required this.rsvp,
      required this.uid,
      required this.group});
  final String groupId, uid;
  final Json post;
  final Map<String, dynamic> rsvp;
  final GroupInfo group;

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final mine = rsvp[uid] as String?;
    final inIt = [for (final e in rsvp.entries) group.nameOf(e.key)];
    final done = rsvp.values.where((v) => v == 'done').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (inIt.isNotEmpty)
          Row(children: [
            AvatarStack(inIt, size: 24),
            const SizedBox(width: 8),
            Text('$done of ${inIt.length} done',
                style: RbType.label(color: c.brandText, size: 11.5)),
          ]),
        const SizedBox(height: 6),
        if (mine == null)
          RbButton.secondary('Join the challenge',
              small: true,
              icon: Icons.flag_outlined,
              onPressed: () => Repo.instance
                  .react(groupId, post['post_id'] as String, 'rsvp', 'in'))
        else if (mine != 'done')
          RbButton('I did it: post proof',
              small: true,
              icon: Icons.photo_camera_outlined,
              onPressed: () =>
                  openComments(context, group, post, kind: 'proof'))
        else
          Row(children: [
            Glyph(Glyphs.piece,
                size: 18, color: c.brand, fill: c.brand, weight: 1),
            const SizedBox(width: 6),
            Text('You did it', style: Theme.of(context).textTheme.labelLarge),
          ]),
      ]),
    );
  }
}

/// The conversation under a post, with a photo for results and proofs.
Future<void> openComments(BuildContext context, GroupInfo group, Json post,
        {String kind = 'comment'}) =>
    showRbSheet<void>(context,
        title: kind == 'proof'
            ? 'Post your proof'
            : '${post['title'] ?? 'Comments'}',
        kicker: group.name,
        builder: (_) => _Comments(group: group, post: post, kind: kind));

class _Comments extends StatefulWidget {
  const _Comments(
      {required this.group, required this.post, required this.kind});
  final GroupInfo group;
  final Json post;
  final String kind;

  @override
  State<_Comments> createState() => _CommentsState();
}

class _CommentsState extends State<_Comments> {
  final _text = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;
  late final Stream<List<Json>> _stream =
      Repo.instance.comments(widget.group.id, widget.post['post_id'] as String);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await ImagePicker()
          .pickImage(source: source, maxWidth: 1280, imageQuality: 78);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) toast(context, 'Couldn’t open the photos.');
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty && _photo == null) return;
    setState(() => _busy = true);
    try {
      final kind = _photo != null
          ? (widget.kind == 'proof' || widget.post['kind'] == 'challenge'
              ? 'proof'
              : widget.post['kind'] == 'cook'
                  ? 'result'
                  : 'comment')
          : 'comment';
      await Repo.instance.comment(
          widget.group.id, widget.post['post_id'] as String,
          text: text, photo: _photo, kind: kind);
      if (!mounted) return;
      _text.clear();
      setState(() {
        _photo = null;
        _busy = false;
      });
      if (kind == 'proof') toast(context, 'Proof posted. Nice work.');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, apiError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RbColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RbSpace.side),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        StreamBuilder<List<Json>>(
          stream: _stream,
          builder: (context, snap) {
            final list = snap.data ?? const [];
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                    widget.kind == 'proof'
                        ? 'A photo of you doing it is all it takes.'
                        : 'No comments yet. Say something.',
                    style: t.bodySmall),
              );
            }
            return Column(children: [
              for (final cm in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Avatar(cm['by_name'] as String? ?? '?', size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(cm['by_name'] as String? ?? 'Someone',
                                      style: t.titleSmall),
                                  if (cm['kind'] == 'proof' ||
                                      cm['kind'] == 'result') ...[
                                    const SizedBox(width: 8),
                                    MonoLabel(
                                        cm['kind'] == 'proof'
                                            ? 'Proof'
                                            : 'Result',
                                        color: c.brandText,
                                        size: 10),
                                  ],
                                  const Spacer(),
                                  MonoLabel(ago((cm['at'] ?? 0) as num),
                                      size: 10),
                                ]),
                                if ((cm['text'] as String?)?.isNotEmpty ??
                                    false)
                                  Text('${cm['text']}', style: t.bodyMedium),
                                if (cm['photo'] != null) ...[
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        RbSpace.photoRadius),
                                    child: SizedBox(
                                      height: 180,
                                      width: double.infinity,
                                      child: FrameImage(
                                          stored: cm['photo'] as String?,
                                          fallback:
                                              ColoredBox(color: c.raised)),
                                    ),
                                  ),
                                ],
                              ]),
                        ),
                      ]),
                ),
            ]);
          },
        ),
        const SizedBox(height: 8),
        if (_photo != null)
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RbSpace.photoRadius),
              child: Image.memory(_photo!,
                  height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: PhotoIconButton(
                  icon: Icons.close,
                  label: 'Remove photo',
                  onTap: () => setState(() => _photo = null)),
            ),
          ]),
        Row(children: [
          IconButton(
              tooltip: 'Take a photo',
              onPressed: () => _pick(ImageSource.camera),
              icon: Icon(Icons.photo_camera_outlined, color: c.muted)),
          IconButton(
              tooltip: 'Choose a photo',
              onPressed: () => _pick(ImageSource.gallery),
              icon: Icon(Icons.photo_outlined, color: c.muted)),
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                  hintText: widget.kind == 'proof'
                      ? 'Add a line (optional)'
                      : 'Write a comment',
                  counterText: ''),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: _busy ? null : _send,
            style: IconButton.styleFrom(
                backgroundColor: c.brand, foregroundColor: c.onBrand),
            icon: _busy
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.onBrand))
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ]),
      ]),
    );
  }
}
