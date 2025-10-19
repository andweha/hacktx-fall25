// lib/pages/profile_page.dart
import 'dart:ui' as ui; // for ImageFilter.blur

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/widgets/task_dialog.dart';
import '/widgets/stat_dialog.dart';
import '/widgets/stat_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  // NEW: one-time public-profile backfill (for older accounts)
  bool _ensuredPublic = false;
  Future<void> _ensurePublicProfile() async {
    final user = FirebaseAuth.instance.currentUser!;
    final pubRef = FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(user.uid);
    final exists = (await pubRef.get()).exists;
    if (exists) return;

    final privSnap = await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(user.uid)
        .get();
    final m = privSnap.data() ?? {};
    final displayName = (m['displayName'] ?? user.displayName ?? '').toString();
    final username = (m['username'] ?? '').toString();

    await pubRef.set({
      'displayName': displayName,
      'username': username,
      'photoURL': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // If no user, show a simple message instead of redirecting
      // The main app's auth state will handle showing the sign-in page
      return const Scaffold(
        body: Center(
          child: Text(
            'Please sign in to access profile',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    // Kick off one-time backfill without blocking build
    if (!_ensuredPublic) {
      _ensuredPublic = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensurePublicProfile(),
      );
    }

    final profRef = FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(uid);
    final boardRef = FirebaseFirestore.instance.collection('boards').doc(uid);

    return Scaffold(
      // appBar: AppBar(),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists) {
            return Center(
              child: FilledButton(
                onPressed: () async {
                  await _createDefaultProfile(profRef);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile created.')),
                  );
                },
                child: const Text('Create profile now'),
              ),
            );
          }

          final data = snap.data!.data()!;
          final displayName = (data['displayName'] ?? '').toString();
          final username = (data['username'] ?? '').toString();
          final photoUrl = (data['photoURL'] as String?) ??
              FirebaseAuth.instance.currentUser?.photoURL;
          final sanitizedHandle = username.trim().replaceFirst('@', '');
          final fallbackHandle =
              uid.length > 6 ? uid.substring(0, 6) : uid;
          final handle = sanitizedHandle.isEmpty ? fallbackHandle : sanitizedHandle;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ProfileHeader(
                      displayName: displayName.isEmpty ? '(no name)' : displayName,
                      handle: handle,
                      photoUrl: photoUrl,
                      avatarRadius: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: boardRef.snapshots(),
                      builder: (context, boardSnap) {
                        if (boardSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!boardSnap.hasData || !boardSnap.data!.exists) {
                          return _buildEmptyGallery();
                        }

                        final boardData = boardSnap.data!.data();
                        if (boardData == null) {
                          return _buildEmptyGallery();
                        }

                        final cells = boardData['cells'];
                        if (cells is! List) {
                          return _buildEmptyGallery();
                        }

                        final tasks = _mapCellsToTaskItems(cells);
                        if (tasks.isEmpty) {
                          return _buildEmptyGallery();
                        }

                        final streakWeeks = _calculateStreakWeeks(tasks);

                        return ProfileFeed(
                          tasks: tasks,
                          streakWeeks: streakWeeks,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<TaskItem> _mapCellsToTaskItems(List<dynamic> cells) {
    final items = <TaskItem>[];

    for (final raw in cells) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final status = (map['status'] as String?)?.toLowerCase();
      if (status != 'done') continue;

      final imageUrl = (map['imageUrl'] as String?)?.trim();
      if (imageUrl == null || imageUrl.isEmpty) continue;

      final title = (map['title'] as String?)?.trim();
      final details = map['details'] as String?;
      final location = (map['location'] as String?)?.trim();
      final completedAt = _parseTimestamp(map['completedAt'] as String?);

      final participantAvatars = <String>[];
      final avatars = map['participantAvatars'];
      if (avatars is List) {
        for (final avatar in avatars) {
          if (avatar is String && avatar.isNotEmpty) {
            participantAvatars.add(avatar);
          }
        }
      }

      items.add(
        TaskItem(
          title: (title == null || title.isEmpty) ? 'Completed task' : title,
          timestamp: completedAt,
          location: location?.isEmpty ?? true ? null : location,
          imageUrl: imageUrl,
          participantAvatars: participantAvatars,
          details: details,
        ),
      );
    }

    items.sort((a, b) {
      final at = a.timestamp;
      final bt = b.timestamp;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    return items;
  }

  DateTime? _parseTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int _calculateStreakWeeks(List<TaskItem> tasks) {
    final weeks = <DateTime>{};
    for (final task in tasks) {
      final ts = task.timestamp;
      if (ts == null) continue;
      final normalized = DateTime(ts.year, ts.month, ts.day);
      final startOfWeek = normalized.subtract(
        Duration(days: normalized.weekday - 1),
      );
      weeks.add(DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day));
    }
    return weeks.length;
  }

  Widget _buildEmptyGallery() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.image_outlined, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No completed tasks with photos yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Finish tasks with photos to build your board.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDefaultProfile(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final user = FirebaseAuth.instance.currentUser!;
    final uname = _genUsername();

    // Private profile
    await ref.set({
      'displayName': uname,
      'username': uname,
      'photoURL': null,
      'createdAt': FieldValue.serverTimestamp(),
      'anon': user.isAnonymous,
      'friendUids': [],
      'prefs': {},
    }, SetOptions(merge: true));

    // Public mini profile
    await FirebaseFirestore.instance
        .collection('public_profiles')
        .doc(user.uid)
        .set({
          'displayName': uname,
          'username': uname,
          'photoURL': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    await user.updateDisplayName(uname);
    await user.reload();
  }

  String _genUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'user-${chars[now % chars.length]}'
        '${chars[(now >> 5) % chars.length]}'
        '${chars[(now >> 10) % chars.length]}'
        '${chars[(now >> 15) % chars.length]}';
  }
}

/* ----------------- Single-board stats (fits your current schema) ----------------- */

/* ------------------------------- Friends Section ------------------------------- */

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.handle, // pass without '@'
    this.photoUrl,
    this.avatarRadius = 24,
  });

  final String displayName;
  final String handle;
  final String? photoUrl;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final handleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.grey[600],
    );

    String initialsFrom(String name) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) return '?';
      final f = parts.first.characters.first.toUpperCase();
      final l = parts.length > 1
          ? parts.last.characters.first.toUpperCase()
          : '';
      return (f + l).trim();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isEmpty ? '(no name)' : displayName,
                  style: nameStyle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('@$handle', style: handleStyle),
              ],
            ),
          ),
          CircleAvatar(
            radius: avatarRadius,
            backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                ? NetworkImage(photoUrl!)
                : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Text(initialsFrom(displayName))
                : null,
          ),
        ],
      ),
    );
  }
}

