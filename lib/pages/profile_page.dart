// lib/pages/profile_page.dart
import 'dart:ui' as ui; // for ImageFilter.blur

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/widgets/task_dialog.dart';
import '/widgets/stat_dialog.dart';
import '/widgets/stat_card.dart';

import 'sign_in_page.dart';
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
    final pubRef = FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(user.uid);
    final exists = (await pubRef.get()).exists;
    if (exists) return;

    final privSnap = await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .get();
    final m = privSnap.data() ?? {};
    final displayName = (m['displayName'] ?? user.displayName ?? '').toString();
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
      // If no user, show a simple message instead of redirecting
      // The main app's auth state will handle showing the sign-in page
      return const Scaffold(
        body: Center(
          child: Text(
            'Please sign in to access profile',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    // Kick off one-time backfill without blocking build
    if (!_ensuredPublic) {
      _ensuredPublic = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensurePublicProfile(),
      );
    }

    final profRef = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(uid);
    final boardRef = FirebaseFirestore.instance.collection('boards').doc(uid);

    return Scaffold(
      // appBar: AppBar(),
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

          if (_nameCtrl.text != displayName) {
            _nameCtrl.text = displayName;
            _nameCtrl.selection = TextSelection.collapsed(
              offset: _nameCtrl.text.length,
            );
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header card + name editor
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF8F9FA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF667EEA,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.transparent,
                                child: Text(
                                  (displayName.isEmpty ? '?' : displayName[0])
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName.isEmpty
                                        ? '(no name)'
                                        : displayName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF667EEA,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '@$username',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF667EEA),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                uidShort,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A5568),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: anon
                                    ? const Color(0xFFFED7D7).withOpacity(0.3)
                                    : const Color(0xFFC6F6D5).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                anon
                                    ? Icons.person_outline
                                    : Icons.verified_user,
                                size: 18,
                                color: anon
                                    ? const Color(0xFFE53E3E)
                                    : const Color(0xFF38A169),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              anon ? 'Anonymous account' : 'Linked account',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: anon
                                    ? const Color(0xFFE53E3E)
                                    : const Color(0xFF38A169),
                              ),
                            ),
                          ],
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Color(0xFF718096),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Created: ${createdAt.toLocal()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _nameCtrl,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Display name',
                              labelStyle: const TextStyle(
                                color: Color(0xFF718096),
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                              prefixIcon: const Icon(
                                Icons.edit,
                                color: Color(0xFF667EEA),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667EEA),
                                      Color(0xFF764BA2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF667EEA,
                                      ).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () async {
                                          final name = _nameCtrl.text.trim();
                                          if (name.isEmpty) return;
                                          setState(() => _saving = true);

                                          // Private profile
                                          await profRef.set({
                                            'displayName': name,
                                          }, SetOptions(merge: true));

                                          // Auth displayName
                                          final user = FirebaseAuth
                                              .instance
                                              .currentUser!;
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Saved.'),
                                            ),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: _saving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.save,
                                          color: Colors.white,
                                        ),
                                  label: Text(
                                    'Save',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: uid),
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Friend code copied: $uidShort',
                                        ),
                                        backgroundColor: const Color(
                                          0xFF667EEA,
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide.none,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.copy,
                                    color: Color(0xFF667EEA),
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Copy friend code',
                                    style: TextStyle(
                                      color: Color(0xFF667EEA),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (anon && kIsWeb)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: _linking
                                        ? null
                                        : () async {
                                            setState(() => _linking = true);
                                            try {
                                              final provider =
                                                  GoogleAuthProvider();
                                              // Force account chooser on web
                                              provider.setCustomParameters({
                                                'prompt': 'select_account',
                                              });

                                              await FirebaseAuth
                                                  .instance
                                                  .currentUser!
                                                  .linkWithPopup(provider);

                                              await profRef.set({
                                                'anon': false,
                                              }, SetOptions(merge: true));

                                              final name = (await profRef.get())
                                                  .data()?['displayName'];
                                              if (name is String &&
                                                  name.isNotEmpty) {
                                                await FirebaseAuth
                                                    .instance
                                                    .currentUser!
                                                    .updateDisplayName(name);
                                              }

                                              // Public mirror (also photo)
                                              final me = FirebaseAuth
                                                  .instance
                                                  .currentUser!;
                                              await FirebaseFirestore.instance
                                                  .collection('public_profiles')
                                                  .doc(me.uid)
                                                  .set({
                                                    'displayName':
                                                        me.displayName ??
                                                        (name is String
                                                            ? name
                                                            : ''),
                                                    'photoURL': me.photoURL,
                                                    'updatedAt':
                                                        FieldValue.serverTimestamp(),
                                                  }, SetOptions(merge: true));

                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Linked to Google.',
                                                  ),
                                                ),
                                              );
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Link failed: $e',
                                                  ),
                                                ),
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                  () => _linking = false,
                                                );
                                              }
                                            }
                                          },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide.none,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: _linking
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.link,
                                            color: Color(0xFF667EEA),
                                            size: 20,
                                          ),
                                    label: const Text(
                                      'Link Google (web)',
                                      style: TextStyle(
                                        color: Color(0xFF667EEA),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignInPage(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.login,
                              color: Color(0xFF667EEA),
                              size: 20,
                            ),
                            label: const Text(
                              'Sign in / Manage Account',
                              style: TextStyle(
                                color: Color(0xFF667EEA),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                _SingleBoardStats(boardRef: boardRef),

                const SizedBox(height: 24),

                // Friends Section
                const FriendsSection(),
              ],
            ),
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
        final done =
            (data['completedCount'] as int?) ??
            cells.where((t) => t is Map && t['status'] == 'done').length;
        final rate = (done / 9.0).clamp(0, 1);
        final updated = (data['lastUpdated'] as Timestamp?)?.toDate();

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8F9FA)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.dashboard,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Board Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        title: 'This board',
                        value: '$done/9',
                        icon: Icons.grid_view,
                        color: const Color(0xFF667EEA),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatChip(
                        title: 'Completion',
                        value: '${(rate * 100).toStringAsFixed(0)}%',
                        icon: Icons.check_circle,
                        color: const Color(0xFF38A169),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatChip(
                        title: 'Updated',
                        value: updated == null ? '—' : _relTime(updated),
                        icon: Icons.schedule,
                        color: const Color(0xFFED8936),
                      ),
                    ),
                  ],
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
  const _StatChip({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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

  DocumentReference<Map<String, dynamic>> get _meRef => _profiles.doc(_uid);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8F9FA)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Friends',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Code: ${_uid.substring(0, 6)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667EEA),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    tooltip: 'Add friend by code',
                    icon: const Icon(
                      Icons.person_add_alt_1,
                      color: Colors.white,
                    ),
                    onPressed: () => _showAddFriendSheet(context),
                  ),
                ),
              ],
            ),
          ),

          // PENDING REQUESTS
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFED7D7).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7D7), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mail_outline,
                      color: Color(0xFFE53E3E),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pending requests',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFE53E3E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                        child: Text(
                          'No requests right now.',
                          style: TextStyle(color: Color(0xFF718096)),
                        ),
                      );
                    }
                    return Column(
                      children: docs.map((d) {
                        final fromUid = d.data()['fromUid'] as String? ?? '';
                        return _FriendRequestTile(
                          requestId: d.id,
                          fromUid: fromUid,
                          onAccept: () => _acceptRequest(d.id, fromUid),
                          onReject: () =>
                              _updateRequestStatus(d.id, 'rejected'),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // FRIEND LIST
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFC6F6D5).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC6F6D5), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      color: Color(0xFF38A169),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your friends',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF38A169),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                          style: TextStyle(color: Color(0xFF718096)),
                        ),
                      );
                    }
                    return Column(
                      children: docs.map((d) {
                        final members = List<String>.from(
                          d.data()['members'] as List,
                        );
                        final otherUid = members.firstWhere(
                          (m) => m != _uid,
                          orElse: () => '',
                        );
                        return _FriendTile(
                          friendUid: otherUid,
                          onRemove: () async {
                            try {
                              await _friendships.doc(d.id).delete();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Friend removed.'),
                                  ),
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

          const SizedBox(height: 24),
        ],
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
    final inbox = _profiles.doc(targetUid).collection('friendRequests').doc();
    await inbox.set({
      'fromUid': _uid,
      'toUid': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _acceptRequest(String requestId, String fromUid) async {
    await _meRef.collection('friendRequests').doc(requestId).update({
      'status': 'accepted',
    });

    final pairId = _pairId(_uid, fromUid);
    await _friendships.doc(pairId).set({
      'members': [_uid, fromUid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request accepted.')));
    }
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    await _meRef.collection('friendRequests').doc(requestId).update({
      'status': status,
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request $status.')));
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
      builder: (ctx) => _AddFriendSheet(
        onSubmit: (code) async {
          try {
            await _sendFriendRequestByCode(code);
            if (mounted) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Request sent.')));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
      ),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.mail_outline,
                color: Color(0xFFE53E3E),
                size: 20,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            subtitle: const Text(
              'wants to be friends',
              style: TextStyle(color: Color(0xFF718096), fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53E3E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    tooltip: 'Reject',
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFFE53E3E),
                      size: 18,
                    ),
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38A169), Color(0xFF2F855A)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    tooltip: 'Accept',
                    icon: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: onAccept,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friendUid, required this.onRemove});

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

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.transparent,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(
                        title.isNotEmpty ? title[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
            subtitle: username.isEmpty
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667EEA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '@$username',
                      style: const TextStyle(
                        color: Color(0xFF667EEA),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
            trailing: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Color(0xFFE53E3E),
                  size: 20,
                ),
                tooltip: 'Remove',
                onPressed: onRemove,
              ),
            ),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF8F9FA)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Send friend request',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _code,
                textInputAction: TextInputAction.done,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  labelText: 'Friend code',
                  hintText: 'Paste full UID or short prefix',
                  labelStyle: TextStyle(
                    color: Color(0xFF718096),
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  prefixIcon: Icon(
                    Icons.tag,
                    color: Color(0xFF667EEA),
                    size: 20,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Send Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
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

/* ----------------- Profile header ----------------- */

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.handle, // pass without '@'
    this.photoUrl,
    this.avatarRadius = 24,
  });

  final String displayName;
  final String handle;
  final String? photoUrl;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final handleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.grey[600],
    );

    String _initials(String name) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) return '?';
      final f = parts.first.characters.first.toUpperCase();
      final l = parts.length > 1
          ? parts.last.characters.first.toUpperCase()
          : '';
      return (f + l).trim();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isEmpty ? '(no name)' : displayName,
                  style: nameStyle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('@$handle', style: handleStyle),
              ],
            ),
          ),
          CircleAvatar(
            radius: avatarRadius,
            backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Text(_initials(displayName))
                : null,
          ),
        ],
      ),
    );
  }
}

