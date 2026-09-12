import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_pocket/application/controllers/ai_insight_controller.dart';
import 'package:smart_pocket/application/financial_snapshot_collector.dart';
import 'package:smart_pocket/core/models/category_model.dart';
import 'package:smart_pocket/core/models/financial_snapshot.dart';
import 'package:smart_pocket/core/models/investment_pnl_point.dart';
import 'package:smart_pocket/core/models/recurring_plan_model.dart';
import 'package:smart_pocket/core/utils/constants.dart';
import 'package:smart_pocket/core/utils/theme.dart';
import 'package:smart_pocket/data/services/ai_insight_cache_service.dart';
import 'package:smart_pocket/data/services/ai_insight_service.dart';
import 'package:smart_pocket/presentation/smart_insight/evidence_presentation.dart';
import 'package:smart_pocket/presentation/widgets/smart_insight/smart_insight_card.dart';

void main() {
  final now = DateTime(2026, 9, 13, 10, 32);

  group('Evidence presentation', () {
    test('uses deterministic labels and financial formatting', () async {
      final source = _Source(now: now, mode: 'detailed');
      final snapshot = await FinancialSnapshotCollector(
        source: source,
      ).buildCurrentSnapshot(now: now);
      final category = snapshot.spending.categories.single;
      final categoryKey = '${category.evidenceKeyPrefix}.change_amount';
      final resolved = EvidencePresentationResolver.resolve(
        snapshot: snapshot,
        evidenceKey: categoryKey,
      );

      expect(
        EvidenceValueFormatter.format(1234.56, EvidenceValueKind.money),
        'RM 1,234.56',
      );
      expect(
        EvidenceValueFormatter.format(68.4, EvidenceValueKind.percentage),
        '68.4%',
      );
      expect(
        EvidenceValueFormatter.format(-7, EvidenceValueKind.percentagePoints),
        '-7.0 pp',
      );
      expect(resolved?.label, 'Dining Change');
      expect(resolved?.formattedValue, '+RM 110.00');
      expect(resolved?.label, isNot(contains(category.evidenceKeyPrefix)));
    });
  });

  group('SmartInsightCard', () {
    testWidgets('renders empty state without generating an insight', (
      tester,
    ) async {
      final setup = _Setup(now: now);

      await tester.pumpWidget(_app(setup.controller));
      await tester.pumpAndSettle();

      expect(find.text('Generate Insight'), findsOneWidget);
      expect(
        find.textContaining('Raw transaction notes and account details'),
        findsOneWidget,
      );
      expect(setup.generator.calls, 0);
    });

    testWidgets('shows initial loading while local snapshot preparation runs', (
      tester,
    ) async {
      final setup = _Setup(now: now);
      setup.source.pendingSummary = Completer<Map<String, double>>();

      await tester.pumpWidget(_app(setup.controller));
      await tester.pump();

      expect(
        find.byKey(const Key('smart-insight-loading-copy')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('generate-insight-button')), findsNothing);
      expect(setup.generator.calls, 0);

      setup.source.pendingSummary!.complete({'income': 2500, 'expense': 800});
      await tester.pumpAndSettle();
    });

    testWidgets('shows loading copy and prevents duplicate refresh taps', (
      tester,
    ) async {
      final setup = _Setup(now: now);
      await setup.controller.generateInsight();
      setup.generator.pending = Completer<String?>();

      final refresh = setup.controller.refreshInsight();
      await _pumpUntil(tester, () => setup.generator.calls == 2);
      await tester.pumpWidget(_app(setup.controller));

      expect(find.text('Refreshing your verified insight...'), findsOneWidget);
      final refreshButton = tester.widget<FilledButton>(
        find.byKey(const Key('refresh-insight-button')),
      );
      expect(refreshButton.onPressed, isNull);

      setup.generator.pending!.complete(_successResponse());
      await refresh;
    });

    testWidgets('renders a Detailed insight with structured sections', (
      tester,
    ) async {
      final setup = _Setup(now: now, mode: 'detailed');
      await setup.controller.generateInsight();

      await tester.pumpWidget(_app(setup.controller));

      expect(find.text('Needs Attention'), findsOneWidget);
      expect(find.text('Spending is above the verified pace.'), findsOneWidget);
      expect(find.text('What happened'), findsOneWidget);
      expect(find.text('Why'), findsOneWidget);
      expect(find.text('What you can do'), findsOneWidget);
      expect(find.byKey(const Key('view-evidence-button')), findsOneWidget);
    });

    testWidgets('keeps Lazy presentation concise', (tester) async {
      final setup = _Setup(now: now, mode: 'lazy');
      await setup.controller.generateInsight();

      await tester.pumpWidget(_app(setup.controller));

      expect(find.text('What happened'), findsOneWidget);
      expect(find.text('Why'), findsNothing);
      expect(find.text('What you can do'), findsOneWidget);
    });

    testWidgets('shows evidence in a bottom sheet without a new AI call', (
      tester,
    ) async {
      final setup = _Setup(now: now, mode: 'detailed');
      await setup.controller.generateInsight();
      final callsBeforeOpeningEvidence = setup.generator.calls;

      await tester.pumpWidget(_app(setup.controller));
      await tester.tap(find.byKey(const Key('view-evidence-button')));
      await tester.pumpAndSettle();

      expect(find.text('Evidence'), findsOneWidget);
      expect(find.text('Monthly Expenses'), findsOneWidget);
      expect(find.text('RM 800.00'), findsOneWidget);
      expect(find.text('Budget Used'), findsOneWidget);
      expect(find.text('80.0%'), findsOneWidget);
      expect(find.text('Verified Data'), findsOneWidget);
      expect(setup.generator.calls, callsBeforeOpeningEvidence);
    });

    testWidgets('keeps stale insight evidence unavailable and offers refresh', (
      tester,
    ) async {
      final setup = _Setup(now: now);
      await setup.controller.generateInsight();
      setup.source.expense = 850;
      await setup.controller.prepareSnapshot();
      final callsBeforeRenderingStaleInsight = setup.generator.calls;

      await tester.pumpWidget(_app(setup.controller));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your financial data has changed since this insight was generated.',
        ),
        findsOneWidget,
      );
      expect(find.text('Previous insight'), findsOneWidget);
      expect(
        find.byKey(const Key('stale-evidence-unavailable-message')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Evidence is unavailable for this outdated insight. Refresh to verify the insight against your latest financial data.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('view-evidence-button')), findsNothing);
      expect(find.text('Refresh Insight'), findsOneWidget);
      expect(setup.generator.calls, callsBeforeRenderingStaleInsight);
    });

    testWidgets('shows a calm retry when initial generation fails', (
      tester,
    ) async {
      final setup = _Setup(now: now)..generator.shouldFail = true;
      await setup.controller.generateInsight();

      await tester.pumpWidget(_app(setup.controller));

      expect(
        find.text('AI insight is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.textContaining('provider-secret-detail'), findsNothing);
    });

    testWidgets('keeps current insight evidence available when refresh fails', (
      tester,
    ) async {
      final setup = _Setup(now: now);
      await setup.controller.generateInsight();
      setup.generator.shouldFail = true;
      await setup.controller.refreshInsight();
      final callsBeforeOpeningEvidence = setup.generator.calls;

      await tester.pumpWidget(_app(setup.controller));

      expect(find.text('Spending is above the verified pace.'), findsOneWidget);
      expect(
        find.text('AI insight is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('view-evidence-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('view-evidence-button')));
      await tester.pumpAndSettle();

      expect(find.text('Evidence'), findsOneWidget);
      expect(find.text('RM 800.00'), findsOneWidget);
      expect(setup.generator.calls, callsBeforeOpeningEvidence);
    });

    testWidgets('keeps stale insight evidence unavailable when refresh fails', (
      tester,
    ) async {
      final setup = _Setup(now: now);
      await setup.controller.generateInsight();
      setup.source.expense = 850;
      await setup.controller.prepareSnapshot();
      setup.generator.shouldFail = true;
      await setup.controller.refreshInsight();
      final callsBeforeRenderingStaleFailure = setup.generator.calls;

      await tester.pumpWidget(_app(setup.controller));
      await tester.pumpAndSettle();

      expect(find.text('Spending is above the verified pace.'), findsOneWidget);
      expect(
        find.text(
          'Your financial data has changed since this insight was generated.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('stale-evidence-unavailable-message')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('view-evidence-button')), findsNothing);
      expect(find.text('Refresh Insight'), findsOneWidget);
      expect(
        find.text('AI insight is temporarily unavailable.'),
        findsOneWidget,
      );
      final refreshButton = tester.widget<FilledButton>(
        find.byKey(const Key('refresh-insight-button')),
      );
      expect(refreshButton.onPressed, isNotNull);
      expect(setup.generator.calls, callsBeforeRenderingStaleFailure);
    });

    testWidgets('builds in light and dark themes without visual assumptions', (
      tester,
    ) async {
      final setup = _Setup(now: now);
      await setup.controller.generateInsight();

      await tester.pumpWidget(_app(setup.controller, dark: false));
      expect(find.text('SMART INSIGHT'), findsOneWidget);

      await tester.pumpWidget(_app(setup.controller, dark: true));
      expect(find.text('SMART INSIGHT'), findsOneWidget);
    });
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 12 && !condition(); attempt++) {
    await tester.pump();
  }
  expect(condition(), isTrue);
}

Widget _app(AiInsightController controller, {bool dark = false}) {
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: ChangeNotifierProvider<AiInsightController>.value(
      value: controller,
      child: const Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: SmartInsightCard(),
          ),
        ),
      ),
    ),
  );
}

