import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainBoardPage extends StatefulWidget {
  const MainBoardPage({super.key});

  @override
  State<MainBoardPage> createState() => _MainBoardPageState();
}

class _MainBoardPageState extends State<MainBoardPage> {
  final List<String> taskDataset = [
   'Wake up before 7 AM and get out of bed immediately', 'Meditate in silence for 15 minutes', 'Journal one full page about your current mindset', 'Read 20 pages of a nonfiction or self-growth book', 'Complete a 30-minute workout or jog 2 miles', 'Spend one hour completely offline (no phone, laptop, TV)', 'Cook a healthy meal entirely from scratch', 'Go for a 45-minute outdoor walk or hike', 'Take a cold shower and last at least 1 minute', 'Delete all unused apps on your phone', 'Organize your entire workspace or desk', 'Write down 3 goals for the next week and 1 step for each', 'Do a full cleanout of your backpack or room', 'Compliment three people genuinely', 'Spend 30 minutes learning something new', 'Donate or recycle 3 items you no longer use', 'Unsubscribe from 10 marketing emails', 'Spend the evening without any screens after 8 PM', 'Text or call a friend you haven’t spoken to in a while', 'Write a handwritten note or thank-you letter', 'Watch a documentary or educational video instead of entertainment', 'Try a new recipe and share a picture', 'Do a 20-minute yoga or stretching session', 'Write a gratitude list of 10 specific things', 'Plan your full schedule for tomorrow in detail', 'Take a picture of something that inspires you and write why', 'Write a list of 5 habits you want to break', 'Spend an hour organizing your digital files or photos', 'Cook dinner for your household', 'Listen to a podcast on personal growth or psychology', 'Read one article or paper about a new topic', 'Spend an hour in nature without headphones', 'Write 3 affirmations you actually believe', 'Skip caffeine or sugar for a day', 'Try a new form of exercise (boxing, yoga, cycling, etc.)', 'Reflect on one mistake and write what you learned from it', 'Spend an hour doing something creative (art, music, design, writing)', 'Compliment yourself in writing', 'Spend 15 minutes doing mindful breathing', 'Plan a small fun outing for the weekend', 'Write out 5-year goals and one concrete next action', 'Review your budget and record today’s spending', 'Rearrange or clean part of your room', 'Read one poem and reflect on it', 'Go a whole meal without multitasking or using screens', 'Spend 30 minutes volunteering or helping someone', 'Write one paragraph describing your ideal day', 'Go through your camera roll and delete 50 photos', 'Set your phone down for an hour and do something offline', 'Research a topic you’ve been curious about and summarize it in 3 sentences', 'Go to sleep 30 minutes earlier than usual'
  ];

  late List<Task> tasks = []; 

  bool boardCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Load saved task state
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    tasks = List.generate(
      9,
      (index) {
        final title = taskDataset[index % taskDataset.length];
        final completed = prefs.getBool('task_$index') ?? false;
        return Task(title: title, completed: completed);
      },
    );
    _checkBoardCompleted();
    setState(() {});
  }

  // Save task state
  Future<void> _saveTask(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('task_$index', tasks[index].completed);
  }

  void _showTaskDialog(int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tasks[index].title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                const Text('Did you finish this task?', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      tasks[index].completed = !tasks[index].completed; // toggle
                      _checkBoardCompleted();
                      _saveTask(index);
                    });
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    tasks[index].completed ? Icons.undo : Icons.check_circle_outline,
                  ),
                  label: Text(tasks[index].completed ? 'Mark Incomplete' : 'Mark Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tasks[index].completed ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _checkBoardCompleted() {
    List<List<Task>> grid = [
      tasks.sublist(0, 3),
      tasks.sublist(3, 6),
      tasks.sublist(6, 9),
    ];

    bool won = false;

    for (var row in grid) if (row.every((task) => task.completed)) won = true;

    for (int col = 0; col < 3; col++) {
      if (grid[0][col].completed &&
          grid[1][col].completed &&
          grid[2][col].completed) won = true;
    }

    if ((grid[0][0].completed && grid[1][1].completed && grid[2][2].completed) ||
        (grid[0][2].completed && grid[1][1].completed && grid[2][0].completed)) {
      won = true;
    }

    setState(() {
      boardCompleted = won;
    });

    if (won) _showCelebrationDialog();
  }

  void _showCelebrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.green.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.celebration, size: 70, color: Colors.green),
                const SizedBox(height: 16),
                const Text('Tasks Done Today!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 12),
                const Text('You’ve completed 3 in a row! Keep up the streak!',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    if (tasks.isEmpty) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: boardCompleted ? Colors.green.shade100 : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: boardCompleted ? Colors.green : Colors.blueAccent,
        title: Text(boardCompleted ? 'Tasks Done Today!' : 'Main Board', style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          itemCount: tasks.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return GestureDetector(
              onTap: () => _showTaskDialog(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: task.completed ? Colors.green.shade300 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
                ),
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: Text(task.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        decoration: task.completed ? TextDecoration.lineThrough : null,
                        color: task.completed ? Colors.white : Colors.black87,
                      )),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class Task {
  final String title;
  bool completed;

  Task({required this.title, this.completed = false});
}
