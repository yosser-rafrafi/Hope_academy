import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('attendance');

  // ─── Stream for a class on a date ────────────────────────────────────────

  Stream<List<AttendanceRecord>> streamByClassAndDate(
    String classId,
    DateTime date,
  ) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _col
        .where('classId', isEqualTo: classId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) => s.docs.map(AttendanceRecord.fromFirestore).toList());
  }

  // ─── Stream attendance for a student ─────────────────────────────────────

  Stream<List<AttendanceRecord>> streamByStudent(
    String studentId, {
    int limit = 30,
  }) {
    return _col
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AttendanceRecord.fromFirestore).toList());
  }

  // ─── Save / upsert ────────────────────────────────────────────────────────

  Future<void> saveRecord(AttendanceRecord record) async {
    // Use studentId+date as a deterministic doc id to avoid duplicates
    final docId =
        '${record.studentId}_${record.date.year}${record.date.month.toString().padLeft(2, '0')}${record.date.day.toString().padLeft(2, '0')}';
    await _col.doc(docId).set(record.toFirestore(), SetOptions(merge: true));
  }

  Future<void> saveBatch(List<AttendanceRecord> records) async {
    final batch = _db.batch();
    for (final r in records) {
      final docId =
          '${r.studentId}_${r.date.year}${r.date.month.toString().padLeft(2, '0')}${r.date.day.toString().padLeft(2, '0')}';
      batch.set(_col.doc(docId), r.toFirestore(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  Future<Map<String, int>> getMonthlyStats(
    String studentId,
    int year,
    int month,
  ) async {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    final snap = await _col
        .where('studentId', isEqualTo: studentId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            isLessThan: Timestamp.fromDate(end))
        .get();

    final counts = {
      'present': 0,
      'absent': 0,
      'late': 0,
      'excused': 0,
    };
    for (final doc in snap.docs) {
      final r = AttendanceRecord.fromFirestore(doc);
      counts[r.status.name] = (counts[r.status.name] ?? 0) + 1;
    }
    return counts;
  }
}
