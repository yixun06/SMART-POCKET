import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/models/shortcut_model.dart';
import '../../data/services/shortcut_service.dart';
import 'transaction_controller.dart';

class ShortcutExecutionResult {
  final bool success;
  final String? errorMessage;
  final Map<String, double> splitDetails;
  final List<String> fallbackWarnings;
  final String type;
  final double amount;

  const ShortcutExecutionResult({
    required this.success,
    this.errorMessage,
    this.splitDetails = const {},
    this.fallbackWarnings = const [],
    required this.type,
    required this.amount,
  });
}

class ShortcutController extends ChangeNotifier {
  final ShortcutService _service;
  final TransactionController _tx;

  ShortcutController(this._service, this._tx);

  bool isLoading = false;
  String? errorMessage;
  List<ShortcutModel> shortcuts = [];

  StreamSubscription<List<ShortcutModel>>? _sub;

  void bind() {
    _sub?.cancel();
    isLoading = true;
    notifyListeners();

    try {
      _sub = _service.watchShortcuts().listen((list) {
        shortcuts = list;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      }, onError: (e) {
        isLoading = false;
        errorMessage = e.toString();
        notifyListeners();
      });
    } catch (e) {
      isLoading = false;
      errorMessage = null;
      shortcuts = [];
      notifyListeners();
    }
  }

  void rebind() {
    _sub?.cancel();
    _sub = null;
    shortcuts = [];
    errorMessage = null;
    bind();
  }

  Future<void> addShortcut({
    required String label,
    required String categoryId,
    required String amountText,
    required String type, // expense | income
    required bool useDefaultAccount,
    String? defaultAccountId,
  }) async {
    errorMessage = null;
    final amount = double.tryParse(amountText.trim());

    if (label.trim().isEmpty) {
      errorMessage = 'Label required';
      notifyListeners();
      return;
    }
    if (amount == null || amount <= 0) {
      errorMessage = 'Invalid Number';
      notifyListeners();
      return;
    }
    if (type != 'expense' && type != 'income') {
      errorMessage = 'Invalid shortcut type';
      notifyListeners();
      return;
    }

    try {
      await _service.createShortcut(
        label: label.trim(),
        categoryId: categoryId,
        amount: amount,
        type: type,
        useDefaultAccount: useDefaultAccount,
        defaultAccountId: defaultAccountId,
      );
      await refreshOnce();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateShortcut({
    required String id,
    required String label,
    required String categoryId,
    required String amountText,
    required String type,
    required bool useDefaultAccount,
    String? defaultAccountId,
  }) async {
    errorMessage = null;
    final amount = double.tryParse(amountText.trim());

    if (label.trim().isEmpty) {
      errorMessage = 'Label required';
      notifyListeners();
      return;
    }
    if (amount == null || amount <= 0) {
      errorMessage = 'Invalid Number';
      notifyListeners();
      return;
    }
    if (type != 'expense' && type != 'income') {
      errorMessage = 'Invalid shortcut type';
      notifyListeners();
      return;
    }

    try {
      await _service.updateShortcut(
        id: id,
        label: label.trim(),
        categoryId: categoryId,
        amount: amount,
        type: type,
        useDefaultAccount: useDefaultAccount,
        defaultAccountId: defaultAccountId,
      );
      await refreshOnce();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshOnce() async {
    try {
      shortcuts = await _service.getShortcutsOnce();
      notifyListeners();
    } catch (_) {}
  }

  Future<ShortcutExecutionResult> executeShortcut({
    required ShortcutModel s,
    required bool isLazyMode,
    String? accountId,
    String? lazyCategoryTag,
  }) async {
    if (isLazyMode) {
      final ok = await _tx.addTxLazyMode(
        categoryId: s.categoryId,
        categoryTag: lazyCategoryTag,
        type: s.type,
        amountText: s.amount.toString(),
        note: s.label,
        source: 'shortcut',
      );
      if (!ok) {
        return ShortcutExecutionResult(
          success: false,
          errorMessage: _tx.errorMessage ?? 'Failed',
          type: s.type,
          amount: s.amount,
        );
      }
      return ShortcutExecutionResult(
        success: true,
        splitDetails: _tx.lastCommittedAllocation ?? const {},
        fallbackWarnings: _tx.lastCommittedFallbackWarnings ?? const [],
        type: s.type,
        amount: s.amount,
      );
    }

    if (accountId == null || accountId.trim().isEmpty) {
      return ShortcutExecutionResult(
        success: false,
        errorMessage: 'Please select an account',
        type: s.type,
        amount: s.amount,
      );
    }

    final ok = await _tx.addTx(
      accountId: accountId,
      categoryId: s.categoryId,
      type: s.type, // expense / income
      amountText: s.amount.toString(),
      note: s.label,
      source: 'shortcut',
    );
    if (!ok) {
      return ShortcutExecutionResult(
        success: false,
        errorMessage: _tx.errorMessage ?? 'Failed',
        type: s.type,
        amount: s.amount,
      );
    }
    return ShortcutExecutionResult(
      success: true,
      splitDetails: {accountId: s.amount},
      type: s.type,
      amount: s.amount,
    );
  }

  Future<void> deleteShortcut(String id) async {
    await _service.deleteShortcut(id);
    await refreshOnce();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
