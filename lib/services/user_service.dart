import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class UserService {
  UserService._();
  static final instance = UserService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Ensure an authenticated session. Anonymous is fine.
  Future<User> ensureAnonSignIn() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  // Create a profile doc if missing.
  Future<void> ensureProfile() async {
    final uid = _auth.currentUser!.uid;
    final ref = _db.collection('user_profiles').doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;

    final uname = _generateUsername();
    await ref.set({
      'displayName': uname,
      'username': uname,
      'photoURL': null,
      'createdAt': FieldValue.serverTimestamp(),
      'anon': _auth.currentUser!.isAnonymous,
      'friendUids': [],
      'prefs': {},
    });
  }

  // Live updates for the current user's profile.
  Stream<DocumentSnapshot<Map<String, dynamic>>> myProfileStream() {
    final uid = _auth.currentUser!.uid;
    return _db.collection('user_profiles').doc(uid).snapshots();
  }

  // Simple profile edits.
  Future<void> updateDisplayName(String name) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('user_profiles').doc(uid).set(
      {'displayName': name},
      SetOptions(merge: true),
    );
  }

  Future<void> updatePrefs(Map<String, dynamic> prefs) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('user_profiles').doc(uid).set(
      {'prefs': prefs},
      SetOptions(merge: true),
    );
  }

  // Optional: upgrade anon account by linking Google.
  Future<void> linkGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // user cancelled
    final googleAuth = await googleUser.authentication;

    final cred = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _auth.currentUser!.linkWithCredential(cred);

    // Reflect that the account is no longer anonymous.
    final uid = _auth.currentUser!.uid;
    await _db.collection('user_profiles').doc(uid).set(
      {'anon': false},
      SetOptions(merge: true),
    );
  }

  String _generateUsername() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random();
    final suffix = List.generate(
      4,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
    return 'user-$suffix';
  }
}
