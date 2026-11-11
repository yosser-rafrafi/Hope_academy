import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pei_model.dart';

/// Firestore access for the PEI module.
///
///   pei_plans/{planId}                    plan + goals[] (embedded)
///   pei_plans/{planId}/progress/{entryId} one observation of one goal
///
/// All queries are single-field (client-side sorting) so no composite index
/// is required — same convention as the rest of the app.
class PeiService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _plans => _db.collection('pei_plans');

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// All plans of a student, newest first.
  Stream<List<PeiModel>> streamByStudent(String studentId) {
    return _plans
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((s) {
      final list = s.docs.map(PeiModel.fromFirestore).toList();
      list.sort((a, b) => b.startDate.compareTo(a.startDate));
      return list;
    });
  }

  Stream<PeiModel?> streamPlan(String planId) {
    return _plans
        .doc(planId)
        .snapshots()
        .map((d) => d.exists ? PeiModel.fromFirestore(d) : null);
  }

  /// Observations of a plan (all goals), newest first.
  Stream<List<PeiProgressEntry>> streamProgress(String planId) {
    return _plans.doc(planId).collection('progress').snapshots().map((s) {
      final list = s.docs.map(PeiProgressEntry.fromFirestore).toList();
      list.sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  Future<List<PeiProgressEntry>> getProgress(String planId) async {
    final s = await _plans.doc(planId).collection('progress').get();
    final list = s.docs.map(PeiProgressEntry.fromFirestore).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ─── Plan CRUD ────────────────────────────────────────────────────────────

  Future<String> createPlan(PeiModel plan) async {
    final ref = await _plans.add(plan.toFirestore());
    return ref.id;
  }

  /// Updates the profile fields only (goals are left untouched).
  Future<void> updatePlanInfo(PeiModel plan) async {
    await _plans.doc(plan.id).update({
      ...plan.infoMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setStatus(String planId, PeiStatus status) async {
    await _plans.doc(planId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Goals (read-modify-write inside a transaction) ───────────────────────

  static String newGoalId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${Random().nextInt(0xFFFF).toRadixString(36)}';

  /// Adds the goal, or replaces the goal with the same id.
  Future<void> saveGoal(String planId, PeiGoal goal) async {
    final ref = _plans.doc(planId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('PEI not found');
      final goals = PeiModel.fromFirestore(snap).goals;
      final i = goals.indexWhere((g) => g.id == goal.id);
      final next = [...goals];
      if (i >= 0) {
        next[i] = goal;
      } else {
        next.add(goal);
      }
      tx.update(ref, {
        'goals': next.map((g) => g.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Removes the goal and every observation recorded for it.
  Future<void> deleteGoal(String planId, String goalId) async {
    final ref = _plans.doc(planId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final goals =
          PeiModel.fromFirestore(snap).goals.where((g) => g.id != goalId);
      tx.update(ref, {
        'goals': goals.map((g) => g.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    final entries = await ref
        .collection('progress')
        .where('goalId', isEqualTo: goalId)
        .get();
    if (entries.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in entries.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  // ─── Progress ─────────────────────────────────────────────────────────────

  /// Records an observation and refreshes the goal's current level/status in
  /// the same transaction (so list screens never need to scan the history).
  Future<void> addProgress(String planId, PeiProgressEntry entry) async {
    final planRef = _plans.doc(planId);
    final entryRef = planRef.collection('progress').doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(planRef);
      if (!snap.exists) throw Exception('PEI not found');
      final plan = PeiModel.fromFirestore(snap);

      final goals = plan.goals.map((g) {
        if (g.id != entry.goalId) return g;
        // A back-dated entry must not overwrite a more recent observation.
        final isLatest =
            g.lastObservedAt == null || !entry.date.isBefore(g.lastObservedAt!);
        if (!isLatest) return g;
        final GoalStatus status;
        if (entry.level >= g.targetLevel) {
          status = GoalStatus.achieved;
        } else if (g.status == GoalStatus.onHold) {
          status = GoalStatus.onHold;
        } else {
          status = GoalStatus.inProgress;
        }
        return g.copyWith(
          currentLevel: entry.level,
          status: status,
          lastObservedAt: entry.date,
        );
      }).toList();

      tx.set(entryRef, entry.toFirestore());
      tx.update(planRef, {
        'goals': goals.map((g) => g.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
