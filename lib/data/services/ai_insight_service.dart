import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../application/ai_insight_prompt_builder.dart';
import '../../application/ai_insight_validator.dart';
import '../../core/config/ai_insight_config.dart';
import '../../core/models/ai_insight_result.dart';
import '../../core/models/financial_snapshot.dart';

abstract interface class AiContentGenerator {
  Future<String?> generate(String prompt);
}

final class FirebaseAiContentGenerator implements AiContentGenerator {
  FirebaseAiContentGenerator({FirebaseAI? firebaseAI})
    : _model =
          (firebaseAI ??
                  FirebaseAI.googleAI(
                    appCheck: FirebaseAppCheck.instance,
                    auth: FirebaseAuth.instance,
                  ))
              .generativeModel(
                model: AiInsightConfig.modelName,
                generationConfig: GenerationConfig(
                  responseMimeType: 'application/json',
                  responseSchema: _responseSchema,
                  temperature: 0.2,
                  maxOutputTokens: 512,
                ),
              );

  static final Schema _responseSchema = Schema.object(
    properties: {
      'headline': Schema.string(
        description: 'A concise financial insight headline.',
      ),
      'what_happened': Schema.string(
        description: 'One or two short sentences describing verified facts.',
      ),
      'why': Schema.string(
        description: 'One or two short evidence-based explanatory sentences.',
      ),
      'action': Schema.string(
        description: 'One calm, practical behavioral recommendation.',
      ),
      'evidence_keys': Schema.array(
        description: 'Keys copied exactly from the supplied evidence object.',
        items: Schema.string(),
        maxItems: AiInsightConfig.maxEvidenceKeys,
      ),
    },
  );

  final GenerativeModel _model;

  @override
  Future<String?> generate(String prompt) async {
    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text;
  }
}

final class AiInsightService {
  const AiInsightService({
    required AiContentGenerator generator,
    this.promptBuilder = const AiInsightPromptBuilder(),
    this.validator = const AiInsightValidator(),
  }) : _generator = generator;

  factory AiInsightService.firebase() =>
      AiInsightService(generator: FirebaseAiContentGenerator());

  final AiContentGenerator _generator;
  final AiInsightPromptBuilder promptBuilder;
  final AiInsightValidator validator;

  Future<AiInsightOutcome> generateInsight(FinancialSnapshot snapshot) async {
    String? response;
    try {
      response = await _generator.generate(promptBuilder.buildPrompt(snapshot));
    } catch (_) {
      return AiInsightFailure(
        reason: AiInsightFailureReason.generationFailed,
        severity: snapshot.severity,
      );
    }

    return validator.parseAndValidate(
      rawJson: response ?? '',
      snapshot: snapshot,
    );
  }
}
