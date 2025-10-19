import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'pages/friends_page.dart';
import 'pages/settings_page.dart';
import 'pages/mainboard_page.dart';
import 'pages/feed_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _isUploading = false;

  final List<Widget> _pages = [
    const MainBoardPage(),
    const FeedPage(),
    const FriendsPage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _uploadImage() async {
    if (_isUploading) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('gallery_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Upload image data (works for both web and mobile)
      final bytes = await image.readAsBytes();
      await storageRef.putData(bytes);
      
      final imageUrl = await storageRef.getDownloadURL();

      // Create a gallery image document (not a task)
      await FirebaseFirestore.instance.collection('boards').add({
        'title': 'Shared Image',
        'imageUrl': imageUrl,
        'completed': true,
        'completedAt': DateTime.now().toIso8601String(),
        'location': 'Gallery',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'gallery_image', // Mark as gallery image, not task
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image shared to gallery!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 1 // Only show on Feed tab
          ? FloatingActionButton(
              onPressed: _isUploading ? null : _uploadImage,
              backgroundColor: Colors.blue[600],
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Board',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
