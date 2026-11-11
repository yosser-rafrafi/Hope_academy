import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

enum SupportNeed {
  autism,
  speechLanguage,
  behavioral,
  occupationalTherapy,
  learningDifficulty,
  physicalDisability,
  other,
}

extension SupportNeedExt on SupportNeed {
  String get label {
    switch (this) {
      case SupportNeed.autism:
        return 'Autism Spectrum';
      case SupportNeed.speechLanguage:
        return 'Speech & Language';
      case SupportNeed.behavioral:
        return 'Behavioral Support';
      case SupportNeed.occupationalTherapy:
        return 'Occupational Therapy';
      case SupportNeed.learningDifficulty:
        return 'Learning Difficulty';
      case SupportNeed.physicalDisability:
        return 'Physical Disability';
      case SupportNeed.other:
        return 'Other';
    }
  }

  static SupportNeed fromString(String v) => SupportNeed.values.firstWhere(
        (e) => e.name == v,
        orElse: () => SupportNeed.other,
      );
}

class StudentModel extends UserModel {
  // ── Student-specific fields ───────────────────────────────────────────────

  final String classId;
  final String className;
  final List<String> assignedTeacherIds;
  final List<String> parentIds;

  // Support profile
  final List<SupportNeed> supportNeeds;
  final String? diagnosisNotes;
  final String? therapyNotes;

  // Learning objectives (free-text list)
  final List<String> learningObjectives;

  // Enrollment
  final DateTime enrolledAt;

  const StudentModel({
    // ── UserModel fields ────────────────────────────────────────────────────
    required super.uid,
    super.email = '',
    required super.firstName,
    required super.lastName,
    super.role = UserRole.student,
    super.status = UserStatus.newUser,
    super.isActive = true,
    super.birthday,
    super.cin,
    super.nationality,
    super.gender,
    super.profileImageUrl,
    super.language,
    required super.createdAt,
    super.enrollmentDate,
    super.lastLoginAt,
    super.phoneNumber,
    super.address,
    super.motherName,
    super.motherPhone,
    super.fatherName,
    super.fatherPhone,
    super.diagnoses = const [],
    super.allergies = const [],
    super.medications = const [],
    super.speciality,
    super.group,
    super.diplomas = const [],
    super.languages = const [],
    super.salary,
    super.additionalInfo,
    super.linkedStudentIds = const [],

    // ── Student-specific fields ─────────────────────────────────────────────
    required this.classId,
    required this.className,
    this.assignedTeacherIds = const [],
    this.parentIds = const [],
    this.supportNeeds = const [],
    this.diagnosisNotes,
    this.therapyNotes,
    this.learningObjectives = const [],
    required this.enrolledAt,
  });

  // ── Derived helpers ───────────────────────────────────────────────────────

  int get age {
    if (birthday == null) return 0;
    final now = DateTime.now();
    int a = now.year - birthday!.year;
    if (now.month < birthday!.month ||
        (now.month == birthday!.month && now.day < birthday!.day)) {
      a--;
    }
    return a;
  }

