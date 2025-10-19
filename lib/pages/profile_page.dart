// lib/pages/profile_page.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'sign_in_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _linking = false;

  // NEW: one-time public-profile backfill (for older accounts)
  bool _ensuredPublic = false;
  Future<void> _ensurePublicProfile() async {
    final user = FirebaseAuth.instance.currentUser!;
    final pubRef =
        FirebaseFirestore.instance.collection('public_profiles').doc(user.uid);
    final exists = (await pubRef.get()).exists;
    if (exists) return;

    final privSnap = await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .get();
    final m = privSnap.data() ?? {};
    final displayName =
        (m['displayName'] ?? user.displayName ?? '').toString();
    final username = (m['username'] ?? '').toString();

    await pubRef.set({
      'displayName': displayName,
      'username': username,
      'photoURL': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in.')));
    }

    // Kick off one-time backfill without blocking build
    if (!_ensuredPublic) {
      _ensuredPublic = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePublicProfile());
    }

    final profRef =
        FirebaseFirestore.instance.collection('user_profiles').doc(uid);
    final boardRef =
        FirebaseFirestore.instance.collection('boards').doc(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists) {
            return Center(
              child: FilledButton(
                onPressed: () async {
                  await _createDefaultProfile(profRef);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile created.')),
                  );
                },
                child: const Text('Create profile now'),
              ),
            );
          }

          final data = snap.data!.data()!;
          final displayName = (data['displayName'] ?? '').toString();
          final username = (data['username'] ?? '').toString();
          final anon = data['anon'] == true;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final uidShort = uid.substring(0, 6);

          if (_nameCtrl.text != displayName) {
            _nameCtrl.text = displayName;
            _nameCtrl.selection =
                TextSelection.collapsed(offset: _nameCtrl.text.length);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header card + name editor
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 24,
                          child: Text(
                            (displayName.isEmpty ? '?' : displayName[0])
                                .toUpperCase(),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          displayName.isEmpty ? '(no name)' : displayName,
                        ),
                        subtitle: Text('Username: $username'),
                        trailing: Text(uidShort),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.verified_user, size: 18),
                          const SizedBox(width: 6),
                          Text(anon ? 'Anonymous account' : 'Linked account'),
                        ],
                      ),
                      if (createdAt != null)
                        Text(
                          'Created: ${createdAt.toLocal()}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      final name = _nameCtrl.text.trim();
                                      if (name.isEmpty) return;
                                      setState(() => _saving = true);

                                      // Private profile
                                      await profRef.set(
                                        {'displayName': name},
                                        SetOptions(merge: true),
                                      );

                                      // Auth displayName
                                      final user = FirebaseAuth
                                          .instance.currentUser!;
                                      await user.updateDisplayName(name);
                                      await user.reload();

                                      // Public mini-profile mirror
                                      await FirebaseFirestore.instance
                                          .collection('public_profiles')
                                          .doc(user.uid)
                                          .set({
                                        'displayName': name,
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));

                                      setState(() => _saving = false);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('Saved.')));
                                    },
                              icon: _saving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: uid));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Friend code copied: $uidShort'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy friend code'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (anon && kIsWeb)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _linking
                                    ? null
                                    : () async {
                                        setState(() => _linking = true);
                                        try {
                                          final provider =
                                              GoogleAuthProvider();
                                          // Force account chooser on web
                                          provider.setCustomParameters(
                                              {'prompt': 'select_account'});

                                          await FirebaseAuth.instance
                                              .currentUser!
                                              .linkWithPopup(provider);

                                          await profRef.set(
                                              {'anon': false},
                                              SetOptions(merge: true));

                                          final name = (await profRef.get())
                                              .data()?['displayName'];
                                          if (name is String &&
                                              name.isNotEmpty) {
                                            await FirebaseAuth.instance
                                                .currentUser!
                                                .updateDisplayName(name);
                                          }

                                          // Public mirror (also photo)
                                          final me = FirebaseAuth
                                              .instance.currentUser!;
                                          await FirebaseFirestore.instance
                                              .collection('public_profiles')
                                              .doc(me.uid)
                                              .set({
                                            'displayName': me.displayName ??
                                                (name is String ? name : '') ??
                                                '',
                                            'photoURL': me.photoURL,
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          }, SetOptions(merge: true));

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Linked to Google.')));
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content:
                                                      Text('Link failed: $e')));
                                        } finally {
                                          if (mounted) {
                                            setState(() => _linking = false);
                                          }
                                        }
                                      },
                                icon: _linking
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.link),
                                label: const Text('Link Google (web)'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const SignInPage()));
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in / Manage Account'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _SingleBoardStats(boardRef: boardRef),

              const SizedBox(height: 16),

              // Friends Section
              const FriendsSection(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createDefaultProfile(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final user = FirebaseAuth.instance.currentUser!;
    final uname = _genUsername();

    // Private profile
    await ref.set({
      'displayName': uname,
      'username': uname,
      'photoURL': null,
      'createdAt': FieldValue.serverTimestamp(),
      'anon': user.isAnonymous,
      'friendUids': [],
      'prefs': {},
    }, SetOptions(merge: true));

    // Public mini profile
    await FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(user.uid)
        .set({
      'displayName': uname,
      'username': uname,
      'photoURL': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await user.updateDisplayName(uname);
    await user.reload();
  }

  String _genUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'user-${chars[now % chars.length]}'
        '${chars[(now >> 5) % chars.length]}'
        '${chars[(now >> 10) % chars.length]}'
        '${chars[(now >> 15) % chars.length]}';
  }
}

/* ----------------- Single-board stats (fits your current schema) ----------------- */

class _SingleBoardStats extends StatelessWidget {
  const _SingleBoardStats({required this.boardRef});
  final DocumentReference<Map<String, dynamic>> boardRef;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: boardRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Card(
            child: SizedBox(
              height: 56,
              child: Center(child: Text('No recent boards yet.')),
            ),
          );
        }
        final data = snap.data!.data()!;
        final cells = List.from(data['cells'] ?? []);
        final done = (data['completedCount'] as int?) ??
            cells.where((t) => t is Map && t['status'] == 'done').length;
        final rate = (done / 9.0).clamp(0, 1);
        final updated = (data['lastUpdated'] as Timestamp?)?.toDate();

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              children: [
                _StatChip(title: 'This board', value: '$done/9'),
                const SizedBox(width: 10),
                _StatChip(
                  title: 'Completion',
                  value: '${(rate * 100).toStringAsFixed(0)}%',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  title: 'Updated',
                  value: updated == null ? '—' : _relTime(updated),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _relTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

/* ------------------------------- Friends Section ------------------------------- */

class FriendsSection extends StatefulWidget {
  const FriendsSection({super.key});

  @override
  State<FriendsSection> createState() => _FriendsSectionState();
}

class _FriendsSectionState extends State<FriendsSection> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      FirebaseFirestore.instance.collection('user_profiles');

  CollectionReference<Map<String, dynamic>> get _friendships =>
      FirebaseFirestore.instance.collection('friendships');

  DocumentReference<Map<String, dynamic>> get _meRef =>
      _profiles.doc(_uid);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('Friends'),
              subtitle: Text('Your code: ${_uid.substring(0, 6)}'),
              trailing: IconButton(
                tooltip: 'Add friend by code',
                icon: const Icon(Icons.person_add_alt_1),
                onPressed: () => _showAddFriendSheet(context),
              ),
            ),
            const Divider(height: 1),

            // PENDING REQUESTS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Pending requests',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _meRef
                  .collection('friendRequests')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('No requests right now.'),
                  );
                }
                return Column(
                  children: docs.map((d) {
                    final fromUid = d.data()['fromUid'] as String? ?? '';
                    return _FriendRequestTile(
                      requestId: d.id,
                      fromUid: fromUid,
                      onAccept: () => _acceptRequest(d.id, fromUid),
                      onReject: () => _updateRequestStatus(d.id, 'rejected'),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // FRIEND LIST
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Your friends',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _friendships
                  .where('members', arrayContains: _uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No friends yet. Share your code or add a friend.',
                    ),
                  );
                }
                return Column(
                  children: docs.map((d) {
                    final members =
                        List<String>.from(d.data()['members'] as List);
                    final otherUid =
                        members.firstWhere((m) => m != _uid, orElse: () => '');
                    return _FriendTile(
                      friendUid: otherUid,
                      onRemove: () async {
                        try {
                          await _friendships.doc(d.id).delete();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Friend removed.')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /* ----------------------------- Requests Actions ----------------------------- */

  Future<void> _sendFriendRequestByCode(String code) async {
    final targetUid = await _resolveUidFromCode(code);
    if (targetUid == null) {
      throw Exception('No user found for that code.');
    }
    if (targetUid == _uid) {
      throw Exception('You cannot add yourself.');
    }
    final inbox =
        _profiles.doc(targetUid).collection('friendRequests').doc();
    await inbox.set({
      'fromUid': _uid,
      'toUid': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _acceptRequest(String requestId, String fromUid) async {
    await _meRef
        .collection('friendRequests')
        .doc(requestId)
        .update({'status': 'accepted'});

    final pairId = _pairId(_uid, fromUid);
    await _friendships.doc(pairId).set({
      'members': [_uid, fromUid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted.')),
      );
    }
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    await _meRef
        .collection('friendRequests')
        .doc(requestId)
        .update({'status': status});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $status.')),
      );
    }
  }

  /* --------------------------------- Helpers --------------------------------- */

  // Accept full UID; short prefix also supported by scanning (demo).
  Future<String?> _resolveUidFromCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length >= 20) return trimmed; // full UID

    final q = await _profiles.limit(100).get();
    for (final d in q.docs) {
      if (d.id.startsWith(trimmed)) return d.id;
    }
    return null;
  }

  String _pairId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  void _showAddFriendSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _AddFriendSheet(onSubmit: (code) async {
        try {
          await _sendFriendRequestByCode(code);
          if (mounted) {
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Request sent.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      }),
    );
  }
}

class _FriendRequestTile extends StatelessWidget {
  const _FriendRequestTile({
    required this.requestId,
    required this.fromUid,
    required this.onAccept,
    required this.onReject,
  });

  final String requestId;
  final String fromUid;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(fromUid);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: ref.get(),
      builder: (context, snap) {
        final m = snap.data?.data() ?? {};
        final displayName = (m['displayName'] ?? '').toString();
        final username = (m['username'] ?? '').toString();
        final title = displayName.isNotEmpty
            ? displayName
            : (username.isNotEmpty ? username : fromUid);

        return ListTile(
          leading: const Icon(Icons.mail_outline),
          title: Text(title),
          subtitle: const Text('wants to be friends'),
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(
                tooltip: 'Reject',
                icon: const Icon(Icons.close),
                onPressed: onReject,
              ),
              IconButton(
                tooltip: 'Accept',
                icon: const Icon(Icons.check_circle),
                onPressed: onAccept,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friendUid,
    required this.onRemove,
  });

  final String friendUid;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(friendUid);

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: ref.get(),
      builder: (context, snap) {
        final m = snap.data?.data() ?? {};
        final displayName = (m['displayName'] ?? '').toString();
        final username = (m['username'] ?? '').toString();
        final photo = (m['photoURL'] ?? '').toString();

        final title = displayName.isNotEmpty
            ? displayName
            : (username.isNotEmpty ? username : friendUid);

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child:
                photo.isEmpty ? Text(title.isNotEmpty ? title[0] : '?') : null,
          ),
          title: Text(title),
          subtitle: username.isEmpty ? null : Text('@$username'),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        );
      },
    );
  }
}

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet({required this.onSubmit});
  final Future<void> Function(String) onSubmit;

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Send friend request',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Friend code',
              hintText: 'Paste full UID or short prefix',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a friend code.')),
      );
      return;
    }
    setState(() => _busy = true);
    await widget.onSubmit(code);
    if (mounted) setState(() => _busy = false);
  }
}
