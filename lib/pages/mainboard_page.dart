// lib/pages/mainboard_page.dart
import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/board_service.dart';
import '../services/guest_session.dart';
import '../widgets/task_dialog.dart';

class MainBoardPage extends StatefulWidget {
  const MainBoardPage({super.key});

  @override
  State<MainBoardPage> createState() => _MainBoardPageState();
}

class _MainBoardPageState extends State<MainBoardPage> {
  // Incomplete tasks - muted gray colors
  static const _TilePalette _greyPalette = _TilePalette(
    top: Color(0xFFE5E5E5),
    bottom: Color(0xFFCCCCCC),
  );

  // Completed tasks - vibrant, distinct colors
  static const List<_TilePalette> _completedPalettes = [
    _TilePalette(
      top: Color(0xFF607D8B),
      bottom: Color(0xFF455A64),
    ), // slate blue-gray
    _TilePalette(top: Color(0xFF2196F3), bottom: Color(0xFF1976D2)), // blue
    _TilePalette(top: Color(0xFFFF9800), bottom: Color(0xFFF57C00)), // orange
    _TilePalette(top: Color(0xFF9C27B0), bottom: Color(0xFF7B1FA2)), // purple
    _TilePalette(top: Color(0xFFE91E63), bottom: Color(0xFFC2185B)), // pink
    _TilePalette(top: Color(0xFF00BCD4), bottom: Color(0xFF0097A7)), // cyan
    _TilePalette(top: Color(0xFF009688), bottom: Color(0xFF00796B)), // teal
    _TilePalette(
      top: Color(0xFFFF5722),
      bottom: Color(0xFFD84315),
    ), // deep orange
  ];

  // Special color for first three-in-a-row completion
  static const _TilePalette _threeInRowPalette = _TilePalette(
    top: Color(0xFF8BC34A), // green
    bottom: Color.fromARGB(255, 31, 184, 11), // dark goldenrod
  );

  final List<String> taskDataset = [
    'Wake up before 8 AM and get out of bed immediately',
    'Do a 20-minute yoga or stretching session',
    'Meditate in silence for 15 minutes',
    'Journal one full page about your current mindset',
    'Read 20 pages of a nonfiction or self-growth book',
    'Complete a 30-minute workout or jog 2 miles',
    'Spend one hour completely offline (no phone, laptop, TV)',
    'Cook a healthy meal entirely from scratch',
    'Go for a 45-minute outdoor walk or hike',
    'Take a cold shower and last at least 1 minute',
    'Delete all unused apps on your phone',
    'Organize your entire workspace or desk',
    'Write down 3 goals for the next week and 1 step for each',
    'Do a full cleanout of your backpack or room',
    'Compliment three people genuinely',
    'Spend 30 minutes learning something new',
    'Donate or recycle 3 items you no longer use',
    'Unsubscribe from 10 marketing emails',
    'Spend the evening without any screens after 8 PM',
    'Text or call a friend you haven’t spoken to in a while',
    'Write a handwritten note or thank-you letter',
    'Watch a documentary or educational video instead of entertainment',
    'Try a new recipe and share a picture',
    'Write a gratitude list of 10 specific things',
    'Plan your full schedule for tomorrow in detail',
    'Take a picture of something that inspires you and write why',
    'Write a list of 5 habits you want to break',
    'Spend an hour organizing your digital files or photos',
    'Cook dinner for your household',
    'Listen to a podcast on personal growth or psychology',
    'Read one article or paper about a new topic',
    'Spend an hour in nature without headphones',
    'Write 3 affirmations you actually believe',
    'Skip caffeine or sugar for a day',
    'Try a new form of exercise (boxing, yoga, cycling, etc.)',
    'Reflect on one mistake and write what you learned from it',
    'Spend an hour doing something creative (art, music, design, writing)',
    'Compliment yourself in writing',
    'Spend 15 minutes doing mindful breathing',
    'Plan a small fun outing for the weekend',
    'Write out 5-year goals and one concrete next action',
    'Review your budget and record today’s spending',
    'Rearrange or clean part of your room',
    'Read one poem and reflect on it',
    'Go a whole meal without multitasking or using screens',
    'Spend 30 minutes volunteering or helping someone',
    'Write one paragraph describing your ideal day',
    'Go through your camera roll and delete 50 photos',
    'Set your phone down for an hour and do something offline',
    'Research a topic you’ve been curious about and summarize it in 3 sentences',
    'Go to sleep 30 minutes earlier than usual',
  ];

