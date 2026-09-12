import 'dart:convert';

import '../core/models/financial_snapshot.dart';
import 'ai_insight_prompt_builder.dart';

final class AiInsightSnapshotFingerprint {
  const AiInsightSnapshotFingerprint({
    this.promptBuilder = const AiInsightPromptBuilder(),
  });

  final AiInsightPromptBuilder promptBuilder;

  String compute(FinancialSnapshot snapshot) {
    final canonical = jsonEncode(promptBuilder.buildSafePayload(snapshot));
    final mask = BigInt.parse('ffffffffffffffff', radix: 16);
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    for (final byte in utf8.encode(canonical)) {
      hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
