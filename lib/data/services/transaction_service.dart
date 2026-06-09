import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/constants.dart';
import '../../core/models/transaction_model.dart';

class TransactionEditUndoPayload {
  final String txId;
  final Map<String, dynamic> previousTxData;

  const TransactionEditUndoPayload({
    required this.txId,
    required this.previousTxData,
  });
}

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tx(String uid) => _db
      .collection(AppCollections.users)
      .doc(uid)
      .collection(AppCollections.transactions);

  CollectionReference<Map<String, dynamic>> _accounts(String uid) => _db
      .collection(AppCollections.users)
      .doc(uid)
      .collection(AppCollections.accounts);

  Future<void> _ensureDefaultCash(String uid) async {
    final ref = _accounts(uid).doc('default_cash');
    await ref.set({
      CommonFields.id: 'default_cash',
      CommonFields.userId: uid,
      AccountFields.name: 'Cash',
      AccountFields.type: 'cash',
      AccountFields.isLiquid: true,
      AccountFields.balance: FieldValue.increment(0),
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  DateTime _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.now();
  }

  String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Map<String, dynamic> _txToMap(TransactionModel t) {
    return {
      CommonFields.id: t.id,
      CommonFields.userId: t.userId,
      TransactionFields.accountId: t.accountId,
      TransactionFields.categoryId: t.categoryId,
      TransactionFields.type: t.type,
      TransactionFields.amount: t.amount,
      TransactionFields.note: t.note,
      TransactionFields.source: t.source,
      TransactionFields.datetime: Timestamp.fromDate(t.datetime),
      CommonFields.createdAt: Timestamp.fromDate(t.createdAt),
      CommonFields.updatedAt: Timestamp.fromDate(t.updatedAt),
      if (t.splitDetails != null)
        TransactionFields.splitDetails: t.splitDetails,
      if (t.splitDetails != null) TransactionFields.splits: t.splitDetails,
    };
  }

  bool isTransientFirestoreError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('cloud_firestore/unavailable') ||
        msg.contains('cloud_firestore/unknown') ||
        msg.contains('[cloud_firestore/unknown]') ||
        msg.contains('unavailable');
  }

  Map<String, dynamic> _toListItem(Map<String, dynamic> m, String fallbackId) {
    final dt = _toDate(m[TransactionFields.datetime]);

    final rawCategoryId =
        (m[TransactionFields.categoryId] ??
                m['category_id'] ??
                m['categoryId'] ??
                m['category'] ??
                '')
            .toString();

    return {
      'id': (m[CommonFields.id] ?? fallbackId).toString(),
      'type': (m[TransactionFields.type] ?? '').toString(),
      'amount': _toDouble(m[TransactionFields.amount]),
      'note': (m[TransactionFields.note] ?? '').toString(),
      'categoryId': rawCategoryId,
      'category': rawCategoryId,
      'date': _fmtDateTime(dt),
      'datetime': dt,
      'accountId': (m[TransactionFields.accountId] ?? '').toString(),
      'toAccountId': (m[TransactionFields.toAccountId] ?? '').toString(),
      'source': (m[TransactionFields.source] ?? '').toString(),
      'splitDetails':
          m[TransactionFields.splits] ?? m[TransactionFields.splitDetails],
    };
  }

  Map<String, double> _parseSplitMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, double>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      final value = _toDouble(entry.value);
      if (value <= 0) continue;
      out[key] = value;
    }
    return out;
  }

  Map<String, double> _effectFromTx(Map<String, dynamic> tx) {
    final type = (tx[TransactionFields.type] ?? '').toString();
    final amount = _toDouble(tx[TransactionFields.amount]);
    final accountId = (tx[TransactionFields.accountId] ?? '').toString();
    final toAccountId = (tx[TransactionFields.toAccountId] ?? '').toString();
    final split = _parseSplitMap(
      tx[TransactionFields.splits] ?? tx[TransactionFields.splitDetails],
    );
    final effect = <String, double>{};

    if (type == 'transfer') {
      if (accountId.isNotEmpty) {
        effect[accountId] = (effect[accountId] ?? 0) - amount;
      }
      if (toAccountId.isNotEmpty) {
        effect[toAccountId] = (effect[toAccountId] ?? 0) + amount;
      }
      return effect;
    }

    final sign = type == 'income' ? 1.0 : -1.0;
    if (split.isNotEmpty) {
      for (final e in split.entries) {
        effect[e.key] = (effect[e.key] ?? 0) + sign * e.value;
      }
      return effect;
    }

    if (accountId.isNotEmpty) {
      effect[accountId] = (effect[accountId] ?? 0) + sign * amount;
    }
    return effect;
  }

  Map<String, double> _effectFromInput({
    required String type,
    required double amount,
    required String accountId,
    String? toAccountId,
  }) {
    if (type == 'transfer') {
      return {accountId: -amount, toAccountId!: amount};
    }
    if (type == 'income') return {accountId: amount};
    return {accountId: -amount};
  }

  Future<void> addTransaction(String uid, TransactionModel t) async {
    try {
      await _ensureDefaultCash(uid);

      final accountId = t.accountId.isEmpty ? 'default_cash' : t.accountId;
      final txRef = _tx(uid).doc(t.id);
      final accountRef = _accounts(uid).doc(accountId);
      final delta = t.type == 'expense'
          ? -t.amount
          : (t.type == 'income'
                ? t.amount
                : throw Exception('Invalid transaction type'));

      await _db.runTransaction((transaction) async {
        final accountSnap = await transaction.get(accountRef);
        if (!accountSnap.exists) throw Exception('Account not found');

        final current = _toDouble(accountSnap.data()?[AccountFields.balance]);
        final next = current + delta;
        if (next < 0) {
          throw Exception('Insufficient balance');
        }

        transaction.set(txRef, _txToMap(t));
        transaction.update(accountRef, {
          AccountFields.balance: next,
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addTransfer({
    required String uid,
    required String txId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? note,
    DateTime? datetime,
    String? source,
  }) async {
    try {
      await _ensureDefaultCash(uid);

      if (fromAccountId == toAccountId) {
        throw Exception('Source and destination cannot be same');
      }
      if (amount <= 0) throw Exception('Invalid Number');

      final fromRef = _accounts(uid).doc(fromAccountId);
      final toRef = _accounts(uid).doc(toAccountId);
      final txRef = _tx(uid).doc(txId);

      final now = datetime ?? DateTime.now();

      await _db.runTransaction((transaction) async {
        final fromSnap = await transaction.get(fromRef);
        final toSnap = await transaction.get(toRef);
        if (!fromSnap.exists) throw Exception('Source account not found');
        if (!toSnap.exists) throw Exception('Destination account not found');

        final fromBalance = _toDouble(fromSnap.data()?[AccountFields.balance]);
        if (fromBalance < amount) {
          throw Exception('Insufficient balance');
        }

        transaction.update(fromRef, {
          AccountFields.balance: fromBalance - amount,
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });

        transaction.update(toRef, {
          AccountFields.balance:
              _toDouble(toSnap.data()?[AccountFields.balance]) + amount,
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });

        transaction.set(txRef, {
          CommonFields.id: txId,
          CommonFields.userId: uid,
          TransactionFields.accountId: fromAccountId,
          TransactionFields.toAccountId: toAccountId,
          TransactionFields.categoryId: 'transfer',
          TransactionFields.type: 'transfer',
          TransactionFields.amount: amount,
          TransactionFields.note: note,
          TransactionFields.source: source,
          TransactionFields.datetime: Timestamp.fromDate(now),
          CommonFields.createdAt: Timestamp.fromDate(now),
          CommonFields.updatedAt: Timestamp.fromDate(now),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<TransactionEditUndoPayload> editTransaction({
    required String uid,
    required String txId,
    required String type,
    required double amount,
    required String accountId,
    required String categoryId,
    String? toAccountId,
    String? note,
    DateTime? datetime,
  }) async {
    if (amount <= 0) throw Exception('Invalid Number');
    if (type != 'expense' && type != 'income' && type != 'transfer') {
      throw Exception('Unsupported transaction type');
    }
    if (accountId.trim().isEmpty) throw Exception('Account not found');
    if (type != 'transfer' && categoryId.trim().isEmpty) {
      throw Exception('Category is required');
    }
    if (type == 'transfer') {
      if ((toAccountId ?? '').trim().isEmpty) {
        throw Exception('Destination account not found');
      }
      if (toAccountId!.trim() == accountId.trim()) {
        throw Exception('Source and destination cannot be same');
      }
    }

    final txRef = _tx(uid).doc(txId);
    final now = datetime ?? DateTime.now();

    late final Map<String, dynamic> previousSnapshot;
    await _db.runTransaction((transaction) async {
      final txSnap = await transaction.get(txRef);
      if (!txSnap.exists) throw Exception('Transaction not found');
      final oldTx = txSnap.data() ?? <String, dynamic>{};
      previousSnapshot = Map<String, dynamic>.from(oldTx);
      final oldType = (oldTx[TransactionFields.type] ?? '').toString();
      if (oldType != 'expense' &&
          oldType != 'income' &&
          oldType != 'transfer') {
        throw Exception('This transaction type cannot be edited');
      }

      final oldEffect = _effectFromTx(oldTx);
      final newEffect = _effectFromInput(
        type: type,
        amount: amount,
        accountId: accountId.trim(),
        toAccountId: toAccountId?.trim(),
      );

      final impacted = <String>{...oldEffect.keys, ...newEffect.keys}
        ..removeWhere((id) => id.trim().isEmpty);
      if (impacted.isEmpty) throw Exception('Account not found');

      final accountSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in impacted) {
        final snap = await transaction.get(_accounts(uid).doc(id));
        if (!snap.exists) throw Exception('Account not found');
        accountSnaps[id] = snap;
      }

      for (final id in impacted) {
        final current = _toDouble(
          accountSnaps[id]!.data()?[AccountFields.balance],
        );
        final reverted = current - (oldEffect[id] ?? 0.0);
        final next = reverted + (newEffect[id] ?? 0.0);
        if (next < 0) throw Exception('Insufficient balance');
      }

      for (final id in impacted) {
        final current = _toDouble(
          accountSnaps[id]!.data()?[AccountFields.balance],
        );
        final reverted = current - (oldEffect[id] ?? 0.0);
        final next = reverted + (newEffect[id] ?? 0.0);
        transaction.update(_accounts(uid).doc(id), {
          AccountFields.balance: next,
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });
      }

      final updateData = <String, dynamic>{
        TransactionFields.type: type,
        TransactionFields.accountId: accountId.trim(),
        TransactionFields.amount: amount,
        TransactionFields.note: (note ?? '').trim().isEmpty
            ? null
            : note!.trim(),
        TransactionFields.datetime: Timestamp.fromDate(now),
        CommonFields.updatedAt: FieldValue.serverTimestamp(),
        TransactionFields.splits: FieldValue.delete(),
        TransactionFields.splitDetails: FieldValue.delete(),
      };

      if (type == 'transfer') {
        updateData[TransactionFields.toAccountId] = toAccountId!.trim();
        updateData[TransactionFields.categoryId] = 'transfer';
      } else {
        updateData[TransactionFields.toAccountId] = FieldValue.delete();
        updateData[TransactionFields.categoryId] = categoryId.trim();
      }

      transaction.update(txRef, updateData);
    });

    return TransactionEditUndoPayload(
      txId: txId,
      previousTxData: previousSnapshot,
    );
  }

  Future<void> undoEditTransaction({
    required String uid,
    required String txId,
    required Map<String, dynamic> previousTxData,
  }) async {
    final txRef = _tx(uid).doc(txId);
    await _db.runTransaction((transaction) async {
      final currentSnap = await transaction.get(txRef);
      if (!currentSnap.exists) throw Exception('Transaction not found');
      final currentTx = currentSnap.data() ?? <String, dynamic>{};
      final currentEffect = _effectFromTx(currentTx);
      final targetEffect = _effectFromTx(previousTxData);

      final impacted = <String>{...currentEffect.keys, ...targetEffect.keys}
        ..removeWhere((id) => id.trim().isEmpty);
      if (impacted.isEmpty) throw Exception('Account not found');

      final accountSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in impacted) {
        final snap = await transaction.get(_accounts(uid).doc(id));
        if (!snap.exists) throw Exception('Account not found');
        accountSnaps[id] = snap;
      }

      for (final id in impacted) {
        final current = _toDouble(
          accountSnaps[id]!.data()?[AccountFields.balance],
        );
        final reverted = current - (currentEffect[id] ?? 0.0);
        final next = reverted + (targetEffect[id] ?? 0.0);
        if (next < 0) throw Exception('Insufficient balance');
      }

      for (final id in impacted) {
        final current = _toDouble(
          accountSnaps[id]!.data()?[AccountFields.balance],
        );
        final reverted = current - (currentEffect[id] ?? 0.0);
        final next = reverted + (targetEffect[id] ?? 0.0);
        transaction.update(_accounts(uid).doc(id), {
          AccountFields.balance: next,
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });
      }

      final restore = Map<String, dynamic>.from(previousTxData);
      restore[CommonFields.id] = txId;
      restore[CommonFields.userId] = uid;
      restore[CommonFields.updatedAt] = FieldValue.serverTimestamp();
      transaction.set(txRef, restore, SetOptions(merge: false));
    });
  }

  Future<void> deleteTransaction({
    required String uid,
    required String txId,
  }) async {
    final txRef = _tx(uid).doc(txId);
    await _db.runTransaction((transaction) async {
      final txSnap = await transaction.get(txRef);
      if (!txSnap.exists) throw Exception('Transaction not found');
      final tx = txSnap.data() ?? <String, dynamic>{};
      final type = (tx[TransactionFields.type] ?? '').toString();
      if (type != 'expense' && type != 'income' && type != 'transfer') {
        throw Exception('This transaction type cannot be deleted');
      }

      final effect = _effectFromTx(tx);
      final impacted = effect.keys.where((e) => e.trim().isNotEmpty).toSet();
      if (impacted.isEmpty) throw Exception('Account not found');

      final accountSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in impacted) {
        final snap = await transaction.get(_accounts(uid).doc(id));
        if (!snap.exists) throw Exception('Account not found');
        accountSnaps[id] = snap;
      }

      for (final id in impacted) {
        final current = _toDouble(
          accountSnaps[id]!.data()?[AccountFields.balance],
        );
        final next = current - (effect[id] ?? 0.0);
        if (next < 0) throw Exception('Insufficient balance');
      }

      for (final id in impacted) {
        final current = _toDouble(
          accountSnaps[id]!.data()?[AccountFields.balance],
        );
        final next = current - (effect[id] ?? 0.0);
        transaction.update(_accounts(uid).doc(id), {
          AccountFields.balance: next,
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.delete(txRef);
    });
  }

  Future<TransactionModel> addTransactionWithAutoAllocation({
    required String uid,
    required String type,
    required double amount,
    required Map<String, double> allocation,
    required String categoryId,
    required List<String> deductionOrder,
    String? note,
    DateTime? datetime,
    String? source,
  }) async {
    try {
      await _ensureDefaultCash(uid);

      if (allocation.isEmpty) throw Exception('No allocation provided');
      if (type != 'expense' && type != 'income') {
        throw Exception('Invalid transaction type');
      }
      if (allocation.length > LazyModeConfig.maxSplitAccounts) {
        throw Exception('Split transaction exceeds limit');
      }

      final now = datetime ?? DateTime.now();
      final txId = const Uuid().v4();
      final txRef = _tx(uid).doc(txId);

      final primaryAccountId = deductionOrder.isNotEmpty
          ? deductionOrder.first
          : allocation.keys.first;

      if (type == 'expense') {
        double totalNeeded = 0;
        for (final entry in allocation.entries) {
          totalNeeded += entry.value;
        }
        if ((totalNeeded - amount).abs() > 0.000001) {
          throw Exception('Allocation total does not match transaction amount');
        }
      }

      final txData = {
        CommonFields.id: txId,
        CommonFields.userId: uid,
        TransactionFields.accountId: primaryAccountId,
        TransactionFields.categoryId: categoryId,
        TransactionFields.type: type,
        TransactionFields.amount: amount,
        TransactionFields.note: note,
        TransactionFields.source: source,
        TransactionFields.datetime: Timestamp.fromDate(now),
        CommonFields.createdAt: Timestamp.fromDate(now),
        CommonFields.updatedAt: Timestamp.fromDate(now),
        if (allocation.length > 1) TransactionFields.splitDetails: allocation,
        if (allocation.length > 1) TransactionFields.splits: allocation,
      };

      await _db.runTransaction((transaction) async {
        final accountSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final accountId in allocation.keys) {
          accountSnaps[accountId] = await transaction.get(
            _accounts(uid).doc(accountId),
          );
          if (!(accountSnaps[accountId]?.exists ?? false)) {
            throw Exception('Account not found');
          }
        }

        if (type == 'expense') {
          for (final entry in allocation.entries) {
            final current = _toDouble(
              accountSnaps[entry.key]!.data()?[AccountFields.balance],
            );
            if (current < entry.value) {
              throw Exception('Insufficient balance');
            }
          }
        }

        transaction.set(txRef, txData);

        for (final entry in allocation.entries) {
          final accountId = entry.key;
          final allocAmount = entry.value;
          final current = _toDouble(
            accountSnaps[accountId]!.data()?[AccountFields.balance],
          );
          final next = type == 'expense'
              ? current - allocAmount
              : current + allocAmount;
          transaction.update(_accounts(uid).doc(accountId), {
            AccountFields.balance: next,
            CommonFields.updatedAt: FieldValue.serverTimestamp(),
          });
        }
      });

      return TransactionModel(
        id: txId,
        userId: uid,
        accountId: primaryAccountId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        note: note,
        source: source,
        datetime: now,
        createdAt: now,
        updatedAt: now,
        splitDetails: allocation.length > 1 ? allocation : null,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addAdjustmentTransaction({
    required String uid,
    required String accountId,
    required double targetBalance,
    String? note,
    DateTime? datetime,
  }) async {
    try {
      if (targetBalance < 0) throw Exception('Invalid amount');
      await _ensureDefaultCash(uid);
      final accountRef = _accounts(uid).doc(accountId);
      final txRef = _tx(uid).doc(const Uuid().v4());
      final now = datetime ?? DateTime.now();

      await _db.runTransaction((transaction) async {
        final accSnap = await transaction.get(accountRef);
        if (!accSnap.exists) throw Exception('Account not found');

        final acc = accSnap.data() as Map<String, dynamic>;
        final current = _toDouble(acc[AccountFields.balance]);
        final diff = targetBalance - current;
        if (diff.abs() < 0.000001) {
          return;
        }

        transaction.update(accountRef, {
          AccountFields.balance: targetBalance,
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });

        transaction.set(txRef, {
          CommonFields.id: txRef.id,
          CommonFields.userId: uid,
          TransactionFields.accountId: accountId,
          TransactionFields.categoryId: 'adjustment',
          TransactionFields.type: 'adjustment',
          TransactionFields.amount: diff,
          TransactionFields.note: note ?? 'manual correction',
          TransactionFields.source: 'manual_correction',
          TransactionFields.splits: {accountId: diff},
          TransactionFields.splitDetails: {accountId: diff},
          TransactionFields.datetime: Timestamp.fromDate(now),
          CommonFields.createdAt: Timestamp.fromDate(now),
          CommonFields.updatedAt: Timestamp.fromDate(now),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<TransactionModel>> watchRecent(String uid, {int limit = 20}) {
    return _tx(uid)
        .orderBy(TransactionFields.datetime, descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          DateTime toDate(dynamic v) => v is Timestamp
              ? v.toDate()
              : (v is DateTime ? v : DateTime.now());
          return snap.docs.map((d) {
            final m = d.data();
            return TransactionModel(
              id: (m[CommonFields.id] ?? d.id).toString(),
              userId: (m[CommonFields.userId] ?? uid).toString(),
              accountId: (m[TransactionFields.accountId] ?? 'default_cash')
                  .toString(),
              categoryId:
                  (m[TransactionFields.categoryId] ??
                          m['category_id'] ??
                          m['categoryId'] ??
                          m['category'] ??
                          '')
                      .toString(),
              type: (m[TransactionFields.type] ?? 'expense').toString(),
              amount: _toDouble(m[TransactionFields.amount]),
              note: m[TransactionFields.note]?.toString(),
              source: m[TransactionFields.source]?.toString(),
              datetime: toDate(m[TransactionFields.datetime]),
              createdAt: toDate(m[CommonFields.createdAt]),
              updatedAt: toDate(m[CommonFields.updatedAt]),
              splitDetails: TransactionModel.fromMap(m, id: d.id).splitDetails,
            );
          }).toList();
        });
  }

  Stream<Map<String, double>> watchMonthlySummary(String uid) {
    final now = DateTime.now();
    return watchMonthlySummaryByMonth(
      uid,
      month: DateTime(now.year, now.month, 1),
    );
  }

  Stream<Map<String, double>> watchMonthlySummaryByMonth(
    String uid, {
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return _tx(uid)
        .where(
          TransactionFields.datetime,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(TransactionFields.datetime, isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) {
          double income = 0, expense = 0;
          for (final d in snap.docs) {
            final m = d.data();
            final type = (m[TransactionFields.type] ?? '').toString();
            final amount = _toDouble(m[TransactionFields.amount]);
            if (type == 'income') {
              income += amount;
            } else if (type == 'expense') {
              expense += amount;
            }
          }
          return {'income': income, 'expense': expense};
        });
  }

  Stream<List<Map<String, dynamic>>> watchMonthlyExpenseByCategoryByMonth(
    String uid, {
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return _tx(uid)
        .where(TransactionFields.type, isEqualTo: 'expense')
        .where(
          TransactionFields.datetime,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(TransactionFields.datetime, isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) {
          final Map<String, double> agg = {};
          for (final d in snap.docs) {
            final m = d.data();
            final cid = (m[TransactionFields.categoryId] ?? 'unknown')
                .toString();
            final amount = _toDouble(m[TransactionFields.amount]);
            agg[cid] = (agg[cid] ?? 0) + amount;
          }
          final list =
              agg.entries
                  .map((e) => {'categoryId': e.key, 'amount': e.value})
                  .toList()
                ..sort(
                  (a, b) =>
                      (b['amount'] as double).compareTo(a['amount'] as double),
                );
          return list;
        });
  }

  Stream<List<Map<String, dynamic>>> watchMonthlyCashFlowCalendar(
    String uid, {
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return _tx(uid)
        .where(
          TransactionFields.datetime,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(TransactionFields.datetime, isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) {
          final Map<int, double> dayIncome = {};
          final Map<int, double> dayExpense = {};

          for (final d in snap.docs) {
            final m = d.data();
            final dt = _toDate(m[TransactionFields.datetime]);

            final type = (m[TransactionFields.type] ?? '').toString();
            final amount = _toDouble(m[TransactionFields.amount]);

            if (type == 'transfer') continue;

            final day = dt.day;
            if (type == 'income') {
              dayIncome[day] = (dayIncome[day] ?? 0) + amount;
            } else if (type == 'expense') {
              dayExpense[day] = (dayExpense[day] ?? 0) + amount;
            }
          }

          final days = <int>{...dayIncome.keys, ...dayExpense.keys}.toList()
            ..sort();
          return days.map((day) {
            final income = dayIncome[day] ?? 0.0;
            final expense = dayExpense[day] ?? 0.0;
            return {
              'day': day,
              'income': income,
              'expense': expense,
              'net': income - expense,
            };
          }).toList();
        });
  }

  Future<List<Map<String, dynamic>>> getMonthlyTransactionsForExport(
    String uid, {
    required DateTime month,
    required String Function(String id) categoryNameResolver,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final snap = await _tx(uid)
        .where(
          TransactionFields.datetime,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(TransactionFields.datetime, isLessThan: Timestamp.fromDate(end))
        .orderBy(TransactionFields.datetime)
        .get();

    return snap.docs.map((d) {
      final m = d.data();
      final dt = _toDate(m[TransactionFields.datetime]);
      final cid =
          (m[TransactionFields.categoryId] ??
                  m['category_id'] ??
                  m['categoryId'] ??
                  m['category'] ??
                  '')
              .toString();
      return {
        'date':
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
        'type': (m[TransactionFields.type] ?? '').toString(),
        'category': categoryNameResolver(cid),
        'amount': _toDouble(m[TransactionFields.amount]),
        'note': (m[TransactionFields.note] ?? '').toString(),
      };
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchMonthlyTransactions(
    String uid, {
    required DateTime month,
  }) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    return _tx(uid)
        .where(
          TransactionFields.datetime,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(TransactionFields.datetime, isLessThan: Timestamp.fromDate(end))
        .orderBy(TransactionFields.datetime, descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => _toListItem(d.data(), d.id)).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> watchTransactionsByDay(
    String uid, {
    required DateTime day,
  }) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    return _tx(uid)
        .where(
          TransactionFields.datetime,
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(TransactionFields.datetime, isLessThan: Timestamp.fromDate(end))
        .orderBy(TransactionFields.datetime, descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => _toListItem(d.data(), d.id)).toList(),
        );
  }

  Future<void> clearAllUserData(String uid) async {
    Future<void> del(CollectionReference<Map<String, dynamic>> col) async {
      while (true) {
        final s = await col.limit(300).get();
        if (s.docs.isEmpty) break;
        final b = _db.batch();
        for (final d in s.docs) {
          b.delete(d.reference);
        }
        await b.commit();
      }
    }

    final userRef = _db.collection(AppCollections.users).doc(uid);
    await del(userRef.collection(AppCollections.transactions));
    await del(userRef.collection(AppCollections.shortcuts));
    await del(userRef.collection(AppCollections.categories));
    await del(userRef.collection(AppCollections.budgets));
    await del(userRef.collection(AppCollections.accounts));
    await del(userRef.collection(AppCollections.assetProfiles));
    await del(userRef.collection(AppCollections.investmentPnlLogs));
    await del(userRef.collection(AppCollections.recurring));
    await del(userRef.collection(AppCollections.recurringPlans));
    await del(userRef.collection(AppCollections.recurringExecutions));
    await del(userRef.collection(AppCollections.systemNotifications));

    await _accounts(uid).doc('default_cash').set({
      CommonFields.id: 'default_cash',
      CommonFields.userId: uid,
      AccountFields.name: 'Cash',
      AccountFields.provider: 'Cash',
      AccountFields.type: 'cash',
      AccountFields.kind: 'standard',
      AccountFields.tag: 'daily_use',
      AccountFields.balance: 0.0,
      AccountFields.isLiquid: true,
      AccountFields.isPrimary: true,
      AccountFields.isVirtual: false,
      CommonFields.createdAt: FieldValue.serverTimestamp(),
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }
}
