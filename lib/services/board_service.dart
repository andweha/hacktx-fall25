import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardService {
  static DocumentReference<Map<String, dynamic>> _doc() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('boards').doc(uid);
  }

  /// Create a 3x3 board if it doesn't exist.
  static Future<void> ensureSeed() async {
    final snap = await _doc().get();
    if (snap.exists) return;

    final allTasks = [
      'Wake up before 8 AM and get out of bed immediately',
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

    final random = Random();
    allTasks.shuffle(random);
    final defaults = allTasks.take(9).toList();

    await _doc().set({
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'completedCount': 0,
      'cells': defaults
          .map(
            (t) => {
              'title': t,
              'status': 'open', // 'open' or 'done'
              'caption': '',
              'imageUrl': null,
              'completedAt': null,
            },
          )
          .toList(),
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> stream() =>
      _doc().snapshots();

  /// Toggle a single cell and refresh summary fields.
  static Future<void> toggle(int index, List cells) async {
    // Get the current cell data from Firestore to preserve imageUrl
    final doc = await _doc().get();
    if (!doc.exists) return;

    final currentCells = List<Map<String, dynamic>>.from(
      (doc.data()!['cells'] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    final cell = Map<String, dynamic>.from(currentCells[index]);
    final nowDone = cell['status'] != 'done';
    cell['status'] = nowDone ? 'done' : 'open';
    cell['completedAt'] = nowDone ? DateTime.now().toIso8601String() : null;

    final newCells = List<Map<String, dynamic>>.from(currentCells);
    newCells[index] = cell;

    // 1) Write the updated cells array
    await _doc().update({'cells': newCells});

    // 2) Recompute count and bump lastUpdated
    final newCount = newCells
        .where((m) => (m['status'] as String?) == 'done')
        .length;

    await _doc().set({
      'completedCount': newCount,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveCaption(int index, List cells, String text) async {
    final cell = Map<String, dynamic>.from(cells[index]);
    cell['caption'] = text;
    final newCells = List<Map<String, dynamic>>.from(cells);
    newCells[index] = cell;
    await _doc().update({'cells': newCells});

    // Keep lastUpdated fresh on caption edits (optional)
    await _doc().set({
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveImageUrl(
    int index,
    List cells,
    String imageUrl,
  ) async {
    final cell = Map<String, dynamic>.from(cells[index]);
    cell['imageUrl'] = imageUrl;
    final newCells = List<Map<String, dynamic>>.from(cells);
    newCells[index] = cell;
    await _doc().update({'cells': newCells});

    // Keep lastUpdated fresh on image uploads
    await _doc().set({
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
