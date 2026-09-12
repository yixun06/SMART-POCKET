import 'dart:convert';

import '../../core/config/ai_insight_config.dart';
import '../../core/models/ai_insight_result.dart';
import '../../core/models/financial_snapshot.dart';
import '../../core/utils/ai_insight_safety.dart';
import 'local_storage_service.dart';

enum AiInsightCacheLoadStatus { missing, found, corrupt }

final class CachedAiInsight {
  const CachedAiInsight({
    required this.month,
    required this.mode,
    required this.fingerprint,
    required this.result,
    required this.generatedAt,
  });

  final String month;
  final FinancialMode mode;
  final String fingerprint;
  final AiInsightResult result;
  final DateTime generatedAt;
}

final class AiInsightCacheLoadResult {
  const AiInsightCacheLoadResult._(this.status, this.record);

  const AiInsightCacheLoadResult.missing()
    : this._(AiInsightCacheLoadStatus.missing, null);
  const AiInsightCacheLoadResult.corrupt()
    : this._(AiInsightCacheLoadStatus.corrupt, null);
  const AiInsightCacheLoadResult.found(CachedAiInsight record)
    : this._(AiInsightCacheLoadStatus.found, record);

  final AiInsightCacheLoadStatus status;
  final CachedAiInsight? record;
}

abstract interface class AiInsightCache {
  Future<AiInsightCacheLoadResult> load({
    required String uid,
    required DateTime month,
    required FinancialMode mode,
  });

  Future<void> save({required String uid, required CachedAiInsight record});

  Future<void> remove({
    required String uid,
    required DateTime month,
    required FinancialMode mode,
  });
}

final class LocalAiInsightCache implements AiInsightCache {
  const LocalAiInsightCache(this._storage);

  static const _schemaVersion = 1;
  final LocalStorageService _storage;

  @override
  Future<AiInsightCacheLoadResult> load({
    required String uid,
    required DateTime month,
    required FinancialMode mode,
  }) async {
    final key = _key(uid, month, mode);
    final String? raw;
    try {
      raw = await _storage.readAiInsightCache(key);
    } catch (_) {
      return const AiInsightCacheLoadResult.corrupt();
    }
    if (raw == null) return const AiInsightCacheLoadResult.missing();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema_version'] != _schemaVersion) {
        throw const FormatException('Unsupported AI cache schema');
      }
      final cachedMonth = _requiredString(decoded['month']);
      final modeName = _requiredString(decoded['mode']);
      final fingerprint = _requiredString(decoded['snapshot_fingerprint']);
      final generatedAt = DateTime.tryParse(
        _requiredString(decoded['generated_at']),
      );
      final insight = decoded['insight'];
      if (generatedAt == null || insight is! Map<String, dynamic>) {
        throw const FormatException('Invalid AI cache metadata');
      }
      final parsedMode = FinancialMode.values
          .where((value) => value.name == modeName)
          .firstOrNull;
      final severityName = _requiredString(insight['severity']);
      final severity = FinancialSeverity.values
          .where((value) => value.name == severityName)
          .firstOrNull;
      final evidence = insight['evidence_keys'];
      if (parsedMode == null ||
          severity == null ||
          evidence is! List ||
          evidence.isEmpty ||
          evidence.length > AiInsightConfig.maxEvidenceKeys ||
          evidence.any((value) => value is! String || value.trim().isEmpty)) {
        throw const FormatException('Invalid AI cache insight');
      }

      final headline = _requiredString(insight['headline']);
      final whatHappened = _requiredString(insight['what_happened']);
      final why = _requiredString(insight['why']);
      final action = _requiredString(insight['action']);
      final model = _requiredString(insight['model']);
      if (headline.length > AiInsightConfig.maxHeadlineCharacters ||
          whatHappened.length > AiInsightConfig.maxSectionCharacters ||
          why.length > AiInsightConfig.maxSectionCharacters ||
          action.length > AiInsightConfig.maxSectionCharacters ||
          AiInsightSafety.containsRestrictedInvestmentAdvice([
            headline,
            whatHappened,
            why,
            action,
          ])) {
        throw const FormatException('AI cache insight exceeds limits');
      }

      return AiInsightCacheLoadResult.found(
        CachedAiInsight(
          month: cachedMonth,
          mode: parsedMode,
          fingerprint: fingerprint,
          result: AiInsightResult(
            headline: headline,
            whatHappened: whatHappened,
            why: why,
            action: action,
            severity: severity,
            evidenceKeys: evidence.cast<String>(),
            model: model,
          ),
          generatedAt: generatedAt,
        ),
      );
    } catch (_) {
      try {
        await _storage.removeAiInsightCache(key);
      } catch (_) {}
      return const AiInsightCacheLoadResult.corrupt();
    }
  }

  @override
  Future<void> save({required String uid, required CachedAiInsight record}) {
    final value = jsonEncode({
      'schema_version': _schemaVersion,
      'month': record.month,
      'mode': record.mode.name,
      'snapshot_fingerprint': record.fingerprint,
      'generated_at': record.generatedAt.toUtc().toIso8601String(),
      'insight': record.result.toJson(),
    });
    return _storage.saveAiInsightCache(
      _key(uid, _parseMonth(record.month), record.mode),
      value,
    );
  }

  @override
  Future<void> remove({
    required String uid,
    required DateTime month,
    required FinancialMode mode,
  }) => _storage.removeAiInsightCache(_key(uid, month, mode));

  String _key(String uid, DateTime month, FinancialMode mode) =>
      'ai_insight_cache_v$_schemaVersion.$uid.${_month(month)}.${mode.name}';

  String _month(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';

  DateTime _parseMonth(String value) {
    final parsed = DateTime.tryParse('$value-01');
    if (parsed == null) throw const FormatException('Invalid cache month');
    return parsed;
  }

  String _requiredString(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Required cache string missing');
    }
    return value.trim();
  }
}
