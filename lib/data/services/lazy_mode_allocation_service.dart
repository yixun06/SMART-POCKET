import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/constants.dart';
import '../../core/models/allocation_result.dart';
import 'account_service.dart';

class LazyModeAllocationService {
  final AccountService _accountService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  LazyModeAllocationService(this._accountService);

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(AppCollections.users).doc(uid);

  Future<bool> _allowSavingsFallback(String uid) async {
    try {
      final snap = await _userDoc(uid).get();
      final m = snap.data() ?? {};
      final settings = (m[UserFields.settings] as Map<String, dynamic>?) ?? {};
      return settings[UserSettingsFields.lazyAllowSavingsFallback] == true;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'unknown') return false;
      rethrow;
    }
  }

  Future<AllocationResult> allocateExpense({
    required String uid,
    required double amount,
    String category = LazyModeConfig.expensePrimaryCategory,
  }) async {
    if (amount <= 0) {
      return AllocationResult(
        success: false,
        allocation: {},
        deductionOrder: [],
        fallbackWarnings: [],
        errorMessage: 'Invalid amount',
      );
    }

    final allocation = <String, double>{};
    final deductionOrder = <String>[];
    final fallbackWarnings = <String>[];
    var remaining = amount;

    try {
      final categoryAccounts = await _accountService.getAccountsByTag(
        uid,
        category,
        excludeInvestment: true,
      );
      final usedInCategory = await _deductFromAccounts(
        categoryAccounts,
        remaining,
        allocation,
        deductionOrder,
      );
      remaining -= usedInCategory;

      if (remaining <= 0) {
        return AllocationResult(
          success: true,
          allocation: allocation,
          deductionOrder: deductionOrder,
          fallbackWarnings: fallbackWarnings,
        );
      }
    } catch (e) {
      return AllocationResult(
        success: false,
        allocation: {},
        deductionOrder: [],
        fallbackWarnings: [],
        errorMessage: 'Failed to query primary category: $e',
      );
    }

    final allowSavingsFallback = await _allowSavingsFallback(uid);
    if (allowSavingsFallback &&
        category.toLowerCase() != LazyModeConfig.savingsCategory) {
      try {
        final savingsAccounts = await _accountService.getAccountsByTag(
          uid,
          LazyModeConfig.savingsCategory,
          excludeInvestment: true,
        );
        if (savingsAccounts.isNotEmpty) {
          fallbackWarnings.add('Fallback used: savings accounts');
          final usedInFallback = await _deductFromAccounts(
            savingsAccounts,
            remaining,
            allocation,
            deductionOrder,
          );
          remaining -= usedInFallback;
        }
      } catch (_) {}
    }

    if (remaining <= 0) {
      return AllocationResult(
        success: true,
        allocation: allocation,
        deductionOrder: deductionOrder,
        fallbackWarnings: fallbackWarnings,
      );
    }

    return AllocationResult(
      success: false,
      allocation: {},
      deductionOrder: [],
      fallbackWarnings: [],
      errorMessage: allowSavingsFallback
          ? 'Insufficient balance. Need ${remaining.toStringAsFixed(2)} more.'
          : 'Insufficient balance in daily_use accounts. Savings fallback is disabled.',
    );
  }

  Future<AllocationResult> allocateIncome({
    required String uid,
    required double amount,
    String category = LazyModeConfig.incomePrimaryCategory,
  }) async {
    if (amount <= 0) {
      return AllocationResult(
        success: false,
        allocation: {},
        deductionOrder: [],
        fallbackWarnings: [],
        errorMessage: 'Invalid amount',
      );
    }

    try {
      final primaryAccount = await _accountService.getPrimaryAccountByTag(
        uid,
        category,
        excludeInvestment: true,
      );
      if (primaryAccount == null) {
        final accounts = await _accountService.getAccountsByTag(
          uid,
          category,
          excludeInvestment: true,
        );
        if (accounts.isEmpty) {
          return AllocationResult(
            success: false,
            allocation: {},
            deductionOrder: [],
            fallbackWarnings: [],
            errorMessage: 'No account found in $category for income deposit',
          );
        }
        final accountId = accounts.first['_id'].toString();
        return AllocationResult(
          success: true,
          allocation: {accountId: amount},
          deductionOrder: [accountId],
          fallbackWarnings: [
            'No primary account in $category, using first account',
          ],
        );
      }

      final accountId = primaryAccount['_id'].toString();
      return AllocationResult(
        success: true,
        allocation: {accountId: amount},
        deductionOrder: [accountId],
        fallbackWarnings: [],
      );
    } catch (e) {
      return AllocationResult(
        success: false,
        allocation: {},
        deductionOrder: [],
        fallbackWarnings: [],
        errorMessage: 'Failed to allocate income: $e',
      );
    }
  }

  Future<double> _deductFromAccounts(
    List<Map<String, dynamic>> accounts,
    double amount,
    Map<String, double> allocation,
    List<String> deductionOrder,
  ) async {
    var remaining = amount;

    for (final account in accounts) {
      if (remaining <= 0) break;
      if (deductionOrder.length >= LazyModeConfig.maxSplitAccounts) break;

      final accountId = account['_id'].toString();
      final balance = (account[AccountFields.balance] as num).toDouble();

      if (balance <= 0) continue;

      final toDeduct = balance >= remaining ? remaining : balance;
      allocation[accountId] = (allocation[accountId] ?? 0) + toDeduct;
      deductionOrder.add(accountId);
      remaining -= toDeduct;
    }

    return amount - remaining;
  }
}
