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
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) {
      return s.docs
          .map(ActivityModel.fromFirestore)
          .where((a) => a.teacherId == teacherId)
          .toList();
    });
  }

  /// Activities for a specific student, newest first.
  Stream<List<ActivityModel>> streamByStudent(String studentId) {
    return _col
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) {
      return s.docs
          .map(ActivityModel.fromFirestore)
          .where((a) => a.studentId == studentId)
          .toList();
    });
  }

  /// Activities visible to a parent.
  /// Strategy (in order of reliability):
  /// 1. parentIds array contains parentId  (new activities)
  /// 2. parent's linkedStudentIds → match studentId  (legacy activities)
  /// 3. studentId == parentId directly (parent and student share same account)
  Stream<List<ActivityModel>> streamForParent(String parentId) async* {
    // Fetch parent document to get linkedStudentIds
    final parentDoc = await _db.collection('users').doc(parentId).get();
    final List<String> linkedStudentIds = parentDoc.exists
        ? List<String>.from(
            (parentDoc.data() as Map<String, dynamic>)['linkedStudentIds'] ?? [])
        : [];

    // Also search for students that list this parent's UID in their parentIds
    final studentSnap = await _db
        .collection('users')
        .where('parentIds', arrayContains: parentId)
        .get();
    final studentIdsFromStudentDocs =
        studentSnap.docs.map((d) => d.id).toList();

    // Merge all known student IDs — including the parent's own UID
    // (covers the case where parent and student share the same account/doc)
    final allLinkedStudentIds = <String>{
      parentId, // self — in case studentId == parentId
      ...linkedStudentIds,
      ...studentIdsFromStudentDocs,
    };

    yield* _col
        .where('isVisibleToParent', isEqualTo: true)
        .snapshots()
        .map((s) {
      final all = s.docs.map(ActivityModel.fromFirestore).toList();
      final result = all.where((a) {
        if (a.parentIds.contains(parentId)) return true;
        if (allLinkedStudentIds.contains(a.studentId)) return true;
        return false;
      }).toList();
      result.sort((a, b) => b.date.compareTo(a.date));
      return result;
    });
  }

  // ─── Create ───────────────────────────────────────────────────────────────

  /// Create a single activity.
  /// Automatically resolves parentIds from the student if not already set.
  /// Status is computed automatically from date/duration — no override needed.
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
    List<String> mediaUrls = const [],
    String? classId,
    String? className,
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
        classId:           classId,
        className:         className,
        teacherId:         teacherId,
        objectives:        objectives,
        duration:          duration,
        isVisibleToParent: isVisibleToParent,
        mediaUrls:         mediaUrls,
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
