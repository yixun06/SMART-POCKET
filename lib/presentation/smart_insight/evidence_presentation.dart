import 'package:intl/intl.dart';

import '../../core/models/financial_snapshot.dart';

enum EvidenceValueKind {
  money,
  signedMoney,
  percentage,
  percentagePoints,
  count,
}

final class EvidencePresentation {
  const EvidencePresentation({
    required this.label,
    required this.value,
    required this.kind,
  });

  final String label;
  final Object value;
  final EvidenceValueKind kind;

  String get formattedValue => EvidenceValueFormatter.format(value, kind);
}

abstract final class EvidencePresentationResolver {
  static EvidencePresentation? resolve({
    required FinancialSnapshot snapshot,
    required String evidenceKey,
  }) {
    final value = snapshot.evidenceValue(evidenceKey);
    if (value == null) return null;

    final category = snapshot.spending.categories
        .where((item) => evidenceKey.startsWith('${item.evidenceKeyPrefix}.'))
        .firstOrNull;
    if (category != null) {
      return _categoryPresentation(
        categoryName: category.categoryName,
        evidenceKey: evidenceKey,
        value: value,
      );
    }
    final definition = _definitions[evidenceKey];
    if (definition == null) return null;
    return EvidencePresentation(
      label: definition.label,
      value: value,
      kind: definition.kind,
    );
  }

  static EvidencePresentation? _categoryPresentation({
    required String categoryName,
    required String evidenceKey,
    required Object value,
  }) {
    final suffix = evidenceKey.split('.').last;
    final definition = switch (suffix) {
      'current_amount' => _EvidenceDefinition(
        '$categoryName Spending',
        EvidenceValueKind.money,
      ),
      'previous_amount' => _EvidenceDefinition(
        '$categoryName Previous Spending',
        EvidenceValueKind.money,
      ),
      'change_amount' => _EvidenceDefinition(
        '$categoryName Change',
        EvidenceValueKind.signedMoney,
      ),
      'change_pct' => _EvidenceDefinition(
        '$categoryName Change',
        EvidenceValueKind.percentage,
      ),
      _ => null,
    };
    if (definition == null) return null;
    return EvidencePresentation(
      label: definition.label,
      value: value,
      kind: definition.kind,
    );
  }

  static const _definitions = <String, _EvidenceDefinition>{
    'cashflow.income': _EvidenceDefinition(
      'Monthly Income',
      EvidenceValueKind.money,
    ),
    'cashflow.expense': _EvidenceDefinition(
      'Monthly Expenses',
      EvidenceValueKind.money,
    ),
    'cashflow.net': _EvidenceDefinition(
      'Net Cash Flow',
      EvidenceValueKind.signedMoney,
    ),
    'budget.amount': _EvidenceDefinition(
      'Monthly Budget',
      EvidenceValueKind.money,
    ),
    'budget.remaining': _EvidenceDefinition(
      'Budget Remaining',
      EvidenceValueKind.money,
    ),
    'budget.usage_pct': _EvidenceDefinition(
      'Budget Used',
      EvidenceValueKind.percentage,
    ),
    'budget.safe_daily_spend': _EvidenceDefinition(
      'Safe Daily Spend',
      EvidenceValueKind.money,
    ),
    'budget.expected_usage_pct': _EvidenceDefinition(
      'Expected Budget Used',
      EvidenceValueKind.percentage,
    ),
    'budget.pace_delta_pp': _EvidenceDefinition(
      'Spending Pace Difference',
      EvidenceValueKind.percentagePoints,
    ),
    'allocation.daily_use.actual_pct': _EvidenceDefinition(
      'Daily Use Allocation',
      EvidenceValueKind.percentage,
    ),
    'allocation.daily_use.target_pct': _EvidenceDefinition(
      'Daily Use Allocation Target',
      EvidenceValueKind.percentage,
    ),
    'allocation.daily_use.gap_pp': _EvidenceDefinition(
      'Daily Use Allocation Gap',
      EvidenceValueKind.percentagePoints,
    ),
    'allocation.savings.actual_pct': _EvidenceDefinition(
      'Savings Allocation',
      EvidenceValueKind.percentage,
    ),
    'allocation.savings.target_pct': _EvidenceDefinition(
      'Savings Allocation Target',
      EvidenceValueKind.percentage,
    ),
    'allocation.savings.gap_pp': _EvidenceDefinition(
      'Savings Allocation Gap',
      EvidenceValueKind.percentagePoints,
    ),
    'allocation.investment.actual_pct': _EvidenceDefinition(
      'Investment Allocation',
      EvidenceValueKind.percentage,
    ),
    'allocation.investment.target_pct': _EvidenceDefinition(
      'Investment Allocation Target',
      EvidenceValueKind.percentage,
    ),
    'allocation.investment.gap_pp': _EvidenceDefinition(
      'Investment Allocation Gap',
      EvidenceValueKind.percentagePoints,
    ),
    'recurring.next_30d_amount': _EvidenceDefinition(
      'Upcoming Recurring Expenses',
      EvidenceValueKind.money,
    ),
    'recurring.next_30d_occurrence_count': _EvidenceDefinition(
      'Upcoming Recurring Occurrences',
      EvidenceValueKind.count,
    ),
    'investment.monthly_pnl': _EvidenceDefinition(
      'Monthly Investment Performance',
      EvidenceValueKind.signedMoney,
    ),
  };
}

abstract final class EvidenceValueFormatter {
  static final NumberFormat _money = NumberFormat.currency(
    locale: 'en_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );
  static final NumberFormat _oneDecimal = NumberFormat('0.0', 'en_MY');

  static String format(Object value, EvidenceValueKind kind) {
    final number = value is num ? value.toDouble() : null;
    if (number == null || !number.isFinite) return 'Unavailable';
    return switch (kind) {
      EvidenceValueKind.money => _money.format(number),
      EvidenceValueKind.signedMoney =>
        '${_sign(number)}${_money.format(number.abs())}',
      EvidenceValueKind.percentage => '${_oneDecimal.format(number)}%',
      EvidenceValueKind.percentagePoints =>
        '${_sign(number)}${_oneDecimal.format(number.abs())} pp',
      EvidenceValueKind.count =>
        '${number.round()} ${number.round() == 1 ? 'occurrence' : 'occurrences'}',
    };
  }

  static String _sign(double value) => value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
}

final class _EvidenceDefinition {
  const _EvidenceDefinition(this.label, this.kind);

  final String label;
  final EvidenceValueKind kind;
}
