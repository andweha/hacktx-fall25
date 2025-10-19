// lib/widgets/task_dialog.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:palette_generator/palette_generator.dart';

typedef TaskToggleCallback = Future<void> Function();

// Cache for sampled colors to avoid repeated processing
final Map<String, Color> _colorCache = {};

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
    this.completedAt,
  });

  final String title;
  final bool completed;
  final TaskToggleCallback onToggle;
  final VoidCallback onCancel;

  // For image preview / upload
  final String? imageUrl;
  final int? cellIndex;
  final DocumentReference<Map<String, dynamic>>? boardRef;
  final String? completedAt;

  @override
  Widget build(BuildContext context) {
    return completed
        ? _CompletedTaskDialog(
            title: title,
            onToggle: onToggle,
            onCancel: onCancel,
            imageUrl: imageUrl,
            completedAt: completedAt,
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
            (map['cells'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
        } else {
          cells = List.generate(
            9,
            (i) => {
              'title': '',
              'status': 'open',
              'caption': '',
              'imageUrl': null,
              'completedAt': null,
            },
          );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image uploaded!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.75, // Reduced from 0.80 to eliminate white space
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
                    // grabber and close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48), // Spacer to center grabber
                        Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0D9CC),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onCancel,
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF7A6F62),
                            size: 24,
                          ),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // Reduced from 16

                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4B4034),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8), // Reduced from 12
                    const Text(
                      'Did you finish this task?',
                      style: TextStyle(fontSize: 16, color: Color(0xFF7A6F62)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12), // Reduced from 16
                    // preview - clickable upload area
                    GestureDetector(
                      onTap: _isUploading ? null : _uploadImage,
                      child: Container(
                        height: 140, // Back to original size
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE0D9CC),
                            width: 1,
                          ),
                          color: const Color(0xFFFAFAFA),
                        ),
                        child:
                            (_currentImageUrl != null &&
                                _currentImageUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _currentImageUrl!,
                                  fit: BoxFit
                                      .contain, // Keep showing whole image
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Color(0xFF7A6F62),
                                    ),
                                  ),
                                  loadingBuilder: (c, child, p) => p == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.image_outlined,
                                      color: Color(0xFFB59F84),
                                      size: 32,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'No image uploaded',
                                      style: TextStyle(
                                        color: Color(0xFF7A6F62),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Tap here or "Upload Photo" to add one',
                                      style: TextStyle(
                                        color: Color(0xFFB59F84),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12), // Reduced from 16
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6), // Reduced from 8

                    if (widget.boardRef != null && widget.cellIndex != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : _uploadImage,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt),
                          label: Text(
                            _isUploading ? 'Uploading...' : 'Upload Photo',
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),
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

class _CompletedTaskDialog extends StatefulWidget {
  const _CompletedTaskDialog({
    required this.title,
    required this.onToggle,
    required this.onCancel,
    this.imageUrl,
    this.completedAt,
  });

  final String title;
  final TaskToggleCallback onToggle;
  final VoidCallback onCancel;
  final String? imageUrl;
  final String? completedAt;

  @override
  State<_CompletedTaskDialog> createState() => _CompletedTaskDialogState();
}

class _CompletedTaskDialogState extends State<_CompletedTaskDialog> {
  String _locationString = 'Getting location...';
  bool _locationLoading = true;
  Color? _bgColor; // sampled from the image

  @override
  void initState() {
    super.initState();
    // Start location detection immediately but don't block UI
    _getCurrentLocation();
    // Run palette generation in background - don't block UI
    Future.microtask(() => _updatePaletteIfNeeded());
  }

