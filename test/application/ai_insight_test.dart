import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pocket/application/ai_insight_prompt_builder.dart';
import 'package:smart_pocket/application/ai_insight_validator.dart';
import 'package:smart_pocket/application/financial_snapshot_builder.dart';
import 'package:smart_pocket/core/models/ai_insight_result.dart';
import 'package:smart_pocket/core/models/financial_snapshot.dart';
import 'package:smart_pocket/core/utils/ai_insight_safety.dart';
import 'package:smart_pocket/data/services/ai_insight_service.dart';

void main() {
  const snapshotBuilder = FinancialSnapshotBuilder();
  const promptBuilder = AiInsightPromptBuilder();
  const validator = AiInsightValidator();
  final now = DateTime(2026, 9, 10, 10, 30);

  FinancialSnapshot snapshot({
    FinancialMode mode = FinancialMode.detailed,
    List<CategorySpendingInput> categories = const [],
    double expense = 800,
    double? budget = 800,
  }) => snapshotBuilder.build(
    FinancialSnapshotBuildInput(
      mode: mode,
      month: now,
      now: now,
      monthlyIncome: 2500,
      monthlyExpense: expense,
      budgetAmount: budget,
      allocationGoal: const AllocationGoalInput(
        enabled: true,
        tolerance: 5,
        dailyUseTargetPct: 40,
        savingsTargetPct: 30,
        investmentTargetPct: 30,
      ),
      actualAllocation: const ActualAllocationInput(
        hasData: true,
        dailyUseActualPct: 50,
        savingsActualPct: 25,
        investmentActualPct: 25,
      ),
      currentCategories: categories,
      previousCategories: const [
        CategorySpendingInput(
          categoryId: 'private-category-id',
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
          nextRunAt: DateTime(2026, 9, 15),
          active: true,
        ),
      ],
      investmentPnlPoints: [
        InvestmentPnlInput(date: now, rawDiff: -80, pnlType: 'loss'),
      ],
    ),
  );

  Map<String, Object> validResponse({List<String>? evidenceKeys}) => {
    'headline': 'Spending is ahead of this month’s pace',
    'what_happened': 'Recorded spending is progressing faster than expected.',
    'why': 'The verified budget pace is above its expected level.',
    'action': 'Keep spending near the supplied safe daily amount.',
    'evidence_keys': evidenceKeys ?? ['budget.usage_pct'],
  };

  group('AI-safe payload and prompt', () {
    test('includes only explicitly allowed deterministic snapshot data', () {
      final value = snapshot(
        categories: const [
          CategorySpendingInput(
            categoryId: 'private-category-id',
            categoryName: 'Food',
            amount: 520,
          ),
        ],
      );
      final payload = promptBuilder.buildSafePayload(value);
      final encoded = jsonEncode(payload);

      expect(encoded, contains('"income":2500.0'));
      expect(encoded, contains('"monthly_pnl":-80.0'));
      expect(encoded, contains('"budget.usage_pct"'));
      expect(encoded, isNot(contains('private-category-id')));
      expect(encoded, isNot(contains('account_number')));
      expect(encoded, isNot(contains('firebase_uid')));
      expect(encoded, isNot(contains('email')));
      expect(encoded, isNot(contains('note')));
      expect(encoded, isNot(contains('generated_at')));
    });

    test('uses simple Lazy instructions and only mode-approved categories', () {
      final prompt = promptBuilder.buildPrompt(
        snapshot(
          mode: FinancialMode.lazy,
          categories: const [
            CategorySpendingInput(
              categoryId: 'a',
              categoryName: 'Largest',
              amount: 300,
            ),
            CategorySpendingInput(
              categoryId: 'b',
              categoryName: 'Second',
              amount: 200,
            ),
            CategorySpendingInput(
              categoryId: 'c',
              categoryName: 'Hidden third',
              amount: 100,
            ),
          ],
        ),
      );

      expect(prompt, contains('MODE: Lazy'));
      expect(prompt, contains('simple, high-level language'));
      expect(prompt, contains('Largest'));
      expect(prompt, contains('Second'));
      expect(prompt, isNot(contains('Hidden third')));
    });

    test('uses one Detailed prompt architecture with precise guidance', () {
      final prompt = promptBuilder.buildPrompt(snapshot());

      expect(prompt, contains('MODE: Detailed'));
      expect(prompt, contains('month-over-month'));
      expect(prompt, contains('allocation details more precisely'));
    });

    test('states investment and monetary recommendation restrictions', () {
      final prompt = promptBuilder.buildPrompt(snapshot()).toLowerCase();

      expect(prompt, contains('never predict investment prices or returns'));
      expect(
        prompt,
        contains('never recommend buy, sell, hold, market timing'),
      );
      expect(prompt, contains('specific monetary recommendation'));
      expect(prompt, contains('exact amount already exists'));
      expect(
        AiInsightSafety.restrictedInvestmentResponse,
        contains('does not predict future asset prices'),
      );
    });

    test('is deterministic for the same snapshot', () {
      final value = snapshot();

      expect(
        jsonEncode(promptBuilder.buildSafePayload(value)),
        jsonEncode(promptBuilder.buildSafePayload(value)),
      );
      expect(
        promptBuilder.buildPrompt(value),
        promptBuilder.buildPrompt(value),
      );
    });
  });

  group('structured parsing and evidence validation', () {
    test('accepts valid JSON and attaches deterministic snapshot severity', () {
      final value = snapshot();
      final outcome = validator.parseAndValidate(
        rawJson: jsonEncode(validResponse()),
        snapshot: value,
      );

      expect(outcome, isA<AiInsightSuccess>());
      final result = (outcome as AiInsightSuccess).result;
      expect(result.severity, value.severity);
      expect(result.severity, FinancialSeverity.needsAttention);
      expect(result.evidenceKeys, ['budget.usage_pct']);
    });

    test('rejects missing required fields', () {
      final response = validResponse()..remove('why');
      final outcome = validator.parseAndValidate(
        rawJson: jsonEncode(response),
        snapshot: snapshot(),
      );

      expect(
        (outcome as AiInsightFailure).reason,
        AiInsightFailureReason.missingRequiredField,
      );
    });

    test('rejects malformed JSON', () {
      final outcome = validator.parseAndValidate(
        rawJson: '{not-json',
        snapshot: snapshot(),
      );

      expect(
        (outcome as AiInsightFailure).reason,
        AiInsightFailureReason.malformedResponse,
      );
    });

    test('removes hallucinated evidence when valid evidence remains', () {
      final outcome = validator.parseAndValidate(
        rawJson: jsonEncode(
          validResponse(
            evidenceKeys: ['budget.usage_pct', 'invented.money.value'],
          ),
        ),
        snapshot: snapshot(),
      );

      final result = (outcome as AiInsightSuccess).result;
      expect(result.evidenceKeys, ['budget.usage_pct']);
    });

    test('rejects a response when all evidence keys are hallucinated', () {
      final outcome = validator.parseAndValidate(
        rawJson: jsonEncode(
          validResponse(evidenceKeys: ['invented.money.value']),
        ),
        snapshot: snapshot(),
      );

      expect(
        (outcome as AiInsightFailure).reason,
        AiInsightFailureReason.invalidEvidence,
      );
    });

    test('rejects model-provided severity instead of allowing override', () {
      final response = validResponse()..['severity'] = 'normal';
      final outcome = validator.parseAndValidate(
        rawJson: jsonEncode(response),
        snapshot: snapshot(),
      );

      expect(
        (outcome as AiInsightFailure).reason,
        AiInsightFailureReason.malformedResponse,
      );
    });

    test('rejects deterministic restricted investment advice', () {
      final response = validResponse()
        ..['action'] = 'Buy this investment now for future gains.';
      final outcome = validator.parseAndValidate(
        rawJson: jsonEncode(response),
        snapshot: snapshot(),
      );

      expect(
        (outcome as AiInsightFailure).reason,
        AiInsightFailureReason.restrictedAdvice,
      );
    });
  });

  group('service failure handling', () {
    test('uses an injectable generator without network access', () async {
      final generator = _FakeGenerator(jsonEncode(validResponse()));
      final service = AiInsightService(generator: generator);

      final outcome = await service.generateInsight(snapshot());

      expect(outcome, isA<AiInsightSuccess>());
      expect(generator.lastPrompt, contains('AI_SAFE_SNAPSHOT_JSON'));
    });

    test('converts provider failure into a safe typed fallback', () async {
      final value = snapshot();
      final service = AiInsightService(generator: _ThrowingGenerator());

      final outcome = await service.generateInsight(value);

      expect(outcome, isA<AiInsightFailure>());
      final failure = outcome as AiInsightFailure;
      expect(failure.reason, AiInsightFailureReason.generationFailed);
      expect(failure.severity, value.severity);
      expect(failure.userMessage, AiInsightFailure.temporaryUnavailableMessage);
      expect(value.cashFlow.netCashFlow, 1700);
    });

    test('converts an empty provider response into a safe fallback', () async {
      final service = AiInsightService(generator: _FakeGenerator(null));

      final outcome = await service.generateInsight(snapshot());

      expect(
        (outcome as AiInsightFailure).reason,
        AiInsightFailureReason.emptyResponse,
      );
    });
  });
}

final class _FakeGenerator implements AiContentGenerator {
  _FakeGenerator(this.response);

  final String? response;
  String? lastPrompt;

  @override
  Future<String?> generate(String prompt) async {
    lastPrompt = prompt;
    return response;
  }
}

final class _ThrowingGenerator implements AiContentGenerator {
  @override
  Future<String?> generate(String prompt) {
    throw Exception('provider detail that must not escape');
  }
}
