import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_pocket/application/ai_insight_snapshot_fingerprint.dart';
import 'package:smart_pocket/application/controllers/ai_insight_controller.dart';
import 'package:smart_pocket/application/financial_snapshot_collector.dart';
import 'package:smart_pocket/core/config/ai_insight_config.dart';
import 'package:smart_pocket/core/models/ai_insight_result.dart';
import 'package:smart_pocket/core/models/category_model.dart';
import 'package:smart_pocket/core/models/financial_snapshot.dart';
import 'package:smart_pocket/core/models/investment_pnl_point.dart';
import 'package:smart_pocket/core/models/recurring_plan_model.dart';
import 'package:smart_pocket/core/utils/constants.dart';
import 'package:smart_pocket/data/services/ai_insight_cache_service.dart';
import 'package:smart_pocket/data/services/ai_insight_service.dart';
import 'package:smart_pocket/data/services/local_storage_service.dart';

void main() {
  final now = DateTime(2026, 9, 10, 10, 30);

  group('financial snapshot collector', () {
    test(
      'passes existing verified source values into the M1 builder',
      () async {
        final source = _FakeSnapshotSource(now: now);
        final snapshot = await FinancialSnapshotCollector(
          source: source,
        ).buildCurrentSnapshot(now: now);

        expect(snapshot.context.mode, FinancialMode.lazy);
        expect(snapshot.cashFlow.income, 2500);
        expect(snapshot.cashFlow.expense, 800);
        expect(snapshot.cashFlow.netCashFlow, 1700);
        expect(snapshot.budget.amount, 1000);
        expect(snapshot.spending.categories.single.categoryName, 'Food');
        expect(snapshot.recurring.next30DaysAmount, 55);
        expect(snapshot.investment.monthlyPnl, -80);
        expect(source.monthlySummaryCalls, 1);
      },
    );

    test(
      'missing optional sources produce a valid availability-aware snapshot',
      () async {
        final source = _FakeSnapshotSource(now: now)
          ..budget = null
          ..goals = null
          ..actual = null
          ..includeRecurring = false
          ..includeInvestmentPnl = false
          ..previousRows = const [];
        final snapshot = await FinancialSnapshotCollector(
          source: source,
        ).buildCurrentSnapshot(now: now);

        expect(snapshot.availability.hasBudget, isFalse);
        expect(snapshot.availability.hasAllocationData, isFalse);
        expect(snapshot.availability.hasPreviousMonthData, isFalse);
        expect(snapshot.availability.hasRecurringData, isFalse);
        expect(snapshot.availability.hasInvestmentData, isFalse);
      },
    );

    test('missing critical monthly summary returns a typed failure', () async {
      final source = _FakeSnapshotSource(now: now)..summaryFails = true;

      await expectLater(
        FinancialSnapshotCollector(
          source: source,
        ).buildCurrentSnapshot(now: now),
        throwsA(
          isA<FinancialSnapshotCollectionFailure>().having(
            (failure) => failure.reason,
            'reason',
            FinancialSnapshotCollectionFailureReason.monthlySummaryUnavailable,
          ),
        ),
      );
    });
  });

  group('snapshot fingerprint', () {
    test(
      'ignores generatedAt but changes for finance or mode changes',
      () async {
        final source = _FakeSnapshotSource(now: now);
        final collector = FinancialSnapshotCollector(source: source);
        final first = await collector.buildCurrentSnapshot(now: now);
        final later = await collector.buildCurrentSnapshot(
          now: now.add(const Duration(hours: 2)),
        );
        const fingerprint = AiInsightSnapshotFingerprint();

        expect(fingerprint.compute(first), fingerprint.compute(later));

        source.expense = 850;
        final changed = await collector.buildCurrentSnapshot(now: now);
        expect(fingerprint.compute(changed), isNot(fingerprint.compute(first)));

        source.expense = 800;
        source.mode = 'detailed';
        final detailed = await collector.buildCurrentSnapshot(now: now);
        expect(
          fingerprint.compute(detailed),
          isNot(fingerprint.compute(first)),
        );
      },
    );
  });

  group('AI insight controller', () {
    test('construction and snapshot preparation make zero AI calls', () async {
      final setup = _Setup(now);

      expect(setup.generator.calls, 0);
      await setup.controller.prepareSnapshot();

      expect(setup.generator.calls, 0);
      expect(
        setup.controller.status,
        AiInsightControllerStatus.readyToGenerate,
      );
      expect(setup.controller.snapshot, isNotNull);
    });

    test(
      'cache decoding failure is distinguished without blocking readiness',
      () async {
        final setup = _Setup(now)..cache.returnCorrupt = true;

        await setup.controller.prepareSnapshot();

        expect(setup.generator.calls, 0);
        expect(
          setup.controller.status,
          AiInsightControllerStatus.readyToGenerate,
        );
        expect(
          setup.controller.failureKind,
          AiInsightControllerFailureKind.cacheDecoding,
        );
      },
    );

    test('explicit generate calls AI once and caches success', () async {
      final setup = _Setup(now);

      await setup.controller.generateInsight();

      expect(setup.generator.calls, 1);
      expect(setup.cache.saveCount, 1);
      expect(setup.controller.insight, isNotNull);
      expect(setup.controller.hasCachedInsight, isTrue);
      expect(setup.controller.isStale, isFalse);
      expect(setup.controller.status, AiInsightControllerStatus.success);
    });

    test('generate with matching cache avoids an AI call', () async {
      final setup = _Setup(now);
      await setup.seedMatchingCache();

      await setup.controller.generateInsight();

      expect(setup.generator.calls, 0);
      expect(setup.controller.insight?.headline, 'Cached insight');
      expect(setup.controller.isStale, isFalse);
    });

    test('explicit refresh bypasses a matching cache exactly once', () async {
      final setup = _Setup(now);
      await setup.seedMatchingCache();

      await setup.controller.refreshInsight();

      expect(setup.generator.calls, 1);
      expect(setup.cache.saveCount, 2);
      expect(setup.controller.insight?.headline, 'Fresh insight');
    });

    test(
      'refresh failure preserves the previously valid cached insight',
      () async {
        final setup = _Setup(now, generatorFails: true);
        await setup.seedMatchingCache();

        await setup.controller.refreshInsight();

        expect(setup.generator.calls, 1);
        expect(setup.controller.insight?.headline, 'Cached insight');
        expect(setup.controller.cachedInsight?.headline, 'Cached insight');
        expect(setup.controller.refreshError, isNotNull);
        expect(
          setup.controller.failureKind,
          AiInsightControllerFailureKind.aiGeneration,
        );
      },
    );

    test(
      'different financial fingerprint exposes cache only as stale',
      () async {
        final setup = _Setup(now);
        await setup.seedMatchingCache();
        setup.source.expense = 850;

        await setup.controller.prepareSnapshot();

        expect(setup.generator.calls, 0);
        expect(setup.controller.insight, isNull);
        expect(setup.controller.cachedInsight?.headline, 'Cached insight');
        expect(setup.controller.isStale, isTrue);
        expect(
          setup.controller.status,
          AiInsightControllerStatus.readyToGenerate,
        );
      },
    );

    test(
      'cached evidence missing from current snapshot rejects cache',
      () async {
        final setup = _Setup(now);
        await setup.seedMatchingCache(evidenceKeys: ['budget.usage_pct']);
        setup.source.budget = null;

        await setup.controller.prepareSnapshot();

        expect(setup.controller.insight, isNull);
        expect(setup.controller.cachedInsight, isNull);
        expect(setup.controller.isStale, isFalse);
        expect(setup.cache.removeCount, 1);
      },
    );

    test('cached severity mismatch rejects cache', () async {
      final setup = _Setup(now);
      await setup.seedMatchingCache(severity: FinancialSeverity.normal);

      await setup.controller.prepareSnapshot();

      expect(setup.controller.insight, isNull);
      expect(setup.controller.cachedInsight, isNull);
      expect(setup.cache.removeCount, 1);
    });

    test('cache namespace prevents user A data surfacing for user B', () async {
      final setup = _Setup(now);
      await setup.seedMatchingCache();
      setup.source.uid = 'user-b';

      await setup.controller.prepareSnapshot();

      expect(setup.cache.lastLoadUid, 'user-b');
      expect(setup.controller.insight, isNull);
      expect(setup.controller.cachedInsight, isNull);
    });

    test(
      'logout clears all in-memory AI and financial snapshot state',
      () async {
        final setup = _Setup(now);
        await setup.seedMatchingCache();
        await setup.controller.prepareSnapshot();
        expect(setup.controller.insight, isNotNull);

        setup.source.uid = null;
        setup.controller.handleAuthChanged(null);

        expect(setup.controller.status, AiInsightControllerStatus.idle);
        expect(setup.controller.snapshot, isNull);
        expect(setup.controller.insight, isNull);
        expect(setup.controller.cachedInsight, isNull);
        expect(setup.controller.snapshotFingerprint, isNull);
      },
    );
  });

  group('local AI insight cache', () {
    test('round-trips only the typed minimal cache record', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      final cache = LocalAiInsightCache(storage);
      final record = CachedAiInsight(
        month: '2026-09',
        mode: FinancialMode.lazy,
        fingerprint: 'abc123',
        result: _insight(
          headline: 'Cached insight',
          severity: FinancialSeverity.normal,
          evidenceKeys: const ['cashflow.income'],
        ),
        generatedAt: now,
      );

      await cache.save(uid: 'user-a', record: record);
      final loaded = await cache.load(
        uid: 'user-a',
        month: now,
        mode: FinancialMode.lazy,
      );

      expect(loaded.status, AiInsightCacheLoadStatus.found);
      expect(loaded.record?.fingerprint, 'abc123');
      expect(loaded.record?.result.headline, 'Cached insight');
      expect(loaded.record?.result.evidenceKeys, ['cashflow.income']);
      final raw = await storage.readAiInsightCache(
        'ai_insight_cache_v1.user-a.2026-09.lazy',
      );
      expect(raw, isNot(contains('transaction')));
      expect(raw, isNot(contains('prompt')));
      expect(raw, isNot(contains('email')));
    });

    test('corrupted JSON is removed and reported without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'ai_insight_cache_v1.user-a.2026-09.lazy': '{broken-json',
      });
      final storage = LocalStorageService();
      final cache = LocalAiInsightCache(storage);

      final result = await cache.load(
        uid: 'user-a',
        month: now,
        mode: FinancialMode.lazy,
      );

      expect(result.status, AiInsightCacheLoadStatus.corrupt);
      expect(
        await storage.readAiInsightCache(
          'ai_insight_cache_v1.user-a.2026-09.lazy',
        ),
        isNull,
      );
    });
  });
}

