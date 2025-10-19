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

    final defaults = [
      'Wake up before 7 AM and get out of bed immediately',
      'Meditate in silence for 15 minutes',
      'Journal one full page about your current mindset',
      'Drink 8 glasses of water',
      '30 minutes of focused study',
      'Call or text a friend',
      'Read 10 pages',
      'Walk outside for 20 minutes',
      'Tidy your desk for 10 minutes',
    ];

    await _doc().set({
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'completedCount': 0,
      'cells': defaults.map((t) => {
            'title': t,
            'status': 'open',        // 'open' or 'done'
            'caption': '',
            'imageUrl': null,
            'completedAt': null,
          }).toList(),
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> stream() =>
      _doc().snapshots();

  /// Toggle a single cell and refresh summary fields.
  static Future<void> toggle(int index, List cells) async {
    final cell = Map<String, dynamic>.from(cells[index]);
    final nowDone = cell['status'] != 'done';
    cell['status'] = nowDone ? 'done' : 'open';
    cell['completedAt'] =
        nowDone ? DateTime.now().toIso8601String() : null;

    final newCells = List<Map<String, dynamic>>.from(cells);
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

  static Future<void> saveCaption(
      int index, List cells, String text) async {
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
}
