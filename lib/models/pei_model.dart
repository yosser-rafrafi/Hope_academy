import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Plan status ──────────────────────────────────────────────────────────────

enum PeiStatus { draft, active, completed, archived }

extension PeiStatusExt on PeiStatus {
  String get value => name;

  static PeiStatus fromString(String? v) => PeiStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => PeiStatus.draft,
      );
}

// ─── Goal domain ──────────────────────────────────────────────────────────────

enum PeiDomain {
  communication,
  social,
  academic,
  motor,
  autonomy,
  behavior,
  sensory,
  emotional,
}

extension PeiDomainExt on PeiDomain {
  String get value => name;

  /// Language-neutral; the label comes from `pei.domain.<name>`.
  String get emoji {
    switch (this) {
      case PeiDomain.communication: return '🗣️';
      case PeiDomain.social:        return '🤝';
      case PeiDomain.academic:      return '📚';
      case PeiDomain.motor:         return '🏃';
      case PeiDomain.autonomy:      return '🌟';
      case PeiDomain.behavior:      return '🧩';
      case PeiDomain.sensory:       return '🖐️';
      case PeiDomain.emotional:     return '💛';
    }
  }

  static PeiDomain fromString(String? v) => PeiDomain.values.firstWhere(
        (e) => e.name == v,
        orElse: () => PeiDomain.academic,
      );
}

// ─── Goal status ──────────────────────────────────────────────────────────────

enum GoalStatus { notStarted, inProgress, achieved, onHold }

extension GoalStatusExt on GoalStatus {
  String get value => name;

  static GoalStatus fromString(String? v) => GoalStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => GoalStatus.notStarted,
      );
}

/// Independence scale used everywhere in the PEI module (0 – 4):
/// 0 not acquired · 1 full guidance · 2 partial help · 3 verbal reminder ·
/// 4 independent. Labels come from `pei.level.<n>`.
const int kPeiMinLevel = 0;
const int kPeiMaxLevel = 4;

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

// ─── PeiGoal (embedded in the plan document) ──────────────────────────────────

class PeiGoal {
  final String id;
  final String title;
  final String? description;
  final PeiDomain domain;
  final GoalStatus status;
  final int baselineLevel;
  final int targetLevel;
  final int currentLevel;
  final DateTime? targetDate;
  final String? strategies;
  final String? criteria;
  final DateTime? lastObservedAt;
  final DateTime createdAt;

  const PeiGoal({
    required this.id,
    required this.title,
    this.description,
    this.domain = PeiDomain.academic,
    this.status = GoalStatus.notStarted,
    this.baselineLevel = 0,
    this.targetLevel = kPeiMaxLevel,
    int? currentLevel,
    this.targetDate,
    this.strategies,
    this.criteria,
    this.lastObservedAt,
    required this.createdAt,
  }) : currentLevel = currentLevel ?? baselineLevel;

  /// 0.0 – 1.0 : how far the student has travelled from baseline to target.
  double get progress {
    final span = targetLevel - baselineLevel;
    if (span <= 0) return currentLevel >= targetLevel ? 1.0 : 0.0;
    return ((currentLevel - baselineLevel) / span).clamp(0.0, 1.0);
  }

  bool get isAchieved => status == GoalStatus.achieved;

  /// Level gained since the starting point (can be negative).
  int get delta => currentLevel - baselineLevel;

