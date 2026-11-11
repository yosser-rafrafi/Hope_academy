import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;
double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

// ─── Enums ────────────────────────────────────────────────────────────────────

/// Labels: `fin.category.<name>`
enum FeeCategory { tuition, transport, meals, materials, activities, uniform, other }

extension FeeCategoryExt on FeeCategory {
  String get emoji {
    switch (this) {
      case FeeCategory.tuition:    return '🎓';
      case FeeCategory.transport:  return '🚌';
      case FeeCategory.meals:      return '🍽️';
      case FeeCategory.materials:  return '✏️';
      case FeeCategory.activities: return '🎨';
      case FeeCategory.uniform:    return '👕';
      case FeeCategory.other:      return '📌';
    }
  }

  static FeeCategory fromString(String? v) => FeeCategory.values
      .firstWhere((e) => e.name == v, orElse: () => FeeCategory.other);
}

/// Labels: `fin.method.<key>`
enum PaymentMethod { cash, bank, card, cheque, other }

extension PaymentMethodExt on PaymentMethod {
  static PaymentMethod fromString(String? v) => PaymentMethod.values
      .firstWhere((e) => e.name == v, orElse: () => PaymentMethod.cash);
}

/// Derived, never stored. Labels: `fin.status.<name>`
enum ChargeStatus { unpaid, partial, paid, overdue }

// ─── FeeCharge  (collection: fee_charges) ─────────────────────────────────────

class FeeCharge {
  final String id;
  final String studentId;
  final String studentName;
  final String? classId;
  final String academicYear;
  final FeeCategory category;
  final String title;
  final double amount;
  final double discount;
  final double paidAmount; // maintained by FinanceService transactions
  final DateTime dueDate;
  final String? note;
  final String createdById;
  final String createdByName;
  final DateTime createdAt;

  const FeeCharge({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.classId,
    required this.academicYear,
    this.category = FeeCategory.tuition,
    required this.title,
    required this.amount,
    this.discount = 0,
    this.paidAmount = 0,
    required this.dueDate,
    this.note,
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
  });

  /// Amount actually owed after discount.
  double get due => (amount - discount).clamp(0, double.infinity).toDouble();
  double get balance => (due - paidAmount).clamp(0, double.infinity).toDouble();
  bool get isSettled => balance < 0.005;

  bool get isOverdue {
    if (isSettled) return false;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return dueDate.isBefore(today);
  }

  ChargeStatus get status {
    if (isSettled) return ChargeStatus.paid;
    if (isOverdue) return ChargeStatus.overdue;
    if (paidAmount > 0.004) return ChargeStatus.partial;
    return ChargeStatus.unpaid;
  }

