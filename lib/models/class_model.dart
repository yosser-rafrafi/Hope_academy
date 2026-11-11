import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Schedule entry ───────────────────────────────────────────────────────────

class ClassSchedule {
  final String day;
  final String startTime;
  final String endTime;

  const ClassSchedule({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  factory ClassSchedule.fromMap(Map<String, dynamic> m) => ClassSchedule(
        day: m['day'] ?? '',
        startTime: m['startTime'] ?? '',
        endTime: m['endTime'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
      };

  /// e.g.  "Monday 09:00 – 10:30"
  String get display => '$day  $startTime – $endTime';

  @override
  String toString() => display;
}

// ─── Level enum ───────────────────────────────────────────────────────────────

enum ClassLevel { beginner, intermediate, advanced }

extension ClassLevelExt on ClassLevel {
  String get label {
    switch (this) {
      case ClassLevel.beginner:     return 'Beginner';
      case ClassLevel.intermediate: return 'Intermediate';
      case ClassLevel.advanced:     return 'Advanced';
    }
  }

  String get value => name;

  static ClassLevel fromString(String v) => ClassLevel.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ClassLevel.beginner,
      );
}

// ─── ClassModel ───────────────────────────────────────────────────────────────

class ClassModel {
  final String id;
  final String name;
  final ClassLevel level;
  final int capacity;
  final List<String> teacherIds;
  final List<String> studentIds;
  final ClassSchedule schedule;
  final String? room;
  final String academicYear;
  final bool isActive;
  final DateTime createdAt;

  const ClassModel({
    required this.id,
    required this.name,
    required this.level,
    required this.capacity,
    this.teacherIds = const [],
    this.studentIds = const [],
    required this.schedule,
    this.room,
    required this.academicYear,
    this.isActive = true,
    required this.createdAt,
  });

  // ── Derived ───────────────────────────────────────────────────────────────

  int get studentCount  => studentIds.length;
  int get teacherCount  => teacherIds.length;
  bool get isFull       => studentIds.length >= capacity;
  int get spotsLeft     => (capacity - studentIds.length).clamp(0, capacity);

  // ── Firestore ─────────────────────────────────────────────────────────────

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // Backwards-compat: old docs stored schedule as a plain String
    final rawSchedule = d['schedule'];
    final ClassSchedule schedule;
    if (rawSchedule is Map<String, dynamic>) {
      schedule = ClassSchedule.fromMap(rawSchedule);
    } else {
      schedule = const ClassSchedule(day: '', startTime: '', endTime: '');
    }

    return ClassModel(
      id: doc.id,
      name: d['name'] ?? '',
      level: ClassLevelExt.fromString(d['level'] ?? 'beginner'),
      capacity: (d['capacity'] as num?)?.toInt() ?? 0,
      teacherIds: List<String>.from(d['teacherIds'] ?? []),
      studentIds: List<String>.from(d['studentIds'] ?? []),
      schedule: schedule,
      room: d['room'],
      academicYear: d['academicYear'] ?? '',
      isActive: d['isActive'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'level': level.value,
        'capacity': capacity,
        'teacherIds': teacherIds,
        'studentIds': studentIds,
        'schedule': schedule.toMap(),
        if (room != null) 'room': room,
        'academicYear': academicYear,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  // ── copyWith ──────────────────────────────────────────────────────────────

  ClassModel copyWith({
    String? name,
    ClassLevel? level,
    int? capacity,
    List<String>? teacherIds,
    List<String>? studentIds,
    ClassSchedule? schedule,
    String? room,
    String? academicYear,
    bool? isActive,
  }) =>
      ClassModel(
        id: id,
        name: name ?? this.name,
        level: level ?? this.level,
        capacity: capacity ?? this.capacity,
        teacherIds: teacherIds ?? this.teacherIds,
        studentIds: studentIds ?? this.studentIds,
        schedule: schedule ?? this.schedule,
        room: room ?? this.room,
        academicYear: academicYear ?? this.academicYear,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );
}
