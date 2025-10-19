// lib/widgets/task_dialog.dart
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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

  // For image preview / upload
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
            onToggle: onToggle,
            onCancel: onCancel,
            imageUrl: imageUrl,
            cellIndex: cellIndex,
            boardRef: boardRef,
          );
  }
}

/* ========================= INCOMPLETE (Mark Complete) ========================= */

class _IncompleteTaskDialog extends StatefulWidget {
  const _IncompleteTaskDialog({
    required this.title,
    required this.onToggle,
    required this.onCancel,
    this.imageUrl,
    this.cellIndex,
    this.boardRef,
  });

  final String title;
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
  void didUpdateWidget(covariant _IncompleteTaskDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _currentImageUrl = widget.imageUrl;
    }
  }

  /// Uploads an image to imgbb and stores the URL in Firestore at cells[cellIndex].
  /// IMPORTANT: Firestore cannot update an array element by index, so we:
  /// 1) read the whole `cells` array,
  /// 2) modify the desired element,
  /// 3) write the full array back in a transaction.
  Future<void> _uploadImage() async {
    if (widget.cellIndex == null || widget.boardRef == null) return;

    print('=== Upload Image Debug ===');
    print('Cell index: ${widget.cellIndex}');
    print('Board ref: ${widget.boardRef!.path}');

    setState(() => _isUploading = true);
    try {
      // Pick image
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (picked == null) {
        print('No image selected');
        return;
      }

      print('Image selected: ${picked.path}');
      final bytes = await picked.readAsBytes();
      print('Image bytes length: ${bytes.length}');
      if (bytes.length > 32 * 1024 * 1024) {
        throw Exception('Image too large (max 32 MB).');
      }

      // Upload to imgbb (free, no Firebase Storage billing)
      print('Starting imgbb API upload...');
      final resp = await http
          .post(
            Uri.parse('https://api.imgbb.com/1/upload'),
            body: {
              'key': '388b801ad115b37264215ebf5df0c7c6', // your key
              'image': base64Encode(bytes),
            },
          )
          .timeout(const Duration(seconds: 30));

      print('imgbb API response status: ${resp.statusCode}');
      if (resp.statusCode != 200) {
        throw Exception('imgbb error: ${resp.statusCode} ${resp.body}');
      }
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      if (decoded['success'] != true) {
        throw Exception('imgbb upload failed');
      }
      final url = (decoded['data'] as Map)['url'] as String;
      print('imgbb upload successful');
      print('Image URL: $url');

      // Update Firestore using a TRANSACTION (array element update by index is not supported)
      print('Updating Firestore with image URL: $url');
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(widget.boardRef!);
        if (!snap.exists) {
          throw Exception('Board not found');
        }
        final map = Map<String, dynamic>.from(snap.data() as Map);

        // Ensure `cells` exists and is a list of 9 maps
        List<Map<String, dynamic>> cells;
        if (map['cells'] is List && (map['cells'] as List).isNotEmpty) {
          cells = List<Map<String, dynamic>>.from(
            (map['cells'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } else {
          cells = List.generate(9, (i) => {
                'title': '',
                'status': 'open',
                'caption': '',
                'imageUrl': null,
                'completedAt': null,
              });
        }

        final idx = widget.cellIndex!;
        if (idx < 0 || idx >= cells.length) {
          throw Exception('Cell index out of range ($idx)');
        }

        final updatedCell = Map<String, dynamic>.from(cells[idx]);
        updatedCell['imageUrl'] = url;
        cells[idx] = updatedCell;

        print('Updated cell $idx: ${cells[idx]}');
        print('Full cells array: $cells');

        tx.update(widget.boardRef!, {
          'cells': cells,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      print('Firestore update completed');
      // Update local preview immediately
      setState(() => _currentImageUrl = url);
      print('Local state updated with imageUrl: $_currentImageUrl');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Image uploaded!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.70,
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
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomInset),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // grabber
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
                    const Text(
                      'Did you finish this task?',
                      style: TextStyle(fontSize: 16, color: Color(0xFF7A6F62)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // preview
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0D9CC), width: 1),
                        color: const Color(0xFFFAFAFA),
                      ),
                      child: (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _currentImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image, color: Color(0xFF7A6F62)),
                                ),
                                loadingBuilder: (c, child, p) =>
                                    p == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image_outlined, color: Color(0xFFB59F84), size: 32),
                                  SizedBox(height: 8),
                                  Text('No image uploaded', style: TextStyle(color: Color(0xFF7A6F62))),
                                  SizedBox(height: 2),
                                  Text('Tap "Upload Photo" to add one',
                                      style: TextStyle(color: Color(0xFFB59F84), fontSize: 12)),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // actions
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: widget.onToggle,
                        label: const Text('Mark Complete'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEABF4E),
                          foregroundColor: const Color(0xFF4B4034),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (widget.boardRef != null && widget.cellIndex != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : _uploadImage,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.camera_alt),
                          label: Text(_isUploading ? 'Uploading...' : 'Upload Photo'),
                        ),
                      ),

                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* =========================== COMPLETED (Mark Incomplete) =========================== */

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
  static const _fallbackAsset = 'assets/images/task_complete_bg.png';

  Widget _image() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => Image.asset(_fallbackAsset, fit: BoxFit.cover),
        loadingBuilder: (c, child, p) =>
            p == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Image.asset(_fallbackAsset, fit: BoxFit.cover);
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
                Positioned.fill(child: _image()),
                Positioned.fill(
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.fromRGBO(0, 0, 0, 0.05), Color.fromRGBO(0, 0, 0, 0.45)],
                        stops: [0.45, 1.0],
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
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color.fromRGBO(0, 0, 0, 0.0), Color.fromRGBO(0, 0, 0, 0.65)],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ) ??
                                  const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _dateString,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _locationString,
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: onToggle,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color.fromRGBO(255, 255, 255, 0.92),
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                child: const Text('Mark Incomplete'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: onCancel,
                                child: const Text('Close'),
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
