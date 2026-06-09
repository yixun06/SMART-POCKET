import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/constants.dart';
import '../../data/services/account_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/local_storage_service.dart';
import '../../data/services/shortcut_service.dart';

class ConfigController extends ChangeNotifier {
  final LocalStorageService _local;
  final AuthService _authService;
  final AccountService _accountService;
  final ShortcutService _shortcutService;

  ConfigController(
    this._local,
    this._authService,
    this._accountService,
    this._shortcutService,
  );

  String _mode = 'lazy';
  bool _isLoading = false;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _modeSub;
  String? _listeningUid;

  String get appMode => _mode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _error;

  String? get _uid => _authService.currentUserId;

  Future<void> loadCurrentMode() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final local = await _local.readAppMode();
      if (local == 'lazy' || local == 'detailed') {
        _mode = local!;
      }

      final uid = _uid;
      if (uid != null) {
        await _loadRemoteMode(uid);
        _bindModeStream(uid);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> handleAuthChanged(String? uid) async {
    if (uid == null) {
      await _modeSub?.cancel();
      _modeSub = null;
      _listeningUid = null;
      _mode = 'lazy';
      _error = null;
      notifyListeners();
      return;
    }

    await loadCurrentMode();
  }

  Future<bool> switchMode(String nextMode) async {
    if (nextMode != 'lazy' && nextMode != 'detailed') {
      _error = 'Invalid mode';
      notifyListeners();
      return false;
    }
    if (nextMode == _mode) return true;

    final prev = _mode;

    _mode = nextMode;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _local.saveAppMode(nextMode);
      String? origin;
      final uid = _uid;
      if (uid != null && nextMode == 'lazy') {
        final accounts = await _accountService.watchAccounts(uid).first;
        final hasDetailed = accounts.any((a) {
          final id = (a['_id'] ?? a['id'] ?? '').toString();
          return id.isNotEmpty && !id.startsWith('lazy_');
        });
        origin = hasDetailed ? 'derived' : 'standalone';
        await _mapShortcutsForLazyMode(uid);
      } else if (nextMode == 'detailed') {
        if (uid != null && prev == 'lazy') {
          await _migrateLazyToDetailedIfNeeded(uid);
          await _markShortcutsNeedDetailedConfirm(uid);
        }
        origin = 'detailed';
      }
      if (uid != null) {
        await _saveModeRemote(nextMode, uid: uid, origin: origin);
      }
      return true;
    } catch (e) {
      _mode = prev;
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _mapShortcutsForLazyMode(String uid) async {
    final accounts = await _accountService.watchAccounts(uid).first;
    final shortcuts = await _shortcutService.getShortcutsOnce();
    if (shortcuts.isEmpty) return;

    final accountTagById = <String, String>{};
    for (final a in accounts) {
      final id = (a['_id'] ?? a['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final tag = _normalizeTag((a[AccountFields.tag] ?? '').toString());
      if (tag == 'daily_use' || tag == 'savings' || tag == 'investment') {
        accountTagById[id] = tag;
      }
    }

    final updates = <Map<String, dynamic>>[];
    for (final s in shortcuts) {
      if (!s.useDefaultAccount) continue;
      final currentDefaultId = (s.defaultAccountId ?? '').trim();
      final type = s.type.toLowerCase();
      var poolTag = accountTagById[currentDefaultId];
      poolTag ??= type == 'income'
          ? LazyModeConfig.incomePrimaryCategory
          : LazyModeConfig.expensePrimaryCategory;
      final poolAccountId = switch (poolTag) {
        'daily_use' => 'virtual_daily_use_wallet',
        'savings' => 'virtual_savings_pool',
        _ => 'virtual_investment_pool',
      };
      updates.add({
        'id': s.id,
        'data': {
          ShortcutFields.detailedDefaultAccountId: currentDefaultId.isEmpty
              ? null
              : currentDefaultId,
          ShortcutFields.defaultPoolTag: poolTag,
          ShortcutFields.defaultAccountId: poolAccountId,
          ShortcutFields.requireDetailedReconfirm: false,
        },
      });
    }

    await _shortcutService.batchUpdateShortcuts(updates);
  }

  Future<void> _markShortcutsNeedDetailedConfirm(String uid) async {
    final shortcuts = await _shortcutService.getShortcutsOnce();
    if (shortcuts.isEmpty) return;

    final updates = <Map<String, dynamic>>[];
    for (final s in shortcuts) {
      if (!s.useDefaultAccount) continue;
      updates.add({
        'id': s.id,
        'data': {ShortcutFields.requireDetailedReconfirm: true},
      });
    }

    await _shortcutService.batchUpdateShortcuts(updates);
  }

  String _normalizeTag(String? raw) => (raw ?? '').trim().toLowerCase();
  double _toDouble(dynamic raw) => raw is num ? raw.toDouble() : 0.0;

  bool _isStandaloneLazyOrigin(String raw) {
    final v = raw.trim().toLowerCase();
    return v == 'standalone' || v == 'lazy' || v.isEmpty;
  }

  Future<void> _migrateLazyToDetailedIfNeeded(String uid) async {
    final settings = await _authService.getUserSettings(uid);
    final origin = (settings[UserSettingsFields.appModeOrigin] ?? '')
        .toString();

    if (!_isStandaloneLazyOrigin(origin)) return;

    final docs = await _accountService.watchAccounts(uid).first;

    final hasExistingDetailed = docs.any((d) {
      final id = (d['_id'] ?? d['id'] ?? '').toString();
      return id.isNotEmpty &&
          !id.startsWith('lazy_') &&
          !id.startsWith('virtual_');
    });
    if (hasExistingDetailed) return;

    double dailyUseTotal = 0;
    double savingsTotal = 0;
    double investmentTotal = 0;

    for (final m in docs) {
      final tag = _normalizeTag((m[AccountFields.tag] ?? '').toString());
      final bal = _toDouble(m[AccountFields.balance]);
      if (tag == 'daily_use') dailyUseTotal += bal;
      if (tag == 'savings') savingsTotal += bal;
      if (tag == 'investment') investmentTotal += bal;
    }

    final deleteIds = <String>[];
    for (final d in docs) {
      final id = (d['_id'] ?? d['id'] ?? '').toString();
      if (id.startsWith('lazy_') || id.startsWith('virtual_')) {
        deleteIds.add(id);
      }
    }

    final virtuals = <Map<String, dynamic>>[
      {
        'id': 'virtual_daily_use_wallet',
        AccountFields.name: 'Daily Use Wallet',
        AccountFields.provider: 'Daily Use Wallet',
        AccountFields.type: 'cash',
        AccountFields.kind: 'standard',
        AccountFields.tag: 'daily_use',
        AccountFields.isLiquid: true,
        AccountFields.isPrimary: true,
        AccountFields.isVirtual: true,
        AccountFields.balance: dailyUseTotal,
      },
      {
        'id': 'virtual_savings_pool',
        AccountFields.name: 'Savings Pool',
        AccountFields.provider: 'Savings Pool',
        AccountFields.type: 'bank',
        AccountFields.kind: 'standard',
        AccountFields.tag: 'savings',
        AccountFields.isLiquid: true,
        AccountFields.isPrimary: true,
        AccountFields.isVirtual: true,
        AccountFields.balance: savingsTotal,
      },
      {
        'id': 'virtual_investment_pool',
        AccountFields.name: 'Investment Pool',
        AccountFields.provider: 'Investment Pool',
        AccountFields.type: 'investment',
        AccountFields.kind: 'investment',
        AccountFields.tag: 'investment',
        AccountFields.isLiquid: false,
        AccountFields.isPrimary: true,
        AccountFields.isVirtual: true,
        AccountFields.balance: investmentTotal,
      },
    ];

    await _accountService.replaceAccounts(
      uid: uid,
      deleteIds: deleteIds,
      newAccounts: virtuals,
    );
  }

  Future<void> _saveModeRemote(
    String mode, {
    String? uid,
    String? origin,
  }) async {
    final targetUid = uid ?? _uid;
    if (targetUid == null) return;

    await _authService.updateUserMode(targetUid, mode, origin: origin);
  }

  Future<void> _loadRemoteMode(String uid) async {
    final settings = await _authService.getUserSettings(uid);
    final remote = (settings[UserSettingsFields.appMode] ?? '').toString();

    if (_isValidMode(remote)) {
      _mode = remote;
      await _local.saveAppMode(_mode);
    } else {
      await _saveModeRemote(_mode, uid: uid);
    }
  }

  void _bindModeStream(String uid) {
    if (_listeningUid == uid && _modeSub != null) return;

    _modeSub?.cancel();
    _listeningUid = uid;
    _modeSub = _authService.watchUserSettings(uid).listen((settings) async {
      final remote = (settings[UserSettingsFields.appMode] ?? '').toString();

      if (_isValidMode(remote)) {
        if (remote != _mode) {
          _mode = remote;
          await _local.saveAppMode(remote);
          notifyListeners();
        }
        return;
      }

      try {
        await _saveModeRemote(_mode, uid: uid);
      } catch (_) {}
    });
  }

  bool _isValidMode(String mode) => mode == 'lazy' || mode == 'detailed';

  @override
  void dispose() {
    _modeSub?.cancel();
    super.dispose();
  }
}
