import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/absence_model.dart';
import '../models/user_model.dart';

class AbsenceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Create Absence ───────────────────────────────────────────────────────

  /// Enregistrer une absence pour un étudiant à une date donnée
  Future<String> recordAbsence({
    required String studentId,
    required String studentName,
    required DateTime date,
    required AbsenceType type,
    String? reason,
    String? justificationUrl,
    required String recordedById,
    required String recordedByName,
    required UserRole recordedByRole,
  }) async {
    // Vérifier les permissions (pas student/parent)
    if (recordedByRole == UserRole.student) {
      throw Exception('Les étudiants ne peuvent pas enregistrer les absences');
    }

    final now = DateTime.now();
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Vérifier si une absence existe déjà pour ce jour
    final existing = await _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .where('date',
            isEqualTo: Timestamp.fromDate(normalizedDate))
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Une absence existe déjà pour cet étudiant à cette date');
    }

    final absence = AbsenceModel(
      id: '', // Sera assigné par Firestore
      studentId: studentId,
      studentName: studentName,
      date: normalizedDate,
      type: type,
      reason: reason,
      justificationUrl: justificationUrl,
      recordedById: recordedById,
      recordedByName: recordedByName,
      recordedByRole: recordedByRole.value,
      createdAt: now,
      updatedAt: now,
      parentNotified: false,
    );

    final docRef = await _db.collection('absences').add(absence.toFirestore());
    return docRef.id;
  }

  // ─── Update Absence ───────────────────────────────────────────────────────

  /// Mettre à jour une absence existante
  Future<void> updateAbsence({
    required String absenceId,
    AbsenceType? type,
    String? reason,
    String? justificationUrl,
    bool? parentNotified,
    required UserRole updatedByRole,
  }) async {
    // Vérifier les permissions
    if (updatedByRole == UserRole.student) {
      throw Exception('Les étudiants ne peuvent pas modifier les absences');
    }

    // Teachers peuvent seulement ajouter des justifications
    if (updatedByRole == UserRole.teacher) {
      if (type != null) {
        throw Exception(
            'Les enseignants ne peuvent pas modifier le type d\'absence');
      }
    }

    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (type != null) updates['type'] = type.name;
    if (reason != null) updates['reason'] = reason;
    if (justificationUrl != null) updates['justificationUrl'] = justificationUrl;
    if (parentNotified != null) updates['parentNotified'] = parentNotified;

    await _db.collection('absences').doc(absenceId).update(updates);
  }

  // ─── Delete Absence ───────────────────────────────────────────────────────

  /// Supprimer une absence (Admin et SubAdmin seulement)
  Future<void> deleteAbsence(String absenceId, UserRole deletedByRole) async {
    if (deletedByRole != UserRole.admin &&
        deletedByRole != UserRole.subAdmin) {
      throw Exception(
          'Seuls les administrateurs peuvent supprimer les absences');
    }

    await _db.collection('absences').doc(absenceId).delete();
  }

  // ─── Stream Absences ──────────────────────────────────────────────────────

  /// Stream toutes les absences (pour Admin/SubAdmin)
  Stream<List<AbsenceModel>> streamAllAbsences() {
    return _db
        .collection('absences')
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AbsenceModel.fromFirestore).toList());
  }

  /// Stream absences d'un étudiant spécifique
  Stream<List<AbsenceModel>> streamAbsencesByStudent(String studentId) {
    return _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AbsenceModel.fromFirestore).toList());
  }

  /// Stream absences pour une période donnée
  Stream<List<AbsenceModel>> streamAbsencesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? studentId,
  }) {
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    Query query = _db.collection('absences');

    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    }

    return query
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(normalizedEnd))
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AbsenceModel.fromFirestore).toList());
  }

  // ─── Get Absences (Future) ────────────────────────────────────────────────

  /// Récupérer les absences d'un étudiant
  Future<List<AbsenceModel>> getAbsencesByStudent(String studentId) async {
    final snap = await _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .get();

    return snap.docs.map(AbsenceModel.fromFirestore).toList();
  }

  /// Récupérer une absence spécifique
  Future<AbsenceModel?> getAbsenceById(String absenceId) async {
    final doc = await _db.collection('absences').doc(absenceId).get();
    if (!doc.exists) return null;
    return AbsenceModel.fromFirestore(doc);
  }

  // ─── Statistics ───────────────────────────────────────────────────────────

  /// Compter les absences d'un étudiant pour un mois donné
  Future<int> countAbsencesByMonth({
    required String studentId,
    required int year,
    required int month,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    final snap = await _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    return snap.docs.length;
  }

  /// Compter les absences d'un étudiant pour une année donnée
  Future<int> countAbsencesByYear({
    required String studentId,
    required int year,
  }) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31, 23, 59, 59);

    final snap = await _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    return snap.docs.length;
  }

  /// Obtenir les statistiques d'absences par type pour un étudiant
  Future<Map<AbsenceType, int>> getAbsenceStatsByType({
    required String studentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId);

    if (startDate != null) {
      final normalized = DateTime(startDate.year, startDate.month, startDate.day);
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalized));
    }

    if (endDate != null) {
      final normalized = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      query = query.where('date',
          isLessThanOrEqualTo: Timestamp.fromDate(normalized));
    }

    final snap = await query.get();
    final absences = snap.docs.map(AbsenceModel.fromFirestore).toList();

    final stats = <AbsenceType, int>{};
    for (final absence in absences) {
      stats[absence.type] = (stats[absence.type] ?? 0) + 1;
    }

    return stats;
  }

  /// Obtenir les statistiques globales d'absences (tous les étudiants)
  /// Pour Admin/SubAdmin seulement
  Future<Map<String, dynamic>> getGlobalAbsenceStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _db.collection('absences');

    if (startDate != null) {
      final normalized = DateTime(startDate.year, startDate.month, startDate.day);
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalized));
    }

    if (endDate != null) {
      final normalized = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      query = query.where('date',
          isLessThanOrEqualTo: Timestamp.fromDate(normalized));
    }

    final snap = await query.get();
    final absences = snap.docs.map(AbsenceModel.fromFirestore).toList();

    // Statistiques par type
    final statsByType = <AbsenceType, int>{};
    for (final absence in absences) {
      statsByType[absence.type] = (statsByType[absence.type] ?? 0) + 1;
    }

    // Étudiants avec le plus d'absences
    final studentCounts = <String, Map<String, dynamic>>{};
    for (final absence in absences) {
      if (!studentCounts.containsKey(absence.studentId)) {
        studentCounts[absence.studentId] = {
          'studentId': absence.studentId,
          'studentName': absence.studentName,
          'count': 0,
        };
      }
      studentCounts[absence.studentId]!['count'] =
          (studentCounts[absence.studentId]!['count'] as int) + 1;
    }

    final topAbsentStudents = studentCounts.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return {
      'totalAbsences': absences.length,
      'statsByType': statsByType,
      'topAbsentStudents': topAbsentStudents.take(10).toList(),
    };
  }

  /// Obtenir les absences par mois pour un étudiant (pour graphiques)
  Future<Map<String, int>> getMonthlyAbsences({
    required String studentId,
    required int year,
  }) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31, 23, 59, 59);

    final snap = await _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final absences = snap.docs.map(AbsenceModel.fromFirestore).toList();

    // Compter par mois
    final monthlyStats = <String, int>{};
    for (int month = 1; month <= 12; month++) {
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      monthlyStats[monthKey] = 0;
    }

    for (final absence in absences) {
      final monthKey =
          '${absence.date.year}-${absence.date.month.toString().padLeft(2, '0')}';
      monthlyStats[monthKey] = (monthlyStats[monthKey] ?? 0) + 1;
    }

    return monthlyStats;
  }

  // ─── Check if student is absent on specific date ─────────────────────────

  /// Vérifier si un étudiant est absent à une date donnée
  Future<bool> isStudentAbsent({
    required String studentId,
    required DateTime date,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final snap = await _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .where('date', isEqualTo: Timestamp.fromDate(normalizedDate))
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }
}
