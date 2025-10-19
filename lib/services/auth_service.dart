// lib/services/auth_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Ensure there's a signed-in user (anonymous if needed)
  Future<User> ensureAnon() async {
    final u = _auth.currentUser;
    if (u != null) return u;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  /* ===================== LINK (UPGRADE GUEST) ===================== */

  /// Web-only Google link (upgrade anonymous account, keep UID)
  Future<void> linkGoogleWeb() async {
    if (!kIsWeb) {
      throw StateError('Use google_sign_in on mobile. On web, use linkWithPopup.');
    }
    final provider = GoogleAuthProvider();
    await _auth.currentUser!.linkWithPopup(provider);
  }

  /// Link email/password to the CURRENT account (upgrade guest, keep UID)
  Future<void> linkEmailPassword(String email, String password) async {
    final cred = EmailAuthProvider.credential(email: email, password: password);
    await _auth.currentUser!.linkWithCredential(cred);
  }

  /* ===================== SIGN IN (RETURNING USER) ===================== */

  /// Google sign-in (when logged out, or you want to switch accounts)
  Future<UserCredential> signInGoogleWeb() async {
    if (!kIsWeb) {
      throw StateError('Use google_sign_in on mobile. On web, use signInWithPopup.');
    }
    final provider = GoogleAuthProvider();
    return _auth.signInWithPopup(provider);
  }

  /// Username/Password sign-in (when logged out) - converts username to synthetic email
  Future<UserCredential> signInUsernamePassword(String username, String password) async {
    final uname = username.trim().toLowerCase();
    final syntheticEmail = '$uname@app.local';
    return _auth.signInWithEmailAndPassword(email: syntheticEmail, password: password);
  }

  /// Register a brand-new username/password account (when logged out)
  Future<UserCredential> registerUsernamePassword(String username, String password) async {
    final uname = username.trim().toLowerCase();
    final syntheticEmail = '$uname@app.local';

    // Check username uniqueness
    final nameDoc = FirebaseFirestore.instance.doc('usernames/$uname');
    final snap = await nameDoc.get();
    if (snap.exists) {
      throw Exception('Username is taken.');
    }

    // Create the account
    final cred = await _auth.createUserWithEmailAndPassword(
      email: syntheticEmail, 
      password: password
    );

    final uid = cred.user!.uid;
    
    // Store user data and username mapping
    await FirebaseFirestore.instance.doc('users/$uid').set({
      'username': uname,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    await nameDoc.set({'uid': uid}); // map username -> uid
    
    return cred;
  }

  /// Link username/password to the CURRENT account (upgrade guest, keep UID)
  Future<void> linkUsernamePassword(String username, String password) async {
    final uname = username.trim().toLowerCase();
    final syntheticEmail = '$uname@app.local';
    
    // Check username uniqueness
    final nameDoc = FirebaseFirestore.instance.doc('usernames/$uname');
    final snap = await nameDoc.get();
    if (snap.exists) {
      throw Exception('Username is taken.');
    }

    // Link the credential
    final cred = EmailAuthProvider.credential(email: syntheticEmail, password: password);
    await _auth.currentUser!.linkWithCredential(cred);

    // Store username mapping
    final uid = _auth.currentUser!.uid;
    await FirebaseFirestore.instance.doc('users/$uid').update({
      'username': uname,
    });
    
    await nameDoc.set({'uid': uid}); // map username -> uid
  }

  /// Email/Password sign-in (when logged out) - kept for backward compatibility
  Future<UserCredential> signInEmailPassword(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Register a brand-new email/password account (when logged out) - kept for backward compatibility
  Future<UserCredential> registerEmailPassword(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  /* ===================== OTHER HELPERS ===================== */

  /// Update the FirebaseAuth user's display name
  Future<void> updateAuthDisplayName(String name) async {
    await _auth.currentUser!.updateDisplayName(name);
    await _auth.currentUser!.reload();
  }

  /// Sign out current user
  Future<void> signOut() => _auth.signOut();

  /// DELETE the current account entirely (auth only; Firestore cleanup is separate)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Re-authentication required before deleting account.');
      } else {
        rethrow;
      }
    }
  }
}
