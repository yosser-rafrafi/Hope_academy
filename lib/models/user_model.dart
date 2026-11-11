import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Roles ────────────────────────────────────────────────────────────────────

enum UserRole { admin, subAdmin, teacher, student }

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.subAdmin:
        return 'Sub-Administrator';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.subAdmin:
        return 'Sub-Admin';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
    }
  }

  String get value => name;

  static UserRole fromString(String value) {
    // legacy 'parent' in Firestore maps to student
    if (value == 'parent') return UserRole.student;
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.student,
    );
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  bool get isAdmin => this == UserRole.admin;
  bool get isSubAdmin => this == UserRole.subAdmin || this == UserRole.admin;
  bool get isTeacher => this == UserRole.teacher;
  bool get isStudent => this == UserRole.student;

  bool get canManageUsers =>
      this == UserRole.admin || this == UserRole.subAdmin;
  bool get canViewSalaries => this == UserRole.admin;
  bool get canAccessSettings => this == UserRole.admin;
  bool get canViewGlobalStats => this == UserRole.admin;

  bool canCreateRole(UserRole targetRole) {
    if (this == UserRole.admin) return true;
    if (this == UserRole.subAdmin) {
      return targetRole == UserRole.teacher ||
          targetRole == UserRole.student;
    }
    return false;
  }
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum UserStatus {
  newUser,
  notStarted,
  inProgress,
  holding,
  completed,
  blocked;

  String get label {
    switch (this) {
      case UserStatus.newUser:
        return 'New';
      case UserStatus.notStarted:
        return 'Not Started';
      case UserStatus.inProgress:
        return 'In Progress';
      case UserStatus.holding:
        return 'Holding';
      case UserStatus.completed:
        return 'Completed';
      case UserStatus.blocked:
        return 'Blocked';
    }
  }

  String get value => name;

  static UserStatus fromString(String value) {
    return UserStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => UserStatus.newUser,
    );
  }
}

enum Gender {
  male,
  female,
  other;

  String get label {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }

  String get value => name;

  static Gender fromString(String value) {
    return Gender.values.firstWhere(
      (g) => g.name == value,
      orElse: () => Gender.other,
    );
  }
}

// ─── Medication dosage model ──────────────────────────────────────────────────

class Medication {
  final String name;
  final String dosage;
  final String? frequency;
  final String? notes;

  const Medication({
    required this.name,
    required this.dosage,
    this.frequency,
    this.notes,
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'dosage': dosage,
        if (frequency != null) 'frequency': frequency,
        if (notes != null) 'notes': notes,
      };
}

// ─── UserModel ────────────────────────────────────────────────────────────────

class UserModel {
  // ── Identity ──────────────────────────────────────────────────────────────
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final DateTime? birthday;
  final String? cin; // National ID card number
  final String? nationality;
  final Gender? gender;
  final String? profileImageUrl;
  final String? language; // preferred UI language

  // ── Role & Status ─────────────────────────────────────────────────────────
  final UserRole role;
  final UserStatus status;
  final bool isActive;

  // ── Dates ─────────────────────────────────────────────────────────────────
  final DateTime createdAt;
  final DateTime? enrollmentDate;
  final DateTime? lastLoginAt;

  // ── Contact ───────────────────────────────────────────────────────────────
  final String? phoneNumber;
  final String? address;

  // ── Family ────────────────────────────────────────────────────────────────
  final String? motherName;
  final String? motherPhone;
  final String? fatherName;
  final String? fatherPhone;

  // ── Medical ───────────────────────────────────────────────────────────────
  final List<String> diagnoses;       // list of diagnosis labels
  final List<String> allergies;       // list of allergy labels
  final List<Medication> medications; // name + dosage pairs

  // ── Academic ──────────────────────────────────────────────────────────────
  final String? speciality;
  final String? group;        // applies to teachers and students
  final List<String> diplomas;
  final List<String> languages; // spoken/taught languages

  // ── Employment (admin/teacher) ────────────────────────────────────────────
  final double? salary;

