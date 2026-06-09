import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/investment_pnl_point.dart';
import '../../data/services/account_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/pdf_service.dart';
import '../../data/services/transaction_service.dart';

class AnalyticsController extends ChangeNotifier {
  AnalyticsController(
    this._transactionService,
    this._accountService,
    this._pdfService,
    this._authService,
  );

  final TransactionService _transactionService;
  final AccountService _accountService;
  final PdfService _pdfService;
  final AuthService _authService;

  String? get uid => _authService.currentUserId;

  Stream<Map<String, double>> watchMonthlySummary(DateTime month) {
    final userId = uid;
    if (userId == null) return Stream.value(const {});
    return _transactionService.watchMonthlySummaryByMonth(userId, month: month);
  }

  Stream<List<Map<String, dynamic>>> watchMonthlyExpenseByCategory(
    DateTime month,
  ) {
    final userId = uid;
    if (userId == null) return Stream.value(const []);
    return _transactionService.watchMonthlyExpenseByCategoryByMonth(
      userId,
      month: month,
    );
  }

  Stream<List<Map<String, dynamic>>> watchMonthlyCashFlowCalendar(
    DateTime month,
  ) {
    final userId = uid;
    if (userId == null) return Stream.value(const []);
    return _transactionService.watchMonthlyCashFlowCalendar(
      userId,
      month: month,
    );
  }

  Stream<List<InvestmentPnlPoint>> watchInvestmentPnlPoints() {
    final userId = uid;
    if (userId == null) return Stream.value(const []);
    return _accountService.watchInvestmentPnlPoints(userId, limit: 500);
  }

  Future<String> exportMonthlyReport({
    required DateTime month,
    required String Function(String categoryId) categoryNameResolver,
    required double budget,
    required double totalAssets,
    required List<Map<String, dynamic>> accounts,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final userId = _requireUid();
    final rows = await _transactionService.getMonthlyTransactionsForExport(
      userId,
      month: month,
      categoryNameResolver: categoryNameResolver,
    );
    final summary = await _transactionService
        .watchMonthlySummaryByMonth(userId, month: month)
        .first;

    return _pdfService
        .exportMonthlyPdf(
          month: month,
          rows: rows,
          income: _toDouble(summary['income']),
          expense: _toDouble(summary['expense']),
          budget: budget,
          totalAssets: totalAssets,
          accounts: accounts,
        )
        .timeout(timeout);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0.0;
    return 0.0;
  }

  String _requireUid() {
    final userId = uid;
    if (userId == null) throw Exception('Please login first');
    return userId;
  }
}
