import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../feed/feed_screen.dart';

/// Saves that need you (P1-07): unsure, caption-only or failed.
const inboxStatuses = {'needs_review', 'partial', 'failed'};

bool inInbox(Map<String, dynamic> save) =>
    inboxStatuses.contains(save['status']);

/// Files a save under a section: the backend logs the correction and re-reads the video.
Future<void> fileUnder(
        BuildContext context, Map<String, dynamic> save, String section) =>
    _run(
        context,
        () => api('POST', '/v1/saves/${save['save_id']}/section',
            {'section': section}),
        section == 'none'
            ? 'Kept as a plain save'
            : 'Re-reading it as ${sectionLabels[section]}');

Future<void> retrySave(BuildContext context, Map<String, dynamic> save) => _run(
    context,
    () => api('POST', '/v1/saves/${save['save_id']}/retry'),
    'Trying again');

Future<void> _run(
    BuildContext context, Future<Object?> Function() call, String done) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await call();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(apiError(e))));
  }
}

/// Live list from the feed (no second Firestore subscription).
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key, required this.saves, required this.spaceLabel});
  final ValueListenable<List<Map<String, dynamic>>> saves;
  final String Function(String spaceId) spaceLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // the liquid shows through
      appBar: AppBar(
          backgroundColor: Colors.transparent, title: const Text('Inbox')),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: saves,
        builder: (context, list, _) =>
            InboxList(saves: list, spaceLabel: spaceLabel),
      ),
    );
  }
}

class InboxList extends StatelessWidget {
  const InboxList({super.key, required this.saves, required this.spaceLabel});
  final List<Map<String, dynamic>> saves;
  final String Function(String spaceId) spaceLabel;

  @override
  Widget build(BuildContext context) {
    if (saves.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
            'Nothing to sort. Saves the AI was unsure about, or could not fully read, show up here.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final s in saves) ...[
          SaveCard(save: s, space: spaceLabel(s['space_id'] as String? ?? '')),
          _Actions(save: s),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.save});
  final Map<String, dynamic> save;

  @override
  Widget build(BuildContext context) {
    final failed = save['status'] == 'failed';
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!failed) ...[
          const Text('File as'),
          for (final e in sectionLabels.entries)
            ActionChip(
                label: Text(e.value),
                onPressed: () => fileUnder(context, save, e.key)),
          ActionChip(
              label: const Text('None of these'),
              onPressed: () => fileUnder(context, save, 'none')),
        ],
        TextButton.icon(
          onPressed: () => retrySave(context, save),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
