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

enum ActivityStatus { pending, inProgress, completed, skipped }

extension ActivityStatusExt on ActivityStatus {
  String get label {
    switch (this) {
      case ActivityStatus.pending:    return 'Pending';
      case ActivityStatus.inProgress: return 'In Progress';
      case ActivityStatus.completed:  return 'Completed';
      case ActivityStatus.skipped:    return 'Skipped';
    }
  }

  static ActivityStatus fromString(String v) =>
      ActivityStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ActivityStatus.pending,
      );
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

  // ── Teacher ───────────────────────────────────────────────────────────────
  final String teacherId;

  // ── Status & completion ───────────────────────────────────────────────────
  final ActivityStatus status;
  final double completionRate;       // 0–100
  final String? teacherNotes;
  final String? parentFeedback;

  // ── Media & metadata ──────────────────────────────────────────────────────
  final List<String> mediaUrls;
  final int? duration;               // minutes
  final List<String> objectives;
  final bool isVisibleToParent;

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
    required this.teacherId,
    this.status = ActivityStatus.pending,
    this.completionRate = 0,
    this.teacherNotes,
    this.parentFeedback,
    this.mediaUrls = const [],
    this.duration,
    this.objectives = const [],
    this.isVisibleToParent = true,
    required this.createdAt,
    required this.updatedAt,
  });

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
      teacherId:      d['teacherId'] ?? '',
      status:         ActivityStatusExt.fromString(d['status'] ?? 'pending'),
      completionRate: (d['completionRate'] as num?)?.toDouble() ?? 0,
      teacherNotes:   d['teacherNotes'],
      parentFeedback: d['parentFeedback'],
      mediaUrls:      List<String>.from(d['mediaUrls'] ?? []),
      duration:       (d['duration'] as num?)?.toInt(),
      objectives:     List<String>.from(d['objectives'] ?? []),
      isVisibleToParent: d['isVisibleToParent'] ?? true,
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
    'teacherId':        teacherId,
    'status':           status.name,
    'completionRate':   completionRate,
    if (teacherNotes   != null) 'teacherNotes':   teacherNotes,
    if (parentFeedback != null) 'parentFeedback': parentFeedback,
    'mediaUrls':        mediaUrls,
    if (duration       != null) 'duration':       duration,
    'objectives':       objectives,
    'isVisibleToParent': isVisibleToParent,
    'createdAt':        Timestamp.fromDate(createdAt),
    'updatedAt':        Timestamp.fromDate(updatedAt),
  };

  ActivityModel copyWith({
    String? title,
    String? description,
    ActivityCategory? category,
    DateTime? date,
    ActivityStatus? status,
    double? completionRate,
    String? teacherNotes,
    String? parentFeedback,
    List<String>? mediaUrls,
    int? duration,
    List<String>? objectives,
    bool? isVisibleToParent,
    List<String>? parentIds,
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
        teacherId:         teacherId,
        status:            status         ?? this.status,
        completionRate:    completionRate ?? this.completionRate,
        teacherNotes:      teacherNotes   ?? this.teacherNotes,
        parentFeedback:    parentFeedback ?? this.parentFeedback,
        mediaUrls:         mediaUrls      ?? this.mediaUrls,
        duration:          duration       ?? this.duration,
        objectives:        objectives     ?? this.objectives,
        isVisibleToParent: isVisibleToParent ?? this.isVisibleToParent,
        createdAt:         createdAt,
        updatedAt:         DateTime.now(),
      );
}
