// lib/settings_page.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/auth_service.dart';
import 'pages/sign_in_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  // For the pre-header editor
  final TextEditingController _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _linking = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final providers =
        user?.providerData.map((p) => p.providerId).toList() ?? [];
    final isAnon = (user?.isAnonymous ?? true);

    final profRef = uid == null
        ? null
        : FirebaseFirestore.instance.collection('user_profiles').doc(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --------- Pre-header (moved from ProfilePage) ----------
          if (uid != null && profRef != null) _buildPreHeader(profRef, uid),
          if (uid != null) const SizedBox(height: 12),

          // --------- Existing settings UI (unchanged) -------------
          Card(
            child: ListTile(
              title: const Text('Account'),
              subtitle: Text(
                'UID: ${_short(uid ?? "(none)")} • '
                '${isAnon ? "Anonymous" : "Linked"} • '
                'Providers: ${providers.isEmpty ? "-" : providers.join(", ")}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: uid ?? '(none)'));
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('UID copied')));
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            icon: const Icon(Icons.manage_accounts),
            label: const Text('Sign in / Manage account'),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SignInPage()));
            },
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await AuthService.instance.signOut();
                    // Immediately create a new anonymous session so the app keeps working
                    final guest = await AuthService.instance.ensureAnon();

                    // create a basic profile doc if missing
                    final pref = FirebaseFirestore.instance
                        .collection('user_profiles')
                        .doc(guest.uid);
                    final snap = await pref.get();
                    if (!snap.exists) {
                      await pref.set({
                        'displayName': 'user-${guest.uid.substring(0, 4)}',
                        'username': 'user-${guest.uid.substring(0, 4)}',
                        'anon': true,
                        'createdAt': FieldValue.serverTimestamp(),
                        'friendUids': [],
                        'prefs': {},
                      });
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Signed out. New anonymous session started.',
                        ),
                      ),
                    );
                    setState(() => _busy = false);
                  },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),

          const SizedBox(height: 8),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _busy
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete account?'),
                        content: const Text(
                          'This removes your authentication record.\n'
                          'Your Firestore docs may remain unless you add server-side cleanup.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    setState(() => _busy = true);
                    try {
                      await AuthService.instance.deleteAccount();
                      final guest = await AuthService.instance.ensureAnon();
                      final pref = FirebaseFirestore.instance
                          .collection('user_profiles')
                          .doc(guest.uid);
                      final snap = await pref.get();
                      if (!snap.exists) {
                        await pref.set({
                          'displayName': 'user-${guest.uid.substring(0, 4)}',
                          'username': 'user-${guest.uid.substring(0, 4)}',
                          'anon': true,
                          'createdAt': FieldValue.serverTimestamp(),
                          'friendUids': [],
                          'prefs': {},
                        });
                      }
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Account deleted. New anonymous session started.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Delete failed: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete account'),
          ),
        ],
      ),
    );
  }

  // ---------- Pre-header block (moved from ProfilePage) ----------
  Widget _buildPreHeader(
    DocumentReference<Map<String, dynamic>> profRef,
    String uid,
  ) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
        final uidShort = uid.substring(0, uid.length >= 6 ? 6 : uid.length);

        if (_nameCtrl.text != displayName) {
          _nameCtrl.text = displayName;
          _nameCtrl.selection = TextSelection.collapsed(
            offset: _nameCtrl.text.length,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          fontSize: 12,
                          color: Colors.grey,
                        ),
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

                                    await profRef.set({
                                      'displayName': name,
                                    }, SetOptions(merge: true));

                                    final user =
                                        FirebaseAuth.instance.currentUser!;
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
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
                                SnackBar(
                                  content: Text(
                                    'Friend code copied: $uidShort',
                                  ),
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
                                        final provider = GoogleAuthProvider();
                                        await FirebaseAuth.instance.currentUser!
                                            .linkWithPopup(provider);
                                        await profRef.set({
                                          'anon': false,
                                        }, SetOptions(merge: true));

                                        final name = (await profRef.get())
                                            .data()?['displayName'];
                                        if (name is String && name.isNotEmpty) {
                                          await FirebaseAuth
                                              .instance
                                              .currentUser!
                                              .updateDisplayName(name);
                                        }

                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Linked to Google.'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Link failed: $e'),
                                          ),
                                        );
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
                                        strokeWidth: 2,
                                      ),
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
          ],
        );
      },
    );
  }

  Future<void> _createDefaultProfile(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final user = FirebaseAuth.instance.currentUser!;
    final uname = _genUsername();

    await ref.set({
      'displayName': uname,
      'username': uname,
      'photoURL': null,
      'createdAt': FieldValue.serverTimestamp(),
      'anon': user.isAnonymous,
      'friendUids': [],
      'prefs': {},
    }, SetOptions(merge: true));

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

  String _short(String s) => s.length > 8 ? s.substring(0, 8) : s;
}
