import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/constants.dart';
import '../../core/models/allocation_result.dart';
import '../../core/models/transaction_model.dart';
import '../../data/services/account_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/lazy_mode_allocation_service.dart';
import '../../data/services/transaction_service.dart';

class TransactionController extends ChangeNotifier {
  final TransactionService _service;
  final AccountService _accountService;
  final LazyModeAllocationService _allocationService;
  final AuthService _authService;

  TransactionController(
    this._service,
    this._accountService,
    this._allocationService,
    this._authService,
  );

  bool isLoading = false;
  String? errorMessage;

  List<TransactionModel> recent = [];
  List<Map<String, dynamic>> accounts = [];

  double monthlyIncome = 0.0;
  double monthlyExpense = 0.0;
  double get monthlyBalance => monthlyIncome - monthlyExpense;
  TransactionEditUndoPayload? _lastEditUndo;
  bool get canUndoLastEdit => _lastEditUndo != null;

  Map<String, double>? currentAllocationPlan;
  List<String>? deductionOrder;
  List<String>? fallbackWarnings;
  Map<String, double>? lastCommittedAllocation;
  List<String>? lastCommittedFallbackWarnings;
  String? lastCommittedType;
  double? lastCommittedAmount;

  bool _isTransientFirestoreError(Object e) =>
      _service.isTransientFirestoreError(e);

  bool isTransientError(Object e) => _isTransientFirestoreError(e);

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  String _normalizeTag(String tag) => tag.trim().toLowerCase();

  String _accountId(Map<String, dynamic> account) =>
      (account['_id'] ?? account[CommonFields.id] ?? '').toString();

  bool _isInvestmentAccount(Map<String, dynamic> account) {
    final type = (account[AccountFields.type] ?? '').toString().toLowerCase();
    final kind = (account[AccountFields.kind] ?? '').toString().toLowerCase();
    return type == 'investment' || kind == 'investment';
  }

  bool _isPrimaryAccount(Map<String, dynamic> account) =>
      account[AccountFields.isPrimary] == true;