  factory FeeCharge.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FeeCharge(
      id: doc.id,
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      classId: d['classId'],
      academicYear: d['academicYear'] ?? '',
      category: FeeCategoryExt.fromString(d['category']),
      title: d['title'] ?? '',
      amount: _num(d['amount']),
      discount: _num(d['discount']),
      paidAmount: _num(d['paidAmount']),
      dueDate: _ts(d['dueDate']) ?? DateTime.now(),
      note: d['note'],
      createdById: d['createdById'] ?? '',
      createdByName: d['createdByName'] ?? '',
      createdAt: _ts(d['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'studentName': studentName,
        if (classId != null) 'classId': classId,
        'academicYear': academicYear,
        'category': category.name,
        'title': title,
        'amount': amount,
        'discount': discount,
        'paidAmount': paidAmount,
        'dueDate': Timestamp.fromDate(dueDate),
        if (note != null && note!.isNotEmpty) 'note': note,
        'createdById': createdById,
        'createdByName': createdByName,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  /// Editable fields only (never touches paidAmount).
  Map<String, dynamic> editMap() => {
        'category': category.name,
        'title': title,
        'amount': amount,
        'discount': discount,
        'dueDate': Timestamp.fromDate(dueDate),
        'note': note,
      };
}

// ─── FeePayment  (collection: fee_payments) ───────────────────────────────────

class FeePayment {
  final String id;
  final String chargeId;
  final String chargeTitle;
  final String studentId;
  final String studentName;
  final double amount;
  final PaymentMethod method;
  final DateTime date;
  final String? reference;
  final String receiptNo;
  final String recordedById;
  final String recordedByName;
  final DateTime createdAt;

  const FeePayment({
    required this.id,
    required this.chargeId,
    required this.chargeTitle,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.method,
    required this.date,
    this.reference,
    required this.receiptNo,
    required this.recordedById,
    required this.recordedByName,
    required this.createdAt,
  });

  factory FeePayment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FeePayment(
      id: doc.id,
      chargeId: d['chargeId'] ?? '',
      chargeTitle: d['chargeTitle'] ?? '',
      studentId: d['studentId'] ?? '',
      studentName: d['studentName'] ?? '',
      amount: _num(d['amount']),
      method: PaymentMethodExt.fromString(d['method']),
      date: _ts(d['date']) ?? DateTime.now(),
      reference: d['reference'],
      receiptNo: d['receiptNo'] ?? '',
      recordedById: d['recordedById'] ?? '',
      recordedByName: d['recordedByName'] ?? '',
      createdAt: _ts(d['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'chargeId': chargeId,
        'chargeTitle': chargeTitle,
        'studentId': studentId,
        'studentName': studentName,
        'amount': amount,
        'method': method.name,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        if (reference != null && reference!.isNotEmpty) 'reference': reference,
        'receiptNo': receiptNo,
        'recordedById': recordedById,
        'recordedByName': recordedByName,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

// ─── SalaryRecord  (collection: salary_records, id = "<staffId>_<yyyy-MM>") ───

class SalaryRecord {
  final String id;
  final String staffId;
  final String staffName;
  final String roleLabel;
  final String month; // yyyy-MM
  final double baseSalary;
  final double bonus;
  final double deduction;
  final bool paid;
  final DateTime? paidAt;
  final String? note;
  final String recordedByName;

  const SalaryRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.roleLabel,
    required this.month,
    required this.baseSalary,
    this.bonus = 0,
    this.deduction = 0,
    this.paid = false,
    this.paidAt,
    this.note,
    this.recordedByName = '',
  });

  static String idFor(String staffId, String month) => '${staffId}_$month';

  double get net =>
      (baseSalary + bonus - deduction).clamp(0, double.infinity).toDouble();

  SalaryRecord copyWith({
    double? baseSalary,
    double? bonus,
    double? deduction,
    bool? paid,
    DateTime? paidAt,
    bool clearPaidAt = false,
    String? note,
    String? recordedByName,
  }) =>
      SalaryRecord(
        id: id,
        staffId: staffId,
        staffName: staffName,
        roleLabel: roleLabel,
        month: month,
        baseSalary: baseSalary ?? this.baseSalary,
        bonus: bonus ?? this.bonus,
        deduction: deduction ?? this.deduction,
        paid: paid ?? this.paid,
        paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
        note: note ?? this.note,
        recordedByName: recordedByName ?? this.recordedByName,
      );

  factory SalaryRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SalaryRecord(
      id: doc.id,
      staffId: d['staffId'] ?? '',
      staffName: d['staffName'] ?? '',
      roleLabel: d['roleLabel'] ?? '',
      month: d['month'] ?? '',
      baseSalary: _num(d['baseSalary']),
      bonus: _num(d['bonus']),
      deduction: _num(d['deduction']),
      paid: d['paid'] == true,
      paidAt: _ts(d['paidAt']),
      note: d['note'],
      recordedByName: d['recordedByName'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'staffId': staffId,
        'staffName': staffName,
        'roleLabel': roleLabel,
        'month': month,
        'baseSalary': baseSalary,
        'bonus': bonus,
        'deduction': deduction,
        'net': net,
        'paid': paid,
        'paidAt': paidAt == null ? null : Timestamp.fromDate(paidAt!),
        'note': note,
        'recordedByName': recordedByName,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
