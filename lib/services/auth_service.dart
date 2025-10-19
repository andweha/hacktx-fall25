// lib/services/auth_service.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'guest_session.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  
  /// Check if current user is a guest (session-based)
  bool get isGuest => GuestSession.isGuest;

  /// Start a guest session (no Firebase auth required)
  Future<Map<String, String>> startGuestSession() async {
    GuestSession.startGuestSession();
    return GuestSession.getGuestInfo();
  }

  /// Ensure there's a signed-in user (anonymous if needed)
  Future<User> ensureAnon() async {
    final u = _auth.currentUser;
    if (u != null && u.isAnonymous) {
      // Already have an anonymous user, use it
      return u;
    }
    
    // Sign out any existing user first (to avoid conflicts)
    if (u != null) {
      await _auth.signOut();
    }
    
    try {
      final cred = await _auth.signInAnonymously();
      return cred.user!;
    } catch (e) {
      print('AuthService.ensureAnon error: $e');
      rethrow;
    }
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
    try {
      final cred = EmailAuthProvider.credential(email: email, password: password);
      await _auth.currentUser!.linkWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already linked to another account.';
          break;
        case 'weak-password':
          message = 'Password must be at least 6 characters.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'credential-already-in-use':
          message = 'This email is already linked to another account.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled.';
          break;
        default:
          message = 'An unexpected error occurred. Please try again.';
      }
      throw Exception(message);
    }
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
    
    try {
      return await _auth.signInWithEmailAndPassword(email: syntheticEmail, password: password);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with that username.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid username.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled.';
          break;
        default:
          message = 'An unexpected error occurred. Please try again.';
      }
      throw Exception(message);
    }
  }

  /// Register a brand-new username/password account (when logged out)
  Future<UserCredential> registerUsernamePassword(String username, String password) async {
    final uname = username.trim().toLowerCase();
    final syntheticEmail = '$uname@app.local';

    // Check username uniqueness
    final nameDoc = FirebaseFirestore.instance.doc('usernames/$uname');
    final snap = await nameDoc.get();
    if (snap.exists) {
      throw Exception('That username is already taken.');
    }

    try {
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
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'That username is already taken.';
          break;
        case 'weak-password':
          message = 'Password must be at least 6 characters.';
          break;
        case 'invalid-email':
          message = 'Please choose a valid username.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled.';
          break;
        default:
          message = 'An unexpected error occurred. Please try again.';
      }
      throw Exception(message);
    }
  }

  /// Link username/password to the CURRENT account (upgrade guest, keep UID)
  Future<void> linkUsernamePassword(String username, String password) async {
    final uname = username.trim().toLowerCase();
    final syntheticEmail = '$uname@app.local';
    
    // Check username uniqueness
    final nameDoc = FirebaseFirestore.instance.doc('usernames/$uname');
    final snap = await nameDoc.get();
    if (snap.exists) {
      throw Exception('That username is already taken.');
    }

    try {
      // Link the credential
      final cred = EmailAuthProvider.credential(email: syntheticEmail, password: password);
      await _auth.currentUser!.linkWithCredential(cred);

      // Store username mapping
      final uid = _auth.currentUser!.uid;
      await FirebaseFirestore.instance.doc('users/$uid').update({
        'username': uname,
      });
      
      await nameDoc.set({'uid': uid}); // map username -> uid
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'That username is already taken.';
          break;
        case 'weak-password':
          message = 'Password must be at least 6 characters.';
          break;
        case 'invalid-email':
          message = 'Please choose a valid username.';
          break;
        case 'credential-already-in-use':
          message = 'This username is already linked to another account.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled.';
          break;
        default:
          message = 'An unexpected error occurred. Please try again.';
      }
      throw Exception(message);
    }
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