/* ----------------- Profile Feed (cards + popups) ----------------- */

class ProfileFeed extends StatelessWidget {
  const ProfileFeed({
    super.key,
    this.tasks,
    this.streakWeeks = 3,
    this.horizontalGap = 12,
    this.verticalGap = 12,
  });

  final List<TaskItem>? tasks;
  final int streakWeeks;
  final double horizontalGap;
  final double verticalGap;

  @override
  Widget build(BuildContext context) {
    final data = tasks ?? _demoTasks();

    // Split into two columns (simple alternating layout)
    final left = <Widget>[];
    final right = <Widget>[];

    // Streak card at the top-left
    left.add(
      StatCard(
        title: 'Week',
        value: '$streakWeeks',
        subtitle: 'Streak',
        backgroundColor: const Color(0xFFF7E39E), // same yellow
        onTap: () => _showStreakPopup(context),
      ),
    );

    left.add(SizedBox(height: verticalGap));

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final card = TaskCard(
        task: item,
        onTap: () => _showTaskPopup(context, item),
      );
      if (i.isEven) {
        left.add(card);
        left.add(SizedBox(height: verticalGap));
      } else {
        right.add(card);
        right.add(SizedBox(height: verticalGap));
      }
    }
    const int totalCompletedTasks = 27;
    final completedCard = StatCard(
      title: 'Completed',
      value: '$totalCompletedTasks',
      subtitle: 'tasks',
      height: 140, // shorter tile looks nice under a task
      backgroundColor: const Color(0xFFF7E39E),
      onTap: () => _showTotalCompletedPopup(context, totalCompletedTasks),
    );

