import 'dart:convert';

import '../core/config/ai_insight_config.dart';
import '../core/models/ai_insight_result.dart';
import '../core/models/financial_snapshot.dart';
import '../core/utils/ai_insight_safety.dart';

final class AiInsightValidator {
  const AiInsightValidator();

  static const _requiredFields = {
    'headline',
    'what_happened',
    'why',
    'action',
    'evidence_keys',
  };

  AiInsightOutcome parseAndValidate({
    required String rawJson,
    required FinancialSnapshot snapshot,
  }) {
    if (rawJson.trim().isEmpty) {
      return _failure(AiInsightFailureReason.emptyResponse, snapshot);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException {
      return _failure(AiInsightFailureReason.malformedResponse, snapshot);
    }
    if (decoded is! Map<String, dynamic>) {
      return _failure(AiInsightFailureReason.malformedResponse, snapshot);
    }
    if (!_requiredFields.every(decoded.containsKey)) {
      return _failure(AiInsightFailureReason.missingRequiredField, snapshot);
    }
    if (decoded.keys.any((key) => !_requiredFields.contains(key))) {
      return _failure(AiInsightFailureReason.malformedResponse, snapshot);
    }

    final headline = _requiredText(decoded['headline']);
    final whatHappened = _requiredText(decoded['what_happened']);
    final why = _requiredText(decoded['why']);
    final action = _requiredText(decoded['action']);
    final rawEvidence = decoded['evidence_keys'];
    if (headline == null ||
        whatHappened == null ||
        why == null ||
        action == null ||
        rawEvidence is! List ||
        rawEvidence.length > AiInsightConfig.maxEvidenceKeys ||
        rawEvidence.any((value) => value is! String || value.trim().isEmpty) ||
        headline.length > AiInsightConfig.maxHeadlineCharacters ||
        whatHappened.length > AiInsightConfig.maxSectionCharacters ||
        why.length > AiInsightConfig.maxSectionCharacters ||
        action.length > AiInsightConfig.maxSectionCharacters) {
      return _failure(AiInsightFailureReason.malformedResponse, snapshot);
    }

    final evidenceKeys = <String>[];
    for (final value in rawEvidence.cast<String>()) {
      final key = value.trim();
      if (snapshot.hasEvidence(key) && !evidenceKeys.contains(key)) {
        evidenceKeys.add(key);
      }
    }
    if (evidenceKeys.isEmpty) {
      return _failure(AiInsightFailureReason.invalidEvidence, snapshot);
    }

    if (AiInsightSafety.containsRestrictedInvestmentAdvice([
      headline,
      whatHappened,
      why,
      action,
    ])) {
      return _failure(AiInsightFailureReason.restrictedAdvice, snapshot);
    }

    return AiInsightSuccess(
      AiInsightResult(
        headline: headline,
        whatHappened: whatHappened,
        why: why,
        action: action,
        severity: snapshot.severity,
        evidenceKeys: evidenceKeys,
        model: AiInsightConfig.modelName,
      ),
    );
  }

  String? _requiredText(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  AiInsightFailure _failure(
    AiInsightFailureReason reason,
    FinancialSnapshot snapshot,
  ) => AiInsightFailure(reason: reason, severity: snapshot.severity);
}
