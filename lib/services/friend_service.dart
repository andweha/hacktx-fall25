import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  FriendService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('No signed in user.');
    }
    return u.uid;
  }

  /// Returns the current user's friend code, creating one if missing.
  Future<String> getOrCreateFriendCode() async {
    final meRef = _db.collection('users').doc(_uid);
    final snap = await meRef.get();
    final data = snap.data() ?? {};
    final existing = data['friendCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate a short unique code like K20k17.
    String makeCode() {
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final r = Random.secure();
      return List.generate(6, (_) => alphabet[r.nextInt(alphabet.length)])
          .join();
    }

    // Ensure uniqueness by checking the index.
    String code = makeCode();
    while (true) {
      final q = await _db
          .collection('users')
          .where('friendCode', isEqualTo: code)
          .limit(1)
          .get();
      if (q.docs.isEmpty) break;
      code = makeCode();
    }

    await meRef.set({'friendCode': code}, SetOptions(merge: true));
    return code;
  }

  /// Stream of the current user's friends as a list of UIDs.
  Stream<List<String>> friendIdsStream() {
    final meRef = _db.collection('users').doc(_uid);
    return meRef.snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return <String>[];
      final list = data['friends'];
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
      return <String>[];
    });
  }

  /// Look up a user's minimal public profile.
  Future<_UserMini?> fetchUserMini(String uid) async {
    final d = await _db.collection('users').doc(uid).get();
    if (!d.exists) return null;
    final m = d.data()!;
    return _UserMini(
      uid: uid,
      username: (m['username'] as String?) ?? '',
      displayName: (m['displayName'] as String?) ?? '',
      photoUrl: (m['photoUrl'] as String?) ?? '',
      friendCode: (m['friendCode'] as String?) ?? '',
    );
  }

  /// Add a friend by friend code. Adds both sides with arrayUnion.
  Future<void> addFriendByCode(String code) async {
    final targetQ = await _db
        .collection('users')
        .where('friendCode', isEqualTo: code)
        .limit(1)
        .get();

    if (targetQ.docs.isEmpty) {
      throw Exception('No user found for that code.');
    }

    final targetUid = targetQ.docs.first.id;
    if (targetUid == _uid) {
      throw Exception('You cannot add yourself.');
    }

    final meRef = _db.collection('users').doc(_uid);
    final themRef = _db.collection('users').doc(targetUid);

    await _db.runTransaction((tx) async {
      tx.update(meRef, {'friends': FieldValue.arrayUnion([targetUid])});
      tx.update(themRef, {'friends': FieldValue.arrayUnion([_uid])});
    });
  }

  /// Remove a friend on both sides.
  Future<void> removeFriend(String friendUid) async {
    final meRef = _db.collection('users').doc(_uid);
    final themRef = _db.collection('users').doc(friendUid);
    await _db.runTransaction((tx) async {
      tx.update(meRef, {'friends': FieldValue.arrayRemove([friendUid])});
      tx.update(themRef, {'friends': FieldValue.arrayRemove([_uid])});
    });
  }
}

/// Internal helper for tiny profile display.
class _UserMini {
  _UserMini({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.photoUrl,
    required this.friendCode,
  });

  final String uid;
  final String username;
  final String displayName;
  final String photoUrl;
  final String friendCode;

  String get title {
    if (displayName.isNotEmpty) return displayName;
    if (username.isNotEmpty) return username;
    return uid;
  }
}
