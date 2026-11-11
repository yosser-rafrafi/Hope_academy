import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/finance_utils.dart';
import '../models/finance_model.dart';

/// Business-rule violation; [code] maps to the translation `fin.err.<code>`.
class FinanceException implements Exception {
  final String code;
  const FinanceException(this.code);
  @override
  String toString() => 'FinanceException($code)';
}

/// Firestore access for fees, payments and salaries.
///
///   fee_charges/{id}        one invoice line for one student (paidAmount kept in sync)
///   fee_payments/{id}       one payment against one charge (+ receipt number)
///   finance_meta/counters   { receipt: n }  — receipt numbering
///   salary_records/{staff_yyyy-MM}
///
/// Single-field queries only (client-side sort) → no composite index needed.
class FinanceService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _charges => _db.collection('fee_charges');
  CollectionReference get _payments => _db.collection('fee_payments');
  CollectionReference get _salaries => _db.collection('salary_records');

  // ─── Charges ──────────────────────────────────────────────────────────────

  Stream<List<FeeCharge>> streamChargesByStudent(String studentId) => _charges
          .where('studentId', isEqualTo: studentId)
          .snapshots()
          .map((s) {
        final l = s.docs.map(FeeCharge.fromFirestore).toList();
        l.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return l;
      });

  Stream<List<FeeCharge>> streamChargesByYear(String academicYear) => _charges
      .where('academicYear', isEqualTo: academicYear)
      .snapshots()
      .map((s) => s.docs.map(FeeCharge.fromFirestore).toList());

  Future<void> addCharge(FeeCharge c) => _charges.add(c.toFirestore());

  /// Creates many charges (bulk billing). Returns how many were written.
  Future<int> addChargesBulk(List<FeeCharge> charges) async {
    for (var i = 0; i < charges.length; i += 400) {
      final batch = _db.batch();
      for (final c in charges.skip(i).take(400)) {
        batch.set(_charges.doc(), c.toFirestore());
      }
      await batch.commit();
    }
    return charges.length;
  }

  Future<void> updateCharge(FeeCharge c) => _charges.doc(c.id).update({
        ...c.editMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteCharge(String chargeId) async {
    final ref = _charges.doc(chargeId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      if (FeeCharge.fromFirestore(snap).paidAmount > 0.004) {
        throw const FinanceException('hasPayments');
      }
      tx.delete(ref);
    });
  }

  // ─── Payments ─────────────────────────────────────────────────────────────

  Stream<List<FeePayment>> streamPaymentsByStudent(String studentId) =>
      _payments.where('studentId', isEqualTo: studentId).snapshots().map((s) {
        final l = s.docs.map(FeePayment.fromFirestore).toList();
        l.sort((a, b) {
          final d = b.date.compareTo(a.date);
          return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
        });
        return l;
      });

  /// Payments whose date falls in [from, to] (inclusive days), newest first.
  Stream<List<FeePayment>> streamPaymentsBetween(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return _payments
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((s) {
      final l = s.docs.map(FeePayment.fromFirestore).toList();
      l.sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
      });
      return l;
    });
  }

  /// Records a payment atomically: validates against the remaining balance,
  /// allocates the next receipt number and updates the charge.
  Future<FeePayment> recordPayment({
    required String chargeId,
    required double amount,
    required PaymentMethod method,
    required DateTime date,
    String? reference,
    required String byId,
    required String byName,
  }) async {
    final value = roundMoney(amount);
    if (value <= 0) throw const FinanceException('amount');

    final chargeRef = _charges.doc(chargeId);
    final payRef = _payments.doc();
    final counterRef = _db.collection('finance_meta').doc('counters');
    late FeePayment result;

    await _db.runTransaction((tx) async {
      final cSnap = await tx.get(chargeRef);
      if (!cSnap.exists) throw const FinanceException('amount');
      final charge = FeeCharge.fromFirestore(cSnap);
      if (value > charge.balance + 0.005) {
        throw const FinanceException('overpay');
      }
      final kSnap = await tx.get(counterRef);
      final next = ((kSnap.data() as Map<String, dynamic>?)?['receipt'] as num?)
              ?.toInt() ??
          0;
      final no = next + 1;
      final receiptNo = 'R-${date.year}-${no.toString().padLeft(6, '0')}';

      result = FeePayment(
        id: payRef.id,
        chargeId: chargeId,
        chargeTitle: charge.title,
        studentId: charge.studentId,
        studentName: charge.studentName,
        amount: value,
        method: method,
        date: date,
        reference: reference,
        receiptNo: receiptNo,
        recordedById: byId,
        recordedByName: byName,
        createdAt: DateTime.now(),
      );
      tx.set(counterRef, {'receipt': no}, SetOptions(merge: true));
      tx.set(payRef, result.toFirestore());
      tx.update(chargeRef, {
        'paidAmount': roundMoney(charge.paidAmount + value),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return result;
  }

  /// Cancels a payment and restores the charge balance.
  Future<void> deletePayment(FeePayment p) async {
    final payRef = _payments.doc(p.id);
    final chargeRef = _charges.doc(p.chargeId);
    await _db.runTransaction((tx) async {
      final paySnap = await tx.get(payRef);
      if (!paySnap.exists) return;
      final amount = FeePayment.fromFirestore(paySnap).amount;
      final cSnap = await tx.get(chargeRef);
      if (cSnap.exists) {
        final paid = FeeCharge.fromFirestore(cSnap).paidAmount;
        tx.update(chargeRef, {
          'paidAmount': roundMoney((paid - amount).clamp(0, double.infinity).toDouble()),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.delete(payRef);
    });
  }

  // ─── Salaries ─────────────────────────────────────────────────────────────

  Stream<List<SalaryRecord>> streamSalaries(String month) => _salaries
      .where('month', isEqualTo: month)
      .snapshots()
      .map((s) => s.docs.map(SalaryRecord.fromFirestore).toList());

  Future<void> saveSalary(SalaryRecord r) =>
      _salaries.doc(r.id).set(r.toFirestore(), SetOptions(merge: true));
}