final class _Setup {
  _Setup(this.now, {bool generatorFails = false})
    : source = _FakeSnapshotSource(now: now),
      cache = _MemoryCache(),
      generator = _CountingGenerator(fails: generatorFails) {
    collector = FinancialSnapshotCollector(source: source);
    controller = AiInsightController(
      collector: collector,
      cache: cache,
      service: AiInsightService(generator: generator),
      clock: () => now,
    );
  }

  final DateTime now;
  final _FakeSnapshotSource source;
  final _MemoryCache cache;
  final _CountingGenerator generator;
  late final FinancialSnapshotCollector collector;
  late final AiInsightController controller;

  Future<void> seedMatchingCache({
    List<String> evidenceKeys = const ['cashflow.income'],
    FinancialSeverity? severity,
  }) async {
    final snapshot = await collector.buildCurrentSnapshot(now: now);
    final record = CachedAiInsight(
      month: '2026-09',
      mode: snapshot.context.mode,
      fingerprint: const AiInsightSnapshotFingerprint().compute(snapshot),
      result: _insight(
        headline: 'Cached insight',
        severity: severity ?? snapshot.severity,
        evidenceKeys: evidenceKeys,
      ),
      generatedAt: now.subtract(const Duration(hours: 1)),
    );
    await cache.save(uid: source.uid!, record: record);
  }
}

