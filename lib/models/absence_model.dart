import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Absence Type ─────────────────────────────────────────────────────────────

enum AbsenceType {
  excused,      // Justifiée
  unexcused,    // Non justifiée
  sick,         // Maladie
  authorized,   // Autorisée
}

extension AbsenceTypeExt on AbsenceType {
  String get label {
    switch (this) {
      case AbsenceType.excused:
        return 'Justifiée';
      case AbsenceType.unexcused:
        return 'Non justifiée';
      case AbsenceType.sick:
        return 'Maladie';
      case AbsenceType.authorized:
        return 'Autorisée';
    }
  }

  String get emoji {
    switch (this) {
      case AbsenceType.excused:
        return '✅';
      case AbsenceType.unexcused:
        return '❌';
      case AbsenceType.sick:
        return '🤒';
      case AbsenceType.authorized:
        return '📝';
    }
  }

  static AbsenceType fromString(String v) => AbsenceType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => AbsenceType.unexcused,
      );
}

// ─── AbsenceModel ─────────────────────────────────────────────────────────────

class AbsenceModel {
  final String id;

  // ── Student info ──────────────────────────────────────────────────────────
  final String studentId;       // UID de l'étudiant absent
  final String studentName;     // Nom complet pour affichage rapide

  // ── Date (jour entier) ────────────────────────────────────────────────────
  final DateTime date;          // Date de l'absence (jour uniquement)

  // ── Type & détails ────────────────────────────────────────────────────────
  final AbsenceType type;
  final String? reason;         // Raison de l'absence
  final String? justificationUrl; // URL du justificatif (certificat médical, etc.)

  // ── Recorded by ───────────────────────────────────────────────────────────
  final String recordedById;    // UID de la personne qui a enregistré l'absence
  final String recordedByName;  // Nom pour affichage
  final String recordedByRole;  // Role (admin, subAdmin, teacher)

  // ── Timestamps ────────────────────────────────────────────────────────────
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Notifications ─────────────────────────────────────────────────────────
  final bool parentNotified;    // Les parents ont été notifiés

  const AbsenceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.date,
    this.type = AbsenceType.unexcused,
    this.reason,
    this.justificationUrl,
    required this.recordedById,
    required this.recordedByName,
    required this.recordedByRole,
    required this.createdAt,
    required this.updatedAt,
    this.parentNotified = false,
  });

  // ── Firestore ─────────────────────────────────────────────────────────────

  factory AbsenceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AbsenceModel(
      id: doc.id,
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: AbsenceTypeExt.fromString(d['type'] ?? 'unexcused'),
      reason: d['reason'],
      justificationUrl: d['justificationUrl'],
      recordedById: d['recordedById'] ?? '',
      recordedByName: d['recordedByName'] ?? '',
      recordedByRole: d['recordedByRole'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentNotified: d['parentNotified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'studentName': studentName,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'type': type.name,
        if (reason != null) 'reason': reason,
        if (justificationUrl != null) 'justificationUrl': justificationUrl,
        'recordedById': recordedById,
        'recordedByName': recordedByName,
        'recordedByRole': recordedByRole,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'parentNotified': parentNotified,
      };

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Normalise la date pour comparer uniquement jour/mois/année
  DateTime get normalizedDate =>
      DateTime(date.year, date.month, date.day);

  AbsenceModel copyWith({
    String? studentId,
    String? studentName,
    DateTime? date,
    AbsenceType? type,
    String? reason,
    String? justificationUrl,
    String? recordedById,
    String? recordedByName,
    String? recordedByRole,
    bool? parentNotified,
  }) =>
      AbsenceModel(
        id: id,
        studentId: studentId ?? this.studentId,
        studentName: studentName ?? this.studentName,
        date: date ?? this.date,
        type: type ?? this.type,
        reason: reason ?? this.reason,
        justificationUrl: justificationUrl ?? this.justificationUrl,
        recordedById: recordedById ?? this.recordedById,
        recordedByName: recordedByName ?? this.recordedByName,
        recordedByRole: recordedByRole ?? this.recordedByRole,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        parentNotified: parentNotified ?? this.parentNotified,
      );
}
