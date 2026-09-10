import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pocket/application/financial_snapshot_builder.dart';
import 'package:smart_pocket/core/models/financial_snapshot.dart';
import 'package:smart_pocket/core/utils/investment_pnl_normalizer.dart';

void main() {
  const builder = FinancialSnapshotBuilder();
  final now = DateTime(2026, 3, 10, 9, 30);

  FinancialSnapshotBuildInput input({
    FinancialMode mode = FinancialMode.detailed,
    DateTime? month,
    DateTime? referenceTime,
    double income = 0,
    double expense = 0,
    double? budgetAmount,
    AllocationGoalInput? allocationGoal,
    ActualAllocationInput? actualAllocation,
    List<CategorySpendingInput> currentCategories = const [],
    List<CategorySpendingInput> previousCategories = const [],
    bool hasPreviousMonthData = false,
    List<RecurringCommitmentInput> recurringPlans = const [],
    List<InvestmentPnlInput> investmentPnlPoints = const [],
  }) => FinancialSnapshotBuildInput(
    mode: mode,
    month: month ?? now,
    now: referenceTime ?? now,
    monthlyIncome: income,
    monthlyExpense: expense,
    budgetAmount: budgetAmount,
    allocationGoal: allocationGoal,
    actualAllocation: actualAllocation,
    currentCategories: currentCategories,
    previousCategories: previousCategories,
    hasPreviousMonthData: hasPreviousMonthData,
    recurringPlans: recurringPlans,
    investmentPnlPoints: investmentPnlPoints,
  );

  group('cash flow and budget', () {
    test(
      'uses supplied verified monthly totals and derives current budget pace',
      () {
        final snapshot = builder.build(
          input(income: 2500, expense: 500, budgetAmount: 800),
        );

        expect(snapshot.cashFlow.income, 2500);
        expect(snapshot.cashFlow.expense, 500);
        expect(snapshot.cashFlow.netCashFlow, 2000);
        expect(snapshot.budget.remaining, 300);
        expect(snapshot.budget.usagePct, 62.5);
        expect(snapshot.budget.daysRemaining, 22);
        expect(snapshot.budget.safeDailySpend, closeTo(300 / 22, 0.000001));
        expect(
          snapshot.budget.expectedUsagePct,
          closeTo(10 / 31 * 100, 0.000001),
        );
        expect(
          snapshot.budget.paceDeltaPp,
          closeTo(62.5 - 10 / 31 * 100, 0.000001),
        );
      },
    );

    test('calculates net cash flow without reinterpreting totals', () {
      final snapshot = builder.build(input(income: 2500, expense: 1780));

      expect(snapshot.cashFlow.netCashFlow, 720);
    });

    test('preserves overspending and never makes remaining negative', () {
      final snapshot = builder.build(input(expense: 1000, budgetAmount: 800));

      expect(snapshot.budget.usagePct, 125);
      expect(snapshot.budget.remaining, 0);
    });

    test(
      'keeps budget-derived values unavailable when no real budget exists',
      () {
        final missing = builder.build(input(expense: 500));
        final zero = builder.build(input(expense: 500, budgetAmount: 0));

        for (final snapshot in [missing, zero]) {
          expect(snapshot.budget.hasBudget, isFalse);
          expect(snapshot.availability.hasBudget, isFalse);
          expect(snapshot.budget.amount, isNull);
          expect(snapshot.budget.remaining, isNull);
          expect(snapshot.budget.usagePct, isNull);
          expect(snapshot.budget.safeDailySpend, isNull);
          expect(snapshot.hasEvidence('budget.amount'), isFalse);
          expect(snapshot.hasEvidence('budget.pace_delta_pp'), isFalse);
        }
      },
    );

    test('does not calculate current-month pace for a historical month', () {
      final snapshot = builder.build(
        input(month: DateTime(2026, 2), expense: 500, budgetAmount: 800),
      );

      expect(snapshot.budget.remaining, 300);
      expect(snapshot.budget.safeDailySpend, isNull);
      expect(snapshot.budget.expectedUsagePct, isNull);
      expect(snapshot.budget.paceDeltaPp, isNull);
    });

    test('applies budget pace severity boundaries exactly', () {
      final worthWatching = builder.build(
        input(
          month: DateTime(2026, 2),
          referenceTime: DateTime(2026, 2, 14),
          expense: 60,
          budgetAmount: 100,
        ),
      );
      final needsAttention = builder.build(
        input(
          month: DateTime(2026, 2),
          referenceTime: DateTime(2026, 2, 14),
          expense: 70,
          budgetAmount: 100,
        ),
      );

      expect(worthWatching.budget.paceDeltaPp, 10);
      expect(worthWatching.severity, FinancialSeverity.worthWatching);
      expect(needsAttention.budget.paceDeltaPp, 20);
      expect(needsAttention.severity, FinancialSeverity.needsAttention);
    });
  });

  group('allocation severity', () {
    AllocationGoalInput goal({bool enabled = true, double tolerance = 5}) =>
        AllocationGoalInput(
          enabled: enabled,
          tolerance: tolerance,
          dailyUseTargetPct: 40,
          savingsTargetPct: 30,
          investmentTargetPct: 30,
        );

    ActualAllocationInput actual(double dailyUse) => ActualAllocationInput(
      hasData: true,
      dailyUseActualPct: dailyUse,
      savingsActualPct: 30,
      investmentActualPct: 30,
    );

    test('is normal within tolerance', () {
      final snapshot = builder.build(
        input(allocationGoal: goal(), actualAllocation: actual(45)),
      );

      expect(snapshot.severity, FinancialSeverity.normal);
    });

    test('is worth watching above tolerance', () {
      final snapshot = builder.build(
        input(allocationGoal: goal(), actualAllocation: actual(46)),
      );

      expect(snapshot.severity, FinancialSeverity.worthWatching);
    });

    test('is worth watching at exactly tolerance plus eight points', () {
      final snapshot = builder.build(
        input(allocationGoal: goal(), actualAllocation: actual(53)),
      );

      expect(snapshot.severity, FinancialSeverity.worthWatching);
    });

    test('needs attention above tolerance plus eight percentage points', () {
      final snapshot = builder.build(
        input(allocationGoal: goal(), actualAllocation: actual(54)),
      );

      expect(snapshot.severity, FinancialSeverity.needsAttention);
    });

    test('does not use allocation severity when goals are disabled', () {
      final snapshot = builder.build(
        input(
          allocationGoal: goal(enabled: false),
          actualAllocation: actual(90),
        ),
      );

      expect(snapshot.severity, FinancialSeverity.normal);
    });

    test('does not use an allocation bucket without a target', () {
      final snapshot = builder.build(
        input(
          allocationGoal: const AllocationGoalInput(
            enabled: true,
            tolerance: 5,
          ),
          actualAllocation: const ActualAllocationInput(
            hasData: true,
            dailyUseActualPct: 90,
          ),
        ),
      );

      expect(snapshot.allocation.dailyUse.targetPct, isNull);
      expect(snapshot.allocation.dailyUse.gapPp, isNull);
      expect(snapshot.severity, FinancialSeverity.normal);
    });
  });

  group('category comparisons', () {
    test(
      'calculates meaningful increases without tiny-amount exaggeration',
      () {
        final snapshot = builder.build(
          input(
            currentCategories: const [
              CategorySpendingInput(
                categoryId: 'food',
                categoryName: 'Food',
                amount: 520,
              ),
              CategorySpendingInput(
                categoryId: 'snacks',
                categoryName: 'Snacks',
                amount: 4,
              ),
            ],
            previousCategories: const [
              CategorySpendingInput(
                categoryId: 'food',
                categoryName: 'Food',
                amount: 410,
              ),
              CategorySpendingInput(
                categoryId: 'snacks',
                categoryName: 'Snacks',
                amount: 2,
              ),
            ],
            hasPreviousMonthData: true,
          ),
        );
        final food = snapshot.spending.categories.firstWhere(
          (c) => c.categoryId == 'food',
        );
        final snacks = snapshot.spending.categories.firstWhere(
          (c) => c.categoryId == 'snacks',
        );

        expect(food.changeAmount, 110);
        expect(food.changePct, closeTo(110 / 410 * 100, 0.000001));
        expect(food.isMeaningfulIncrease, isTrue);
        expect(snacks.changePct, 100);
        expect(snacks.isMeaningfulIncrease, isFalse);
      },
    );

    test('avoids divide-by-zero and fabricated trends', () {
      final withZeroPrevious = builder.build(
        input(
          currentCategories: const [
            CategorySpendingInput(
              categoryId: 'food',
              categoryName: 'Food',
              amount: 20,
            ),
          ],
          previousCategories: const [
            CategorySpendingInput(
              categoryId: 'food',
              categoryName: 'Food',
              amount: 0,
            ),
          ],
          hasPreviousMonthData: true,
        ),
      );
      final withoutPrevious = builder.build(
        input(
          currentCategories: const [
            CategorySpendingInput(
              categoryId: 'food',
              categoryName: 'Food',
              amount: 20,
            ),
          ],
        ),
      );

      expect(withZeroPrevious.spending.categories.single.changePct, isNull);
      expect(withoutPrevious.spending.hasPreviousMonthData, isFalse);
      expect(withoutPrevious.spending.categories.single.previousAmount, isNull);
      expect(withoutPrevious.spending.categories.single.changeAmount, isNull);
    });

    test('limits exposure by mode with deterministic ordering', () {
      final categories = List.generate(
        6,
        (index) => CategorySpendingInput(
          categoryId: 'c$index',
          categoryName: 'Category $index',
          amount: index == 5 ? 10.0 : 100 - index.toDouble(),
        ),
      );
      final lazy = builder.build(
        input(mode: FinancialMode.lazy, currentCategories: categories),
      );
      final detailed = builder.build(input(currentCategories: categories));

      expect(lazy.spending.categories, hasLength(2));
      expect(detailed.spending.categories, hasLength(5));
      expect(detailed.spending.categories.first.categoryId, 'c0');
    });
  });

  group('recurring commitments', () {
    test('uses an exact 30-calendar-day inclusive/exclusive boundary', () {
      final referenceTime = DateTime(2026, 9, 10, 14, 30);
      final snapshot = builder.build(
        input(
          referenceTime: referenceTime,
          recurringPlans: [
            RecurringCommitmentInput(
              type: 'expense',
              amount: 10,
              intervalDays: 365,
              startDate: DateTime(2026, 9, 10),
              endDate: DateTime(2027, 12, 31),
              nextRunAt: DateTime(2026, 9, 10),
              active: true,
            ),
            RecurringCommitmentInput(
              type: 'expense',
              amount: 20,
              intervalDays: 365,
              startDate: DateTime(2026, 9, 10),
              endDate: DateTime(2027, 12, 31),
              nextRunAt: DateTime(2026, 10, 9),
              active: true,
            ),
            RecurringCommitmentInput(
              type: 'expense',
              amount: 40,
              intervalDays: 365,
              startDate: DateTime(2026, 9, 10),
              endDate: DateTime(2027, 12, 31),
              nextRunAt: DateTime(2026, 10, 10),
              active: true,
            ),
          ],
        ),
      );

      expect(snapshot.recurring.occurrenceCount, 2);
      expect(snapshot.recurring.next30DaysAmount, 30);
    });

    test('mirrors plan interval, active, type, and end-date semantics', () {
      final snapshot = builder.build(
        input(
          recurringPlans: [
            RecurringCommitmentInput(
              type: 'expense',
              amount: 55,
              intervalDays: 30,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
              nextRunAt: DateTime(2026, 3, 12),
              active: true,
            ),
            RecurringCommitmentInput(
              type: 'expense',
              amount: 40,
              intervalDays: 30,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
              nextRunAt: DateTime(2026, 3, 18),
              active: true,
            ),
            RecurringCommitmentInput(
              type: 'expense',
              amount: 80,
              intervalDays: 16,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
              nextRunAt: DateTime(2026, 3, 10),
              active: true,
            ),
            RecurringCommitmentInput(
              type: 'expense',
              amount: 100,
              intervalDays: 30,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
              nextRunAt: DateTime(2026, 3, 12),
              active: false,
            ),
            RecurringCommitmentInput(
              type: 'income',
              amount: 1000,
              intervalDays: 30,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
              nextRunAt: DateTime(2026, 3, 12),
              active: true,
            ),
            RecurringCommitmentInput(
              type: 'expense',
              amount: 999,
              intervalDays: 30,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 3, 9),
              nextRunAt: DateTime(2026, 3, 10),
              active: true,
            ),
          ],
        ),
      );

      expect(snapshot.recurring.hasRecurringData, isTrue);
      expect(snapshot.recurring.occurrenceCount, 4);
      expect(snapshot.recurring.next30DaysAmount, 255);
    });
  });

  group('investment P/L integrity', () {
    test('normalizes historical and new signed P/L records', () {
      expect(normalizeInvestmentPnlDiff(rawDiff: 80, pnlType: 'profit'), 80);
      expect(normalizeInvestmentPnlDiff(rawDiff: -80, pnlType: 'profit'), 80);
      expect(normalizeInvestmentPnlDiff(rawDiff: 80, pnlType: 'loss'), -80);
      expect(normalizeInvestmentPnlDiff(rawDiff: -80, pnlType: 'loss'), -80);
      expect(normalizeInvestmentPnlDiff(rawDiff: 80, pnlType: 'unknown'), 80);
      expect(normalizeInvestmentPnlDiff(rawDiff: -80, pnlType: 'unknown'), -80);
    });

    test('excludes manual corrections from investment P/L facts', () {
      final snapshot = builder.build(
        input(
          investmentPnlPoints: [
            InvestmentPnlInput(date: now, rawDiff: 80, pnlType: 'profit'),
            InvestmentPnlInput(
              date: now,
              rawDiff: 1000,
              pnlType: 'profit',
              isGenuineInvestmentPnl: false,
            ),
          ],
        ),
      );

      expect(snapshot.investment.monthlyPnl, 80);
      expect(snapshot.investment.hasInvestmentData, isTrue);
    });
  });

  group('severity composition and evidence', () {
    test(
      'category, recurring, and investment signals cannot independently need attention',
      () {
        final category = builder.build(
          input(
            currentCategories: const [
              CategorySpendingInput(
                categoryId: 'food',
                categoryName: 'Food',
                amount: 520,
              ),
            ],
            previousCategories: const [
              CategorySpendingInput(
                categoryId: 'food',
                categoryName: 'Food',
                amount: 410,
              ),
            ],
            hasPreviousMonthData: true,
          ),
        );
        final recurringOnly = builder.build(
          input(
            recurringPlans: [
              RecurringCommitmentInput(
                type: 'expense',
                amount: 5000,
                intervalDays: 1,
                startDate: DateTime(2026, 1, 1),
                endDate: DateTime(2026, 12, 31),
                nextRunAt: now,
                active: true,
              ),
            ],
          ),
        );
        final investmentLossOnly = builder.build(
          input(
            investmentPnlPoints: [
              InvestmentPnlInput(date: now, rawDiff: -5000, pnlType: 'loss'),
            ],
          ),
        );
        final budget = builder.build(input(expense: 800, budgetAmount: 800));

        expect(category.severity, FinancialSeverity.worthWatching);
        expect(recurringOnly.severity, FinancialSeverity.normal);
        expect(investmentLossOnly.severity, FinancialSeverity.normal);
        expect(budget.severity, FinancialSeverity.needsAttention);
      },
    );

    test(
      'publishes only verified available evidence with stable category tokens',
      () {
        final first = builder.build(
          input(
            income: 2500,
            expense: 500,
            budgetAmount: 800,
            allocationGoal: const AllocationGoalInput(
              enabled: true,
              tolerance: 5,
              dailyUseTargetPct: 40,
              savingsTargetPct: 30,
              investmentTargetPct: 30,
            ),
            actualAllocation: const ActualAllocationInput(
              hasData: true,
              dailyUseActualPct: 45,
              savingsActualPct: 30,
              investmentActualPct: 25,
            ),
            currentCategories: const [
              CategorySpendingInput(
                categoryId: 'food',
                categoryName: 'Food',
                amount: 520,
              ),
            ],
            previousCategories: const [
              CategorySpendingInput(
                categoryId: 'food',
                categoryName: 'Food',
                amount: 410,
              ),
            ],
            hasPreviousMonthData: true,
            recurringPlans: [
              RecurringCommitmentInput(
                type: 'expense',
                amount: 55,
                intervalDays: 30,
                startDate: DateTime(2026, 1, 1),
                endDate: DateTime(2026, 12, 31),
                nextRunAt: DateTime(2026, 3, 12),
                active: true,
              ),
            ],
            investmentPnlPoints: [
              InvestmentPnlInput(date: now, rawDiff: 80, pnlType: 'profit'),
            ],
          ),
        );
        final second = builder.build(
          input(
            currentCategories: const [
              CategorySpendingInput(
                categoryId: 'food',
                categoryName: 'Different label',
                amount: 1,
              ),
            ],
          ),
        );
        final prefix = first.spending.categories.single.evidenceKeyPrefix;

        expect(first.hasEvidence('cashflow.income'), isTrue);
        expect(first.evidenceValue('cashflow.net'), 2000);
        expect(first.hasEvidence('$prefix.current_amount'), isTrue);
        expect(first.hasEvidence('$prefix.previous_amount'), isTrue);
        expect(first.hasEvidence('allocation.daily_use.gap_pp'), isTrue);
        expect(first.hasEvidence('recurring.next_30d_amount'), isTrue);
        expect(first.hasEvidence('investment.monthly_pnl'), isTrue);
        expect(second.spending.categories.single.evidenceKeyPrefix, prefix);
        expect(second.hasEvidence('$prefix.previous_amount'), isFalse);
        expect(first.hasEvidence('does.not.exist'), isFalse);
        expect(first.evidenceValue('does.not.exist'), isNull);
        expect(first.toJson()['severity'], 'needsAttention');
      },
    );

    test('same input and supplied time produce identical snapshots', () {
      final buildInput = input(
        income: 2500,
        expense: 500,
        budgetAmount: 800,
        currentCategories: const [
          CategorySpendingInput(
            categoryId: 'food',
            categoryName: 'Food',
            amount: 520,
          ),
        ],
        previousCategories: const [
          CategorySpendingInput(
            categoryId: 'food',
            categoryName: 'Food',
            amount: 410,
          ),
        ],
        hasPreviousMonthData: true,
      );

      expect(
        builder.build(buildInput).toJson(),
        builder.build(buildInput).toJson(),
      );
    });
  });
}