/* ----------------- Profile Feed (cards + popups) ----------------- */

class ProfileFeed extends StatelessWidget {
  const ProfileFeed({
    super.key,
    this.tasks,
    this.streakWeeks = 3,
    this.horizontalGap = 12,
    this.verticalGap = 12,
  });

  final List<TaskItem>? tasks;
  final int streakWeeks;
  final double horizontalGap;
  final double verticalGap;

  @override
  Widget build(BuildContext context) {
    final data = tasks ?? _demoTasks();

    // Split into two columns (simple alternating layout)
    final left = <Widget>[];
    final right = <Widget>[];

    // Streak card at the top-left
    left.add(
      StatCard(
        title: 'Week',
        value: '$streakWeeks',
        subtitle: 'Streak',
        backgroundColor: const Color(0xFFF7E39E), // same yellow
        onTap: () => _showStreakPopup(context),
      ),
    );

    left.add(SizedBox(height: verticalGap));

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final card = TaskCard(
        task: item,
        onTap: () => _showTaskPopup(context, item),
      );
      if (i.isEven) {
        left.add(card);
        left.add(SizedBox(height: verticalGap));
      } else {
        right.add(card);
        right.add(SizedBox(height: verticalGap));
      }
    }
    const int totalCompletedTasks = 27;
    final completedCard = StatCard(
      title: 'Completed',
      value: '$totalCompletedTasks',
      subtitle: 'tasks',
      height: 140, // shorter tile looks nice under a task
      backgroundColor: const Color(0xFFF7E39E),
      onTap: () => _showTotalCompletedPopup(context, totalCompletedTasks),
    );

