import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Helper: sort list by lastName then firstName ─────────────────────────
  static List<UserModel> _sortByName(List<UserModel> list) {
    list.sort((a, b) {
      final last = a.lastName.compareTo(b.lastName);
      return last != 0 ? last : a.firstName.compareTo(b.firstName);
    });
    return list;
  }

  // ─── Stream all users (no index needed — single orderBy) ─────────────────
  Stream<List<UserModel>> streamAllUsers() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(UserModel.fromFirestore).toList());
  }

  /// SubAdmin: only Teachers and Students, sorted client-side (avoids composite index)
  Stream<List<UserModel>> streamUsersForSubAdmin() {
    return _db
        .collection('users')
        .where('role', whereIn: ['teacher', 'student'])
        .snapshots()
        .map((s) => _sortByName(s.docs.map(UserModel.fromFirestore).toList()));
  }

  // ─── Stream users by role, sorted client-side ────────────────────────────
  Stream<List<UserModel>> streamUsersByRole(UserRole role) {
    return _db
        .collection('users')
        .where('role', isEqualTo: role.value)
        .snapshots()
        .map((s) => _sortByName(s.docs.map(UserModel.fromFirestore).toList()));
  }

  // ─── Fetch single user ────────────────────────────────────────────────────
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> streamUserById(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // ─── Fetch parents for a student ──────────────────────────────────────────
  Future<List<String>> getParentIdsForStudent(String studentId) async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'parent')
        .where('linkedStudentIds', arrayContains: studentId)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  // ─── Create / Update ──────────────────────────────────────────────────────
  Future<void> updateUser(UserModel user) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    await _db
        .collection('users')
        .doc(uid)
        .set(fields, SetOptions(merge: true));
  }

  // ─── Toggle active status ─────────────────────────────────────────────────
  Future<void> toggleUserActive(String uid, bool isActive) async {
    await _db.collection('users').doc(uid).set(
      {'isActive': isActive},
      SetOptions(merge: true),
    );
  }

  Future<void> deactivateUser(String uid) => toggleUserActive(uid, false);
  Future<void> activateUser(String uid)   => toggleUserActive(uid, true);

  // ─── Delete ───────────────────────────────────────────────────────────────
  /// Soft delete — keeps the document but marks it inactive/deleted.
  Future<void> softDeleteUser(String uid) async {
    await _db.collection('users').doc(uid).set({
      'isActive': false,
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Hard delete — removes the Firestore document entirely.
  Future<void> hardDeleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  // ─── Count users by role ──────────────────────────────────────────────────
  Future<Map<UserRole, int>> getUserCountByRole() async {
    final snap = await _db.collection('users').get();
    final counts = {
      UserRole.admin: 0,
      UserRole.subAdmin: 0,
      UserRole.teacher: 0,
      UserRole.student: 0,
    };
    for (final doc in snap.docs) {
      final role = UserRoleExtension.fromString(
        (doc.data()['role'] as String?) ?? 'student',
      );
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }
}