  // ── Misc ──────────────────────────────────────────────────────────────────
  final String? additionalInfo;

  // ── Legacy: linked students for parents ──────────────────────────────────
  final List<String> linkedStudentIds;

  const UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.status = UserStatus.newUser,
    this.isActive = true,
    this.birthday,
    this.cin,
    this.nationality,
    this.gender,
    this.profileImageUrl,
    this.language,
    required this.createdAt,
    this.enrollmentDate,
    this.lastLoginAt,
    this.phoneNumber,
    this.address,
    this.motherName,
    this.motherPhone,
    this.fatherName,
    this.fatherPhone,
    this.diagnoses = const [],
    this.allergies = const [],
    this.medications = const [],
    this.speciality,
    this.group,
    this.diplomas = const [],
    this.languages = const [],
    this.salary,
    this.additionalInfo,
    this.linkedStudentIds = const [],
  });

  // ── Derived helpers ───────────────────────────────────────────────────────

  String get fullName => '$firstName $lastName';

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  // ── Firestore serialization ───────────────────────────────────────────────

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      role: UserRoleExtension.fromString(data['role'] ?? 'parent'),
      status: UserStatus.fromString(data['status'] ?? 'newUser'),
      isActive: data['isActive'] ?? true,
      birthday: (data['birthday'] as Timestamp?)?.toDate(),
      cin: data['cin'],
      nationality: data['nationality'],
      gender: data['gender'] != null
          ? Gender.fromString(data['gender'])
          : null,
      profileImageUrl: data['profileImageUrl'],
      language: data['language'],
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      enrollmentDate: (data['enrollmentDate'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      phoneNumber: data['phoneNumber'],
      address: data['address'],
      motherName: data['motherName'],
      motherPhone: data['motherPhone'],
      fatherName: data['fatherName'],
      fatherPhone: data['fatherPhone'],
      diagnoses: List<String>.from(data['diagnoses'] ?? []),
      allergies: List<String>.from(data['allergies'] ?? []),
      medications: (data['medications'] as List<dynamic>? ?? [])
          .map((m) => Medication.fromMap(m as Map<String, dynamic>))
          .toList(),
      speciality: data['speciality'],
      group: data['group'],
      diplomas: List<String>.from(data['diplomas'] ?? []),
      languages: List<String>.from(data['languages'] ?? []),
      salary: (data['salary'] as num?)?.toDouble(),
      additionalInfo: data['additionalInfo'],
      linkedStudentIds: List<String>.from(data['linkedStudentIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.value,
      'status': status.value,
      'isActive': isActive,
      if (birthday != null) 'birthday': Timestamp.fromDate(birthday!),
      if (cin != null) 'cin': cin,
      if (nationality != null) 'nationality': nationality,
      if (gender != null) 'gender': gender!.value,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      if (language != null) 'language': language,
      'createdAt': Timestamp.fromDate(createdAt),
      if (enrollmentDate != null)
        'enrollmentDate': Timestamp.fromDate(enrollmentDate!),
      if (lastLoginAt != null)
        'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (address != null) 'address': address,
      if (motherName != null) 'motherName': motherName,
      if (motherPhone != null) 'motherPhone': motherPhone,
      if (fatherName != null) 'fatherName': fatherName,
      if (fatherPhone != null) 'fatherPhone': fatherPhone,
      'diagnoses': diagnoses,
      'allergies': allergies,
      'medications': medications.map((m) => m.toMap()).toList(),
      if (speciality != null) 'speciality': speciality,
      if (group != null) 'group': group,
      'diplomas': diplomas,
      'languages': languages,
      if (salary != null) 'salary': salary,
      if (additionalInfo != null) 'additionalInfo': additionalInfo,
      'linkedStudentIds': linkedStudentIds,
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  UserModel copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    UserRole? role,
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
    DateTime? lastLoginAt,
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
    double? salary,
    String? additionalInfo,
    List<String>? linkedStudentIds,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
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
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
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
      salary: salary ?? this.salary,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      linkedStudentIds: linkedStudentIds ?? this.linkedStudentIds,
    );
  }
}