  bool boardCompleted = false;

  @override
  void initState() {
    super.initState();
    BoardService.ensureSeed(); // seed 3x3 if missing
  }

  List<int> _getFirstThreeInRow(List<Task> tasks) {
    // Get all possible three-in-a-row combinations
    final List<List<int>> allThreeInRows = [
      // Rows
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      // Columns
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      // Diagonals
      [0, 4, 8], [2, 4, 6],
    ];

    // Find all completed three-in-a-rows
    final List<List<int>> completedThreeInRows = [];
    for (final indices in allThreeInRows) {
      if (indices.every((i) => tasks[i].completed)) {
        completedThreeInRows.add(indices);
      }
    }

    if (completedThreeInRows.isEmpty) return [];

    // Find the three-in-a-row that was completed first based on timestamps
    List<int>? earliestThreeInRow;
    DateTime? earliestTime;

    for (final indices in completedThreeInRows) {
      // Get the latest completion time for this three-in-a-row
      DateTime? latestCompletionTime;
      for (final index in indices) {
        if (tasks[index].completedAt != null) {
          try {
            final completionTime = DateTime.parse(tasks[index].completedAt!);
            if (latestCompletionTime == null ||
                completionTime.isAfter(latestCompletionTime)) {
              latestCompletionTime = completionTime;
            }
          } catch (e) {
            // Skip invalid timestamps
          }
        }
      }

      // If this three-in-a-row has a valid completion time, check if it's the earliest
      if (latestCompletionTime != null) {
        if (earliestTime == null ||
            latestCompletionTime.isBefore(earliestTime)) {
          earliestTime = latestCompletionTime;
          earliestThreeInRow = indices;
        }
      }
    }

    return earliestThreeInRow ?? [];
  }

  List<_TilePalette> _calculateAllPalettes(List<Task> allTasks) {
    final firstThreeInRow = _getFirstThreeInRow(allTasks);
    final List<_TilePalette> palettes = List.filled(9, _greyPalette);
    final List<int> colorAssignments = List.filled(
      9,
      -1,
    ); // -1 means not assigned yet

    // First pass: assign gold to three-in-a-row
    for (final index in firstThreeInRow) {
      palettes[index] = _threeInRowPalette;
      colorAssignments[index] = -2; // -2 means gold (special)
    }

    // Second pass: assign colors to remaining completed tasks
    for (int i = 0; i < 9; i++) {
      if (allTasks[i].completed && colorAssignments[i] == -1) {
        // Get colors used by adjacent tiles
        final Set<int> usedColors = <int>{};

        // Check horizontal neighbors
        if (i % 3 > 0) {
          // not leftmost column
          final leftIndex = i - 1;
          if (colorAssignments[leftIndex] >= 0) {
            usedColors.add(colorAssignments[leftIndex]);
          }
        }
        if (i % 3 < 2) {
          // not rightmost column
          final rightIndex = i + 1;
          if (colorAssignments[rightIndex] >= 0) {
            usedColors.add(colorAssignments[rightIndex]);
          }
        }

        // Check vertical neighbors
        if (i >= 3) {
          // not top row
          final topIndex = i - 3;
          if (colorAssignments[topIndex] >= 0) {
            usedColors.add(colorAssignments[topIndex]);
          }
        }
        if (i < 6) {
          // not bottom row
          final bottomIndex = i + 3;
          if (colorAssignments[bottomIndex] >= 0) {
            usedColors.add(colorAssignments[bottomIndex]);
          }
        }

        // Find first available color
        final seed = allTasks[i].title.hashCode ^ i;
        int paletteIndex = seed.abs() % _completedPalettes.length;

        while (usedColors.contains(paletteIndex)) {
          paletteIndex = (paletteIndex + 1) % _completedPalettes.length;
        }

        colorAssignments[i] = paletteIndex;
        palettes[i] = _completedPalettes[paletteIndex];
      }
    }

    return palettes;
  }

