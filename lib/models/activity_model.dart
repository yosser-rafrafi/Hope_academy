import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Category ────────────────────────────────────────────────────────────────

enum ActivityCategory {
  computerSkills,
  music,
  speechTherapy,
  skillsDevelopment,
  artAndCreativity,
  workshop,
  cookingAndLifeSkills,
  physicalEducation,
  physicalTherapy,
  sensoryIntegration,
  socialSkills,
  languages,
}

extension ActivityCategoryExt on ActivityCategory {
  String get label {
    switch (this) {
      case ActivityCategory.computerSkills:       return 'Computer Skills';
      case ActivityCategory.music:                return 'Music';
      case ActivityCategory.speechTherapy:        return 'Speech Therapy';
      case ActivityCategory.skillsDevelopment:    return 'Skills Development';
      case ActivityCategory.artAndCreativity:     return 'Art & Creativity';
      case ActivityCategory.workshop:             return 'Workshop';
      case ActivityCategory.cookingAndLifeSkills: return 'Cooking & Life Skills';
      case ActivityCategory.physicalEducation:    return 'Physical Education';
      case ActivityCategory.physicalTherapy:      return 'Physical Therapy';
      case ActivityCategory.sensoryIntegration:   return 'Sensory Integration';
      case ActivityCategory.socialSkills:         return 'Social Skills';
      case ActivityCategory.languages:            return 'Languages';
    }
  }

  String get emoji {
    switch (this) {
      case ActivityCategory.computerSkills:       return '💻';
      case ActivityCategory.music:                return '🎵';
      case ActivityCategory.speechTherapy:        return '🗣️';
      case ActivityCategory.skillsDevelopment:    return '📈';
      case ActivityCategory.artAndCreativity:     return '🎨';
      case ActivityCategory.workshop:             return '🛠️';
      case ActivityCategory.cookingAndLifeSkills: return '🍳';
      case ActivityCategory.physicalEducation:    return '⚽';
      case ActivityCategory.physicalTherapy:      return '🩺';
      case ActivityCategory.sensoryIntegration:   return '🖐️';
      case ActivityCategory.socialSkills:         return '🤝';
      case ActivityCategory.languages:            return '💬';
    }
  }

  static ActivityCategory fromString(String v) =>
      ActivityCategory.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ActivityCategory.computerSkills,
      );
}

// ─── Status ───────────────────────────────────────────────────────────────────

enum ActivityStatus { pending, inProgress, completed }

extension ActivityStatusExt on ActivityStatus {
  String get label {
    switch (this) {
      case ActivityStatus.pending:    return 'Pending';
      case ActivityStatus.inProgress: return 'In Progress';
      case ActivityStatus.completed:  return 'Completed';
    }
  }

  static ActivityStatus fromString(String v) =>
      ActivityStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ActivityStatus.pending,
      );
}

// ─── Mood ─────────────────────────────────────────────────────────────────────
// Merged in from the former `ActivityLogModel` (see MERGE_NOTES.md) — this is
// the same concept the AI report generator needs, now attached directly to
// the activity it describes instead of living in a separate, never-persisted
// model.

enum MoodLevel { excellent, good, neutral, difficult, veryDifficult }

extension MoodLevelExt on MoodLevel {
  String get label {
    switch (this) {
      case MoodLevel.excellent:
        return 'Excellent';
      case MoodLevel.good:
        return 'Good';
      case MoodLevel.neutral:
        return 'Neutral';
      case MoodLevel.difficult:
        return 'Difficult';
      case MoodLevel.veryDifficult:
        return 'Very Difficult';
    }
  }

  String get emoji {
    switch (this) {
      case MoodLevel.excellent:
        return '😊';
      case MoodLevel.good:
        return '🙂';
      case MoodLevel.neutral:
        return '😐';
      case MoodLevel.difficult:
        return '😟';
      case MoodLevel.veryDifficult:
        return '😢';
    }
  }

  static MoodLevel? fromString(String? v) {
    if (v == null) return null;
    return MoodLevel.values.firstWhere(
      (e) => e.name == v,
      orElse: () => MoodLevel.neutral,
    );
  }
}

// ─── Target mode — how the activity was created ───────────────────────────────

enum ActivityTargetMode { individual, selection, fullClass }

extension ActivityTargetModeExt on ActivityTargetMode {
  static ActivityTargetMode fromString(String v) =>
      ActivityTargetMode.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ActivityTargetMode.individual,
      );
}

// ─── ActivityModel ────────────────────────────────────────────────────────────

class ActivityModel {
  final String id;
  final String title;
  final String description;
  final ActivityCategory category;
  final DateTime date;

  // ── Target ────────────────────────────────────────────────────────────────
  final String studentId;           // UID of the target student
  final ActivityTargetMode targetMode; // how it was targeted (metadata only)
  final List<String> parentIds;     // UIDs of parents who can see this
  final String? classId;            // ID of the class (fullClass mode only)
  final String? className;          // Display name of the class (fullClass mode only)

  // ── Teacher ───────────────────────────────────────────────────────────────
  final String teacherId;

  // ── Status & completion ───────────────────────────────────────────────────
  final double concentrationRate;    // 0–100 (teacher-logged student focus)
  final String? teacherNotes;
  final String? parentFeedback;

