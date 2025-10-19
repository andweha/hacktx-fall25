import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/board_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainBoardPage extends StatefulWidget {
  const MainBoardPage({super.key});

  @override
  State<MainBoardPage> createState() => _MainBoardPageState();
}

class _MainBoardPageState extends State<MainBoardPage> {
  static const _TilePalette _greyPalette = _TilePalette(
    top: Color(0xFFDCD4BB),
    bottom: Color(0xFFB6AB90),
  );
  static const List<_TilePalette> _completedPalettes = [
    _TilePalette(top: Color(0xFFCFE7F5), bottom: Color(0xFFAAC5D9)), // blue
    _TilePalette(top: Color(0xFFCDEDE0), bottom: Color(0xFFA7CCBD)), // mint
    _TilePalette(top: Color(0xFFF7E6D4), bottom: Color(0xFFE1C4A3)), // peach
    _TilePalette(top: Color(0xFFE4DDF6), bottom: Color(0xFFBFB6D6)), // lavender
    _TilePalette(
      top: Color(0xFFF6F1D6),
      bottom: Color(0xFFD9CCA3),
    ), // light gold
    _TilePalette(top: Color(0xFFDFF2F2), bottom: Color(0xFFB8D2D1)), // aqua
  ];

  final List<String> taskDataset = [
    'Wake up before 7 AM and get out of bed immediately',
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
    'Do a 20-minute yoga or stretching session',
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

  _TilePalette _completedPaletteFor(int index, Task task) {
    final seed = task.title.hashCode ^ index;
    final paletteIndex = seed.abs() % _completedPalettes.length;
    return _completedPalettes[paletteIndex];
  }

  List<Task> _tasksFrom(List rawCells) {
    return List.generate(9, (i) {
      final m = Map<String, dynamic>.from(rawCells[i]);
      final title =
          (m['title'] as String?) ?? taskDataset[i % taskDataset.length];
      final isDone = (m['status'] as String?) == 'done';
      return Task(title: title, completed: isDone);
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
    final cell = Map<String, dynamic>.from(rawCells[index]);
    final title = (cell['title'] as String?) ?? 'Task';
    final done = (cell['status'] as String?) == 'done';

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
                child: FractionallySizedBox(
                  heightFactor: 0.7,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 28,
                          ),
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
                              const SizedBox(height: 24),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4B4034),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                done
                                    ? 'Need to change your mind?'
                                    : 'Did you finish this task?',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF7A6F62),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  icon: Icon(
                                    done
                                        ? Icons.undo
                                        : Icons.check_circle_outline,
                                  ),
                                  onPressed: () async {
                                    await BoardService.toggle(
                                      index,
                                      rawCells,
                                    ); // write to Firestore
                                    if (mounted) Navigator.pop(context);
                                  },
                                  label: Text(
                                    done ? 'Mark Incomplete' : 'Mark Complete',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: done
                                        ? const Color(0xFFB59F84)
                                        : const Color(0xFFEABF4E),
                                    foregroundColor: const Color(0xFF4B4034),
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
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFE0D9CC),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
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

        final cells = List<Map<String, dynamic>>.from(
          snap.data!.data()!['cells'],
        );
        final tasks = _tasksFrom(cells);
        final isCompleted = _isBoardCompleted(tasks);

        // reflect completion state after build, if changed
        if (isCompleted != boardCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => boardCompleted = isCompleted);
            if (isCompleted) _showCelebrationDialog();
          });
        }

        const double spacing = 18;
        const int cols = 3;

        return Scaffold(
          backgroundColor: const Color(0xFFFFFAFA),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      itemCount: tasks.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio: 0.85,
                          ),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final palette = task.completed
                            ? _completedPaletteFor(index, task)
                            : _greyPalette;
                        return _TaskTile(
                          task: task,
                          palette: palette,
                          onTap: () => _showTaskDialog(index, cells),
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
  const Task({required this.title, required this.completed});
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
    const Color textColor = Color(0xFF4B4034);
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
