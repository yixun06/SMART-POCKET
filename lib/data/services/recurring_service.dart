import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/constants.dart';
import '../../core/models/recurring_plan_model.dart';
import '../../core/models/transaction_model.dart';
import 'transaction_service.dart';

class RecurringService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TransactionService _txService = TransactionService();

  CollectionReference<Map<String, dynamic>> _plans(String uid) => _db
      .collection(AppCollections.users)
      .doc(uid)
      .collection('recurring_plans');

  CollectionReference<Map<String, dynamic>> _ledger(String uid) => _db
      .collection(AppCollections.users)
      .doc(uid)
      .collection('recurring_executions');

  CollectionReference<Map<String, dynamic>> _notifications(String uid) => _db
      .collection(AppCollections.users)
      .doc(uid)
      .collection('system_notifications');

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _computeFirstNextRunOnOrAfter({
    required DateTime startDate,
    required int intervalDays,
    required DateTime anchorDate,
  }) {
    var run = _dateOnly(startDate);
    final anchor = _dateOnly(anchorDate);
    while (run.isBefore(anchor)) {
      run = run.add(Duration(days: intervalDays));
    }
    return run;
  }

  Stream<List<RecurringPlanModel>> watchPlans(String uid) {
    return _plans(uid)
        .orderBy('nextRunAt')
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => RecurringPlanModel.fromMap(d.data(), id: d.id))
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> watchFailureNotifications(String uid) {
    return _notifications(uid)
        .where('type', isEqualTo: 'recurring_failed')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) {
          final rows = snap.docs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'title': data['title'],
              'body': data['body'],
              'createdAt': data['createdAt'],
            };
          }).toList();

          rows.sort((a, b) {
            final ad = _toDate(a['createdAt']);
            final bd = _toDate(b['createdAt']);
            return bd.compareTo(ad);
          });
          return rows;
        });
  }

  Future<void> markNotificationRead(String uid, String notificationId) async {
    if (notificationId.trim().isEmpty) return;
    await _notifications(uid).doc(notificationId).update({'read': true});
  }

  Future<void> createPlan({
    required String uid,
    required String id,
    required String type,
    required String label,
    required double amount,
    required String accountId,
    required String? toAccountId,
    required String? categoryId,
    required String? note,
    required int intervalDays,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (uid.trim().isEmpty) throw Exception('uid is empty');
    if (accountId.trim().isEmpty) throw Exception('accountId is required');
    if (amount <= 0) throw Exception('amount must be > 0');
    if (intervalDays <= 0) throw Exception('intervalDays must be > 0');

    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) throw Exception('endDate must be >= startDate');

    final t = type.toLowerCase().trim();
    if (t != 'expense' && t != 'income' && t != 'transfer') {
      throw Exception('Invalid recurring type: $type');
    }

    if (t == 'transfer') {
      if ((toAccountId ?? '').trim().isEmpty) {
        throw Exception('Transfer recurring requires toAccountId');
      }
      if (toAccountId!.trim() == accountId.trim()) {
        throw Exception('Source and destination account cannot be same');
      }
    } else {
      if ((categoryId ?? '').trim().isEmpty) {
        throw Exception('Expense/Income recurring requires categoryId');
      }
    }

    final now = DateTime.now();

    final nextRun = start;

    final plan = RecurringPlanModel(
      id: id,
      userId: uid,
      type: t,
      label: label.trim().isEmpty
          ? 'Recurring ${t.toUpperCase()}'
          : label.trim(),
      amount: amount,
      accountId: accountId.trim(),
      toAccountId: toAccountId?.trim(),
      categoryId: categoryId?.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      intervalDays: intervalDays,
      startDate: start,
      endDate: end,
      nextRunAt: nextRun,
      active: true,
      version: 1,
      createdAt: now,
      updatedAt: now,
    );

    final ref = _plans(uid).doc(id);
    await ref.set(plan.toMap());

    final check = await ref.get();
    if (!check.exists) {
      throw Exception('Recurring plan write verification failed');
    }

    debugPrint('[REC][CREATE] success path=${ref.path}');
  }

  Future<void> updatePlanFutureOnly({
    required String uid,
    required String id,
    required String type,
    required String label,
    required double amount,
    required String accountId,
    required String? toAccountId,
    required String? categoryId,
    required String? note,
    required int intervalDays,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final ref = _plans(uid).doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Recurring plan not found');

    final old = RecurringPlanModel.fromMap(snap.data() ?? {}, id: snap.id);

    if (accountId.trim().isEmpty) throw Exception('accountId is required');
    if (amount <= 0) throw Exception('amount must be > 0');
    if (intervalDays <= 0) throw Exception('intervalDays must be > 0');

    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) throw Exception('endDate must be >= startDate');

    final t = type.toLowerCase().trim();
    if (t != 'expense' && t != 'income' && t != 'transfer') {
      throw Exception('Invalid recurring type: $type');
    }

    if (t == 'transfer') {
      if ((toAccountId ?? '').trim().isEmpty) {
        throw Exception('Transfer recurring requires toAccountId');
      }
      if (toAccountId!.trim() == accountId.trim()) {
        throw Exception('Source and destination account cannot be same');
      }
    } else {
      if ((categoryId ?? '').trim().isEmpty) {
        throw Exception('Expense/Income recurring requires categoryId');
      }
    }

    final nextRun = _computeFirstNextRunOnOrAfter(
      startDate: start,
      intervalDays: intervalDays,
      anchorDate: DateTime.now(),
    );

    await ref.update({
      'type': t,
      'label': label.trim().isEmpty
          ? 'Recurring ${t.toUpperCase()}'
          : label.trim(),
      'amount': amount,
      'accountId': accountId.trim(),
      'toAccountId': toAccountId?.trim(),
      'categoryId': categoryId?.trim(),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'intervalDays': intervalDays,
      'startDate': Timestamp.fromDate(start),
      'endDate': Timestamp.fromDate(end),
      'nextRunAt': Timestamp.fromDate(nextRun),
      'version': old.version + 1,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });

    debugPrint('[REC][UPDATE] id=$id');
  }

  Future<void> deletePlan(String uid, String id) async {
    await _plans(uid).doc(id).delete();
  }

  Future<void> setPlanActive(String uid, String id, bool active) async {
    await _plans(uid).doc(id).update({
      'active': active,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> runDuePlansForDate({
    required String uid,
    required DateTime date,
  }) async {
    await runDuePlansForDateWithSummary(uid: uid, date: date);
  }

  Future<Map<String, int>> runDuePlansForDateWithSummary({
    required String uid,
    required DateTime date,
  }) async {
    final today = _dateOnly(date);
    int success = 0;
    int failed = 0;

    List<QueryDocumentSnapshot<Map<String, dynamic>>> dueDocs = [];
    try {
      final dueSnap = await _plans(uid)
          .where('active', isEqualTo: true)
          .where('nextRunAt', isLessThanOrEqualTo: Timestamp.fromDate(today))
          .get();
      dueDocs = dueSnap.docs;
    } catch (_) {
      final activeSnap = await _plans(
        uid,
      ).where('active', isEqualTo: true).get();
      dueDocs = activeSnap.docs.where((d) {
        final p = RecurringPlanModel.fromMap(d.data(), id: d.id);
        return !_dateOnly(p.nextRunAt).isAfter(today);
      }).toList();
    }

    for (final d in dueDocs) {
      final plan = RecurringPlanModel.fromMap(d.data(), id: d.id);
      var cursor = _dateOnly(plan.nextRunAt);
      final endDate = _dateOnly(plan.endDate);

      bool hasPendingFailure = false;

      while (!cursor.isAfter(today) && !cursor.isAfter(endDate)) {
        final dayKey = cursor.toIso8601String().split('T').first;
        final execKey = '${plan.id}_${dayKey}_v${plan.version}';
        final execRef = _ledger(uid).doc(execKey);

        final execSnap = await execRef.get();
        if (execSnap.exists) {
          final status = (execSnap.data()?['status'] ?? '').toString();
          if (status == 'success') {
            cursor = cursor.add(Duration(days: plan.intervalDays));
            continue;
          }
        }

        try {
          if (plan.type == 'transfer') {
            await _txService.addTransfer(
              uid: uid,
              txId: 'rtx_${DateTime.now().millisecondsSinceEpoch}_${plan.id}',
              fromAccountId: plan.accountId,
              toAccountId: plan.toAccountId ?? '',
              amount: plan.amount,
              note: (plan.note ?? '').trim().isEmpty ? plan.label : plan.note!,
              datetime: cursor,
              source: 'recurring',
            );
          } else {
            final tx = TransactionModel(
              id: 'rtx_${DateTime.now().millisecondsSinceEpoch}_${plan.id}',
              userId: uid,
              accountId: plan.accountId,
              categoryId: plan.categoryId ?? '',
              type: plan.type,
              amount: plan.amount,
              note: (plan.note ?? '').trim().isEmpty ? plan.label : plan.note!,
              source: 'recurring',
              datetime: cursor,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _txService.addTransaction(uid, tx);
          }

          await execRef.set({
            'id': execKey,
            'planId': plan.id,
            'date': Timestamp.fromDate(cursor),
            'status': 'success',
            'error': null,
            'lastTriedAt': FieldValue.serverTimestamp(),
            'createdAt': execSnap.exists
                ? (execSnap.data()?['createdAt'] ??
                      FieldValue.serverTimestamp())
                : FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          success++;
          cursor = cursor.add(Duration(days: plan.intervalDays));
        } catch (e) {
          hasPendingFailure = true;
          failed++;

          final errorText = e.toString();
          final isInsufficient = errorText.toLowerCase().contains(
            'insufficient balance',
          );

          await execRef.set({
            'id': execKey,
            'planId': plan.id,
            'date': Timestamp.fromDate(cursor),
            'status': 'failed',
            'error': errorText,
            'retryCount': FieldValue.increment(1),
            'lastTriedAt': FieldValue.serverTimestamp(),
            'createdAt': execSnap.exists
                ? (execSnap.data()?['createdAt'] ??
                      FieldValue.serverTimestamp())
                : FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await _notifications(uid).doc().set({
            'type': 'recurring_failed',
            'title': 'Auto-Deduction Failed',
            'body': isInsufficient
                ? 'Failed for ${plan.label}. Select another account with sufficient balance and save the changes.'
                : 'Failed for ${plan.label}. Check the account setup and save the changes.',
            'planId': plan.id,
            'runDate': Timestamp.fromDate(cursor),
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          break;
        }
      }

      if (!hasPendingFailure && cursor.isAfter(endDate)) {
        await d.reference.update({
          'active': false,
          'nextRunAt': Timestamp.fromDate(cursor),
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        await d.reference.update({
          'active': true,
          'nextRunAt': Timestamp.fromDate(cursor),
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    return {'success': success, 'failed': failed};
  }
}
