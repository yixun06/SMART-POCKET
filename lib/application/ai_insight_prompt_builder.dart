import 'dart:collection';
import 'dart:convert';

import '../core/config/ai_insight_config.dart';
import '../core/models/financial_snapshot.dart';

final class AiInsightPromptBuilder {
  const AiInsightPromptBuilder();

  Map<String, Object> buildSafePayload(FinancialSnapshot snapshot) {
    final budget = <String, Object>{'has_budget': snapshot.budget.hasBudget};
    _addIfPresent(budget, 'amount', snapshot.budget.amount);
    _addIfPresent(budget, 'remaining', snapshot.budget.remaining);
    _addIfPresent(budget, 'usage_pct', snapshot.budget.usagePct);
    _addIfPresent(budget, 'safe_daily_spend', snapshot.budget.safeDailySpend);
    _addIfPresent(
      budget,
      'expected_usage_pct',
      snapshot.budget.expectedUsagePct,
    );
    _addIfPresent(budget, 'pace_delta_pp', snapshot.budget.paceDeltaPp);

    final allocation = <String, Object>{
      'enabled': snapshot.allocation.enabled,
      'has_data': snapshot.allocation.hasData,
    };
    _addIfPresent(allocation, 'tolerance', snapshot.allocation.tolerance);
    allocation['daily_use'] = _allocationBucket(snapshot.allocation.dailyUse);
    allocation['savings'] = _allocationBucket(snapshot.allocation.savings);
    allocation['investment'] = _allocationBucket(
      snapshot.allocation.investment,
    );

    final recurring = <String, Object>{
      'has_data': snapshot.recurring.hasRecurringData,
    };
    if (snapshot.recurring.hasRecurringData) {
      recurring['next_30d_amount'] = snapshot.recurring.next30DaysAmount;
      recurring['next_30d_occurrence_count'] =
          snapshot.recurring.occurrenceCount;
    }

    final investment = <String, Object>{
      'has_data': snapshot.investment.hasInvestmentData,
    };
    if (snapshot.investment.hasInvestmentData) {
      investment['monthly_pnl'] = snapshot.investment.monthlyPnl;
    }

    final evidence = SplayTreeMap<String, Object>.from(snapshot.evidence);
    return Map.unmodifiable({
      'context': {
        'mode': snapshot.context.mode.name,
        'period': _period(snapshot.context.period),
      },
      'cash_flow': {
        'income': snapshot.cashFlow.income,
        'expense': snapshot.cashFlow.expense,
        'net': snapshot.cashFlow.netCashFlow,
      },
      'budget': budget,
      'allocation': allocation,
      'spending': {
        'has_previous_month_data': snapshot.spending.hasPreviousMonthData,
        'categories': snapshot.spending.categories
            .map(
              (category) => {
                'name': category.categoryName,
                'evidence_prefix': category.evidenceKeyPrefix,
                'current_amount': category.currentAmount,
                if (category.previousAmount != null)
                  'previous_amount': category.previousAmount!,
                if (category.changeAmount != null)
                  'change_amount': category.changeAmount!,
                if (category.changePct != null)
                  'change_pct': category.changePct!,
                'is_meaningful_increase': category.isMeaningfulIncrease,
              },
            )
            .toList(growable: false),
      },
      'recurring': recurring,
      'investment': investment,
      'availability': snapshot.availability.toJson(),
      'severity': snapshot.severity.name,
      'evidence': evidence,
    });
  }

  String buildPrompt(FinancialSnapshot snapshot) {
    final modeInstruction = switch (snapshot.context.mode) {
      FinancialMode.lazy =>
        'MODE: Lazy. Use simple, high-level language and focus only on the '
            'most important one or two issues.',
      FinancialMode.detailed =>
        'MODE: Detailed. You may explain category, month-over-month, budget, '
            'and allocation details more precisely.',
    };
    final payload = jsonEncode(buildSafePayload(snapshot));

    return '''
ROLE: You are SMART POCKET's financial insight interpreter.

SOURCE OF TRUTH:
All financial facts in the supplied snapshot were calculated by SMART POCKET. Interpret them; do not calculate replacements.

$modeInstruction

RULES:
- Never invent money values, percentages, transactions, account balances, or missing data.
- Use only values in the supplied snapshot and reference only keys present in its evidence object.
- A specific monetary recommendation is allowed only when that exact amount already exists under a cited evidence key.
- Never predict investment prices or returns.
- Never recommend buy, sell, hold, market timing, entry timing, or exit timing.
- Never claim access to live market information or guarantee an outcome.
- Keep the tone calm, practical, and non-alarming.
- Give one actionable behavioral recommendation when possible.
- Do not expose hidden reasoning or chain-of-thought.
- Return only the requested JSON object, with no markdown.

OUTPUT:
- headline: at most ${AiInsightConfig.maxHeadlineCharacters} characters.
- what_happened, why, action: one or two short sentences each.
- evidence_keys: at most ${AiInsightConfig.maxEvidenceKeys} keys copied exactly from the evidence object.
- Do not return severity; SMART POCKET attaches it deterministically.

AI_SAFE_SNAPSHOT_JSON:
$payload
'''
        .trim();
  }

  Map<String, Object> _allocationBucket(AllocationBucketSnapshot bucket) {
    final result = <String, Object>{};
    _addIfPresent(result, 'actual_pct', bucket.actualPct);
    _addIfPresent(result, 'target_pct', bucket.targetPct);
    _addIfPresent(result, 'gap_pp', bucket.gapPp);
    return result;
  }

  void _addIfPresent(Map<String, Object> target, String key, Object? value) {
    if (value != null) target[key] = value;
  }

  String _period(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';
}
