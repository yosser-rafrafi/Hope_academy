import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityCategory {
  academic,
  communication,
  socialSkills,
  motorSkills,
  therapy,
  behavioral,
  art,
  music,
  play,
  selfCare,
  other,
}

extension ActivityCategoryExt on ActivityCategory {
  String get label {
    switch (this) {
      case ActivityCategory.academic:
        return 'Academic';
      case ActivityCategory.communication:
        return 'Communication';
      case ActivityCategory.socialSkills:
        return 'Social Skills';
      case ActivityCategory.motorSkills:
        return 'Motor Skills';
      case ActivityCategory.therapy:
        return 'Therapy';
      case ActivityCategory.behavioral:
        return 'Behavioral';
      case ActivityCategory.art:
        return 'Art';
      case ActivityCategory.music:
        return 'Music';
      case ActivityCategory.play:
        return 'Play';
      case ActivityCategory.selfCare:
        return 'Self-Care';
      case ActivityCategory.other:
        return 'Other';
    }
  }

  static ActivityCategory fromString(String v) =>
      ActivityCategory.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ActivityCategory.other,
      );
}

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

  static MoodLevel fromString(String v) => MoodLevel.values.firstWhere(
        (e) => e.name == v,
        orElse: () => MoodLevel.neutral,
      );
}

class ActivityLogModel {
  final String id;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String teacherName;
  final DateTime date;

  final ActivityCategory category;
  final String title;
  final String notes;
  final MoodLevel mood;
  final List<String> photoUrls;

  // Objectives addressed
  final List<String> objectivesAddressed;

  // AI-generated report (populated after generation)
  final String? aiReport;
  final DateTime? aiGeneratedAt;

  final DateTime createdAt;

  const ActivityLogModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.date,
    required this.category,
    required this.title,
    required this.notes,
    required this.mood,
    this.photoUrls = const [],
    this.objectivesAddressed = const [],
    this.aiReport,
    this.aiGeneratedAt,
    required this.createdAt,
  });

  factory ActivityLogModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivityLogModel(
      id: doc.id,
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      teacherId: d['teacherId'] ?? '',
      teacherName: d['teacherName'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: ActivityCategoryExt.fromString(d['category'] ?? 'other'),
      title: d['title'] ?? '',
      notes: d['notes'] ?? '',
      mood: MoodLevelExt.fromString(d['mood'] ?? 'neutral'),
      photoUrls: List<String>.from(d['photoUrls'] ?? []),
      objectivesAddressed:
          List<String>.from(d['objectivesAddressed'] ?? []),
      aiReport: d['aiReport'],
      aiGeneratedAt: (d['aiGeneratedAt'] as Timestamp?)?.toDate(),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'studentName': studentName,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'date': Timestamp.fromDate(date),
        'category': category.name,
        'title': title,
        'notes': notes,
        'mood': mood.name,
        'photoUrls': photoUrls,
        'objectivesAddressed': objectivesAddressed,
        if (aiReport != null) 'aiReport': aiReport,
        if (aiGeneratedAt != null)
          'aiGeneratedAt': Timestamp.fromDate(aiGeneratedAt!),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