String _successResponse() => jsonEncode({
  'headline': 'Spending is above the verified pace.',
  'what_happened':
      'Monthly expenses are using more of the budget than expected.',
  'why': 'The verified budget pace is above its expected level.',
  'action': 'Keep discretionary spending close to the verified daily amount.',
  'evidence_keys': [
    'cashflow.expense',
    'budget.usage_pct',
    'budget.pace_delta_pp',
  ],
});

final class _Setup {
  _Setup({required DateTime now, String mode = 'lazy'})
    : source = _Source(now: now, mode: mode),
      generator = _Generator() {
    controller = AiInsightController(
      collector: FinancialSnapshotCollector(source: source),
      cache: _MemoryCache(),
      service: AiInsightService(generator: generator),
      clock: () => now,
    );
  }

  final _Source source;
  final _Generator generator;
  late final AiInsightController controller;
}

final class _Generator implements AiContentGenerator {
  int calls = 0;
  bool shouldFail = false;
  Completer<String?>? pending;

  @override
  Future<String?> generate(String prompt) {
    calls++;
    if (shouldFail) throw Exception('provider-secret-detail');
    final wait = pending;
    if (wait != null) return wait.future;
    return Future.value(_successResponse());
  }
}

final class _Source implements FinancialSnapshotDataSource {
  _Source({required this.now, required this.mode});

