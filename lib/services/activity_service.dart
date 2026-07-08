import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';
import 'user_service.dart';

class ActivityService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _col => _db.collection('activities');

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// All activities (for Admin/SubAdmin views).
  Stream<List<ActivityModel>> streamAll() {
    return _col
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ActivityModel.fromFirestore).toList());
  }

  /// Activities created by a teacher, newest first.
  Stream<List<ActivityModel>> streamByTeacher(String teacherId) {
    return _col
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((s) {
      final list = s.docs.map(ActivityModel.fromFirestore).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// Activities for a specific student, newest first.
  Stream<List<ActivityModel>> streamByStudent(String studentId) {
    return _col
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((s) {
      final list = s.docs.map(ActivityModel.fromFirestore).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  /// Activities visible to a parent (via parentIds array).
  Stream<List<ActivityModel>> streamForParent(String parentId) {
    return _col
        .where('parentIds', arrayContains: parentId)
        .where('isVisibleToParent', isEqualTo: true)
        .snapshots()
        .map((s) {
      final list = s.docs.map(ActivityModel.fromFirestore).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  // ─── Create ───────────────────────────────────────────────────────────────

  /// Create a single activity.
  /// Automatically resolves parentIds from the student if not already set.
  Future<ActivityModel> create(ActivityModel a) async {
    ActivityModel toSave = a;
    if (toSave.parentIds.isEmpty && toSave.studentId.isNotEmpty) {
      final pIds = await UserService().getParentIdsForStudent(toSave.studentId);
      toSave = toSave.copyWith(parentIds: pIds);
    }
    final ref = await _col.add(toSave.toFirestore());
    final doc = await ref.get();
    return ActivityModel.fromFirestore(doc);
  }

  /// Batch-create one activity per student (for class-wide or selection mode).
  /// Returns the list of created activities.
  Future<List<ActivityModel>> createBatch({
    required List<String> studentIds,
    required String title,
    required String description,
    required ActivityCategory category,
    required DateTime date,
    required String teacherId,
    required ActivityTargetMode targetMode,
    List<String> objectives = const [],
    int? duration,
    bool isVisibleToParent = true,
  }) async {
    final now = DateTime.now();
    final batch = _db.batch();
    final refs = <DocumentReference>[];

    final userService = UserService();

    for (final sid in studentIds) {
      final ref = _col.doc();
      refs.add(ref);
      
      // Fetch parent IDs for this student
      final pIds = await userService.getParentIdsForStudent(sid);

      final model = ActivityModel(
        id:                ref.id,
        title:             title,
        description:       description,
        category:          category,
        date:              date,
        studentId:         sid,
        targetMode:        targetMode,
        parentIds:         pIds,
        teacherId:         teacherId,
        objectives:        objectives,
        duration:          duration,
        isVisibleToParent: isVisibleToParent,
        createdAt:         now,
        updatedAt:         now,
      );
      batch.set(ref, model.toFirestore());
    }

    await batch.commit();

    // Fetch created docs
    final results = <ActivityModel>[];
    for (final ref in refs) {
      final doc = await ref.get();
      if (doc.exists) results.add(ActivityModel.fromFirestore(doc));
    }
    return results;
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  Future<void> update(ActivityModel a) async {
    await _col.doc(a.id).set(a.toFirestore(), SetOptions(merge: true));
  }

  Future<void> updateFields(String id, Map<String, dynamic> fields) async {
    await _col.doc(id).set({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> delete(String id) => _col.doc(id).delete();
}