  int _createdAtMillis(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is DateTime) return raw.millisecondsSinceEpoch;
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed != null) return parsed;
    return 0;
  }

  List<Map<String, dynamic>> _accountsByTagSorted(
    String tag, {
    bool excludeInvestment = true,
  }) {
    final target = _normalizeTag(tag);
    final list = accounts.map((e) => Map<String, dynamic>.from(e)).where((a) {
      final aTag = _normalizeTag((a[AccountFields.tag] ?? '').toString());
      if (aTag != target) return false;
      if (!excludeInvestment) return true;
      return !_isInvestmentAccount(a);
    }).toList();

    list.sort((a, b) {
      final primaryCmp =
          (_isPrimaryAccount(b) ? 1 : 0) - (_isPrimaryAccount(a) ? 1 : 0);
      if (primaryCmp != 0) return primaryCmp;
      final aMillis = _createdAtMillis(
        a['createdAtMillis'] ?? a[CommonFields.createdAt],
      );
      final bMillis = _createdAtMillis(
        b['createdAtMillis'] ?? b[CommonFields.createdAt],
      );
      return aMillis.compareTo(bMillis);
    });
    return list;
  }

  AllocationResult _buildLocalAllocation({
    required String type,
    required double amount,
    required String categoryTag,
  }) {
    if (type == 'income') {
      final savings = _accountsByTagSorted(
        categoryTag,
        excludeInvestment: true,
      );
      if (savings.isEmpty) {
        return const AllocationResult(
          success: false,
          allocation: {},
          deductionOrder: [],
          fallbackWarnings: [],
          errorMessage: 'No account found in savings for income deposit',
        );
      }
      final id = _accountId(savings.first);
      return AllocationResult(
        success: true,
        allocation: {id: amount},
        deductionOrder: [id],
        fallbackWarnings: const ['Offline mode: using local account snapshot'],
      );
    }

    final allocation = <String, double>{};
    final order = <String>[];
    final warnings = <String>['Offline mode: using local account snapshot'];
    var remaining = amount;

    final dailyUse = _accountsByTagSorted(categoryTag, excludeInvestment: true);
    for (final a in dailyUse) {
      if (remaining <= 0 || order.length >= LazyModeConfig.maxSplitAccounts) {
        break;
      }
      final balance = _toDouble(a[AccountFields.balance]);
      if (balance <= 0) continue;
      final id = _accountId(a);
      if (id.isEmpty) continue;
      final used = balance >= remaining ? remaining : balance;
      allocation[id] = used;
      order.add(id);
      remaining -= used;
    }

    if (remaining > 0) {
      final savings = _accountsByTagSorted(
        LazyModeConfig.savingsCategory,
        excludeInvestment: true,
      );
      if (savings.isNotEmpty) {
        warnings.add('Fallback used: savings accounts');
      }
      for (final a in savings) {
        if (remaining <= 0 || order.length >= LazyModeConfig.maxSplitAccounts) {
          break;
        }
        final balance = _toDouble(a[AccountFields.balance]);
        if (balance <= 0) continue;
        final id = _accountId(a);
        if (id.isEmpty) continue;
        final used = balance >= remaining ? remaining : balance;
        allocation[id] = (allocation[id] ?? 0) + used;
        order.add(id);
        remaining -= used;
      }
    }

    if (remaining > 0) {
      return AllocationResult(
        success: false,
        allocation: const {},
        deductionOrder: const [],
        fallbackWarnings: warnings,
        errorMessage:
            'Insufficient balance. Need ${remaining.toStringAsFixed(2)} more.',
      );
    }

    return AllocationResult(
      success: true,
      allocation: allocation,
      deductionOrder: order,
      fallbackWarnings: warnings,
    );
  }

  Future<void> _retryOnceIfUnavailable(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!_isTransientFirestoreError(e)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await action();
    }
  }

  StreamSubscription<List<TransactionModel>>? _txSub;
  StreamSubscription<List<Map<String, dynamic>>>? _accSub;
  StreamSubscription<Map<String, double>>? _summarySub;

  String get userId => _uid;
  bool get hasUser => _authService.currentUserId != null;

  Stream<List<Map<String, dynamic>>> watchMonthlyTransactions(DateTime month) {
    return _service.watchMonthlyTransactions(_uid, month: month);
  }

  Stream<List<Map<String, dynamic>>> watchTransactionsByDay(DateTime day) {
    return _service.watchTransactionsByDay(_uid, day: day);
  }

  String get _uid {
    final uid = _authService.currentUserId;
    if (uid == null) throw Exception('User not logged in');
    return uid;
  }

  Future<void> init() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _accountService.ensureDefaultAccount(_uid);

      _accSub?.cancel();
      _accSub = _accountService.watchAccounts(_uid).listen((list) {
        accounts = list;
        notifyListeners();
      });

      _txSub?.cancel();
      _txSub = _service
          .watchRecent(_uid)
          .listen(
            (list) {
              recent = list;
              isLoading = false;
              notifyListeners();
            },
            onError: (e) {
              isLoading = false;
              errorMessage = e.toString();
              notifyListeners();
            },
          );

      _summarySub?.cancel();
      _summarySub = _service.watchMonthlySummary(_uid).listen((m) {
        monthlyIncome = m['income'] ?? 0.0;
        monthlyExpense = m['expense'] ?? 0.0;
        notifyListeners();
      });
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> handleAuthChanged() async {
    final uid = _authService.currentUserId;
    if (uid == null) {
      await _txSub?.cancel();
      await _accSub?.cancel();
      await _summarySub?.cancel();
      _txSub = null;
      _accSub = null;
      _summarySub = null;
      recent = [];
      accounts = [];
      monthlyIncome = 0.0;
      monthlyExpense = 0.0;
      isLoading = false;
      errorMessage = null;
      currentAllocationPlan = null;
      deductionOrder = null;
      fallbackWarnings = null;
      lastCommittedAllocation = null;
      lastCommittedFallbackWarnings = null;
      lastCommittedType = null;
      lastCommittedAmount = null;
      _lastEditUndo = null;
      notifyListeners();
      return;
    }
    await init();
  }

  Future<bool> addTx({
    required String accountId,
    required String categoryId,
    required String type,
    required String amountText,
    String? note,
    DateTime? datetime,
    String? source,
  }) async {
    errorMessage = null;

    final amount = double.tryParse(amountText.trim());
    if (amount == null || amount <= 0) {
      errorMessage = 'Invalid Number';
      notifyListeners();
      return false;
    }
    if (type != 'expense' && type != 'income') {
      errorMessage = 'Invalid transaction type';
      notifyListeners();
      return false;
    }

    try {
      if (type == 'expense') {
        final selected = accounts.cast<Map<String, dynamic>>().firstWhere(
          (a) => (a['_id'] ?? a[CommonFields.id]).toString() == accountId,
          orElse: () => <String, dynamic>{},
        );
        if (selected.isEmpty) {
          errorMessage = 'Account not found';
          notifyListeners();
          return false;
        }
        final balance = _toDouble(selected[AccountFields.balance]);
        if (balance < amount) {
          errorMessage = 'Insufficient balance';
          notifyListeners();
          return false;
        }
      }

      final now = DateTime.now();
      final tx = TransactionModel(
        id: const Uuid().v4(),
        userId: _uid,
        accountId: accountId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        note: note,
        source: source,
        datetime: datetime ?? now,
        createdAt: now,
        updatedAt: now,
      );
      await _retryOnceIfUnavailable(() => _service.addTransaction(_uid, tx));
      return true;
    } catch (e) {
      final msg = e.toString();
      if (_isTransientFirestoreError(e)) {
        errorMessage = 'Network is temporarily unavailable. Please retry.';
      } else if (msg.contains('Insufficient balance')) {
        errorMessage = 'Insufficient balance';
      } else if (msg.contains('Account not found')) {
        errorMessage = 'Account not found';
      } else {
        errorMessage = msg;
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required String amountText,
    String? note,
    DateTime? datetime,
    String? source,
  }) async {
    errorMessage = null;

    final amount = double.tryParse(amountText.trim());
    if (amount == null || amount <= 0) {
      errorMessage = 'Invalid Number';
      notifyListeners();
      return false;
    }
    if (fromAccountId == toAccountId) {
      errorMessage = 'Source and destination cannot be same';
      notifyListeners();
      return false;
    }

    try {
      final from = accounts.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['_id'] ?? a[CommonFields.id]).toString() == fromAccountId,
        orElse: () => <String, dynamic>{},
      );
      final to = accounts.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['_id'] ?? a[CommonFields.id]).toString() == toAccountId,
        orElse: () => <String, dynamic>{},
      );
      if (from.isEmpty) {
        errorMessage = 'Source account not found';
        notifyListeners();
        return false;
      }
      if (to.isEmpty) {
        errorMessage = 'Destination account not found';
        notifyListeners();
        return false;
      }
      if (_toDouble(from[AccountFields.balance]) < amount) {
        errorMessage = 'Insufficient balance';
        notifyListeners();
        return false;
      }

      await _retryOnceIfUnavailable(
        () => _service.addTransfer(
          uid: _uid,
          txId: const Uuid().v4(),
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          amount: amount,
          note: note,
          datetime: datetime,
          source: source ?? 'manual',
        ),
      );
      return true;
    } catch (e) {
      final msg = e.toString();
      if (_isTransientFirestoreError(e)) {
        errorMessage = 'Network is temporarily unavailable. Please retry.';
      } else if (msg.contains('Insufficient balance')) {
        errorMessage = 'Insufficient balance';
      } else {
        errorMessage = msg;
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> addTxLazyMode({
    required String type,
    required String amountText,
    String? categoryTag,
    String? categoryId,
    String? note,
    DateTime? datetime,
    String? source,
  }) async {
    errorMessage = null;
    currentAllocationPlan = null;
    deductionOrder = null;
    fallbackWarnings = null;
    lastCommittedAllocation = null;
    lastCommittedFallbackWarnings = null;
    lastCommittedType = null;
    lastCommittedAmount = null;

    final amount = double.tryParse(amountText.trim());
    if (amount == null || amount <= 0) {
      errorMessage = 'Invalid Number';
      notifyListeners();
      return false;
    }
    if (type != 'expense' && type != 'income') {
      errorMessage = 'Invalid transaction type';
      notifyListeners();
      return false;
    }

    try {
      final effectiveCategoryTag =
          categoryTag ??
          (type == 'income'
              ? LazyModeConfig.incomePrimaryCategory
              : LazyModeConfig.expensePrimaryCategory);

      late final AllocationResult allocationResult;
      try {
        allocationResult = type == 'expense'
            ? await _allocationService.allocateExpense(
                uid: _uid,
                amount: amount,
                category: effectiveCategoryTag,
              )
            : await _allocationService.allocateIncome(
                uid: _uid,
                amount: amount,
                category: effectiveCategoryTag,
              );
      } catch (e) {
        if (!_isTransientFirestoreError(e)) rethrow;
        allocationResult = _buildLocalAllocation(
          type: type,
          amount: amount,
          categoryTag: effectiveCategoryTag,
        );
      }

      if (!allocationResult.success) {
        final allocMsg = allocationResult.errorMessage ?? '';
        if (_isTransientFirestoreError(allocMsg)) {
          final local = _buildLocalAllocation(
            type: type,
            amount: amount,
            categoryTag: effectiveCategoryTag,
          );
          if (local.success) {
            currentAllocationPlan = local.allocation;
            deductionOrder = local.deductionOrder;
            fallbackWarnings = local.fallbackWarnings;
            notifyListeners();
            await _retryOnceIfUnavailable(() async {
              await _service.addTransactionWithAutoAllocation(
                uid: _uid,
                type: type,
                amount: amount,
                allocation: local.allocation,
                categoryId: categoryId ?? effectiveCategoryTag,
                deductionOrder: local.deductionOrder,
                note: note,
                datetime: datetime,
                source: source ?? 'manual',
              );
            });
            lastCommittedAllocation = Map<String, double>.from(
              local.allocation,
            );
            lastCommittedFallbackWarnings = List<String>.from(
              local.fallbackWarnings,
            );
            lastCommittedType = type;
            lastCommittedAmount = amount;
            notifyListeners();
            return true;
          }
        }
        errorMessage = allocationResult.errorMessage ?? 'Allocation failed';
        notifyListeners();
        return false;
      }

      currentAllocationPlan = allocationResult.allocation;
      deductionOrder = allocationResult.deductionOrder;
      fallbackWarnings = allocationResult.fallbackWarnings;
      notifyListeners();

      await _retryOnceIfUnavailable(() async {
        await _service.addTransactionWithAutoAllocation(
          uid: _uid,
          type: type,
          amount: amount,
          allocation: allocationResult.allocation,
          categoryId: categoryId ?? effectiveCategoryTag,
          deductionOrder: allocationResult.deductionOrder,
          note: note,
          datetime: datetime,
          source: source ?? 'manual',
        );
      });
      lastCommittedAllocation = Map<String, double>.from(
        allocationResult.allocation,
      );
      lastCommittedFallbackWarnings = List<String>.from(
        allocationResult.fallbackWarnings,
      );
      lastCommittedType = type;
      lastCommittedAmount = amount;
      notifyListeners();

      return true;
    } catch (e) {
      final msg = e.toString();
      if (_isTransientFirestoreError(e)) {
        errorMessage = 'Network is temporarily unavailable. Please retry.';
      } else if (msg.contains('Insufficient balance')) {
        errorMessage = 'Insufficient balance';
      } else if (msg.contains('Account not found')) {
        errorMessage = 'Account not found';
      } else if (msg.contains('No account found')) {
        errorMessage = 'No accounts available for this mode';
      } else {
        errorMessage = msg;
      }

      currentAllocationPlan = null;
      deductionOrder = null;
      fallbackWarnings = null;
      lastCommittedAllocation = null;
      lastCommittedFallbackWarnings = null;
      lastCommittedType = null;
      lastCommittedAmount = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editTransaction({
    required String txId,
    required String type,
    required String amountText,
    required String accountId,
    required String categoryId,
    String? toAccountId,
    String? note,
    DateTime? datetime,
  }) async {
    errorMessage = null;

    final amount = double.tryParse(amountText.trim());
    if (amount == null || amount <= 0) {
      errorMessage = 'Invalid Number';
      notifyListeners();
      return false;
    }
    if (type != 'expense' && type != 'income' && type != 'transfer') {
      errorMessage = 'Unsupported transaction type';
      notifyListeners();
      return false;
    }
    if (accountId.trim().isEmpty) {
      errorMessage = 'Account not found';
      notifyListeners();
      return false;
    }
    if (type != 'transfer' && categoryId.trim().isEmpty) {
      errorMessage = 'Category is required';
      notifyListeners();
      return false;
    }
    if (type == 'transfer') {
      if ((toAccountId ?? '').trim().isEmpty) {
        errorMessage = 'Destination account not found';
        notifyListeners();
        return false;
      }
      if (toAccountId!.trim() == accountId.trim()) {
        errorMessage = 'Source and destination cannot be same';
        notifyListeners();
        return false;
      }
    }

    try {
      final undo = await _retryOnceIfUnavailableResult(
        () => _service.editTransaction(
          uid: _uid,
          txId: txId,
          type: type,
          amount: amount,
          accountId: accountId,
          categoryId: categoryId,
          toAccountId: toAccountId,
          note: note,
          datetime: datetime,
        ),
      );
      _lastEditUndo = undo;
      notifyListeners();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (_isTransientFirestoreError(e)) {
        errorMessage = 'Network is temporarily unavailable. Please retry.';
      } else if (msg.contains('Insufficient balance')) {
        errorMessage = 'Insufficient balance';
      } else if (msg.contains('Account not found')) {
        errorMessage = 'Account not found';
      } else if (msg.contains('Transaction not found')) {
        errorMessage = 'Transaction not found';
      } else {
        errorMessage = msg;
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> undoLastEditTransaction() async {
    final undo = _lastEditUndo;
    if (undo == null) {
      errorMessage = 'No editable change to undo';
      notifyListeners();
      return false;
    }
    try {
      await _retryOnceIfUnavailable(
        () => _service.undoEditTransaction(
          uid: _uid,
          txId: undo.txId,
          previousTxData: undo.previousTxData,
        ),
      );
      _lastEditUndo = null;
      notifyListeners();
      return true;
    } catch (e) {
      if (_isTransientFirestoreError(e)) {
        errorMessage = 'Network is temporarily unavailable. Please retry.';
      } else {
        errorMessage = e.toString();
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(String txId) async {
    errorMessage = null;
    if (txId.trim().isEmpty) {
      errorMessage = 'Transaction not found';
      notifyListeners();
      return false;
    }
    try {
      await _retryOnceIfUnavailable(
        () => _service.deleteTransaction(uid: _uid, txId: txId),
      );
      if (_lastEditUndo?.txId == txId) {
        _lastEditUndo = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      final msg = e.toString();
      if (_isTransientFirestoreError(e)) {
        errorMessage = 'Network is temporarily unavailable. Please retry.';
      } else if (msg.contains('Insufficient balance')) {
        errorMessage = 'Unable to delete: balance protection triggered';
      } else if (msg.contains('cannot be deleted')) {
        errorMessage = 'This transaction type cannot be deleted yet';
      } else if (msg.contains('Transaction not found')) {
        errorMessage = 'Transaction not found';
      } else {
        errorMessage = msg;
      }
      notifyListeners();
      return false;
    }
  }

  Future<T> _retryOnceIfUnavailableResult<T>(
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (e) {
      if (!_isTransientFirestoreError(e)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return await action();
    }
  }

  Future<AllocationResult?> previewAllocation({
    required String type,
    required String amountText,
    String? categoryTag,
  }) async {
    final amount = double.tryParse(amountText.trim());
    if (amount == null || amount <= 0) return null;

    try {
      final effectiveCategoryTag =
          categoryTag ??
          (type == 'income'
              ? LazyModeConfig.incomePrimaryCategory
              : LazyModeConfig.expensePrimaryCategory);
      final result = type == 'expense'
          ? await _allocationService.allocateExpense(
              uid: _uid,
              amount: amount,
              category: effectiveCategoryTag,
            )
          : await _allocationService.allocateIncome(
              uid: _uid,
              amount: amount,
              category: effectiveCategoryTag,
            );
      return result;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _txSub?.cancel();
    _accSub?.cancel();
    _summarySub?.cancel();
    super.dispose();
  }
}
