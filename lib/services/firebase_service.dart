import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload image to Firebase Storage
  Future<String> uploadImage(File imageFile) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'user_images/$userId/$timestamp.jpg';
      final ref = _storage.ref().child(path);
      await ref.putFile(imageFile);
      final downloadUrl = await ref.getDownloadURL();
      await _firestore.collection('posts').add({
        'userId': userId,
        'imageUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Save or update user information
  Future<void> saveUserInfo({
    required String userId,
    required String name,
    String? bio,
    String? profileImageUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'bio': bio,
        'profileImageUrl': profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save user information: $e');
    }
  }

  // Get user information
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      throw Exception('Failed to get user information: $e');
    }
  }

  // Get user's posts
  Future<List<Map<String, dynamic>>> getUserPosts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get user posts: $e');
    }
  }

  // Get all recent posts (for feed)
  Future<List<Map<String, dynamic>>> getRecentPosts() async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get recent posts: $e');
    }
  }
}