    // Place it right below the first right-column item (or at top if column empty)
    if (right.isNotEmpty) {
      right.insertAll(1, [
        SizedBox(height: verticalGap),
        completedCard,
        SizedBox(height: verticalGap),
      ]);
    } else {
      right.addAll([
        SizedBox(height: verticalGap),
        completedCard,
        SizedBox(height: verticalGap),
      ]);
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: left)),
            SizedBox(width: horizontalGap),
            Expanded(child: Column(children: right)),
          ],
        ),
      ),
    );
  }

  /* ---------- POPUPS WITH BACKGROUND BLUR ---------- */

  Future<void> _showTotalCompletedPopup(BuildContext outerContext, int total) {
    return showGeneralDialog(
      context: outerContext,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) {
        return Builder(
          builder: (ctx) {
            return AnimatedBuilder(
              animation: ModalRoute.of(ctx)!.animation!,
              builder: (ctx, child) {
                final curved = CurvedAnimation(
                  parent: ModalRoute.of(ctx)!.animation!,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return Stack(
                  children: [
                    // Tappable blurred backdrop
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(ctx).pop(),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                    // Slide-up StatDialog
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(curved),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: StatDialog(
                              title: 'Completed',
                              value: '$total',
                              caption: 'tasks',
                              description: '', // add copy later if you want
                              onClose: () => Navigator.of(ctx).pop(),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuad,
          ),
          child: child,
        );
      },
    );
  }

  Future<void> _showStreakPopup(BuildContext outerContext) {
    return showGeneralDialog(
      context: outerContext,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) {
        // Fresh context to avoid deactivated-ancestor issues
        return Builder(
          builder: (ctx) {
            return AnimatedBuilder(
              animation: ModalRoute.of(ctx)!.animation!,
              builder: (ctx, child) {
                final curved = CurvedAnimation(
                  parent: ModalRoute.of(ctx)!.animation!,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return Stack(
                  children: [
                    // Tappable blurred backdrop — tap outside to dismiss
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(ctx).pop(),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),

                    // Slide-up StatDialog
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(curved),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: StatDialog(
                              title: 'Streak',
                              value:
                                  '$streakWeeks', // you can pass any number/string
                              caption: 'weeks',
                              description:
                                  '', // keep empty for now; fill later if needed
                              onClose: () => Navigator.of(ctx).pop(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        // Soft fade for the scene while the sheet slides up
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuad,
          ),
          child: child,
        );
      },
    );
  }

  Future<void> _showTaskPopup(BuildContext outerContext, TaskItem task) {
    return showGeneralDialog(
      context: outerContext,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) {
        return Builder(
          builder: (ctx) {
            final dateLine =
                '${_monthDayTime(task.timestamp)}${task.location != null ? '\n${task.location}' : ''}';

            return AnimatedBuilder(
              animation: ModalRoute.of(ctx)!.animation!,
              builder: (ctx, child) {
                final curved = CurvedAnimation(
                  parent: ModalRoute.of(ctx)!.animation!,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return Stack(
                  children: [
                    // Tappable blurred backdrop — tap outside to dismiss
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(ctx).pop(),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),

                    // Slide-up bottom sheet using your TaskDialog
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(curved),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: TaskDialog(
                              title: task.title,
                              completed:
                                  true, // your profile tasks are completed
                              onToggle: () async {
                                // optional: toggle back in Firestore if you support it later
                              },
                              onCancel: () => Navigator.of(ctx).pop(),
                              // If you added these optional params to TaskDialog:
                              dateString: _monthDayTime(task.timestamp),
                              locationString: task.location,
                              backgroundImage:
                                  (task.imageUrl != null &&
                                      task.imageUrl!.isNotEmpty)
                                  ? NetworkImage(task.imageUrl!)
                                  : const AssetImage(
                                      'assets/images/task_complete_bg.png',
                                    ),
                              details: task.details,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuad,
          ),
          child: child,
        );
      },
    );
  }

  String _monthDayTime(DateTime? t) {
    if (t == null) return '';
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '${months[t.month - 1]} ${t.day}, $h:$m $ampm';
  }

  // Demo content so it renders immediately
  List<TaskItem> _demoTasks() => [
    TaskItem(
      title: 'See a tourist attraction',
      timestamp: DateTime(2025, 10, 12, 12, 28),
      location: 'Kyoto, Japan',
      imageUrl:
          'https://images.unsplash.com/photo-1549692520-acc6669e2f0c?w=1200',
      participantAvatars: [
        'https://i.pravatar.cc/100?img=1',
        'https://i.pravatar.cc/100?img=2',
      ],
      completed: true,
      details: 'A perfect afternoon under the cherry blossoms.',
    ),
    TaskItem(
      title: 'New workout',
      timestamp: DateTime(2025, 10, 12, 12, 28),
      location: 'Kyoto, Japan',
      imageUrl:
          'https://images.unsplash.com/photo-1517365830460-955ce3ccd263?w=1200',
      completed: true,
      details: '45-minute HIIT with core focus.',
    ),
    TaskItem(
      title: 'Take a walk in a park',
      timestamp: DateTime(2025, 10, 12, 12, 28),
      location: 'Kyoto, Japan',
      imageUrl:
          'https://images.unsplash.com/photo-1506089676908-3592f7389d4d?w=1200',
      completed: true,
    ),
    TaskItem(
      title: 'Cherry blossoms',
      timestamp: DateTime(2025, 10, 12, 12, 28),
      location: 'Kyoto, Japan',
      imageUrl:
          'https://images.unsplash.com/photo-1524499982521-1ffd58dd89ea?w=1200',
      completed: true,
    ),
  ];
}

/* ----------------- TaskCard ----------------- */

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, this.onTap});

  final TaskItem task;
  final VoidCallback? onTap;

  static const _shadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 6)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLine = '${_monthDayTime(task.timestamp)}\n${task.location ?? ''}'
        .trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: _shadow, // the little shadow below
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Background image
                AspectRatio(
                  aspectRatio: 3 / 8,
                  child: task.imageUrl != null && task.imageUrl!.isNotEmpty
                      ? Image.network(task.imageUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade300),
                ),

                // Bottom blur (like the dialog)
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.fromRGBO(0, 0, 0, 0.00),
                          Color.fromRGBO(0, 0, 0, 0.35),
                          Color.fromRGBO(0, 0, 0, 0.75),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child:
                            task.imageUrl != null && task.imageUrl!.isNotEmpty
                            ? Image.network(task.imageUrl!, fit: BoxFit.cover)
                            : Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                ),

                // A light extra gradient on the very bottom for contrast
                Positioned.fill(
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),

                // Foreground content
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.participantAvatars.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AvatarStack(urls: task.participantAvatars),
                        ),
                      Text(
                        task.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthDayTime(DateTime? t) {
    if (t == null) return '';
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '${months[t.month - 1]} ${t.day}, $h:$m $ampm';
  }
}

/* ----------------- Avatar Stack ----------------- */

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    const overlap = 12.0;

    return SizedBox(
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < urls.length && i < 4; i++)
            Positioned(
              left: i * overlap,
              child: CircleAvatar(
                radius: size / 2,
                backgroundImage: NetworkImage(urls[i]),
              ),
            ),
        ],
      ),
    );
  }
}

/* ----------------- Model ----------------- */

class TaskItem {
  TaskItem({
    required this.title,
    this.timestamp,
    this.location,
    this.imageUrl,
    this.participantAvatars = const [],
    this.completed = true, // all tasks shown are completed
    this.details,
  });

  final String title;
  final DateTime? timestamp;
  final String? location;
  final String? imageUrl;
  final List<String> participantAvatars;
  final bool completed;
  final String? details;
}

/* ----------------- Shared bottom sheet surface ----------------- */

class _BottomSheetSurface extends StatelessWidget {
  const _BottomSheetSurface({required this.child, this.clip = false});

  final Widget child;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(28);
    final content = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: border,
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
    if (clip) {
      return ClipRRect(borderRadius: border, child: content);
    }
    return content;
  }
}