  List<Task> _tasksFrom(List rawCells) {
    return List.generate(9, (i) {
      // Add bounds checking to prevent RangeError
      if (rawCells.isEmpty || i >= rawCells.length) {
        print(
          'Error: rawCells is empty or index $i is out of bounds (length: ${rawCells.length})',
        );
        return Task(
          title: taskDataset[i % taskDataset.length],
          completed: false,
          completedAt: null,
        );
      }

      final m = Map<String, dynamic>.from(rawCells[i]);
      final title =
          (m['title'] as String?) ?? taskDataset[i % taskDataset.length];
      final isDone = (m['status'] as String?) == 'done';
      final completedAt = m['completedAt'] as String?;
      return Task(title: title, completed: isDone, completedAt: completedAt);
    });
  }

  bool _isBoardCompleted(List<Task> tasks) {
    final grid = [
      tasks.sublist(0, 3),
      tasks.sublist(3, 6),
      tasks.sublist(6, 9),
    ];
    bool won = false;

    for (final row in grid) {
      if (row.every((t) => t.completed)) won = true;
    }
    for (int c = 0; c < 3; c++) {
      if (grid[0][c].completed &&
          grid[1][c].completed &&
          grid[2][c].completed) {
        won = true;
      }
    }
    if ((grid[0][0].completed &&
            grid[1][1].completed &&
            grid[2][2].completed) ||
        (grid[0][2].completed &&
            grid[1][1].completed &&
            grid[2][0].completed)) {
      won = true;
    }
    return won;
  }

