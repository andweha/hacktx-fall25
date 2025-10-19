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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '(none)';
    final providers = user?.providerData.map((p) => p.providerId).toList() ?? [];
    final isAnon = (user?.isAnonymous ?? true);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Account'),
              subtitle: Text(
                'UID: ${uid.substring(0, uid.length > 8 ? 8 : uid.length)} • '
                '${isAnon ? "Anonymous" : "Linked"} • Providers: ${providers.isEmpty ? "-" : providers.join(", ")}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: uid));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('UID copied')),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            icon: const Icon(Icons.manage_accounts),
            label: const Text('Sign in / Manage account'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignInPage()),
              );
            },
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: _busy ? null : () async {
              setState(() => _busy = true);
              await AuthService.instance.signOut();
              // Immediately create a new anonymous session so the app keeps working
              final guest = await AuthService.instance.ensureAnon();

              // create a basic profile doc if missing
              final profRef =
                  FirebaseFirestore.instance.collection('user_profiles').doc(guest.uid);
              final snap = await profRef.get();
              if (!snap.exists) {
                await profRef.set({
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
                const SnackBar(content: Text('Signed out. New anonymous session started.')),
              );
              setState(() => _busy = false);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),

          const SizedBox(height: 8),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _busy ? null : () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete account?'),
                  content: const Text(
                      'This removes your authentication record.\n'
                      'Your Firestore docs may remain unless you add server-side cleanup.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
                final profRef =
                    FirebaseFirestore.instance.collection('user_profiles').doc(guest.uid);
                final snap = await profRef.get();
                if (!snap.exists) {
                  await profRef.set({
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
                  const SnackBar(content: Text('Account deleted. New anonymous session started.')),
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
}
