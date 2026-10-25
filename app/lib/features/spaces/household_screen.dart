import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/native.dart';

/// Your spaces (read live from Firestore under the security rules), Create household + invite link,
/// and join by code. Spaces and members are only ever written by the backend.
class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _inviteUrl;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createOrInvite(String? homeId) => _run(() async {
        final r = homeId == null
            ? await api('POST', '/v1/spaces/household', {'name': 'Home'})
            : await api('POST', '/v1/spaces/$homeId/invite');
        setState(() => _inviteUrl = r['invite_url'] as String);
      });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Spaces')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.doc('users/$uid').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return _Pad(Text('Could not load your spaces: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final spaces =
              (snap.data!.data()?['spaces'] as Map?)?.cast<String, String>();
          if (spaces == null) {
            return const _Pad(Text(
                'Setting up your space… (the backend needs to be reachable once)'));
          }
          final home = spaces['home'];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SpaceTile(id: spaces['me']!, label: 'Me'),
              if (home != null) _SpaceTile(id: home, label: 'Home'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : () => _createOrInvite(home),
                child:
                    Text(home == null ? 'Create household' : 'New invite link'),
              ),
              if (_inviteUrl != null) ...[
                const SizedBox(height: 12),
                SelectableText(_inviteUrl!),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      shareText('Join our Reelbrain Home: $_inviteUrl'),
                  icon: const Icon(Icons.share),
                  label: const Text('Share link'),
                ),
                const Text('Valid for 7 days.'),
              ],
              const Divider(height: 40),
              TextField(
                controller: _code,
                decoration: const InputDecoration(
                    labelText: 'Join with an invite code'),
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await api('POST',
                              '/v1/invites/${_code.text.trim()}/accept');
                          _code.clear();
                        }),
                child: const Text('Join'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({required this.id, required this.label});
  final String id;
  final String label;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('spaces/$id').snapshots(),
      builder: (context, snap) {
        final members = (snap.data?.data()?['members'] as List?)?.length;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading:
              Icon(label == 'Me' ? Icons.person_outline : Icons.home_outlined),
          title: Text(label),
          subtitle: Text(members == null
              ? '…'
              : '$members member${members == 1 ? '' : 's'}'),
        );
      },
    );
  }
}

/// Opened from an invite link: confirm, then join.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.code});
  final String code;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api('POST', '/v1/invites/${widget.code}/accept');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join household')),
      body: _Pad(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Join this Home space? Reels shared to Realbrain · Home will be saved there for both of you.'),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _busy ? null : _join, child: const Text('Join')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(16), child: child);
}
