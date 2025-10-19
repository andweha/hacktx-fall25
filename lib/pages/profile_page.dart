// lib/pages/profile_page.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hacktx_fall25/services/friend_service.dart';

import 'sign_in_page.dart'; // <-- NEW: navigate to the sign-in/upgrade screen

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _linking = false;

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
    final profRef = FirebaseFirestore.instance.collection('user_profiles').doc(uid);
    final boardRef = FirebaseFirestore.instance.collection('boards').doc(uid);

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
            _nameCtrl.selection = TextSelection.collapsed(offset: _nameCtrl.text.length);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header card + name editor
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            (displayName.isEmpty ? '?' : displayName[0]).toUpperCase(),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(displayName.isEmpty ? '(no name)' : displayName),
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
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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

                                      // 1) Save to Firestore
                                      await profRef.set(
                                        {'displayName': name},
                                        SetOptions(merge: true),
                                      );

                                      // 2) Also update Auth user displayName
                                      final user = FirebaseAuth.instance.currentUser!;
                                      await user.updateDisplayName(name);
                                      await user.reload();

                                      setState(() => _saving = false);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Saved.')),
                                      );
                                    },
                              icon: _saving
                                  ? const SizedBox(
                                      height: 18, width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
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
                                await Clipboard.setData(ClipboardData(text: uid));
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Friend code copied: $uidShort')),
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
                                          final provider = GoogleAuthProvider();
                                          await FirebaseAuth.instance.currentUser!.linkWithPopup(provider);
                                          await profRef.set({'anon': false}, SetOptions(merge: true));

                                          // Keep Firestore name as Auth name after linking (optional)
                                          final name = (await profRef.get()).data()?['displayName'];
                                          if (name is String && name.isNotEmpty) {
                                            await FirebaseAuth.instance.currentUser!.updateDisplayName(name);
                                          }

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Linked to Google.')),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Link failed: $e')),
                                          );
                                        } finally {
                                          if (mounted) setState(() => _linking = false);
                                        }
                                      },
                                icon: _linking
                                    ? const SizedBox(
                                        height: 18, width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.link),
                                label: const Text('Link Google (web)'),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // NEW: Navigate to the dedicated sign-in/upgrade screen
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignInPage()),
                          );
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in / Manage Account'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Simple stats from your single-board schema
              _SingleBoardStats(boardRef: boardRef),
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

    // Create Firestore profile
    await ref.set({
      'displayName': uname,
      'username': uname,
      'photoURL': null,
      'createdAt': FieldValue.serverTimestamp(),
      'anon': user.isAnonymous,
      'friendUids': [],
      'prefs': {},
    }, SetOptions(merge: true));

    // Also set the Auth displayName so it appears in Auth → Users (details pane)
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              children: [
                _StatChip(title: 'This board', value: '$done/9'),
                const SizedBox(width: 10),
                _StatChip(title: 'Completion', value: '${(rate * 100).toStringAsFixed(0)}%'),
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