  // ── Firestore serialization ───────────────────────────────────────────────

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StudentModel(
      uid: doc.id,
      email: d['email'] ?? '',
      firstName: d['firstName'] ?? '',
      lastName: d['lastName'] ?? '',
      role: UserRole.student,
      status: UserStatus.fromString(d['status'] ?? 'newUser'),
      isActive: d['isActive'] ?? true,
      birthday: (d['birthday'] as Timestamp?)?.toDate() ??
          (d['dateOfBirth'] as Timestamp?)?.toDate(),
      cin: d['cin'],
      nationality: d['nationality'],
      gender: d['gender'] != null ? Gender.fromString(d['gender']) : null,
      profileImageUrl: d['profileImageUrl'] ?? d['photoUrl'],
      language: d['language'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      enrollmentDate: (d['enrollmentDate'] as Timestamp?)?.toDate(),
      lastLoginAt: (d['lastLoginAt'] as Timestamp?)?.toDate(),
      phoneNumber: d['phoneNumber'],
      address: d['address'],
      motherName: d['motherName'],
      motherPhone: d['motherPhone'],
      fatherName: d['fatherName'],
      fatherPhone: d['fatherPhone'],
      diagnoses: List<String>.from(d['diagnoses'] ?? []),
      allergies: List<String>.from(d['allergies'] ?? []),
      medications: (d['medications'] as List<dynamic>? ?? [])
          .map((m) => Medication.fromMap(m as Map<String, dynamic>))
          .toList(),
      speciality: d['speciality'],
      group: d['group'],
      diplomas: List<String>.from(d['diplomas'] ?? []),
      languages: List<String>.from(d['languages'] ?? []),
      additionalInfo: d['additionalInfo'],
      linkedStudentIds: List<String>.from(d['linkedStudentIds'] ?? []),

      // Student-specific
      classId: d['classId'] ?? '',
      className: d['className'] ?? '',
      assignedTeacherIds: List<String>.from(d['assignedTeacherIds'] ?? []),
      parentIds: List<String>.from(d['parentIds'] ?? []),
      supportNeeds: (d['supportNeeds'] as List<dynamic>? ?? [])
          .map((e) => SupportNeedExt.fromString(e.toString()))
          .toList(),
      diagnosisNotes: d['diagnosisNotes'],
      therapyNotes: d['therapyNotes'],
      learningObjectives: List<String>.from(d['learningObjectives'] ?? []),
      enrolledAt: (d['enrolledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toFirestore() => {
        ...super.toFirestore(),
        'role': UserRole.student.value,
        'classId': classId,
        'className': className,
        'assignedTeacherIds': assignedTeacherIds,
        'parentIds': parentIds,
        'supportNeeds': supportNeeds.map((e) => e.name).toList(),
        if (diagnosisNotes != null) 'diagnosisNotes': diagnosisNotes,
        if (therapyNotes != null) 'therapyNotes': therapyNotes,
        'learningObjectives': learningObjectives,
        'enrolledAt': Timestamp.fromDate(enrolledAt),
      };

  StudentModel copyWithStudent({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    UserStatus? status,
    bool? isActive,
    DateTime? birthday,
    String? cin,
    String? nationality,
    Gender? gender,
    String? profileImageUrl,
    String? language,
    DateTime? createdAt,
    DateTime? enrollmentDate,
    String? phoneNumber,
    String? address,
    String? motherName,
    String? motherPhone,
    String? fatherName,
    String? fatherPhone,
    List<String>? diagnoses,
    List<String>? allergies,
    List<Medication>? medications,
    String? speciality,
    String? group,
    List<String>? diplomas,
    List<String>? languages,
    String? additionalInfo,
    List<String>? linkedStudentIds,
    // Student-specific
    String? classId,
    String? className,
    List<String>? assignedTeacherIds,
    List<String>? parentIds,
    List<SupportNeed>? supportNeeds,
    String? diagnosisNotes,
    String? therapyNotes,
    List<String>? learningObjectives,
    bool? isActiveStudent,
    DateTime? enrolledAt,
  }) =>
      StudentModel(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        status: status ?? this.status,
        isActive: isActive ?? this.isActive,
        birthday: birthday ?? this.birthday,
        cin: cin ?? this.cin,
        nationality: nationality ?? this.nationality,
        gender: gender ?? this.gender,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        language: language ?? this.language,
        createdAt: createdAt ?? this.createdAt,
        enrollmentDate: enrollmentDate ?? this.enrollmentDate,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        address: address ?? this.address,
        motherName: motherName ?? this.motherName,
        motherPhone: motherPhone ?? this.motherPhone,
        fatherName: fatherName ?? this.fatherName,
        fatherPhone: fatherPhone ?? this.fatherPhone,
        diagnoses: diagnoses ?? this.diagnoses,
        allergies: allergies ?? this.allergies,
        medications: medications ?? this.medications,
        speciality: speciality ?? this.speciality,
        group: group ?? this.group,
        diplomas: diplomas ?? this.diplomas,
        languages: languages ?? this.languages,
        additionalInfo: additionalInfo ?? this.additionalInfo,
        linkedStudentIds: linkedStudentIds ?? this.linkedStudentIds,
        classId: classId ?? this.classId,
        className: className ?? this.className,
        assignedTeacherIds: assignedTeacherIds ?? this.assignedTeacherIds,
        parentIds: parentIds ?? this.parentIds,
        supportNeeds: supportNeeds ?? this.supportNeeds,
        diagnosisNotes: diagnosisNotes ?? this.diagnosisNotes,
        therapyNotes: therapyNotes ?? this.therapyNotes,
        learningObjectives: learningObjectives ?? this.learningObjectives,
        enrolledAt: enrolledAt ?? this.enrolledAt,
      );
}