  // ── Media & metadata ──────────────────────────────────────────────────────
  final List<String> mediaUrls;
  final int? duration;               // minutes
  final List<String> objectives;
  final bool isVisibleToParent;

  // ── Mood & AI report (merged from the former ActivityLogModel) ────────────
  final MoodLevel? mood;
  final String? aiReport;
  final DateTime? aiGeneratedAt;

  // ── Timestamps ────────────────────────────────────────────────────────────
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.studentId,
    this.targetMode = ActivityTargetMode.individual,
    this.parentIds = const [],
    this.classId,
    this.className,
    required this.teacherId,
    this.concentrationRate = 0,
    this.teacherNotes,
    this.parentFeedback,
    this.mediaUrls = const [],
    this.duration,
    this.objectives = const [],
    this.isVisibleToParent = true,
    this.mood,
    this.aiReport,
    this.aiGeneratedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Auto-computed status based on [date] and [duration].
  ///
  /// - Before start time           → pending
  /// - Within the activity window  → inProgress
  /// - After start + duration      → completed
  /// If [duration] is null we assume the window is 60 minutes.
  ActivityStatus get status {
    final now = DateTime.now();
    final windowMinutes = duration ?? 60;
    final end = date.add(Duration(minutes: windowMinutes));
    if (now.isBefore(date)) return ActivityStatus.pending;
    if (now.isAfter(end))   return ActivityStatus.completed;
    return ActivityStatus.inProgress;
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivityModel(
      id:             doc.id,
      title:          d['title'] ?? '',
      description:    d['description'] ?? '',
      category:       ActivityCategoryExt.fromString(d['category'] ?? 'computerSkills'),
      date:           (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      studentId:      d['studentId'] ?? '',
      targetMode:     ActivityTargetModeExt.fromString(d['targetMode'] ?? 'individual'),
      parentIds:      List<String>.from(d['parentIds'] ?? []),
      classId:        d['classId'],
      className:      d['className'],
      teacherId:      d['teacherId'] ?? '',
      concentrationRate: (d['concentrationRate'] as num?)?.toDouble() ?? 0,
      teacherNotes:   d['teacherNotes'],
      parentFeedback: d['parentFeedback'],
      mediaUrls:      List<String>.from(d['mediaUrls'] ?? []),
      duration:       (d['duration'] as num?)?.toInt(),
      objectives:     List<String>.from(d['objectives'] ?? []),
      isVisibleToParent: d['isVisibleToParent'] ?? true,
      mood:           MoodLevelExt.fromString(d['mood']),
      aiReport:       d['aiReport'],
      aiGeneratedAt:  (d['aiGeneratedAt'] as Timestamp?)?.toDate(),
      createdAt:      (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:      (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title':            title,
    'description':      description,
    'category':         category.name,
    'date':             Timestamp.fromDate(date),
    'studentId':        studentId,
    'targetMode':       targetMode.name,
    'parentIds':        parentIds,
    if (classId   != null) 'classId':   classId,
    if (className != null) 'className': className,
    'teacherId':        teacherId,
    'concentrationRate': concentrationRate,
    if (teacherNotes   != null) 'teacherNotes':   teacherNotes,
    if (parentFeedback != null) 'parentFeedback': parentFeedback,
    'mediaUrls':        mediaUrls,
    if (duration       != null) 'duration':       duration,
    'objectives':       objectives,
    'isVisibleToParent': isVisibleToParent,
    if (mood != null) 'mood': mood!.name,
    if (aiReport != null) 'aiReport': aiReport,
    if (aiGeneratedAt != null) 'aiGeneratedAt': Timestamp.fromDate(aiGeneratedAt!),
    'createdAt':        Timestamp.fromDate(createdAt),
    'updatedAt':        Timestamp.fromDate(updatedAt),
  };

  ActivityModel copyWith({
    String? title,
    String? description,
    ActivityCategory? category,
    DateTime? date,
    double? concentrationRate,
    String? teacherNotes,
    String? parentFeedback,
    List<String>? mediaUrls,
    int? duration,
    List<String>? objectives,
    bool? isVisibleToParent,
    List<String>? parentIds,
    String? classId,
    String? className,
    MoodLevel? mood,
    String? aiReport,
    DateTime? aiGeneratedAt,
  }) =>
      ActivityModel(
        id:                id,
        title:             title          ?? this.title,
        description:       description    ?? this.description,
        category:          category       ?? this.category,
        date:              date           ?? this.date,
        studentId:         studentId,
        targetMode:        targetMode,
        parentIds:         parentIds      ?? this.parentIds,
        classId:           classId        ?? this.classId,
        className:         className      ?? this.className,
        teacherId:         teacherId,
        concentrationRate: concentrationRate ?? this.concentrationRate,
        teacherNotes:      teacherNotes   ?? this.teacherNotes,
        parentFeedback:    parentFeedback ?? this.parentFeedback,
        mediaUrls:         mediaUrls      ?? this.mediaUrls,
        duration:          duration       ?? this.duration,
        objectives:        objectives     ?? this.objectives,
        isVisibleToParent: isVisibleToParent ?? this.isVisibleToParent,
        mood:              mood ?? this.mood,
        aiReport:          aiReport ?? this.aiReport,
        aiGeneratedAt:     aiGeneratedAt ?? this.aiGeneratedAt,
        createdAt:         createdAt,
        updatedAt:         DateTime.now(),
      );
}
