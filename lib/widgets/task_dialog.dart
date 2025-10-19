// lib/widgets/task_dialog.dart
import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

typedef TaskToggleCallback = Future<void> Function();

class TaskDialog extends StatelessWidget {
  const TaskDialog({
    super.key,
    required this.title,
    required this.completed,
    required this.onToggle,
    required this.onCancel,
    this.imageUrl,
    this.cellIndex,
    this.boardRef,
  });

  final String title;
  final bool completed;
  final TaskToggleCallback onToggle;
  final VoidCallback onCancel;
  final String? imageUrl;
  final int? cellIndex;
  final DocumentReference<Map<String, dynamic>>? boardRef;

  @override
  Widget build(BuildContext context) {
    return completed
        ? _CompletedTaskDialog(
            title: title,
            onToggle: onToggle,
            onCancel: onCancel,
            imageUrl: imageUrl,
          )
        : _IncompleteTaskDialog(
            title: title,
            completed: completed,
            onToggle: onToggle,
            onCancel: onCancel,
            imageUrl: imageUrl,
            cellIndex: cellIndex,
            boardRef: boardRef,
          );
  }
}

class _IncompleteTaskDialog extends StatefulWidget {
  const _IncompleteTaskDialog({
    required this.title,
    required this.completed,
    required this.onToggle,
    required this.onCancel,
    this.imageUrl,
    this.cellIndex,
    this.boardRef,
  });

  final String title;
  final bool completed;
  final TaskToggleCallback onToggle;
  final VoidCallback onCancel;
  final String? imageUrl;
  final int? cellIndex;
  final DocumentReference<Map<String, dynamic>>? boardRef;

  @override
  State<_IncompleteTaskDialog> createState() => _IncompleteTaskDialogState();
}