final class _FakeSnapshotSource implements FinancialSnapshotDataSource {
  _FakeSnapshotSource({required this.now});

  final DateTime now;
  String? uid = 'user-a';
  String mode = 'lazy';
  double income = 2500;
  double expense = 800;
  double? budget = 1000;
  bool summaryFails = false;
  int monthlySummaryCalls = 0;
  List<Map<String, dynamic>> currentRows = [
    {'categoryId': 'food-id', 'amount': 520.0},
  ];
  List<Map<String, dynamic>> previousRows = [
    {'categoryId': 'food-id', 'amount': 410.0},
  ];
  Map<String, dynamic>? goals = {
    AllocationFields.enabled: true,
    AllocationFields.tolerance: 5.0,
    AllocationFields.targets: {
      AllocationFields.dailyUse: 40.0,
      AllocationFields.savings: 30.0,
      AllocationFields.investment: 30.0,
    },
  };
  Map<String, double>? actual = {
    AllocationFields.dailyUse: 50,
    AllocationFields.savings: 25,
    AllocationFields.investment: 25,
    '_hasData': 1,
  };
  bool includeRecurring = true;
  bool includeInvestmentPnl = true;
  List<RecurringPlanModel> plans = [];
  List<InvestmentPnlPoint> pnl = [];

