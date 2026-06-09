import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/recurring_plan_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/recurring_service.dart';

class RecurringController extends ChangeNotifier {
  final RecurringService _service;
  final AuthService _authService;

  RecurringController(this._service, this._authService);

  List<RecurringPlanModel> plans = [];
  bool isLoading = false;
  String? errorMessage;

  StreamSubscription<List<RecurringPlanModel>>? _plansSub;
  bool _bound = false;
  bool _runningCatchUp = false;

  String? get uid => _authService.currentUserId;

  void bind() {
    final u = uid;
    if (u == null) return;
    if (_bound) return;
    _bound = true;

    isLoading = true;
    notifyListeners();

    _plansSub = _service.watchPlans(u).listen(
      (rows) {
        plans = rows;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        errorMessage = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );

    unawaited(runTodayCatchUp());
  }

  void resetBinding() {
    _plansSub?.cancel();
    _plansSub = null;
    _bound = false;
    plans = [];
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> watchFailureNotifications() {
    final u = uid;
    if (u == null) return Stream.value(const []);
    return _service.watchFailureNotifications(u);
  }

  Future<void> markFailureNotificationRead(String id) async {
    final u = uid;
    if (u == null) return;
    await _service.markNotificationRead(u, id);
  }

  Future<bool> createPlan({
    required String type,
    required String label,
    required String amountText,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    String? note,
    required int intervalDays,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final u = uid;
    if (u == null) {
      errorMessage = 'Please login first';
      notifyListeners();
      return false;
    }

    final amount = double.tryParse(amountText.trim());
    if (amount == null || amount <= 0) {
      errorMessage = 'Invalid amount';
      notifyListeners();
      return false;
    }
    if (intervalDays <= 0) {
      errorMessage = 'Invalid frequency';
      notifyListeners();
      return false;
    }
    if (endDate.isBefore(startDate)) {
      errorMessage = 'End date must be after start date';
      notifyListeners();
      return false;
    }

    try {
      errorMessage = null;
      final id = 'rp_${DateTime.now().millisecondsSinceEpoch}';

      await _service.createPlan(
        uid: u,
        id: id,
        type: type,
        label: label.trim().isEmpty ? 'Recurring ${type.toUpperCase()}' : label.trim(),
        amount: amount,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        note: note,
        intervalDays: intervalDays,
        startDate: startDate,
        endDate: endDate,
      );

      await runTodayCatchUp();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePlan({
    required String id,
    required String type,
    required String label,
    required String amountText,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    String? note,
    required int intervalDays,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final u = uid;
    if (u == null) {
      errorMessage = 'Please login first';
      notifyListeners();
      return false;
    }

    final amount = double.tryParse(amountText.trim());
    if (amount == null || amount <= 0) {
      errorMessage = 'Invalid amount';
      notifyListeners();
      return false;
    }
    if (intervalDays <= 0) {
      errorMessage = 'Invalid frequency';
      notifyListeners();
      return false;
    }
    if (endDate.isBefore(startDate)) {
      errorMessage = 'End date must be after start date';
      notifyListeners();
      return false;
    }

    try {
      errorMessage = null;
      await _service.updatePlanFutureOnly(
        uid: u,
        id: id,
        type: type,
        label: label.trim().isEmpty ? 'Recurring ${type.toUpperCase()}' : label.trim(),
        amount: amount,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        note: note,
        intervalDays: intervalDays,
        startDate: startDate,
        endDate: endDate,
      );

      await runTodayCatchUp();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> deletePlan(String id) async {
    final u = uid;
    if (u == null) return;
    await _service.deletePlan(u, id);
  }

  Future<void> toggleActive(String id, bool active) async {
    final u = uid;
    if (u == null) return;
    await _service.setPlanActive(u, id, active);
    if (active) await runTodayCatchUp();
  }

  Future<void> runTodayCatchUp() async {
    final u = uid;
    if (u == null) return;
    if (_runningCatchUp) return;

    _runningCatchUp = true;
    try {
      await _service.runDuePlansForDate(uid: u, date: DateTime.now());
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    } finally {
      _runningCatchUp = false;
    }
  }

  Future<Map<String, int>> runTodayCatchUpWithSummary() async {
    final u = uid;
    if (u == null) return {'success': 0, 'failed': 0};
    if (_runningCatchUp) return {'success': 0, 'failed': 0};

    _runningCatchUp = true;
    try {
      return await _service.runDuePlansForDateWithSummary(
        uid: u,
        date: DateTime.now(),
      );
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return {'success': 0, 'failed': 0};
    } finally {
      _runningCatchUp = false;
    }
  }

  @override
  void dispose() {
    _plansSub?.cancel();
    _plansSub = null;
    _bound = false;
    super.dispose();
  }
}
