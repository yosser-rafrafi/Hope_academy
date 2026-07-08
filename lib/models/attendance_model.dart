import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late, excused }

extension AttendanceStatusExt on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.excused:
        return 'Excused';
    }
  }

  static AttendanceStatus fromString(String v) =>
      AttendanceStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => AttendanceStatus.absent,
      );
}

class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final DateTime date;
  final AttendanceStatus status;
  final String? note;
  final String markedById;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.date,
    required this.status,
    this.note,
    required this.markedById,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AttendanceRecord(
      id: doc.id,
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      classId: d['classId'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AttendanceStatusExt.fromString(d['status'] ?? 'absent'),
      note: d['note'],
      markedById: d['markedById'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'studentName': studentName,
        'classId': classId,
        'date': Timestamp.fromDate(date),
        'status': status.name,
        if (note != null) 'note': note,
        'markedById': markedById,
      };
}