  final DateTime now;
  final String mode;
  double expense = 800;
  Completer<Map<String, double>>? pendingSummary;

  @override
  String get appMode => mode;

  @override
  String? get currentUserId => 'test-user';

  @override
  Future<Map<String, double>> actualAllocation() async => {
    AllocationFields.dailyUse: 50,
    AllocationFields.savings: 25,
    AllocationFields.investment: 25,
    '_hasData': 1,
  };

  @override
  Future<Map<String, dynamic>> allocationGoals() async => {
    AllocationFields.enabled: true,
    AllocationFields.tolerance: 5.0,
    AllocationFields.targets: {
      AllocationFields.dailyUse: 40.0,
      AllocationFields.savings: 30.0,
      AllocationFields.investment: 30.0,
    },
  };

  @override
  Future<double> budgetForMonth(DateTime month) async => 1000;

  @override
  Future<List<CategoryModel>> categories() async => [
    CategoryModel(
      id: 'dining',
      userId: 'test-user',
      name: 'Dining',
      type: 'expense',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  @override
  Future<List<InvestmentPnlPoint>> investmentPnlPoints() async => const [];

  @override
  Future<List<Map<String, dynamic>>> monthlyExpensesByCategory(
    DateTime month,
  ) async => month.month == now.month
      ? [
          {'categoryId': 'dining', 'amount': 520.0},
        ]
      : [
          {'categoryId': 'dining', 'amount': 410.0},
        ];

  @override
  Future<Map<String, double>> monthlySummary(DateTime month) {
    final pending = pendingSummary;
    if (pending != null) return pending.future;
    return Future.value({'income': 2500, 'expense': expense});
  }

  @override
  Future<List<RecurringPlanModel>> recurringPlans(String uid) async => const [];
}

final class _MemoryCache implements AiInsightCache {
  final Map<String, CachedAiInsight> _records = {};

  @override
  Future<AiInsightCacheLoadResult> load({
    required String uid,
    required DateTime month,
    required FinancialMode mode,
  }) async {
    final record = _records[_key(uid, month, mode)];
    return record == null
        ? const AiInsightCacheLoadResult.missing()
        : AiInsightCacheLoadResult.found(record);
  }

  @override
  Future<void> remove({
    required String uid,
    required DateTime month,
    required FinancialMode mode,
  }) async {
    _records.remove(_key(uid, month, mode));
  }

  @override
  Future<void> save({
    required String uid,
    required CachedAiInsight record,
  }) async {
    _records[_key(uid, DateTime.parse('${record.month}-01'), record.mode)] =
        record;
  }

  String _key(String uid, DateTime month, FinancialMode mode) =>
      '$uid.${month.year}-${month.month}.${mode.name}';
}
