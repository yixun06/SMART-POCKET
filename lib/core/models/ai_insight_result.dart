import 'financial_snapshot.dart';

enum AiInsightFailureReason {
  generationFailed,
  emptyResponse,
  malformedResponse,
  missingRequiredField,
  invalidEvidence,
  restrictedAdvice,
}

sealed class AiInsightOutcome {
  const AiInsightOutcome();

  FinancialSeverity get severity;
  bool get isSuccess;
}

final class AiInsightSuccess extends AiInsightOutcome {
  const AiInsightSuccess(this.result);

  final AiInsightResult result;

  @override
  FinancialSeverity get severity => result.severity;

  @override
  bool get isSuccess => true;
}

final class AiInsightFailure extends AiInsightOutcome {
  const AiInsightFailure({
    required this.reason,
    required this.severity,
    this.userMessage = temporaryUnavailableMessage,
  });

  static const temporaryUnavailableMessage =
      'AI insight is temporarily unavailable.';

  final AiInsightFailureReason reason;
  final String userMessage;

  @override
  final FinancialSeverity severity;

  @override
  bool get isSuccess => false;
}

final class AiInsightResult {
  AiInsightResult({
    required this.headline,
    required this.whatHappened,
    required this.why,
    required this.action,
    required this.severity,
    required List<String> evidenceKeys,
    required this.model,
  }) : evidenceKeys = List.unmodifiable(evidenceKeys);

  final String headline;
  final String whatHappened;
  final String why;
  final String action;
  final FinancialSeverity severity;
  final List<String> evidenceKeys;
  final String model;

  Map<String, Object> toJson() => {
    'headline': headline,
    'what_happened': whatHappened,
    'why': why,
    'action': action,
    'severity': severity.name,
    'evidence_keys': evidenceKeys,
    'model': model,
  };
}
