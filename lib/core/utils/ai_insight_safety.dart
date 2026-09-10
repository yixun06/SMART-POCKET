abstract final class AiInsightSafety {
  static const restrictedInvestmentResponse =
      'Smart Pocket does not predict future asset prices or provide buy, '
      'sell, hold, or market-timing recommendations. It can explain recorded '
      'performance, allocation, risk exposure, or factual investment concepts '
      'instead.';

  static final List<RegExp> _restrictedPatterns = [
    RegExp(
      r'\b(buy|sell|hold)\b.{0,40}\b(stock|share|asset|investment|fund|crypto)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(stock|share|asset|investment|fund|crypto)\b.{0,40}\b(buy|sell|hold)\b',
      caseSensitive: false,
    ),
    RegExp(r'\bmarket[- ]timing\b', caseSensitive: false),
    RegExp(r'\b(entry|exit)\s+timing\b', caseSensitive: false),
    RegExp(
      r'\b(predict|forecast)\w*\b.{0,40}\b(price|return)s?\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(price|return)s?\b.{0,40}\b(predict|forecast)\w*\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\bguarantee\w*\b.{0,30}\b(profit|return|outcome)s?\b',
      caseSensitive: false,
    ),
  ];

  static bool containsRestrictedInvestmentAdvice(Iterable<String> sections) {
    final text = sections.join(' ');
    return _restrictedPatterns.any((pattern) => pattern.hasMatch(text));
  }
}