  void _showTaskDialog(int index, List rawCells) {
    // Add bounds checking to prevent RangeError
    if (rawCells.isEmpty || index >= rawCells.length) {
      print(
        'Error: rawCells is empty or index $index is out of bounds (length: ${rawCells.length})',
      );
      return;
    }

    final cell = Map<String, dynamic>.from(rawCells[index]);
    final title = (cell['title'] as String?) ?? 'Task';
    final done = (cell['status'] as String?) == 'done';
    final imageUrl = cell['imageUrl'] as String?;
    final completedAt = cell['completedAt'] as String?;

    // Debug logging
    print('=== Task Dialog Debug ===');
    print('Cell index: $index');
    print('Cell data: $cell');
    print('ImageUrl from Firestore: $imageUrl');
    print('Task completed: $done');

    // Get the board reference - handle both Firebase users and guest sessions
    final user = FirebaseAuth.instance.currentUser;
    final guestId = GuestSession.isGuest ? GuestSession.getGuestId() : null;
    final boardRef = user != null
        ? FirebaseFirestore.instance.collection('boards').doc(user.uid)
        : guestId != null
        ? FirebaseFirestore.instance.collection('boards').doc(guestId)
        : null;

    Future<void> handleToggle() async {
      // 1) Simulate the toggle locally to see if board will be complete
      final simulated = List<Map<String, dynamic>>.from(rawCells);
      final newCell = Map<String, dynamic>.from(simulated[index]);
      final toggledDone = newCell['status'] != 'done';
      newCell['status'] = toggledDone ? 'done' : 'open';
      simulated[index] = newCell;

      final completedNow = _isBoardCompleted(_tasksFrom(simulated));

      // Show only on transition false -> true
      final shouldCelebrate = !boardCompleted && completedNow;

      // 2) Persist
      await BoardService.toggle(index, rawCells);

      // 3) Close this sheet first
      if (mounted) Navigator.pop(context);

      // 4) After pop animation, celebrate if needed
      if (shouldCelebrate) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (mounted) _showCelebrationDialog();
      }
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Task details',
      barrierColor: Colors.black.withOpacity(0.1),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withOpacity(0.12)),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curved),
                child: TaskDialog(
                  title: title,
                  completed: done,
                  onToggle: handleToggle,
                  onCancel: () => Navigator.pop(context),
                  imageUrl: imageUrl,
                  cellIndex: index,
                  boardRef: boardRef,
                  completedAt: completedAt,
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
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

  void _showCelebrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.celebration, size: 70, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'Tasks Done Today!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You’ve completed 3 in a row! Keep up the streak!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Awesome!'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: BoardService.stream(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final cellsData = snap.data!.data()!['cells'];
        final cells = cellsData is List
            ? List<Map<String, dynamic>>.from(cellsData)
            : <Map<String, dynamic>>[];
        final tasks = _tasksFrom(cells);
        final isCompleted = _isBoardCompleted(tasks);

        // Keep state in sync, but don't show the dialog from here.
        if (isCompleted != boardCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => boardCompleted = isCompleted);
          });
        }

        const double outerHPad = 24.0;
        const double outerVPad = 12.0;
        const double spacing = 18.0;
        const int cols = 3;
        const int rows = 3;

        return Scaffold(
          backgroundColor: const Color(0xFFFFFAFA),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: outerHPad,
                vertical: outerVPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    width: 160,
                    child: SvgPicture.asset(
                      'assets/svg/logo.svg',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      semanticsLabel: 'App logo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    boardCompleted
                        ? 'Three in a row, nice work!'
                        : 'Tap a tile once you finish the task.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF7A6F62),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Fixed-height responsive grid that always fits 3x3
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double gridW = constraints.maxWidth;
                        final double gridH = constraints.maxHeight;

                        final double tileW =
                            (gridW - spacing * (cols - 1)) / cols;
                        final double tileH =
                            (gridH - spacing * (rows - 1)) / rows;

                        final double safeTileW = tileW.clamp(
                          60.0,
                          double.infinity,
                        );
                        final double safeTileH = tileH.clamp(
                          60.0,
                          double.infinity,
                        );
                        final double childAspectRatio =
                            (safeTileW > 0 && safeTileH > 0)
                            ? safeTileW / safeTileH
                            : 1.0;

                        return GridView.builder(
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tasks.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                childAspectRatio: childAspectRatio,
                              ),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final palettes = _calculateAllPalettes(tasks);
                            return _TaskTile(
                              task: task,
                              palette: palettes[index],
                              onTap: () => _showTaskDialog(index, cells),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class Task {
  final String title;
  final bool completed;
  final String? completedAt;
  const Task({required this.title, required this.completed, this.completedAt});
}

class _TilePalette {
  final Color top;
  final Color bottom;
  const _TilePalette({required this.top, required this.bottom});
}

class _TaskTile extends StatefulWidget {
  final Task task;
  final _TilePalette palette;
  final VoidCallback onTap;

  const _TaskTile({
    required this.task,
    required this.palette,
    required this.onTap,
  });

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // Use white text for completed tasks, dark text for incomplete
    final Color textColor = widget.task.completed
        ? Colors.white
        : const Color(0xFF4B4034);
    const duration = Duration(milliseconds: 140);
    const double baseShadowOffset = 18.0;
    const double pressedShift = 10.0;

    return GestureDetector(
      onTap: () {
        _setPressed(false);
        widget.onTap();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: LayoutBuilder(
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOut,
                top: baseShadowOffset,
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: duration,
                  decoration: BoxDecoration(
                    color: widget.palette.bottom,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOut,
                top: _pressed ? pressedShift : 0,
                left: 0,
                right: 0,
                bottom: _pressed
                    ? baseShadowOffset - pressedShift
                    : baseShadowOffset,
                child: AnimatedContainer(
                  duration: duration,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.palette.top,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      widget.task.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