    // Place it right below the first right-column item (or at top if column empty)
    if (right.isNotEmpty) {
      right.insertAll(1, [
        SizedBox(height: verticalGap),
        completedCard,
        SizedBox(height: verticalGap),
      ]);
    } else {
      right.addAll([
        SizedBox(height: verticalGap),
        completedCard,
        SizedBox(height: verticalGap),
      ]);
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: left)),
            SizedBox(width: horizontalGap),
            Expanded(child: Column(children: right)),
          ],
        ),
      ),
    );
  }

  /* ---------- POPUPS WITH BACKGROUND BLUR ---------- */

  Future<void> _showTotalCompletedPopup(BuildContext outerContext, int total) {
    return showGeneralDialog(
      context: outerContext,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) {
        return Builder(
          builder: (ctx) {
            return AnimatedBuilder(
              animation: ModalRoute.of(ctx)!.animation!,
              builder: (ctx, child) {
                final curved = CurvedAnimation(
                  parent: ModalRoute.of(ctx)!.animation!,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return Stack(
                  children: [
                    // Tappable blurred backdrop
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(ctx).pop(),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                    // Slide-up StatDialog
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(curved),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: StatDialog(
                              title: 'Completed',
                              value: '$total',
                              caption: 'tasks',
                              description: '', // add copy later if you want
                              onClose: () => Navigator.of(ctx).pop(),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuad,
          ),
          child: child,
        );
      },
    );
  }

  Future<void> _showStreakPopup(BuildContext outerContext) {
    return showGeneralDialog(
      context: outerContext,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) {
        // Fresh context to avoid deactivated-ancestor issues
        return Builder(
          builder: (ctx) {
            return AnimatedBuilder(
              animation: ModalRoute.of(ctx)!.animation!,
              builder: (ctx, child) {
                final curved = CurvedAnimation(
                  parent: ModalRoute.of(ctx)!.animation!,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return Stack(
                  children: [
                    // Tappable blurred backdrop — tap outside to dismiss
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(ctx).pop(),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),

                    // Slide-up StatDialog
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(curved),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: StatDialog(
                              title: 'Streak',
                              value:
                                  '$streakWeeks', // you can pass any number/string
                              caption: 'weeks',
                              description:
                                  '', // keep empty for now; fill later if needed
                              onClose: () => Navigator.of(ctx).pop(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        // Soft fade for the scene while the sheet slides up
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuad,
          ),
          child: child,
        );
      },
    );
  }

  Future<void> _showTaskPopup(BuildContext outerContext, TaskItem task) {
    return showGeneralDialog(
      context: outerContext,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.25),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) {
        return Builder(
          builder: (ctx) {
            return AnimatedBuilder(
              animation: ModalRoute.of(ctx)!.animation!,
              builder: (ctx, child) {
                final curved = CurvedAnimation(
                  parent: ModalRoute.of(ctx)!.animation!,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return Stack(
                  children: [
                    // Tappable blurred backdrop — tap outside to dismiss
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(ctx).pop(),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),

                    // Slide-up bottom sheet using your TaskDialog
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(curved),
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: TaskDialog(
                              title: task.title,
                              completed:
                                  true, // your profile tasks are completed
                              onToggle: () async {
                                // optional: toggle back in Firestore if you support it later
                              },
                              onCancel: () => Navigator.of(ctx).pop(),
                              // If you added these optional params to TaskDialog:
                              dateString: _monthDayTime(task.timestamp),
                              locationString: task.location,
                              backgroundImage:
                                  (task.imageUrl != null &&
                                      task.imageUrl!.isNotEmpty)
                                  ? NetworkImage(task.imageUrl!)
                                  : const AssetImage(
                                      'assets/images/task_complete_bg.png',
                                    ),
                              details: task.details,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuad,
          ),
          child: child,
        );
      },
    );
  }

  String _monthDayTime(DateTime? t) {
    if (t == null) return '';
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '${months[t.month - 1]} ${t.day}, $h:$m $ampm';
  }

  // Demo content so it renders immediately
  List<TaskItem> _demoTasks() => [
    TaskItem(
      title: 'See a tourist attraction',
      timestamp: DateTime(2025, 10, 12, 12, 28),
      location: 'Kyoto, Japan',
      imageUrl:
          'https://images.unsplash.com/photo-1549692520-acc6669e2f0c?w=1200',
      participantAvatars: [
        'https://i.pravatar.cc/100?img=1',
        'https://i.pravatar.cc/100?img=2',
      ],
      completed: true,
      details: 'A perfect afternoon under the cherry blossoms.',
    ),
    TaskItem(
      title: 'New workout',
      timestamp: DateTime(2025, 10, 12, 12, 28),
      location: 'Kyoto, Japan',
      imageUrl:
          'https://images.unsplash.com/photo-1517365830460-955ce3ccd263?w=1200',
      completed: true,
      details: '45-minute HIIT with core focus.',
    ),
    TaskItem(
      title: 'Take a walk in a park',
      timestamp: DateTime(2025, 10, 12, 12, 28),
      location: 'Kyoto, Japan',
      imageUrl:
          'https://images.unsplash.com/photo-1506089676908-3592f7389d4d?w=1200',
      completed: true,
    ),
    TaskItem(
      title: 'Cherry blossoms',
      timestamp: DateTime(2025, 10, 12, 12, 28),
      location: 'Kyoto, Japan',
      imageUrl:
          'https://images.unsplash.com/photo-1524499982521-1ffd58dd89ea?w=1200',
      completed: true,
    ),
  ];
}

/* ----------------- TaskCard ----------------- */

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, this.onTap});

  final TaskItem task;
  final VoidCallback? onTap;

  static const _shadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 6)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLine = '${_monthDayTime(task.timestamp)}\n${task.location ?? ''}'
        .trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: _shadow, // the little shadow below
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Background image
                AspectRatio(
                  aspectRatio: 3 / 8,
                  child: task.imageUrl != null && task.imageUrl!.isNotEmpty
                      ? Image.network(task.imageUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.grey.shade300),
                ),

                // Bottom blur (like the dialog)
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.fromRGBO(0, 0, 0, 0.00),
                          Color.fromRGBO(0, 0, 0, 0.35),
                          Color.fromRGBO(0, 0, 0, 0.75),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child:
                            task.imageUrl != null && task.imageUrl!.isNotEmpty
                            ? Image.network(task.imageUrl!, fit: BoxFit.cover)
                            : Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                ),

                // A light extra gradient on the very bottom for contrast
                Positioned.fill(
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),

                // Foreground content
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.participantAvatars.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AvatarStack(urls: task.participantAvatars),
                        ),
                      Text(
                        task.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthDayTime(DateTime? t) {
    if (t == null) return '';
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '${months[t.month - 1]} ${t.day}, $h:$m $ampm';
  }
}

/* ----------------- Avatar Stack ----------------- */

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    const overlap = 12.0;

    return SizedBox(
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < urls.length && i < 4; i++)
            Positioned(
              left: i * overlap,
              child: CircleAvatar(
                radius: size / 2,
                backgroundImage: NetworkImage(urls[i]),
              ),
            ),
        ],
      ),
    );
  }
}

/* ----------------- Model ----------------- */

class TaskItem {
  TaskItem({
    required this.title,
    this.timestamp,
    this.location,
    this.imageUrl,
    this.participantAvatars = const [],
    this.completed = true, // all tasks shown are completed
    this.details,
  });

  final String title;
  final DateTime? timestamp;
  final String? location;
  final String? imageUrl;
  final List<String> participantAvatars;
  final bool completed;
  final String? details;
}
