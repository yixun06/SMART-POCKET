enum FinancialMode { lazy, detailed }

enum FinancialSeverity { normal, worthWatching, needsAttention }

class FinancialSnapshotContext {
  const FinancialSnapshotContext({
    required this.mode,
    required this.period,
    required this.generatedAt,
  });

  final FinancialMode mode;
  final DateTime period;
  final DateTime generatedAt;

  Map<String, Object> toJson() => {
    'mode': mode.name,
    'period':
        '${period.year.toString().padLeft(4, '0')}-${period.month.toString().padLeft(2, '0')}',
    'generated_at': generatedAt.toIso8601String(),
  };
}

class CashFlowSnapshot {
  const CashFlowSnapshot({
    required this.income,
    required this.expense,
    required this.netCashFlow,
  });

  final double income;
  final double expense;
  final double netCashFlow;

  Map<String, Object> toJson() => {
    'income': income,
    'expense': expense,
    'net_cash_flow': netCashFlow,
  };
}

class BudgetSnapshot {
  const BudgetSnapshot({
    required this.hasBudget,
    required this.amount,
    required this.remaining,
    required this.usagePct,
    required this.daysRemaining,
    required this.safeDailySpend,
    required this.expectedUsagePct,
    required this.paceDeltaPp,
  });

  final bool hasBudget;
  final double? amount;
  final double? remaining;
  final double? usagePct;
  final int? daysRemaining;
  final double? safeDailySpend;
  final double? expectedUsagePct;
  final double? paceDeltaPp;

  Map<String, Object?> toJson() => {
    'has_budget': hasBudget,
    'amount': amount,
    'remaining': remaining,
    'usage_pct': usagePct,
    'days_remaining': daysRemaining,
    'safe_daily_spend': safeDailySpend,
    'expected_usage_pct': expectedUsagePct,
    'pace_delta_pp': paceDeltaPp,
  };
}

class AllocationBucketSnapshot {
  const AllocationBucketSnapshot({
    required this.actualPct,
    required this.targetPct,
    required this.gapPp,
  });

  final double? actualPct;
  final double? targetPct;
  final double? gapPp;

  Map<String, Object?> toJson() => {
    'actual_pct': actualPct,
    'target_pct': targetPct,
    'gap_pp': gapPp,
  };
}

class AllocationSnapshot {
  const AllocationSnapshot({
    required this.enabled,
    required this.hasData,
    required this.tolerance,
    required this.dailyUse,
    required this.savings,
    required this.investment,
  });

  final bool enabled;
  final bool hasData;
  final double? tolerance;
  final AllocationBucketSnapshot dailyUse;
  final AllocationBucketSnapshot savings;
  final AllocationBucketSnapshot investment;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'has_data': hasData,
    'tolerance': tolerance,
    'daily_use': dailyUse.toJson(),
    'savings': savings.toJson(),
    'investment': investment.toJson(),
  };
}

class CategoryComparisonSnapshot {
  const CategoryComparisonSnapshot({
    required this.categoryId,
    required this.categoryName,
    required this.currentAmount,
    required this.previousAmount,
    required this.changeAmount,
    required this.changePct,
    required this.isMeaningfulIncrease,
    required this.evidenceKeyPrefix,
  });

  final String categoryId;
  final String categoryName;
  final double currentAmount;
  final double? previousAmount;
  final double? changeAmount;
  final double? changePct;
  final bool isMeaningfulIncrease;
  final String evidenceKeyPrefix;

  Map<String, Object?> toJson() => {
    'category_id': categoryId,
    'category_name': categoryName,
    'current_amount': currentAmount,
    'previous_amount': previousAmount,
    'change_amount': changeAmount,
    'change_pct': changePct,
    'is_meaningful_increase': isMeaningfulIncrease,
    'evidence_key_prefix': evidenceKeyPrefix,
  };
}

class SpendingSnapshot {
  const SpendingSnapshot({
    required this.hasPreviousMonthData,
    required this.categories,
  });

  final bool hasPreviousMonthData;
  final List<CategoryComparisonSnapshot> categories;

  Map<String, Object> toJson() => {
    'has_previous_month_data': hasPreviousMonthData,
    'categories': categories.map((category) => category.toJson()).toList(),
  };
}

class RecurringSnapshot {
  const RecurringSnapshot({
    required this.next30DaysAmount,
    required this.occurrenceCount,
    required this.hasRecurringData,
  });

  final double next30DaysAmount;
  final int occurrenceCount;
  final bool hasRecurringData;

  Map<String, Object> toJson() => {
    'next_30d_amount': next30DaysAmount,
    'next_30d_occurrence_count': occurrenceCount,
    'has_recurring_data': hasRecurringData,
  };
}

class InvestmentSnapshot {
  const InvestmentSnapshot({
    required this.monthlyPnl,
    required this.hasInvestmentData,
  });

  final double monthlyPnl;
  final bool hasInvestmentData;

  Map<String, Object> toJson() => {
    'monthly_pnl': monthlyPnl,
    'has_investment_data': hasInvestmentData,
  };
}

class FinancialAvailability {
  const FinancialAvailability({
    required this.hasBudget,
    required this.hasPreviousMonthData,
    required this.hasAllocationData,
    required this.hasRecurringData,
    required this.hasInvestmentData,
  });

  final bool hasBudget;
  final bool hasPreviousMonthData;
  final bool hasAllocationData;
  final bool hasRecurringData;
  final bool hasInvestmentData;

  Map<String, bool> toJson() => {
    'has_budget': hasBudget,
    'has_previous_month_data': hasPreviousMonthData,
    'has_allocation_data': hasAllocationData,
    'has_recurring_data': hasRecurringData,
    'has_investment_data': hasInvestmentData,
  };
}

class FinancialSnapshot {
  FinancialSnapshot({
    required this.context,
    required this.cashFlow,
    required this.budget,
    required this.allocation,
    required this.spending,
    required this.recurring,
    required this.investment,
    required this.availability,
    required this.severity,
    required Map<String, Object> evidence,
  }) : _evidence = Map.unmodifiable(evidence);

  final FinancialSnapshotContext context;
  final CashFlowSnapshot cashFlow;
  final BudgetSnapshot budget;
  final AllocationSnapshot allocation;
  final SpendingSnapshot spending;
  final RecurringSnapshot recurring;
  final InvestmentSnapshot investment;
  final FinancialAvailability availability;
  final FinancialSeverity severity;
  final Map<String, Object> _evidence;

  Map<String, Object> get evidence => _evidence;

  bool hasEvidence(String key) => _evidence.containsKey(key);

  Object? evidenceValue(String key) => _evidence[key];

  Map<String, Object?> toJson() => {
    'context': context.toJson(),
    'cash_flow': cashFlow.toJson(),
    'budget': budget.toJson(),
    'allocation': allocation.toJson(),
    'spending': spending.toJson(),
    'recurring': recurring.toJson(),
    'investment': investment.toJson(),
    'availability': availability.toJson(),
    'severity': severity.name,
    'evidence': _evidence,
  };
}