  @override
  void didUpdateWidget(covariant _CompletedTaskDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      // Run palette generation in background - don't block UI
      Future.microtask(() => _updatePaletteIfNeeded());
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // For web, use a simpler approach with faster timeout
      if (kIsWeb) {
        // Try to get location with a very short timeout for web
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.lowest,
          timeLimit: const Duration(seconds: 3),
        );

        // For web, we'll use a simple city lookup based on coordinates
        // This is more reliable than reverse geocoding on web
        final lat = position.latitude;
        final lng = position.longitude;

        // Simple coordinate-based city detection for common areas
        String cityName = _getCityFromCoordinates(lat, lng);

        setState(() {
          _locationString = cityName;
          _locationLoading = false;
        });
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationString = 'Location services disabled';
          _locationLoading = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationString = 'Location permission denied';
            _locationLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationString = 'Location permission permanently denied';
          _locationLoading = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Convert coordinates to city name using reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final city =
            placemark.locality ?? placemark.administrativeArea ?? 'Unknown';
        final state = placemark.administrativeArea ?? placemark.country ?? '';

        setState(() {
          _locationString = state.isNotEmpty ? '$city, $state' : city;
          _locationLoading = false;
        });
      } else {
        setState(() {
          _locationString = 'Unknown location';
          _locationLoading = false;
        });
      }
    } catch (e) {
      print('Location error: $e');
      setState(() {
        // Fallback for development/localhost
        _locationString = 'Location unavailable';
        _locationLoading = false;
      });
    }
  }

  Future<void> _updatePaletteIfNeeded() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return;

    // Check cache first - if we've already sampled this image, use cached color
    if (_colorCache.containsKey(url)) {
      if (mounted) {
        setState(() => _bgColor = _colorCache[url]);
      }
      return;
    }

    // Only sample if not cached - run in background
    Future.microtask(() async {
      try {
        final palette = await PaletteGenerator.fromImageProvider(
          NetworkImage(url),
          size: const Size(100, 60), // Even smaller sample for speed
          maximumColorCount: 8, // Reduced color count
        );

        final picked =
            palette.dominantColor?.color ??
            palette.vibrantColor?.color ??
            palette.darkMutedColor?.color;

        if (mounted && picked != null) {
          _colorCache[url] = picked; // Cache the result for future use
          setState(() => _bgColor = picked);
        }
      } catch (_) {
        // Keep fallback color if sampling fails - don't update UI
      }
    });
  }

  String _getCityFromCoordinates(double lat, double lng) {
    // Simple coordinate-based city detection for common areas
    // This is more reliable for web than reverse geocoding

    // Austin, TX area
    if (lat >= 30.0 && lat <= 30.5 && lng >= -98.0 && lng <= -97.5) {
      return 'Austin, TX';
    }

    // San Francisco, CA area
    if (lat >= 37.7 && lat <= 37.8 && lng >= -122.6 && lng <= -122.3) {
      return 'San Francisco, CA';
    }

    // New York, NY area
    if (lat >= 40.6 && lat <= 40.9 && lng >= -74.1 && lng <= -73.7) {
      return 'New York, NY';
    }

    // Los Angeles, CA area
    if (lat >= 33.9 && lat <= 34.2 && lng >= -118.5 && lng <= -118.0) {
      return 'Los Angeles, CA';
    }

    // Chicago, IL area
    if (lat >= 41.7 && lat <= 42.0 && lng >= -87.9 && lng <= -87.5) {
      return 'Chicago, IL';
    }

    // Seattle, WA area
    if (lat >= 47.5 && lat <= 47.7 && lng >= -122.5 && lng <= -122.2) {
      return 'Seattle, WA';
    }

    // Default fallback
    return 'Current Location';
  }

  String _formatCompletionDate() {
    if (widget.completedAt == null || widget.completedAt!.isEmpty) {
      return 'Just completed';
    }

    try {
      final date = DateTime.parse(widget.completedAt!);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just completed';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        // Format as "Month Day, Year at Time"
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final month = months[date.month - 1];
        final hour = date.hour > 12
            ? date.hour - 12
            : (date.hour == 0 ? 12 : date.hour);
        final minute = date.minute.toString().padLeft(2, '0');
        final ampm = date.hour >= 12 ? 'PM' : 'AM';

        return '$month ${date.day}, ${date.year} at $hour:$minute $ampm';
      }
    } catch (e) {
      return 'Recently completed';
    }
  }

  Widget _image() {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return Container(
        color: _bgColor ?? const Color(0xFF1A0B2E), // auto color or fallback
        child: Center(
          child: Image.network(
            widget.imageUrl!,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => _defaultGradient(),
            loadingBuilder: (c, child, p) => p == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ),
      );
    }
    return _defaultGradient();
  }

  Widget _defaultGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1), // Indigo
            Color(0xFF8B5CF6), // Purple
            Color(0xFFEC4899), // Pink
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.check_circle_outline, color: Colors.white, size: 80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive height factor - optimized for image display
    final heightFactor = screenWidth < 600 ? 0.80 : 0.70;

    return FractionallySizedBox(
      heightFactor: heightFactor,
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
                // Image container
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          screenHeight * 0.5, // controls image area height
                      // width stays as wide as the dialog
                    ),
                    child: Stack(
                      children: [
                        // Image
                        _image(),
                        // Gradient over ONLY the top 70% of the image
                        Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            heightFactor: 0.70, // stops at 70% height
                            widthFactor: 1.0,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.5, 0.7],
                                    colors: [
                                      Colors.black.withOpacity(0.15), // top
                                      Colors.black.withOpacity(0.08), // middle
                                      Colors
                                          .transparent, // fully transparent by 70%
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.fromRGBO(0, 0, 0, 0.0),
                          Color.fromRGBO(0, 0, 0, 0.65),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style:
                              theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ],
                              ) ??
                              TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ],
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatCompletionDate(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black.withOpacity(0.4),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        _locationLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Getting location...',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                            : Text(
                                _locationString,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: widget.onToggle,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(
                                255,
                                255,
                                255,
                                0.92,
                              ),
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Mark Incomplete'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: widget.onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                      ],
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
