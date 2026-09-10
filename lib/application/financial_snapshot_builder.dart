import '../core/models/financial_snapshot.dart';
import '../core/utils/investment_pnl_normalizer.dart';

class FinancialSnapshotBuildInput {
  const FinancialSnapshotBuildInput({
    required this.mode,
    required this.month,
    required this.now,
    required this.monthlyIncome,
    required this.monthlyExpense,
    this.budgetAmount,
    this.allocationGoal,
    this.actualAllocation,
    this.currentCategories = const [],
    this.previousCategories = const [],
    required this.hasPreviousMonthData,
    this.recurringPlans = const [],
    this.investmentPnlPoints = const [],
  });

  final FinancialMode mode;
  final DateTime month;
  final DateTime now;
  final double monthlyIncome;
  final double monthlyExpense;
  final double? budgetAmount;
  final AllocationGoalInput? allocationGoal;
  final ActualAllocationInput? actualAllocation;
  final List<CategorySpendingInput> currentCategories;
  final List<CategorySpendingInput> previousCategories;
  final bool hasPreviousMonthData;
  final List<RecurringCommitmentInput> recurringPlans;
  final List<InvestmentPnlInput> investmentPnlPoints;
}

class AllocationGoalInput {
  const AllocationGoalInput({
    required this.enabled,
    this.tolerance,
    this.dailyUseTargetPct,
    this.savingsTargetPct,
    this.investmentTargetPct,
  });

  final bool enabled;
  final double? tolerance;
  final double? dailyUseTargetPct;
  final double? savingsTargetPct;
  final double? investmentTargetPct;
}

class ActualAllocationInput {
  const ActualAllocationInput({
    required this.hasData,
    this.dailyUseActualPct,
    this.savingsActualPct,
    this.investmentActualPct,
  });

  final bool hasData;
  final double? dailyUseActualPct;
  final double? savingsActualPct;
  final double? investmentActualPct;
}

