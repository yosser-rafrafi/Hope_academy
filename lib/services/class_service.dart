import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/class_model.dart';

class ClassService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('classes');

  static List<ClassModel> _sortByName(List<ClassModel> list) {
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// All active classes, sorted by name.
  Stream<List<ClassModel>> streamAll({bool activeOnly = true}) {
    Query q = _col;
    if (activeOnly) q = q.where('isActive', isEqualTo: true);
    return q.snapshots().map(
        (s) => _sortByName(s.docs.map(ClassModel.fromFirestore).toList()));
  }

  /// Stream a single class by ID.
  Stream<ClassModel?> streamById(String id) {
    return _col.doc(id).snapshots().map(
        (doc) => doc.exists ? ClassModel.fromFirestore(doc) : null);
  }

  /// Classes for a specific teacher, active only.
  Stream<List<ClassModel>> streamByTeacher(String teacherId) {
    return _col
        .where('teacherIds', arrayContains: teacherId)
        .snapshots()
        .map((s) => _sortByName(s.docs
            .map(ClassModel.fromFirestore)
            .where((c) => c.isActive)
            .toList()));
  }

  /// Classes for a specific academic year.
  Stream<List<ClassModel>> streamByYear(String academicYear) {
    return _col
        .where('academicYear', isEqualTo: academicYear)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => _sortByName(s.docs.map(ClassModel.fromFirestore).toList()));
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────

  Future<ClassModel?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return ClassModel.fromFirestore(doc);
  }

  // ─── Create / Update ──────────────────────────────────────────────────────

  Future<ClassModel> create(ClassModel c) async {
    final ref = await _col.add(c.toFirestore());
    final doc = await ref.get();
    return ClassModel.fromFirestore(doc);
  }

  Future<void> update(ClassModel c) async {
    await _col.doc(c.id).set(c.toFirestore(), SetOptions(merge: true));
  }

  Future<void> updateFields(String id, Map<String, dynamic> fields) async {
    await _col.doc(id).set(fields, SetOptions(merge: true));
  }

  // ─── Student enrollment ───────────────────────────────────────────────────

  Future<void> enrollStudent(String classId, String studentId) async {
    await _col.doc(classId).update({
      'studentIds': FieldValue.arrayUnion([studentId]),
    });
  }

  Future<void> unenrollStudent(String classId, String studentId) async {
    await _col.doc(classId).update({
      'studentIds': FieldValue.arrayRemove([studentId]),
    });
  }

  // ─── Teacher assignment ───────────────────────────────────────────────────

  Future<void> assignTeacher(String classId, String teacherId) async {
    await _col.doc(classId).update({
      'teacherIds': FieldValue.arrayUnion([teacherId]),
    });
  }

  Future<void> removeTeacher(String classId, String teacherId) async {
    await _col.doc(classId).update({
      'teacherIds': FieldValue.arrayRemove([teacherId]),
    });
  }

  // ─── Activate / Deactivate ────────────────────────────────────────────────

  Future<void> setActive(String id, bool isActive) async {
    await _col.doc(id).set({'isActive': isActive}, SetOptions(merge: true));
  }

  Future<void> deactivate(String id) => setActive(id, false);
  Future<void> activate(String id)   => setActive(id, true);
}
