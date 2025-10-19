// lib/pages/sign_in_page.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _signinEmailCtrl = TextEditingController();
  final _signinPassCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _signinEmailCtrl.dispose();
    _signinPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _mirrorPublicProfile(User u, {String? preferredName}) async {
    final displayName =
        (preferredName?.trim().isNotEmpty == true ? preferredName!.trim() : (u.displayName ?? '')) ;
    await FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(u.uid)
        .set({
      'displayName': displayName,
      'username': displayName.isNotEmpty ? displayName : 'user-${u.uid.substring(0,4)}',
      'photoURL': u.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureProfile(User u, {String? preferredName}) async {
    final ref =
        FirebaseFirestore.instance.collection('user_profiles').doc(u.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      final fallback =
          preferredName ?? u.displayName ?? 'user-${u.uid.substring(0, 4)}';
      await ref.set({
        'displayName': fallback,
        'username': fallback,
        'photoURL': u.photoURL,
        'anon': u.isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'friendUids': [],
        'prefs': {},
      });
      await _mirrorPublicProfile(u, preferredName: fallback);
    } else {
      if (preferredName != null && preferredName.isNotEmpty) {
        await ref.set({'displayName': preferredName},
            SetOptions(merge: true));
        await _mirrorPublicProfile(u, preferredName: preferredName);
      } else {
        await _mirrorPublicProfile(u);
      }
    }
  }

  void _setErr(Object e) {
    setState(() => _error = e.toString());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error: $_error')));
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in / Link account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],

          if (u == null) ...[
            const Text('Welcome! Choose how to start:',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),

            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        final user = await AuthService.instance.ensureAnon();
                        await _ensureProfile(user);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('Continue as guest'),
            ),

            const SizedBox(height: 12),

            if (kIsWeb)
              OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        try {
                          // Force account picker on web
                          final provider = GoogleAuthProvider()
                            ..setCustomParameters({'prompt': 'select_account'});
                          final cred = await FirebaseAuth.instance
                              .signInWithPopup(provider);
                          await _ensureProfile(cred.user!);
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          _setErr(e);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),

            const SizedBox(height: 12),
            const Text('Sign in with Email',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),

            TextField(
              controller: _signinEmailCtrl,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _signinPassCtrl,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        final cred = await AuthService.instance
                            .signInEmailPassword(
                                _signinEmailCtrl.text.trim(),
                                _signinPassCtrl.text);
                        await _ensureProfile(cred.user!);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('Sign in'),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        final cred = await AuthService.instance
                            .registerEmailPassword(
                                _signinEmailCtrl.text.trim(),
                                _signinPassCtrl.text);
                        await _ensureProfile(cred.user!);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('Create new account'),
            ),
          ] else if (u.isAnonymous) ...[
            const Text('Upgrade your guest account',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            if (kIsWeb)
              FilledButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('Link Google (keep my data)'),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        try {
                          final provider = GoogleAuthProvider()
                            ..setCustomParameters({'prompt': 'select_account'});
                          await FirebaseAuth.instance.currentUser!
                              .linkWithPopup(provider);

                          final user = FirebaseAuth.instance.currentUser!;
                          final preferred = _nameCtrl.text.trim();

                          await _ensureProfile(user,
                              preferredName: preferred);
                          await AuthService.instance.updateAuthDisplayName(
                              preferred.isEmpty
                                  ? (user.displayName ?? '')
                                  : preferred);
                          await FirebaseFirestore.instance
                              .collection('user_profiles')
                              .doc(user.uid)
                              .set({'anon': false}, SetOptions(merge: true));

                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          _setErr(e);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),

            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Link Email & Password (keep my data)'),
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        await AuthService.instance.linkEmailPassword(
                            _emailCtrl.text.trim(), _passCtrl.text);
                        final user = FirebaseAuth.instance.currentUser!;
                        await _ensureProfile(user,
                            preferredName: _nameCtrl.text.trim());
                        await FirebaseFirestore.instance
                            .collection('user_profiles')
                            .doc(user.uid)
                            .set({'anon': false}, SetOptions(merge: true));
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Already have an account? Sign in instead:',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),

            if (kIsWeb)
              OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() {
                          _busy = true;
                          _error = null;
                        });
                        try {
                          final provider = GoogleAuthProvider()
                            ..setCustomParameters({'prompt': 'select_account'});
                          final cred = await FirebaseAuth.instance
                              .signInWithPopup(provider);
                          await _ensureProfile(cred.user!);
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          _setErr(e);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),

            const SizedBox(height: 8),
            TextField(
              controller: _signinEmailCtrl,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _signinPassCtrl,
              decoration: const InputDecoration(
                  labelText: 'Password', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        final cred = await AuthService.instance
                            .signInEmailPassword(
                                _signinEmailCtrl.text.trim(),
                                _signinPassCtrl.text);
                        await _ensureProfile(cred.user!);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: const Text('Sign in with Email'),
            ),
          ] else ...[
            // Already signed in with a real provider.
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('You are signed in'),
              subtitle: Text('UID: ${u.uid.substring(0, 8)} • Providers: '
                  '${u.providerData.map((p) => p.providerId).join(", ")}'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        await AuthService.instance.signOut();
                        // Optional: keep the app ready by starting a guest session
                        final guest = await AuthService.instance.ensureAnon();
                        await _ensureProfile(guest);
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        _setErr(e);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }
}