class CategorySpendingInput {
  const CategorySpendingInput({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  final String categoryId;
  final String categoryName;
  final double amount;
}

class RecurringCommitmentInput {
  const RecurringCommitmentInput({
    required this.type,
    required this.amount,
    required this.intervalDays,
    required this.startDate,
    required this.endDate,
    required this.nextRunAt,
    required this.active,
  });

  final String type;
  final double amount;
  final int intervalDays;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime nextRunAt;
  final bool active;
}

class InvestmentPnlInput {
  const InvestmentPnlInput({
    required this.date,
    required this.rawDiff,
    required this.pnlType,
    this.isGenuineInvestmentPnl = true,
  });

  final DateTime date;
  final double rawDiff;
  final String? pnlType;
  final bool isGenuineInvestmentPnl;
}

/// Builds verified financial facts from normalized, repository-owned inputs.
///
/// This class intentionally has no Firebase, network, current-clock, or UI
/// dependencies. Callers must provide [FinancialSnapshotBuildInput.now].
class FinancialSnapshotBuilder {
  const FinancialSnapshotBuilder();

  FinancialSnapshot build(FinancialSnapshotBuildInput input) {
    final month = DateTime(input.month.year, input.month.month);
    final isCurrentMonth = _isSameMonth(month, input.now);
    final cashFlow = CashFlowSnapshot(
      income: input.monthlyIncome,
      expense: input.monthlyExpense,
      netCashFlow: input.monthlyIncome - input.monthlyExpense,
    );
    final budget = _buildBudget(
      amount: input.budgetAmount,
      expense: input.monthlyExpense,
      month: month,
      now: input.now,
      isCurrentMonth: isCurrentMonth,
    );
    final allocation = _buildAllocation(
      goal: input.allocationGoal,
      actual: input.actualAllocation,
    );
    final spending = _buildSpending(
      mode: input.mode,
      current: input.currentCategories,
      previous: input.previousCategories,
      hasPreviousMonthData: input.hasPreviousMonthData,
    );
    final recurring = _buildRecurring(input.recurringPlans, input.now);
    final investment = _buildInvestment(input.investmentPnlPoints, month);
    final severity = _buildSeverity(
      budget: budget,
      allocation: allocation,
      categories: spending.categories,
    );
    final availability = FinancialAvailability(
      hasBudget: budget.hasBudget,
      hasPreviousMonthData: spending.hasPreviousMonthData,
      hasAllocationData: allocation.hasData,
      hasRecurringData: recurring.hasRecurringData,
      hasInvestmentData: investment.hasInvestmentData,
    );

    return FinancialSnapshot(
      context: FinancialSnapshotContext(
        mode: input.mode,
        period: month,
        generatedAt: input.now,
      ),
      cashFlow: cashFlow,
      budget: budget,
      allocation: allocation,
      spending: spending,
      recurring: recurring,
      investment: investment,
      availability: availability,
      severity: severity,
      evidence: _buildEvidence(
        cashFlow: cashFlow,
        budget: budget,
        allocation: allocation,
        spending: spending,
        recurring: recurring,
        investment: investment,
      ),
    );
  }

  BudgetSnapshot _buildBudget({
    required double? amount,
    required double expense,
    required DateTime month,
    required DateTime now,
    required bool isCurrentMonth,
  }) {
    if (amount == null || amount <= 0) {
      return const BudgetSnapshot(
        hasBudget: false,
        amount: null,
        remaining: null,
        usagePct: null,
        daysRemaining: null,
        safeDailySpend: null,
        expectedUsagePct: null,
        paceDeltaPp: null,
      );
    }

    final remaining = (amount - expense).clamp(0, double.infinity).toDouble();
    final usagePct = expense / amount * 100;
    if (!isCurrentMonth) {
      return BudgetSnapshot(
        hasBudget: true,
        amount: amount,
        remaining: remaining,
        usagePct: usagePct,
        daysRemaining: null,
        safeDailySpend: null,
        expectedUsagePct: null,
        paceDeltaPp: null,
      );
    }

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day + 1;
    final expectedUsagePct = now.day / daysInMonth * 100;
    return BudgetSnapshot(
      hasBudget: true,
      amount: amount,
      remaining: remaining,
      usagePct: usagePct,
      daysRemaining: daysRemaining,
      safeDailySpend: remaining / daysRemaining,
      expectedUsagePct: expectedUsagePct,
      paceDeltaPp: usagePct - expectedUsagePct,
    );
  }

  AllocationSnapshot _buildAllocation({
    required AllocationGoalInput? goal,
    required ActualAllocationInput? actual,
  }) {
    final hasData = actual?.hasData == true;
    final enabled = goal?.enabled == true;
    return AllocationSnapshot(
      enabled: enabled,
      hasData: hasData,
      tolerance: goal?.tolerance,
      dailyUse: _allocationBucket(
        actual: hasData ? actual?.dailyUseActualPct : null,
        target: goal?.dailyUseTargetPct,
      ),
      savings: _allocationBucket(
        actual: hasData ? actual?.savingsActualPct : null,
        target: goal?.savingsTargetPct,
      ),
      investment: _allocationBucket(
        actual: hasData ? actual?.investmentActualPct : null,
        target: goal?.investmentTargetPct,
      ),
    );
  }

  AllocationBucketSnapshot _allocationBucket({
    required double? actual,
    required double? target,
  }) => AllocationBucketSnapshot(
    actualPct: actual,
    targetPct: target,
    gapPp: actual != null && target != null ? actual - target : null,
  );

  SpendingSnapshot _buildSpending({
    required FinancialMode mode,
    required List<CategorySpendingInput> current,
    required List<CategorySpendingInput> previous,
    required bool hasPreviousMonthData,
  }) {
    final previousById = <String, double>{};
    if (hasPreviousMonthData) {
      for (final category in previous) {
        previousById[category.categoryId] =
            (previousById[category.categoryId] ?? 0) + category.amount;
      }
    }
    final currentById = <String, CategorySpendingInput>{};
    for (final category in current) {
      final existing = currentById[category.categoryId];
      currentById[category.categoryId] = existing == null
          ? category
          : CategorySpendingInput(
              categoryId: category.categoryId,
              categoryName: category.categoryName,
              amount: existing.amount + category.amount,
            );
    }
    final categories =
        currentById.values.map((category) {
          final previousAmount = hasPreviousMonthData
              ? (previousById[category.categoryId] ?? 0)
              : null;
          final changeAmount = previousAmount == null
              ? null
              : category.amount - previousAmount;
          final changePct = previousAmount != null && previousAmount > 0
              ? changeAmount! / previousAmount * 100
              : null;
          return CategoryComparisonSnapshot(
            categoryId: category.categoryId,
            categoryName: category.categoryName,
            currentAmount: category.amount,
            previousAmount: previousAmount,
            changeAmount: changeAmount,
            changePct: changePct,
            isMeaningfulIncrease:
                changeAmount != null &&
                changeAmount >= 30 &&
                changePct != null &&
                changePct >= 20,
            evidenceKeyPrefix:
                'category.${_categoryToken(category.categoryId)}',
          );
        }).toList()..sort((a, b) {
          final amount = b.currentAmount.compareTo(a.currentAmount);
          if (amount != 0) return amount;
          final id = a.categoryId.compareTo(b.categoryId);
          if (id != 0) return id;
          return a.categoryName.compareTo(b.categoryName);
        });

    final limit = mode == FinancialMode.lazy ? 2 : 5;
    return SpendingSnapshot(
      hasPreviousMonthData: hasPreviousMonthData,
      categories: List.unmodifiable(categories.take(limit)),
    );
  }

  String _categoryToken(String categoryId) {
    var hash = 0x811c9dc5;
    for (final unit in categoryId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'c_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  RecurringSnapshot _buildRecurring(
    List<RecurringCommitmentInput> plans,
    DateTime now,
  ) {
    final windowStart = _dateOnly(now);
    final windowEndExclusive = windowStart.add(const Duration(days: 30));
    var amount = 0.0;
    var occurrenceCount = 0;
    var hasRecurringData = false;

    for (final plan in plans) {
      if (!plan.active || plan.type.trim().toLowerCase() != 'expense') continue;
      if (plan.amount <= 0 || plan.intervalDays <= 0) continue;
      final endDate = _dateOnly(plan.endDate);
      if (endDate.isBefore(windowStart)) continue;
      hasRecurringData = true;
      var occurrence = _dateOnly(plan.nextRunAt);
      final startDate = _dateOnly(plan.startDate);
      if (occurrence.isBefore(startDate)) occurrence = startDate;
      while (occurrence.isBefore(windowStart)) {
        occurrence = occurrence.add(Duration(days: plan.intervalDays));
      }
      while (occurrence.isBefore(windowEndExclusive) &&
          !occurrence.isAfter(endDate)) {
        amount += plan.amount;
        occurrenceCount++;
        occurrence = occurrence.add(Duration(days: plan.intervalDays));
      }
    }

    return RecurringSnapshot(
      next30DaysAmount: amount,
      occurrenceCount: occurrenceCount,
      hasRecurringData: hasRecurringData,
    );
  }

  InvestmentSnapshot _buildInvestment(
    List<InvestmentPnlInput> points,
    DateTime month,
  ) {
    var monthlyPnl = 0.0;
    var hasInvestmentData = false;
    for (final point in points) {
      if (!point.isGenuineInvestmentPnl || !_isSameMonth(point.date, month)) {
        continue;
      }
      hasInvestmentData = true;
      monthlyPnl += normalizeInvestmentPnlDiff(
        rawDiff: point.rawDiff,
        pnlType: point.pnlType,
      );
    }
    return InvestmentSnapshot(
      monthlyPnl: monthlyPnl,
      hasInvestmentData: hasInvestmentData,
    );
  }

  FinancialSeverity _buildSeverity({
    required BudgetSnapshot budget,
    required AllocationSnapshot allocation,
    required List<CategoryComparisonSnapshot> categories,
  }) {
    var severity = FinancialSeverity.normal;
    if (budget.paceDeltaPp != null) {
      severity = _strongest(severity, _budgetSeverity(budget.paceDeltaPp!));
    }
    if (allocation.enabled &&
        allocation.hasData &&
        allocation.tolerance != null) {
      for (final bucket in [
        allocation.dailyUse,
        allocation.savings,
        allocation.investment,
      ]) {
        if (bucket.actualPct == null || bucket.targetPct == null) continue;
        severity = _strongest(
          severity,
          _allocationSeverity(
            (bucket.actualPct! - bucket.targetPct!).abs(),
            allocation.tolerance!,
          ),
        );
      }
    }
    if (categories.any((category) => category.isMeaningfulIncrease)) {
      severity = _strongest(severity, FinancialSeverity.worthWatching);
    }
    return severity;
  }

  FinancialSeverity _budgetSeverity(double paceDeltaPp) {
    if (paceDeltaPp >= 20) return FinancialSeverity.needsAttention;
    if (paceDeltaPp >= 10) return FinancialSeverity.worthWatching;
    return FinancialSeverity.normal;
  }

  FinancialSeverity _allocationSeverity(double deviation, double tolerance) {
    if (deviation > tolerance + 8) return FinancialSeverity.needsAttention;
    if (deviation > tolerance) return FinancialSeverity.worthWatching;
    return FinancialSeverity.normal;
  }

  FinancialSeverity _strongest(
    FinancialSeverity first,
    FinancialSeverity second,
  ) => first.index >= second.index ? first : second;

  Map<String, Object> _buildEvidence({
    required CashFlowSnapshot cashFlow,
    required BudgetSnapshot budget,
    required AllocationSnapshot allocation,
    required SpendingSnapshot spending,
    required RecurringSnapshot recurring,
    required InvestmentSnapshot investment,
  }) {
    final evidence = <String, Object>{
      'cashflow.income': cashFlow.income,
      'cashflow.expense': cashFlow.expense,
      'cashflow.net': cashFlow.netCashFlow,
    };
    void add(String key, Object? value) {
      if (value != null) evidence[key] = value;
    }

    add('budget.amount', budget.amount);
    add('budget.remaining', budget.remaining);
    add('budget.usage_pct', budget.usagePct);
    add('budget.safe_daily_spend', budget.safeDailySpend);
    add('budget.expected_usage_pct', budget.expectedUsagePct);
    add('budget.pace_delta_pp', budget.paceDeltaPp);
    _addAllocationEvidence(evidence, 'daily_use', allocation.dailyUse);
    _addAllocationEvidence(evidence, 'savings', allocation.savings);
    _addAllocationEvidence(evidence, 'investment', allocation.investment);
    for (final category in spending.categories) {
      final prefix = category.evidenceKeyPrefix;
      add('$prefix.current_amount', category.currentAmount);
      add('$prefix.previous_amount', category.previousAmount);
      add('$prefix.change_amount', category.changeAmount);
      add('$prefix.change_pct', category.changePct);
    }
    if (recurring.hasRecurringData) {
      evidence['recurring.next_30d_amount'] = recurring.next30DaysAmount;
      evidence['recurring.next_30d_occurrence_count'] =
          recurring.occurrenceCount;
    }
    if (investment.hasInvestmentData) {
      evidence['investment.monthly_pnl'] = investment.monthlyPnl;
    }
    return evidence;
  }

  void _addAllocationEvidence(
    Map<String, Object> evidence,
    String bucket,
    AllocationBucketSnapshot value,
  ) {
    if (value.actualPct != null) {
      evidence['allocation.$bucket.actual_pct'] = value.actualPct!;
    }
    if (value.targetPct != null) {
      evidence['allocation.$bucket.target_pct'] = value.targetPct!;
    }
    if (value.gapPp != null) {
      evidence['allocation.$bucket.gap_pp'] = value.gapPp!;
    }
  }

  bool _isSameMonth(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month;

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
