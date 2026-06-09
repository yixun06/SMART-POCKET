import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../application/controllers/analytics_controller.dart';
import '../../../application/controllers/budget_controller.dart';
import '../../../application/controllers/category_controller.dart';
import '../../../application/controllers/transaction_controller.dart';
import '../../../core/utils/theme.dart';
import '../../../core/models/investment_pnl_point.dart';
import '../../widgets/navigation/bottom_nav_bar.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  int? selectedDay;

  bool _investmentMonthlyView = true; // true=Monthly, false=Daily

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<BudgetController>().changeMonth(selectedMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cat = context.watch<CategoryController>();
    final analytics = context.watch<AnalyticsController>();
    final budgetCtrl = context.watch<BudgetController>();
    final txCtrl = context.watch<TransactionController>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (analytics.uid == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    String catName(String id) {
      final hit = cat.categories.where((c) => c.id == id).toList();
      return hit.isEmpty ? id : hit.first.name;
    }

    double totalAssets() {
      double sum = 0;
      for (final a in txCtrl.accounts) {
        sum += _toDouble(a['balance']);
      }
      return sum;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          TextButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Back'),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 380;
            final hPad = isNarrow ? 12.0 : 16.0;

            return ListView(
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 110),
              children: [
                _monthYearPicker(),
                const SizedBox(height: 14),
                StreamBuilder<Map<String, double>>(
                  stream: analytics.watchMonthlySummary(selectedMonth),
                  builder: (context, sumSnap) {
                    final expense = _toDouble(sumSnap.data?['expense']);
                    final budget = _toDouble(budgetCtrl.monthlyBudget);
                    final appColors = Theme.of(
                      context,
                    ).extension<AppThemeColors>()!;

                    final rawUsedPct = budget <= 0 ? 0.0 : expense / budget;
                    final usedPct = rawUsedPct.clamp(0.0, 1.0);
                    final usedPercentText = (usedPct * 100).toStringAsFixed(0);
                    final isOverBudget = budget > 0 && expense > budget;
                    final progressColor = isOverBudget ? AppColors.danger : colors.primary;
                    final warningText = isOverBudget
                        ? 'Budget exceeded by RM ${(expense - budget).toStringAsFixed(2)}'
                        : null;

                    return Column(
                      children: [
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Budget',
                                style: TextStyle(
                                  fontSize: isNarrow ? 20 : 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: SizedBox(
                                  width: isNarrow ? 132 : 152,
                                  height: isNarrow ? 132 : 152,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      PieChart(
                                        PieChartData(
                                          startDegreeOffset: -90,
                                          centerSpaceRadius: isNarrow ? 46 : 54,
                                          sectionsSpace: 0,
                                          sections: [
                                            PieChartSectionData(
                                              value: usedPct * 100,
                                              color: progressColor,
                                              title: '',
                                            ),
                                            PieChartSectionData(
                                              value: (1 - usedPct) * 100,
                                              color: colors.outlineVariant,
                                              title: '',
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SafeText(
                                            '$usedPercentText%',
                                            style: TextStyle(
                                              fontSize: isNarrow ? 20 : 24,
                                              fontWeight: FontWeight.w800,
                                              color: appColors.textNumberPrimary,
                                            ),
                                          ),
                                          Text(
                                            'Used',
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: SafeText(
                                  'RM ${expense.toStringAsFixed(2)} / RM ${budget.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (warningText != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appColors.softWarningSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.danger.withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 18,
                                        color: AppColors.danger,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          warningText,
                                          style: TextStyle(
                                            color: AppColors.danger,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: analytics.watchMonthlyExpenseByCategory(
                            selectedMonth,
                          ),
                          builder: (context, catSnap) {
                            final data = catSnap.data ?? [];
                            final total = data.fold<double>(
                              0,
                              (p, e) => p + _toDouble(e['amount']),
                            );
                            final sortedData = [...data]
                              ..sort(
                                (a, b) => _toDouble(b['amount']).compareTo(
                                  _toDouble(a['amount']),
                                ),
                              );

                            final palette = <Color>[
                              colors.primary,
                              colors.secondary,
                              colors.tertiary,
                              colors.error,
                              colors.onSurfaceVariant,
                            ];

                            return _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Spending by Category',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 20 : 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (data.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Center(
                                        child: Text('No expense data'),
                                      ),
                                    )
                                  else ...[
                                    Center(
                                      child: SizedBox(
                                        width: isNarrow ? 176 : 204,
                                        height: isNarrow ? 176 : 204,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            PieChart(
                                              PieChartData(
                                                centerSpaceRadius:
                                                    isNarrow ? 56 : 66,
                                                sectionsSpace: 2,
                                                sections: List.generate(
                                                  sortedData.length,
                                                  (i) {
                                                    final amount = _toDouble(
                                                      sortedData[i]['amount'],
                                                    );
                                                    final v = total <= 0
                                                        ? 0.0
                                                        : (amount / total * 100);
                                                    return PieChartSectionData(
                                                      value: v,
                                                      color: palette[i % palette.length],
                                                      radius: isNarrow ? 44 : 52,
                                                      title: '',
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Total',
                                                  style: TextStyle(
                                                    color: colors.onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                SafeText(
                                                  'RM ${total.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color: appColors.textNumberPrimary,
                                                    fontSize: isNarrow ? 18 : 22,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    ...List.generate(sortedData.length, (i) {
                                      final id = sortedData[i]['categoryId']
                                          .toString();
                                      final amount = _toDouble(sortedData[i]['amount']);
                                      final pct = total <= 0
                                          ? 0.0
                                          : amount / total * 100;
                                      final color = palette[i % palette.length];

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.surfaceContainerHighest
                                                .withValues(alpha: 0.35),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: colors.outlineVariant
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: color,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      catName(id),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: colors.onSurface,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Text(
                                                        'RM ${amount.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color:
                                                              colors.onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${pct.toStringAsFixed(1)}%',
                                                    style: TextStyle(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                                child: LinearProgressIndicator(
                                                  minHeight: 8,
                                                  value: (pct / 100)
                                                      .clamp(0.0, 1.0),
                                                  backgroundColor:
                                                      colors.outlineVariant
                                                          .withValues(alpha: 0.25),
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(
                                                    color,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: analytics.watchMonthlyCashFlowCalendar(
                            selectedMonth,
                          ),
                          builder: (context, calSnap) {
                            final daily = calSnap.data ?? [];
                            return _card(
                              child: _cashFlowCalendar(
                                month: selectedMonth,
                                daily: daily,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 14),
                        _investmentPerformanceCard(),

                        const SizedBox(height: 14),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            side: BorderSide(color: colors.outlineVariant),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            final rootNavigator = Navigator.of(
                              context,
                              rootNavigator: true,
                            );
                            final budgetController = context
                                .read<BudgetController>();
                            final exportMonth =
                                await _pickExportMonthBottomSheet(
                                  navigator.context,
                                  selectedMonth,
                                );
                            if (exportMonth == null) return;

                            showDialog(
                              // ignore: use_build_context_synchronously
                              context: rootNavigator.context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            try {
                              final exportBudget = _toDouble(
                                budgetController.monthlyBudget,
                              );
                              final path = await analytics.exportMonthlyReport(
                                month: exportMonth,
                                categoryNameResolver: catName,
                                budget: exportBudget,
                                totalAssets: totalAssets(),
                                accounts: List<Map<String, dynamic>>.from(
                                  txCtrl.accounts,
                                ),
                              );

                              if (!mounted) return;
                              rootNavigator.pop();

                              final openResult = await OpenFilex.open(path);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    openResult.type.name == 'done'
                                        ? 'Report generated: ${DateFormat('MMM yyyy').format(exportMonth)}'
                                        : 'Report exported: $path',
                                  ),
                                  action: SnackBarAction(
                                    label: 'Share',
                                    onPressed: () async {
                                      await Share.shareXFiles([
                                        XFile(path),
                                      ], text: 'Smart Pocket Monthly Report');
                                    },
                                  ),
                                ),
                              );
                            } on TimeoutException {
                              if (!mounted) return;
                              rootNavigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Report Failed to Generate (timeout). Please retry.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              rootNavigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Report Failed to Generate: $e',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Export PDF Report'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (i) {
          if (i == 0) context.go('/dashboard');
          if (i == 1) context.go('/accounts');
          if (i == 2) context.go('/stats');
          if (i == 3) context.go('/settings');
        },
        onAddTap: () => context.push('/add-transaction'),
      ),
    );
  }

  Widget _investmentPerformanceCard() {
    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 380;
        final titleSize = isNarrow ? 18.0 : 22.0;
        final valueSize = isNarrow ? 24.0 : 30.0;
        final chartHeight = isNarrow ? 190.0 : 230.0;
        final appColors = Theme.of(context).extension<AppThemeColors>()!;

        return StreamBuilder<List<InvestmentPnlPoint>>(
          stream: context
              .read<AnalyticsController>()
              .watchInvestmentPnlPoints(),
          builder: (context, snap) {
            final points = snap.data ?? const <InvestmentPnlPoint>[];

            final year = selectedMonth.year;
            final daysInSelectedMonth = DateTime(
              selectedMonth.year,
              selectedMonth.month + 1,
              0,
            ).day;

            final monthly = <int, double>{for (int i = 1; i <= 12; i++) i: 0.0};
            final daily = <int, double>{
              for (int i = 1; i <= daysInSelectedMonth; i++) i: 0.0,
            };

            for (final point in points) {
              final dt = point.date;
              final diff = point.diff;
              if (dt.year != year) continue;

              monthly[dt.month] = (monthly[dt.month] ?? 0) + diff;
              if (dt.month == selectedMonth.month) {
                daily[dt.day] = (daily[dt.day] ?? 0) + diff;
              }
            }

            final groups = <BarChartGroupData>[];
            if (_investmentMonthlyView) {
              for (int m = 1; m <= 12; m++) {
                final v = monthly[m] ?? 0.0;
                groups.add(
                  BarChartGroupData(
                    x: m,
                    barRods: [
                      BarChartRodData(
                        toY: v,
                        width: isNarrow ? 7 : 10,
                        borderRadius: BorderRadius.circular(2),
                        color: v >= 0
                            ? appColors.positiveAmount
                            : appColors.negativeAmount,
                      ),
                    ],
                  ),
                );
              }
            } else {
              for (int d = 1; d <= daysInSelectedMonth; d++) {
                final v = daily[d] ?? 0.0;
                groups.add(
                  BarChartGroupData(
                    x: d,
                    barRods: [
                      BarChartRodData(
                        toY: v,
                        width: isNarrow ? 4 : 6,
                        borderRadius: BorderRadius.circular(2),
                        color: v >= 0
                            ? appColors.positiveAmount
                            : appColors.negativeAmount,
                      ),
                    ],
                  ),
                );
              }
            }

            final total = _investmentMonthlyView
                ? monthly.values.fold<double>(0, (p, e) => p + e)
                : daily.values.fold<double>(0, (p, e) => p + e);

            final hasData = groups.any(
              (g) => g.barRods.isNotEmpty && g.barRods.first.toY.abs() > 0.0001,
            );

            return _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.trending_up_rounded,
                            size: 18,
                            color: Color.fromARGB(255, 14, 165, 233),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Investment Performance',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SegmentedButton<bool>(
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          side: WidgetStateProperty.all(
                            BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        segments: const [
                          ButtonSegment(value: false, label: Text('Daily')),
                          ButtonSegment(value: true, label: Text('Monthly')),
                        ],
                        selected: {_investmentMonthlyView},
                        onSelectionChanged: (s) {
                          setState(() => _investmentMonthlyView = s.first);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _investmentMonthlyView
                        ? '${selectedMonth.year} Total P/L'
                        : '${_monthName(selectedMonth.month)} ${selectedMonth.year} Daily P/L',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${total >= 0 ? '+' : ''}RM ${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: valueSize,
                        fontWeight: FontWeight.w800,
                        color: total >= 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!hasData)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: Text('No investment P/L data')),
                    )
                  else
                    SizedBox(
                      height: chartHeight,
                      child: BarChart(
                        BarChartData(
                          barGroups: groups,
                          alignment: BarChartAlignment.spaceAround,
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: isNarrow ? 34 : 42,
                                getTitlesWidget: (v, meta) => Text(
                                  formatCompact(v),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                interval: _investmentMonthlyView
                                    ? 1
                                    : (isNarrow ? 7 : 5),
                                getTitlesWidget: (v, meta) {
                                  final i = v.toInt();
                                  return Text(
                                    '$i',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 8 : 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _pickExportMonthBottomSheet(
    BuildContext context,
    DateTime initial,
  ) async {
    final now = DateTime.now();
    int selectedYear = initial.year;
    int selectedMonth = initial.month;

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final years = List.generate(now.year - 2019, (i) => 2020 + i);
            final monthNames = const [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec',
            ];

            int maxMonthForYear = 12;
            if (selectedYear == now.year) maxMonthForYear = now.month;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Export Month',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Text(
                        'Year:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedYear,
                          items: years
                              .map(
                                (y) => DropdownMenuItem<int>(
                                  value: y,
                                  child: Text('$y'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setLocalState(() {
                              selectedYear = v;
                              final maxM = selectedYear == now.year
                                  ? now.month
                                  : 12;
                              if (selectedMonth > maxM) selectedMonth = maxM;
                            });
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Month:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(maxMonthForYear, (i) {
                      final m = i + 1;
                      final selected = m == selectedMonth;
                      return ChoiceChip(
                        label: Text(monthNames[i]),
                        selected: selected,
                        onSelected: (_) {
                          setLocalState(() => selectedMonth = m);
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              ctx,
                              DateTime(selectedYear, selectedMonth, 1),
                            );
                          },
                          child: const Text('Use This Month'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _monthYearPicker() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final label = '${_monthName(selectedMonth.month)} ${selectedMonth.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () async {
              final prev = DateTime(
                selectedMonth.year,
                selectedMonth.month - 1,
                1,
              );
              setState(() {
                selectedMonth = prev;
                selectedDay = null;
              });
              await context.read<BudgetController>().changeMonth(prev);
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final budgetController = context.read<BudgetController>();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedMonth,
                  firstDate: DateTime(2020, 1, 1),
                  lastDate: thisMonth,
                  initialDatePickerMode: DatePickerMode.year,
                  helpText: 'Select Month & Year',
                );
                if (picked == null) return;
                final m = DateTime(picked.year, picked.month, 1);
                setState(() {
                  selectedMonth = m;
                  selectedDay = null;
                });
                await budgetController.changeMonth(m);
              },
              child: Center(
                child: SafeText(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed:
                DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                  1,
                ).isAfter(thisMonth)
                ? null
                : () async {
                    final next = DateTime(
                      selectedMonth.year,
                      selectedMonth.month + 1,
                      1,
                    );
                    setState(() {
                      selectedMonth = next;
                      selectedDay = null;
                    });
                    await context.read<BudgetController>().changeMonth(next);
                  },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _cashFlowCalendar({
    required DateTime month,
    required List<Map<String, dynamic>> daily,
  }) {
    final colors = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppThemeColors>()!;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;

    final incomeByDay = <int, double>{};
    final expenseByDay = <int, double>{};
    final netByDay = <int, double>{};

    for (final d in daily) {
      final day = (d['day'] is int)
          ? d['day'] as int
          : int.tryParse('${d['day']}') ?? 0;
      if (day <= 0) continue;

      final income = _toDouble(d['income']);
      final expense = _toDouble(d['expense']);
      final netRaw = _toDouble(d['net']);
      final net = netRaw == 0 ? (income - expense) : netRaw;

      incomeByDay[day] = income;
      expenseByDay[day] = expense;
      netByDay[day] = net;
    }

    final cells = <Widget>[];
    const wd = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    for (final w in wd) {
      cells.add(
        Center(
          child: Text(
            w,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final lead = firstWeekday % 7;
    for (int i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }

    final today = DateTime.now();
    final isCurrentMonth =
        (today.year == month.year && today.month == month.month);

    for (int day = 1; day <= daysInMonth; day++) {
      final net = netByDay[day];
      final isToday = isCurrentMonth && today.day == day;
      final isSelected = selectedDay == day;

      cells.add(
        GestureDetector(
          onTap: () {
            setState(() {
              selectedDay = (selectedDay == day) ? null : day;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary
                        : (isToday
                              ? colors.primaryContainer
                              : Colors.transparent),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  net == null
                      ? '·'
                      : '${net > 0 ? '+' : ''}${net.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: net == null
                        ? colors.outlineVariant
                        : (net >= 0
                              ? appColors.positiveAmount
                              : appColors.negativeAmount),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pickedIncome = selectedDay == null
        ? 0.0
        : (incomeByDay[selectedDay!] ?? 0.0);
    final pickedExpense = selectedDay == null
        ? 0.0
        : (expenseByDay[selectedDay!] ?? 0.0);
    final pickedNet = pickedIncome - pickedExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Cash Flow Calendar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          childAspectRatio: 0.95,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
        if (selectedDay != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day $selectedDay details',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Expanded(child: Text('Income')),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '+${pickedIncome.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: appColors.positiveAmount,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(child: Text('Expense')),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '-${pickedExpense.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: appColors.negativeAmount,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Expanded(child: Text('Net')),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${pickedNet >= 0 ? '+' : ''}${pickedNet.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: pickedNet >= 0
                                ? appColors.positiveAmount
                                : appColors.negativeAmount,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: child,
    );
  }

  String _monthName(int m) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[m];
  }
}

class SafeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  const SafeText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

String formatCompact(double value) {
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value.abs() >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toStringAsFixed(2);
}
