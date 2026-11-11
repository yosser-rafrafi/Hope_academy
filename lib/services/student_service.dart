import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';

class StudentService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('students');

  static List<StudentModel> _sortByName(List<StudentModel> list) {
    list.sort((a, b) {
      final last = a.lastName.compareTo(b.lastName);
      return last != 0 ? last : a.firstName.compareTo(b.firstName);
    });
    return list;
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// All active students — single field query, no composite index needed.
  Stream<List<StudentModel>> streamAll({bool activeOnly = true}) {
    Query q = activeOnly
        ? _col.where('isActive', isEqualTo: true)
        : _col;
    return q.snapshots().map(
        (s) => _sortByName(s.docs.map(StudentModel.fromFirestore).toList()));
  }

  /// Students by class — filter only, sort client-side.
  Stream<List<StudentModel>> streamByClass(String classId) {
    return _col
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((s) => _sortByName(
            s.docs.map(StudentModel.fromFirestore)
                .where((m) => m.isActive)
                .toList()));
  }

  /// Students assigned to a teacher — filter only, sort client-side.
  Stream<List<StudentModel>> streamByTeacher(String teacherId) {
    return _col
        .where('assignedTeacherIds', arrayContains: teacherId)
        .snapshots()
        .map((s) => _sortByName(
            s.docs.map(StudentModel.fromFirestore)
                .where((m) => m.isActive)
                .toList()));
  }

  /// Students linked to a parent — filter only, sort client-side.
  Stream<List<StudentModel>> streamByParent(String parentId) {
    return _col
        .where('parentIds', arrayContains: parentId)
        .snapshots()
        .map((s) => _sortByName(
            s.docs.map(StudentModel.fromFirestore)
                .where((m) => m.isActive)
                .toList()));
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<StudentModel> create(StudentModel student) async {
    final ref = await _col.add(student.toFirestore());
    final doc = await ref.get();
    return StudentModel.fromFirestore(doc);
  }

  Future<void> update(StudentModel student) async {
    await _col
        .doc(student.uid)
        .set(student.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deactivate(String id) async {
    await _col.doc(id).set({'isActive': false}, SetOptions(merge: true));
  }

  Future<StudentModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return StudentModel.fromFirestore(doc);
  }

  Future<int> getCount() async {
    final snap = await _col.where('isActive', isEqualTo: true).get();
    return snap.size;
  }
}
