import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    final ref = FirebaseFirestore.instance.collection('user_profiles').doc(uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: FilledButton(
                onPressed: () async {
                  await _createDefaultProfile(ref);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile created.')),
                  );
                },
                child: const Text('Create profile now'),
              ),
            );
          }

          final data = snapshot.data!.data()!;
          final displayName = (data['displayName'] ?? '').toString();
          final username = (data['username'] ?? '').toString();
          final anon = data['anon'] == true;
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

          if (_nameCtrl.text != displayName) {
            _nameCtrl.text = displayName;
            _nameCtrl.selection =
                TextSelection.collapsed(offset: _nameCtrl.text.length);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(displayName.isEmpty ? '(no name)' : displayName),
                  subtitle: Text('Username: $username'),
                  trailing: Text(uid.substring(0, 6)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.verified_user, size: 18),
                  const SizedBox(width: 6),
                  Text(anon ? 'Anonymous account' : 'Linked account'),
                ],
              ),
              if (createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Created: ${createdAt.toLocal()}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'Enter a name shown to friends',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        await ref.set(
                          {'displayName': _nameCtrl.text.trim()},
                          SetOptions(merge: true),
                        );
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save'),
              ),
              const SizedBox(height: 12),

              // Web-only Google link (no google_sign_in package needed)
              if (anon && kIsWeb)
                OutlinedButton.icon(
                  onPressed: _linking
                      ? null
                      : () async {
                          setState(() => _linking = true);
                          try {
                            final provider = GoogleAuthProvider();
                            await FirebaseAuth.instance.currentUser!
                                .linkWithPopup(provider);
                            await ref.set({'anon': false},
                                SetOptions(merge: true));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Linked to Google.'),
                              ),
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
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: const Text('Link Google (web)'),
                ),

              const SizedBox(height: 24),
              const Text('Raw Firestore data (debug):'),
              const SizedBox(height: 6),
              SelectableText(
                _prettyMap(data),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
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
    await ref.set({
      'displayName': uname,
      'username': uname,
      'photoURL': null,
      'createdAt': FieldValue.serverTimestamp(),
      'anon': user.isAnonymous,
      'friendUids': [],
      'prefs': {},
    }, SetOptions(merge: true));
  }

  String _genUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'user-${chars[now % chars.length]}'
        '${chars[(now >> 5) % chars.length]}'
        '${chars[(now >> 10) % chars.length]}'
        '${chars[(now >> 15) % chars.length]}';
  }

  String _prettyMap(Map<String, dynamic> m) {
    const indent = '  ';
    final b = StringBuffer('{\n');
    for (final e in m.entries) {
      b.write('$indent${e.key}: ${e.value}\n');
    }
    b.write('}');
    return b.toString();
  }
}
