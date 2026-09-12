import '../core/models/category_model.dart';
import '../core/models/financial_snapshot.dart';
import '../core/models/investment_pnl_point.dart';
import '../core/models/recurring_plan_model.dart';
import '../core/utils/constants.dart';
import '../data/services/account_service.dart';
import '../data/services/allocation_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/budget_service.dart';
import '../data/services/category_service.dart';
import '../data/services/recurring_service.dart';
import '../data/services/transaction_service.dart';
import 'controllers/config_controller.dart';
import 'financial_snapshot_builder.dart';

enum FinancialSnapshotCollectionFailureReason {
  unauthenticated,
  invalidMode,
  monthlySummaryUnavailable,
}

final class FinancialSnapshotCollectionFailure implements Exception {
  const FinancialSnapshotCollectionFailure(this.reason);

  final FinancialSnapshotCollectionFailureReason reason;

  String get userMessage => switch (reason) {
    FinancialSnapshotCollectionFailureReason.unauthenticated =>
      'Please sign in to prepare an AI insight.',
    FinancialSnapshotCollectionFailureReason.invalidMode =>
      'AI insight is unavailable for the current app mode.',
    FinancialSnapshotCollectionFailureReason.monthlySummaryUnavailable =>
      'Financial data is temporarily unavailable.',
  };
}

abstract interface class FinancialSnapshotDataSource {
  String? get currentUserId;
  String get appMode;

  Future<Map<String, double>> monthlySummary(DateTime month);
  Future<List<Map<String, dynamic>>> monthlyExpensesByCategory(DateTime month);
  Future<double> budgetForMonth(DateTime month);
  Future<Map<String, dynamic>> allocationGoals();
  Future<Map<String, double>> actualAllocation();
  Future<List<CategoryModel>> categories();
  Future<List<RecurringPlanModel>> recurringPlans(String uid);
  Future<List<InvestmentPnlPoint>> investmentPnlPoints();
}

final class ExistingFinancialSnapshotDataSource
    implements FinancialSnapshotDataSource {
  ExistingFinancialSnapshotDataSource({
    required AuthService authService,
    required ConfigController configController,
    required TransactionService transactionService,
    required BudgetService budgetService,
    required AssetAllocationService allocationService,
    required CategoryService categoryService,
    required RecurringService recurringService,
    required AccountService accountService,
    this.streamTimeout = const Duration(seconds: 20),
  }) : _authService = authService,
       _configController = configController,
       _transactionService = transactionService,
       _budgetService = budgetService,
       _allocationService = allocationService,
       _categoryService = categoryService,
       _recurringService = recurringService,
       _accountService = accountService;

  final AuthService _authService;
  final ConfigController _configController;
  final TransactionService _transactionService;
  final BudgetService _budgetService;
  final AssetAllocationService _allocationService;
  final CategoryService _categoryService;
  final RecurringService _recurringService;
  final AccountService _accountService;
  final Duration streamTimeout;

  @override
  String? get currentUserId => _authService.currentUserId;

  @override
  String get appMode => _configController.appMode;

  String get _requiredUid {
    final uid = currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      throw const FinancialSnapshotCollectionFailure(
        FinancialSnapshotCollectionFailureReason.unauthenticated,
      );
    }
    return uid;
  }

  @override
  Future<Map<String, double>> monthlySummary(DateTime month) =>
      _transactionService
          .watchMonthlySummaryByMonth(_requiredUid, month: month)
          .first
          .timeout(streamTimeout);

  @override
  Future<List<Map<String, dynamic>>> monthlyExpensesByCategory(
    DateTime month,
  ) => _transactionService
      .watchMonthlyExpenseByCategoryByMonth(_requiredUid, month: month)
      .first
      .timeout(streamTimeout);

  @override
  Future<double> budgetForMonth(DateTime month) =>
      _budgetService.getBudgetForMonth(month).timeout(streamTimeout);

  @override
  Future<Map<String, dynamic>> allocationGoals() =>
      _allocationService.loadGoals(_requiredUid).timeout(streamTimeout);

  @override
  Future<Map<String, double>> actualAllocation() => _allocationService
      .watchActualAllocation(_requiredUid)
      .first
      .timeout(streamTimeout);

  @override
  Future<List<CategoryModel>> categories() =>
      _categoryService.getAllCategories().timeout(streamTimeout);

  @override
  Future<List<RecurringPlanModel>> recurringPlans(String uid) =>
      _recurringService.watchPlans(uid).first.timeout(streamTimeout);

  @override
  Future<List<InvestmentPnlPoint>> investmentPnlPoints() => _accountService
      .watchInvestmentPnlPoints(_requiredUid, limit: 500)
      .first
      .timeout(streamTimeout);
}

final class FinancialSnapshotCollector {
  const FinancialSnapshotCollector({
    required FinancialSnapshotDataSource source,
    this.builder = const FinancialSnapshotBuilder(),
  }) : _source = source;

  final FinancialSnapshotDataSource _source;
  final FinancialSnapshotBuilder builder;

  String? get currentUserId => _source.currentUserId;

  Future<FinancialSnapshot> buildCurrentSnapshot({
    required DateTime now,
  }) async {
    final uid = _source.currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      throw const FinancialSnapshotCollectionFailure(
        FinancialSnapshotCollectionFailureReason.unauthenticated,
      );
    }

    final mode = switch (_source.appMode.trim().toLowerCase()) {
      'lazy' => FinancialMode.lazy,
      'detailed' => FinancialMode.detailed,
      _ => throw const FinancialSnapshotCollectionFailure(
        FinancialSnapshotCollectionFailureReason.invalidMode,
      ),
    };
    final month = DateTime(now.year, now.month, 1);
    final previousMonth = DateTime(now.year, now.month - 1, 1);

