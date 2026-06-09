import 'package:flutter/foundation.dart';

import '../../data/services/budget_service.dart';

class BudgetController extends ChangeNotifier {
  final BudgetService _service;
  BudgetController(this._service);

  bool isLoading = false;
  String? errorMessage;

  DateTime currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime get selectedMonth => currentMonth;

  double monthlyBudget = 0.0;

  Future<void> init() async => loadCurrentBudget();

  Future<void> loadCurrentBudget() async {
    await _loadByMonth(currentMonth);
  }

  Future<void> changeMonth(DateTime month) async {
    currentMonth = DateTime(month.year, month.month, 1);
    await _loadByMonth(currentMonth);
  }

  Future<void> _loadByMonth(DateTime month) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      monthlyBudget = await _service.getBudgetForMonth(month);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveBudget(String amountText) async {
    final amount = double.tryParse(amountText.trim());
    if (amount == null || amount < 0) {
      errorMessage = 'Invalid budget amount';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _service.upsertBudgetForMonth(month: currentMonth, amount: amount);
      monthlyBudget = amount;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setBudget(String amountText) => saveBudget(amountText);
  Future<void> updateBudget(String amountText) => saveBudget(amountText);

  Future<bool> saveBudgetWithNote(String amountText, {String? note}) async {
    await saveBudget(amountText);
    return errorMessage == null;
  }

  Future<void> deleteCurrentMonthBudget() async {
    await _service.deleteBudgetForMonth(currentMonth);
    monthlyBudget = 0.0;
    notifyListeners();
  }

  Future<void> handleAuthChanged() async {
    monthlyBudget = 0.0;
    errorMessage = null;
    notifyListeners();
    await loadCurrentBudget();
  }
}
