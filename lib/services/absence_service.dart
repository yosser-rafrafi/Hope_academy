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
    if (updatedByRole == UserRole.student) {
      throw Exception('Les étudiants ne peuvent pas modifier les absences');
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

  /// Supprimer une absence.
  /// Admin / SubAdmin : peuvent tout supprimer.
  /// Teacher : peut supprimer une absence qu'il a lui-même enregistrée.
  Future<void> deleteAbsence(String absenceId, UserRole deletedByRole,
      {String? deletedById}) async {
    if (deletedByRole == UserRole.student) {
      throw Exception(
          'Les étudiants ne peuvent pas supprimer les absences');
    }

    // Teacher : vérifier qu'il est bien l'auteur de l'absence
    if (deletedByRole == UserRole.teacher && deletedById != null) {
      final doc = await _db.collection('absences').doc(absenceId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['recordedById'] != deletedById) {
          throw Exception(
              'Vous ne pouvez supprimer que les absences que vous avez enregistrées');
        }
      }
    }

    await _db.collection('absences').doc(absenceId).delete();
  }

  /// Suppression directe sans restriction de rôle.
  /// Utilisé pour les corrections d'appel (feuille de présence) et
  /// le remplacement d'une absence existante.
  Future<void> forceDeleteAbsence(String absenceId) async {
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
  /// Pas de orderBy Firestore → tri côté client (évite l'index composite)
  Stream<List<AbsenceModel>> streamAbsencesByStudent(String studentId) {
    return _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((s) {
          final list = s.docs.map(AbsenceModel.fromFirestore).toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  }

  /// Stream absences pour une période donnée
  /// Quand studentId est fourni : filtre uniquement sur 'date' + tri côté client
  /// (évite l'index composite studentId + date)
  Stream<List<AbsenceModel>> streamAbsencesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? studentId,
  }) {
    final normalizedStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    if (studentId != null) {
      // Filtre uniquement sur studentId, tri + filtre date côté client
      return _db
          .collection('absences')
          .where('studentId', isEqualTo: studentId)
          .snapshots()
          .map((s) {
        final list = s.docs
            .map(AbsenceModel.fromFirestore)
            .where((a) =>
                !a.date.isBefore(normalizedStart) &&
                !a.date.isAfter(normalizedEnd))
            .toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });
    }

    // Sans studentId : orderBy('date') seul → aucun index composite requis
    return _db
        .collection('absences')
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedStart))
        .where('date',
            isLessThanOrEqualTo: Timestamp.fromDate(normalizedEnd))
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AbsenceModel.fromFirestore).toList());
  }

  // ─── Get Absences (Future) ────────────────────────────────────────────────

  /// Récupérer les absences d'un étudiant
  /// Tri côté client pour éviter l'index composite
  Future<List<AbsenceModel>> getAbsencesByStudent(String studentId) async {
    final snap = await _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .get();

    final list = snap.docs.map(AbsenceModel.fromFirestore).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Récupérer une absence spécifique
  Future<AbsenceModel?> getAbsenceById(String absenceId) async {
    final doc = await _db.collection('absences').doc(absenceId).get();
    if (!doc.exists) return null;
    return AbsenceModel.fromFirestore(doc);
  }

  // ─── Statistics ───────────────────────────────────────────────────────────

  /// Compter les absences d'un étudiant pour un mois donné
  /// Filtre date côté client pour éviter l'index composite
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
        .get();

    return snap.docs
        .map(AbsenceModel.fromFirestore)
        .where((a) =>
            !a.date.isBefore(startDate) && !a.date.isAfter(endDate))
        .length;
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
        .get();

    return snap.docs
        .map(AbsenceModel.fromFirestore)
        .where((a) =>
            !a.date.isBefore(startDate) && !a.date.isAfter(endDate))
        .length;
  }

  /// Obtenir les statistiques d'absences par type pour un étudiant
  /// Filtre date côté client pour éviter les index composites
  Future<Map<AbsenceType, int>> getAbsenceStatsByType({
    required String studentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final snap = await _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .get();

    final normalizedStart = startDate != null
        ? DateTime(startDate.year, startDate.month, startDate.day)
        : null;
    final normalizedEnd = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)
        : null;

    final absences = snap.docs
        .map(AbsenceModel.fromFirestore)
        .where((a) =>
            (normalizedStart == null || !a.date.isBefore(normalizedStart)) &&
            (normalizedEnd == null || !a.date.isAfter(normalizedEnd)))
        .toList();

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
  /// Filtre date côté client pour éviter l'index composite
  Future<Map<String, int>> getMonthlyAbsences({
    required String studentId,
    required int year,
  }) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31, 23, 59, 59);

    final snap = await _db
        .collection('absences')
        .where('studentId', isEqualTo: studentId)
        .get();

    final absences = snap.docs
        .map(AbsenceModel.fromFirestore)
        .where((a) =>
            !a.date.isBefore(startDate) && !a.date.isAfter(endDate))
        .toList();

    // Initialiser tous les mois à 0
    final monthlyStats = <String, int>{};
    for (int month = 1; month <= 12; month++) {
      monthlyStats['$year-${month.toString().padLeft(2, '0')}'] = 0;
    }

    for (final absence in absences) {
      final key =
          '${absence.date.year}-${absence.date.month.toString().padLeft(2, '0')}';
      monthlyStats[key] = (monthlyStats[key] ?? 0) + 1;
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

  /// Récupérer l'absence d'un étudiant pour une date donnée (null si aucune)
  Future<AbsenceModel?> getAbsenceByStudentAndDate({
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

    if (snap.docs.isEmpty) return null;
    return AbsenceModel.fromFirestore(snap.docs.first);
  }
}
