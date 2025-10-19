import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/guest_session.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  // Global color cache for performance
  final Map<String, Color> _colorCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header with user info
            _buildHeader(),
            const SizedBox(height: 16),
            // Feed content
            Expanded(
              child: _buildFeed(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = GuestSession.isGuest;
    
    String displayName;
    String username;
    
    if (isGuest) {
      displayName = 'Guest User';
      username = 'guest';
    } else {
      displayName = user?.displayName ?? 'User';
      final email = user?.email ?? '';
      username = email.isNotEmpty ? email.split('@')[0] : 'user';
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '@$username',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Profile picture
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: user?.photoURL != null 
                ? NetworkImage(user!.photoURL!) 
                : null,
            child: user?.photoURL == null
                ? Icon(
                    Icons.person,
                    color: Colors.grey[600],
                    size: 24,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    // Get the appropriate user ID for the board reference
    final user = FirebaseAuth.instance.currentUser;
    final guestId = GuestSession.isGuest ? GuestSession.getGuestId() : null;
    final userId = user?.uid ?? guestId;
    
    if (userId == null) {
      return const Center(child: Text('No user session'));
    }
    
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('friendships')
          .where('members', arrayContains: userId)
          .snapshots(),
      builder: (context, friendsSnapshot) {
        if (friendsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final friendIds = <String>{};
        if (friendsSnapshot.hasData) {
          for (final doc in friendsSnapshot.data!.docs) {
            final members = (doc.data()['members'] as List?) ?? [];
            for (final member in members) {
              if (member is String && member != userId) {
                friendIds.add(member);
              }
            }
          }
        }

        final targetIds = <String>{userId, ...friendIds};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('boards').snapshots(),
          builder: (context, boardsSnapshot) {
            if (boardsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = boardsSnapshot.data?.docs ?? [];
            final relevantBoards = docs
                .where((doc) => targetIds.contains(doc.id))
                .toList();

            if (relevantBoards.isEmpty) {
              return const Center(
                child: Text(
                  'No completed tasks yet!\nComplete tasks with photos to see them here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final completedTasks = <Map<String, dynamic>>[];

            for (final board in relevantBoards) {
              final boardData = board.data();
              final cells = boardData['cells'];
              if (cells is! List) continue;

              for (final cell in cells) {
                if (cell is! Map) continue;
                final cellMap = Map<String, dynamic>.from(cell);
                final status =
                    (cellMap['status'] as String?)?.toLowerCase() ?? '';
                final imageUrl = (cellMap['imageUrl'] as String?)?.trim() ?? '';
                if (status != 'done' || imageUrl.isEmpty) continue;

                final ownerId = board.id;
                final shortId = ownerId.length > 6
                    ? ownerId.substring(0, 6)
                    : ownerId;
                final ownerLabel = ownerId == userId ? 'You' : '@$shortId';

                cellMap['ownerId'] = ownerId;
                cellMap['ownerLabel'] = ownerLabel;

                completedTasks.add(cellMap);
              }
            }

            completedTasks.sort((a, b) {
              final aDate = DateTime.tryParse(
                (a['completedAt'] as String?) ?? '',
              );
              final bDate = DateTime.tryParse(
                (b['completedAt'] as String?) ?? '',
              );
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });

            if (completedTasks.isEmpty) {
              return const Center(
                child: Text(
                  'No completed tasks with images yet!\nAsk your friends to share their progress.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                // Responsive grid based on screen width
                final screenWidth = constraints.maxWidth;
                int crossAxisCount;
                double childAspectRatio;
                double spacing;
                
                if (screenWidth < 600) {
                  // Mobile: 2 columns
                  crossAxisCount = 2;
                  childAspectRatio = 0.75;
                  spacing = 12;
                } else if (screenWidth < 900) {
                  // Tablet: 3 columns
                  crossAxisCount = 3;
                  childAspectRatio = 0.8;
                  spacing = 16;
                } else {
                  // Desktop: 4 columns
                  crossAxisCount = 4;
                  childAspectRatio = 0.85;
                  spacing = 20;
                }

                return GridView.builder(
                  padding: EdgeInsets.all(spacing),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: completedTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(completedTasks[index]);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> taskData) {
    final title = taskData['title'] ?? 'Completed Task';
    final imageUrl = taskData['imageUrl'];
    final completedAt = taskData['completedAt'] as String?;
    final location = taskData['location'] ?? 'Unknown Location';
    final ownerLabel = taskData['ownerLabel'] as String? ?? 'Friend';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image with proper scaling and background
            _buildImageWithBackground(imageUrl),
            
            // Gradient overlay for text readability (top 70% only)
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
                          Colors.transparent, // fully transparent by 70%
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Content overlay
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      ownerLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Task title
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Completion info
                  Text(
                    _formatDate(completedAt),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    location,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWithBackground(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        color: _colorCache[imageUrl] ?? const Color(0xFF1A0B2E),
        child: Center(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => _buildGradientBackground(),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // Image loaded, sample colors in background
                _updatePaletteIfNeeded(imageUrl);
                return child;
              }
              return _buildGradientBackground();
            },
          ),
        ),
      );
    }
    return _buildGradientBackground();
  }

  Future<void> _updatePaletteIfNeeded(String imageUrl) async {
    if (_colorCache.containsKey(imageUrl)) return;
    
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(100, 60),
        maximumColorCount: 8,
      );
      
      Color? bgColor;
      if (palette.dominantColor != null) {
        bgColor = palette.dominantColor!.color;
      } else if (palette.vibrantColor != null) {
        bgColor = palette.vibrantColor!.color;
      } else if (palette.darkMutedColor != null) {
        bgColor = palette.darkMutedColor!.color;
      }
      
      if (bgColor != null) {
        _colorCache[imageUrl] = bgColor;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      // Ignore palette generation errors
    }
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[400]!,
            Colors.purple[400]!,
            Colors.pink[400]!,
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Recently completed';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.month}/${date.day}';
      }
    } catch (e) {
      return 'Recently completed';
    }
  }
}