  @override
  String? get currentUserId => uid;

  @override
  String get appMode => mode;

  @override
  Future<Map<String, double>> monthlySummary(DateTime month) async {
    monthlySummaryCalls++;
    if (summaryFails) throw Exception('summary unavailable');
    return {'income': income, 'expense': expense};
  }

  @override
  Future<List<Map<String, dynamic>>> monthlyExpensesByCategory(
    DateTime month,
  ) async => month.month == now.month ? currentRows : previousRows;

  @override
  Future<double> budgetForMonth(DateTime month) async {
    final value = budget;
    if (value == null) throw Exception('no budget');
    return value;
  }

  @override
  Future<Map<String, dynamic>> allocationGoals() async {
    final value = goals;
    if (value == null) throw Exception('no goals');
    return value;
  }

  @override
  Future<Map<String, double>> actualAllocation() async {
    final value = actual;
    if (value == null) throw Exception('no allocation');
    return value;
  }

  @override
  Future<List<CategoryModel>> categories() async => [
    CategoryModel(
      id: 'food-id',
      userId: uid ?? '',
      name: 'Food',
      type: 'expense',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  @override
  Future<List<RecurringPlanModel>> recurringPlans(String uid) async {
    if (!includeRecurring) return const [];
    if (plans.isNotEmpty) return plans;
    return [
      RecurringPlanModel(
        id: 'plan-1',
        userId: uid,
        type: 'expense',
        label: 'Subscription',
        amount: 55,
        accountId: 'account-1',
        categoryId: 'food-id',
        intervalDays: 30,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        nextRunAt: DateTime(2026, 9, 15),
        active: true,
        version: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<List<InvestmentPnlPoint>> investmentPnlPoints() async =>
      !includeInvestmentPnl
      ? const []
      : pnl.isEmpty
      ? [InvestmentPnlPoint(date: now, diff: -80)]
      : pnl;
}

final class _CountingGenerator implements AiContentGenerator {
  _CountingGenerator({required this.fails});

  final bool fails;
  int calls = 0;

  @override
  Future<String?> generate(String prompt) async {
    calls++;
    if (fails) throw Exception('provider failure');
    return jsonEncode({
      'headline': 'Fresh insight',
      'what_happened': 'Verified income is available.',
      'why': 'The snapshot contains the monthly income total.',
      'action': 'Continue reviewing the verified monthly summary.',
      'evidence_keys': ['cashflow.income'],
    });
  }
}

final class _MemoryCache implements AiInsightCache {
  final Map<String, CachedAiInsight> records = {};
  bool returnCorrupt = false;
  int saveCount = 0;
  int removeCount = 0;
  String? lastLoadUid;

  @override
  Future<AiInsightCacheLoadResult> load({
    required String uid,
    required DateTime month,
    required FinancialMode mode,
  }) async {
    lastLoadUid = uid;
    if (returnCorrupt) return const AiInsightCacheLoadResult.corrupt();
    final value = records[_key(uid, month, mode)];
    return value == null
        ? const AiInsightCacheLoadResult.missing()
        : AiInsightCacheLoadResult.found(value);
  }

  @override
  Future<void> save({
    required String uid,
    required CachedAiInsight record,
  }) async {
    saveCount++;
    records[_key(uid, DateTime.parse('${record.month}-01'), record.mode)] =
        record;
  }

  @override
  Future<void> remove({
    required String uid,
    required DateTime month,
    required FinancialMode mode,
  }) async {
    removeCount++;
    records.remove(_key(uid, month, mode));
  }

  String _key(String uid, DateTime month, FinancialMode mode) =>
      '$uid.${month.year}-${month.month}.${mode.name}';
}

AiInsightResult _insight({
  required String headline,
  required FinancialSeverity severity,
  required List<String> evidenceKeys,
}) => AiInsightResult(
  headline: headline,
  whatHappened: 'Verified financial activity is available.',
  why: 'The result references deterministic evidence.',
  action: 'Review the verified figures.',
  severity: severity,
  evidenceKeys: evidenceKeys,
  model: AiInsightConfig.modelName,
);