class _IncompleteTaskDialogState extends State<_IncompleteTaskDialog> {
  bool _isUploading = false;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.imageUrl;
  }

  @override
  void didUpdateWidget(_IncompleteTaskDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _currentImageUrl = widget.imageUrl;
    }
  }

  Future<void> _testImgbbConnection() async {
    try {
      print('Testing imgbb API connection...');
      // Simple test to check if imgbb API is accessible
      final response = await http.get(
        Uri.parse('https://api.imgbb.com/1/'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200 || response.statusCode == 400) {
        print('imgbb API connection: OK');
      } else {
        print('imgbb API connection: FAILED - Status: ${response.statusCode}');
      }
    } catch (e) {
      print('imgbb API connection: FAILED - $e');
    }
  }

  Future<void> _uploadImage() async {
    if (widget.cellIndex == null || widget.boardRef == null) return;
    
    print('=== Upload Image Debug ===');
    print('Cell index: ${widget.cellIndex}');
    print('Board ref: ${widget.boardRef!.path}');
    
    // Test imgbb API connection first
    await _testImgbbConnection();
    
    setState(() => _isUploading = true);
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Smaller for better web performance
        maxHeight: 600, // Smaller for better web performance
        imageQuality: 80, // Good quality but smaller file size
        requestFullMetadata: false, // Faster on web
      );
      
      if (image == null) {
        print('No image selected');
        return;
      }
      
      print('Image selected: ${image.path}');
      
      // Convert XFile to base64 for imgbb API
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      print('Image bytes length: ${bytes.length}');
      
      // Check file size (limit to 32MB for imgbb)
      if (bytes.length > 32 * 1024 * 1024) {
        throw Exception('Image too large. Please choose a smaller image (max 32MB).');
      }
      
      print('Starting imgbb API upload...');
      print('API URL: https://api.imgbb.com/1/upload');
      print('API Key: 388b801a...'); // Show first 8 chars for debugging
      print('Base64 length: ${base64Image.length}');
      
      // Upload to imgbb API
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {
          'key': '388b801ad115b37264215ebf5df0c7c6', // You'll need to get this from imgbb.com
          'image': base64Image,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Upload timeout after 30 seconds. Please try again.');
        },
      );
      
      print('imgbb API response status: ${response.statusCode}');
      print('imgbb API response body: ${response.body}');
      
      String imageUrl;
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        print('Parsed response data: $responseData');
        
        if (responseData['success'] == true) {
          final data = responseData['data'] as Map<String, dynamic>;
          imageUrl = data['url'] as String;
          print('imgbb upload successful');
          print('Image URL: $imageUrl');
        } else {
          final error = responseData['error'] as Map<String, dynamic>;
          throw Exception('imgbb upload failed: ${error['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('imgbb API error: ${response.statusCode} - ${response.body}');
      }
      
      final downloadUrl = imageUrl;
      
      // Update Firestore
      final updateData = {
        'cells.${widget.cellIndex}.imageUrl': downloadUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      print('Updating Firestore with: $updateData');
      
      await widget.boardRef!.update(updateData);
      
      print('Firestore update completed');
      
      // Update local state immediately to show the image
      setState(() {
        _currentImageUrl = downloadUrl;
      });
      
      print('Local state updated with imageUrl: $_currentImageUrl');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      }
    } catch (e) {
      print('Upload error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      print('Upload process finished');
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.55, // Further reduced to prevent overflow
      widthFactor: 1,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Material(
            elevation: 12,
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0D9CC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B4034),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.completed
                        ? 'Need to change your mind?'
                        : 'Did you finish this task?',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF7A6F62),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Image preview section - always show a box
                  Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0D9CC), width: 1),
                      color: const Color(0xFFFAFAFA),
                    ),
                    child: _currentImageUrl != null && _currentImageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _currentImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFFF5F5F5),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          color: Color(0xFF7A6F62),
                                          size: 32,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(
                                            color: Color(0xFF7A6F62),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: const Color(0xFFF5F5F5),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF7A6F62),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Loading image...',
                                          style: TextStyle(
                                            color: Color(0xFF7A6F62),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  color: Color(0xFFB59F84),
                                  size: 40,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No image uploaded',
                                  style: TextStyle(
                                    color: Color(0xFF7A6F62),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tap "Upload Photo" to add one',
                                  style: TextStyle(
                                    color: Color(0xFFB59F84),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: Icon(
                        widget.completed ? Icons.undo : Icons.check_circle_outline,
                      ),
                      onPressed: widget.onToggle,
                      label: Text(
                        widget.completed ? 'Mark Incomplete' : 'Mark Complete',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.completed
                            ? const Color(0xFFB59F84)
                            : const Color(0xFFEABF4E),
                        foregroundColor: const Color(0xFF4B4034),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  if (widget.boardRef != null && widget.cellIndex != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _uploadImage,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE0D9CC)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: _isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt),
                        label: Text(_isUploading ? 'Uploading...' : 'Upload Photo'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0D9CC)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A6F62),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedTaskDialog extends StatelessWidget {
  const _CompletedTaskDialog({
    required this.title,
    required this.onToggle,
    required this.onCancel,
    this.imageUrl,
  });

  final String title;
  final TaskToggleCallback onToggle;
  final VoidCallback onCancel;
  final String? imageUrl;

  static const _dateString = 'October 12, 12:28 PM';
  static const _locationString = 'Kyoto, Japan';
  static const _assetPath = 'assets/images/task_complete_bg.png';

  Widget _buildImageWidget() {
    print('=== Completed Dialog Image Debug ===');
    print('ImageUrl received: $imageUrl');
    print('ImageUrl is null: ${imageUrl == null}');
    print('ImageUrl is empty: ${imageUrl?.isEmpty ?? true}');
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      print('Using Firebase image: $imageUrl');
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          print('Firebase image failed to load: $error');
          return Image.asset(
            _assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: const Color(0xFF2A1F1A));
            },
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF2A1F1A),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        },
      );
    }
    
    print('Using default asset image');
    return Image.asset(
      _assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        return Container(color: const Color(0xFF2A1F1A));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.65,
      widthFactor: 1,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: _buildImageWidget(),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [
                          Color.fromRGBO(0, 0, 0, 0.05),
                          Color.fromRGBO(0, 0, 0, 0.45),
                        ],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const [
                              Color.fromRGBO(0, 0, 0, 0.0),
                              Color.fromRGBO(0, 0, 0, 0.65),
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ) ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _dateString,
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ) ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    // fontWeight: FontWeight.w700,
                                  ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 4),
                            Text(
                              _locationString,
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 15,
                                    // fontWeight: FontWeight.w700,
                                  ) ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: onToggle,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromRGBO(255, 255, 255, 0.92),
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text('Mark Incomplete'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