  factory PeiGoal.fromMap(Map<String, dynamic> m) => PeiGoal(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        description: m['description'],
        domain: PeiDomainExt.fromString(m['domain']),
        status: GoalStatusExt.fromString(m['status']),
        baselineLevel: (m['baselineLevel'] as num?)?.toInt() ?? 0,
        targetLevel: (m['targetLevel'] as num?)?.toInt() ?? kPeiMaxLevel,
        currentLevel: (m['currentLevel'] as num?)?.toInt(),
        targetDate: _ts(m['targetDate']),
        strategies: m['strategies'],
        criteria: m['criteria'],
        lastObservedAt: _ts(m['lastObservedAt']),
        createdAt: _ts(m['createdAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'domain': domain.value,
        'status': status.value,
        'baselineLevel': baselineLevel,
        'targetLevel': targetLevel,
        'currentLevel': currentLevel,
        if (targetDate != null) 'targetDate': Timestamp.fromDate(targetDate!),
        if (strategies != null && strategies!.isNotEmpty)
          'strategies': strategies,
        if (criteria != null && criteria!.isNotEmpty) 'criteria': criteria,
        if (lastObservedAt != null)
          'lastObservedAt': Timestamp.fromDate(lastObservedAt!),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  PeiGoal copyWith({
    String? title,
    String? description,
    PeiDomain? domain,
    GoalStatus? status,
    int? baselineLevel,
    int? targetLevel,
    int? currentLevel,
    DateTime? targetDate,
    String? strategies,
    String? criteria,
    DateTime? lastObservedAt,
  }) =>
      PeiGoal(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        domain: domain ?? this.domain,
        status: status ?? this.status,
        baselineLevel: baselineLevel ?? this.baselineLevel,
        targetLevel: targetLevel ?? this.targetLevel,
        currentLevel: currentLevel ?? this.currentLevel,
        targetDate: targetDate ?? this.targetDate,
        strategies: strategies ?? this.strategies,
        criteria: criteria ?? this.criteria,
        lastObservedAt: lastObservedAt ?? this.lastObservedAt,
        createdAt: createdAt,
      );
}

// ─── PeiModel  (collection: pei_plans) ────────────────────────────────────────

class PeiModel {
  final String id;
  final String studentId;
  final String studentName;
  final String? classId;

  final String academicYear;
  final PeiStatus status;
  final DateTime startDate;
  final DateTime? reviewDate;
  final DateTime? endDate;

  final String? strengths;
  final String? needs;
  final List<String> accommodations;
  final String? familyInput;

  final List<PeiGoal> goals;

  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PeiModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.classId,
    required this.academicYear,
    this.status = PeiStatus.draft,
    required this.startDate,
    this.reviewDate,
    this.endDate,
    this.strengths,
    this.needs,
    this.accommodations = const [],
    this.familyInput,
    this.goals = const [],
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Derived ───────────────────────────────────────────────────────────────

  int get achievedCount => goals.where((g) => g.isAchieved).length;

  /// Average progress of all goals (0.0 – 1.0).
  double get overallProgress => goals.isEmpty
      ? 0
      : goals.map((g) => g.progress).reduce((a, b) => a + b) / goals.length;

  /// Days until the next review (negative = overdue). Null if no review date.
  int? get daysToReview {
    if (reviewDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final r = DateTime(reviewDate!.year, reviewDate!.month, reviewDate!.day);
    return r.difference(today).inDays;
  }

  bool get isOpen => status == PeiStatus.draft || status == PeiStatus.active;

  // ── Firestore ─────────────────────────────────────────────────────────────

  factory PeiModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PeiModel(
      id: doc.id,
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      classId: d['classId'],
      academicYear: d['academicYear'] ?? '',
      status: PeiStatusExt.fromString(d['status']),
      startDate: _ts(d['startDate']) ?? DateTime.now(),
      reviewDate: _ts(d['reviewDate']),
      endDate: _ts(d['endDate']),
      strengths: d['strengths'],
      needs: d['needs'],
      accommodations: List<String>.from(d['accommodations'] ?? const []),
      familyInput: d['familyInput'],
      goals: (d['goals'] as List<dynamic>? ?? const [])
          .map((g) => PeiGoal.fromMap(Map<String, dynamic>.from(g as Map)))
          .toList(),
      createdById: d['createdById'] ?? '',
      createdByName: d['createdByName'] ?? '',
      createdAt: _ts(d['createdAt']) ?? DateTime.now(),
      updatedAt: _ts(d['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Full document (used on creation).
  Map<String, dynamic> toFirestore() => {
        ...infoMap(),
        'studentId': studentId,
        'studentName': studentName,
        if (classId != null) 'classId': classId,
        'goals': goals.map((g) => g.toMap()).toList(),
        'createdById': createdById,
        'createdByName': createdByName,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  /// Editable "profile" fields only — never touches goals, so editing the
  /// plan header can't overwrite progress recorded by someone else.
  Map<String, dynamic> infoMap() => {
        'academicYear': academicYear,
        'status': status.value,
        'startDate': Timestamp.fromDate(startDate),
        'reviewDate':
            reviewDate == null ? null : Timestamp.fromDate(reviewDate!),
        'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
        'strengths': strengths,
        'needs': needs,
        'accommodations': accommodations,
        'familyInput': familyInput,
      };
}

// ─── PeiProgressEntry (subcollection: pei_plans/{id}/progress) ────────────────

class PeiProgressEntry {
  final String id;
  final String goalId;
  final int level;
  final String? note;
  final DateTime date;
  final String recordedById;
  final String recordedByName;
  final DateTime createdAt;

  const PeiProgressEntry({
    required this.id,
    required this.goalId,
    required this.level,
    this.note,
    required this.date,
    required this.recordedById,
    required this.recordedByName,
    required this.createdAt,
  });

  factory PeiProgressEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PeiProgressEntry(
      id: doc.id,
      goalId: d['goalId'] ?? '',
      level: (d['level'] as num?)?.toInt() ?? 0,
      note: d['note'],
      date: _ts(d['date']) ?? DateTime.now(),
      recordedById: d['recordedById'] ?? '',
      recordedByName: d['recordedByName'] ?? '',
      createdAt: _ts(d['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'goalId': goalId,
        'level': level,
        if (note != null && note!.isNotEmpty) 'note': note,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'recordedById': recordedById,
        'recordedByName': recordedByName,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
