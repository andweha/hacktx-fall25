// lib/services/auth_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';

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

  /// Email/Password sign-in (when logged out)
  Future<UserCredential> signInEmailPassword(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Register a brand-new email/password account (when logged out)
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
