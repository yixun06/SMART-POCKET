import 'package:flutter/foundation.dart';

import '../../data/services/account_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/transaction_service.dart';

class AssetController extends ChangeNotifier {
  AssetController(
    this._accountService,
    this._authService,
    this._transactionService,
  );

  final AccountService _accountService;
  final AuthService _authService;
  final TransactionService _transactionService;

  String? get uid => _authService.currentUserId;

  Stream<Map<String, dynamic>> watchAssetProfile() {
    return _accountService.watchAssetProfile(_requireUid());
  }

  Stream<Map<String, dynamic>> watchUserData() {
    return _accountService.watchUserData(_requireUid());
  }

  Stream<List<Map<String, dynamic>>> watchAccounts() {
    return _accountService.watchAccounts(_requireUid());
  }

  Future<void> setAssetMode(String mode) {
    return _accountService.setAssetMode(_requireUid(), mode);
  }

  Future<void> setTotalAsset(double amount) {
    return _accountService.setTotalAsset(_requireUid(), amount);
  }

  Future<void> syncAssetProfile({
    required String mode,
    required double totalAsset,
    bool includeCreatedAt = false,
  }) {
    return _accountService.syncAssetProfile(
      uid: _requireUid(),
      mode: mode,
      totalAsset: totalAsset,
      includeCreatedAt: includeCreatedAt,
    );
  }

  Future<void> createBucketPrimaryAccount(String tag) {
    return _accountService.createBucketPrimaryAccount(
      uid: _requireUid(),
      tag: tag,
    );
  }

  Future<String> createAccount({
    required String name,
    required String type,
    required double openingBalance,
    bool isLiquid = true,
    String? accountNumber,
    String? tag,
  }) {
    return _accountService.createAccount(
      name: name,
      type: type,
      openingBalance: openingBalance,
      isLiquid: isLiquid,
      accountNumber: accountNumber,
      tag: tag,
    );
  }

  Future<void> updateAccount({
    required String accountId,
    required String name,
    required String type,
    required double balance,
    required bool isLiquid,
    String? accountNumber,
    String? tag,
  }) {
    return _accountService.updateAccount(
      accountId: accountId,
      name: name,
      type: type,
      balance: balance,
      isLiquid: isLiquid,
      accountNumber: accountNumber,
      tag: tag,
    );
  }

  Future<void> deleteAccount(String accountId) {
    return _accountService.deleteAccount(accountId);
  }

  Future<void> addAdjustmentTransaction({
    required String accountId,
    required double targetBalance,
    required String note,
  }) {
    return _transactionService.addAdjustmentTransaction(
      uid: _requireUid(),
      accountId: accountId,
      targetBalance: targetBalance,
      note: note,
    );
  }

  Future<String> createAccountWithPayload({
    required double openingBalance,
    required Map<String, dynamic> payload,
  }) {
    return _accountService.createAccountWithPayload(
      uid: _requireUid(),
      openingBalance: openingBalance,
      payload: payload,
    );
  }

  Future<void> updateAccountWithPayload({
    required String accountId,
    required Map<String, dynamic> payload,
  }) {
    return _accountService.updateAccountWithPayload(
      uid: _requireUid(),
      accountId: accountId,
      payload: payload,
    );
  }

  Future<double> updateInvestmentValue({
    required String accountId,
    required double newBalance,
    String? note,
  }) {
    return _accountService.updateInvestmentValue(
      uid: _requireUid(),
      accountId: accountId,
      newBalance: newBalance,
      note: note,
    );
  }

  String _requireUid() {
    final userId = uid;
    if (userId == null) throw Exception('Please login first');
    return userId;
  }
}