    final Map<String, double> summary;
    try {
      summary = await _source.monthlySummary(month);
    } catch (_) {
      throw const FinancialSnapshotCollectionFailure(
        FinancialSnapshotCollectionFailureReason.monthlySummaryUnavailable,
      );
    }
    final income = _requiredFinancialValue(summary['income']);
    final expense = _requiredFinancialValue(summary['expense']);
    if (income == null || expense == null) {
      throw const FinancialSnapshotCollectionFailure(
        FinancialSnapshotCollectionFailureReason.monthlySummaryUnavailable,
      );
    }

    final currentRowsFuture = _optional(
      () => _source.monthlyExpensesByCategory(month),
      const <Map<String, dynamic>>[],
    );
    final previousRowsFuture = _optional(
      () => _source.monthlyExpensesByCategory(previousMonth),
      const <Map<String, dynamic>>[],
    );
    final categoriesFuture = _optional(
      _source.categories,
      const <CategoryModel>[],
    );
    final budgetFuture = _optional<double?>(
      () => _source.budgetForMonth(month),
      null,
    );
    final goalFuture = _optional<Map<String, dynamic>?>(
      _source.allocationGoals,
      null,
    );
    final actualFuture = _optional<Map<String, double>?>(
      _source.actualAllocation,
      null,
    );
    final plansFuture = _optional(
      () => _source.recurringPlans(uid),
      const <RecurringPlanModel>[],
    );
    final pnlPointsFuture = _optional(
      _source.investmentPnlPoints,
      const <InvestmentPnlPoint>[],
    );

    final currentRows = await currentRowsFuture;
    final previousRows = await previousRowsFuture;
    final categories = await categoriesFuture;
    final namesById = {
      for (final category in categories)
        if (category.id.trim().isNotEmpty) category.id: category.name,
    };

    final budgetValue = await budgetFuture;
    final goal = await goalFuture;
    final actual = await actualFuture;
    final plans = await plansFuture;
    final pnlPoints = await pnlPointsFuture;

    return builder.build(
      FinancialSnapshotBuildInput(
        mode: mode,
        month: month,
        now: now,
        monthlyIncome: income,
        monthlyExpense: expense,
        budgetAmount: budgetValue != null && budgetValue > 0
            ? budgetValue
            : null,
        allocationGoal: _allocationGoal(goal),
        actualAllocation: _actualAllocation(actual),
        currentCategories: _categoryInputs(currentRows, namesById),
        previousCategories: _categoryInputs(previousRows, namesById),
        hasPreviousMonthData: previousRows.isNotEmpty,
        recurringPlans: plans
            .map(
              (plan) => RecurringCommitmentInput(
                type: plan.type,
                amount: plan.amount,
                intervalDays: plan.intervalDays,
                startDate: plan.startDate,
                endDate: plan.endDate,
                nextRunAt: plan.nextRunAt,
                active: plan.active,
              ),
            )
            .toList(growable: false),
        investmentPnlPoints: pnlPoints
            .map(
              (point) => InvestmentPnlInput(
                date: point.date,
                rawDiff: point.diff,
                pnlType: null,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  double? _requiredFinancialValue(Object? value) {
    if (value is! num) return null;
    final result = value.toDouble();
    return result.isFinite && result >= 0 ? result : null;
  }

  List<CategorySpendingInput> _categoryInputs(
    List<Map<String, dynamic>> rows,
    Map<String, String> namesById,
  ) {
    final result = <CategorySpendingInput>[];
    for (final row in rows) {
      final id = (row['categoryId'] ?? '').toString().trim();
      final rawAmount = row['amount'];
      if (id.isEmpty || rawAmount is! num) continue;
      final amount = rawAmount.toDouble();
      if (!amount.isFinite || amount < 0) continue;
      final resolvedName = namesById[id]?.trim();
      result.add(
        CategorySpendingInput(
          categoryId: id,
          categoryName: resolvedName == null || resolvedName.isEmpty
              ? 'Uncategorized'
              : resolvedName,
          amount: amount,
        ),
      );
    }
    return result;
  }

  AllocationGoalInput? _allocationGoal(Map<String, dynamic>? value) {
    if (value == null) return null;
    final targets = value[AllocationFields.targets];
    if (targets is! Map) return null;
    return AllocationGoalInput(
      enabled: value[AllocationFields.enabled] == true,
      tolerance: _optionalDouble(value[AllocationFields.tolerance]),
      dailyUseTargetPct: _optionalDouble(targets[AllocationFields.dailyUse]),
      savingsTargetPct: _optionalDouble(targets[AllocationFields.savings]),
      investmentTargetPct: _optionalDouble(
        targets[AllocationFields.investment],
      ),
    );
  }

  ActualAllocationInput? _actualAllocation(Map<String, double>? value) {
    if (value == null) return null;
    return ActualAllocationInput(
      hasData: value['_hasData'] == 1,
      dailyUseActualPct: _optionalDouble(value[AllocationFields.dailyUse]),
      savingsActualPct: _optionalDouble(value[AllocationFields.savings]),
      investmentActualPct: _optionalDouble(value[AllocationFields.investment]),
    );
  }

  double? _optionalDouble(Object? value) {
    if (value is! num) return null;
    final result = value.toDouble();
    return result.isFinite ? result : null;
  }

  Future<T> _optional<T>(Future<T> Function() load, T fallback) async {
    try {
      return await load();
    } catch (_) {
      return fallback;
    }
  }
}
