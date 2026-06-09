import 'package:flutter/foundation.dart';

import '../../data/services/auth_service.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/transaction_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(
    this._authService,
    this._backupService,
    this._transactionService,
  );

  final AuthService _authService;
  final BackupService _backupService;
  final TransactionService _transactionService;

  bool isBusy = false;
  String? errorMessage;

  String? get uid => _authService.currentUserId;

  String get email => _authService.currentUserEmail ?? 'new@user.com';

  String get displayName {
    final name = _authService.currentUserDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  Future<BackupPreview> buildBackupPreview() {
    return _backupService.buildPreview(_requireUid());
  }

  Future<void> createCloudBackup() {
    return _runBusy(() => _backupService.createCloudBackup(_requireUid()));
  }

  Future<String> exportBackupJson() async {
    return _runBusy(() => _backupService.exportBackupJson(_requireUid()));
  }

  Future<void> restoreLatestCloudBackup() {
    return _runBusy(
      () => _backupService.restoreFromLatestCloudBackup(_requireUid()),
    );
  }

  Future<void> restoreFromBackupJson(String jsonText) {
    return _runBusy(
      () => _backupService.restoreFromBackupJson(_requireUid(), jsonText),
    );
  }

  Future<void> resetAllDataWithBackup() {
    return _runBusy(() async {
      final userId = _requireUid();
      await _backupService.createCloudBackup(userId);
      await _transactionService.clearAllUserData(userId);
    });
  }

  Future<T> _runBusy<T>(Future<T> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await action();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  String _requireUid() {
    final userId = uid;
    if (userId == null) throw Exception('Please login first');
    return userId;
  }
}
