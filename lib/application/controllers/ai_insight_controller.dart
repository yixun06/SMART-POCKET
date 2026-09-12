import 'package:flutter/foundation.dart';

import '../../core/config/ai_insight_config.dart';
import '../../core/models/ai_insight_result.dart';
import '../../core/models/financial_snapshot.dart';
import '../../data/services/ai_insight_cache_service.dart';
import '../../data/services/ai_insight_service.dart';
import '../ai_insight_snapshot_fingerprint.dart';
import '../financial_snapshot_collector.dart';

enum AiInsightControllerStatus {
  idle,
  loadingSnapshot,
  readyToGenerate,
  generating,
  success,
  failure,
}

enum AiInsightControllerFailureKind {
  snapshotCollection,
  aiGeneration,
  cacheDecoding,
}

final class AiInsightController extends ChangeNotifier {
  AiInsightController({
    required FinancialSnapshotCollector collector,
    required AiInsightCache cache,
    required AiInsightService? service,
    this.fingerprint = const AiInsightSnapshotFingerprint(),
    DateTime Function()? clock,
  }) : _collector = collector,
       _cache = cache,
       _service = service,
       _clock = clock ?? DateTime.now;

  static const _unavailableMessage = 'AI insight is temporarily unavailable.';

  final FinancialSnapshotCollector _collector;
  final AiInsightCache _cache;
  final AiInsightService? _service;
  final DateTime Function() _clock;
  final AiInsightSnapshotFingerprint fingerprint;

  AiInsightControllerStatus _status = AiInsightControllerStatus.idle;
  AiInsightControllerFailureKind? _failureKind;
  FinancialSnapshot? _snapshot;
  AiInsightResult? _insight;
  AiInsightResult? _cachedInsight;
  CachedAiInsight? _cacheRecord;
  String? _snapshotFingerprint;
  String? _userFacingError;
  String? _refreshError;
  String? _activeUid;
  bool _isStale = false;
  int _sessionRevision = 0;

  AiInsightControllerStatus get status => _status;
  AiInsightControllerFailureKind? get failureKind => _failureKind;
  FinancialSnapshot? get snapshot => _snapshot;
  AiInsightResult? get insight => _insight;
  AiInsightResult? get cachedInsight => _cachedInsight;
  DateTime? get cachedGeneratedAt => _cacheRecord?.generatedAt;
  String? get snapshotFingerprint => _snapshotFingerprint;
  String? get userFacingError => _userFacingError;
  String? get refreshError => _refreshError;
  bool get isLoading =>
      _status == AiInsightControllerStatus.loadingSnapshot ||
      _status == AiInsightControllerStatus.generating;
  bool get canGenerate => !isLoading && _collector.currentUserId != null;
  bool get hasCachedInsight => _cachedInsight != null;
  bool get isStale => _isStale;

  Future<void> prepareSnapshot() async {
    if (isLoading) return;
    await _prepareSnapshot();
  }

  Future<void> generateInsight() async {
    if (isLoading) return;
    final prepared = await _prepareSnapshot();
    if (prepared == null || prepared.hasMatchingCache) return;
    await _generate(prepared, isRefresh: false);
  }

  Future<void> refreshInsight() async {
    if (isLoading) return;
    final prepared = await _prepareSnapshot();
    if (prepared == null) return;
    await _generate(prepared, isRefresh: true);
  }

  void handleAuthChanged(String? uid) {
    if (_activeUid == uid) return;
    _activeUid = uid;
    _sessionRevision++;
    _clearState(notify: true);
  }

  Future<_PreparedSnapshot?> _prepareSnapshot() async {
    _status = AiInsightControllerStatus.loadingSnapshot;
    _failureKind = null;
    _userFacingError = null;
    _refreshError = null;
    notifyListeners();

    final uid = _collector.currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      _setSnapshotFailure(
        const FinancialSnapshotCollectionFailure(
          FinancialSnapshotCollectionFailureReason.unauthenticated,
        ),
      );
      return null;
    }
    if (_activeUid != uid) {
      _activeUid = uid;
      _sessionRevision++;
      _clearState(notify: false);
      _status = AiInsightControllerStatus.loadingSnapshot;
    }
    final revision = _sessionRevision;

    final FinancialSnapshot nextSnapshot;
    try {
      nextSnapshot = await _collector.buildCurrentSnapshot(now: _clock());
    } on FinancialSnapshotCollectionFailure catch (failure) {
      if (_isCurrent(uid, revision)) _setSnapshotFailure(failure);
      return null;
    } catch (_) {
      if (_isCurrent(uid, revision)) {
        _setSnapshotFailure(
          const FinancialSnapshotCollectionFailure(
            FinancialSnapshotCollectionFailureReason.monthlySummaryUnavailable,
          ),
        );
      }
      return null;
    }
    if (!_isCurrent(uid, revision)) return null;

    final nextFingerprint = fingerprint.compute(nextSnapshot);
    late final AiInsightCacheLoadResult cacheLoad;
    try {
      cacheLoad = await _cache.load(
        uid: uid,
        month: nextSnapshot.context.period,
        mode: nextSnapshot.context.mode,
      );
    } catch (_) {
      cacheLoad = const AiInsightCacheLoadResult.corrupt();
    }
    if (!_isCurrent(uid, revision)) return null;

    _snapshot = nextSnapshot;
    _snapshotFingerprint = nextFingerprint;
    _failureKind = cacheLoad.status == AiInsightCacheLoadStatus.corrupt
        ? AiInsightControllerFailureKind.cacheDecoding
        : null;
    _applyCache(
      uid: uid,
      snapshot: nextSnapshot,
      fingerprintValue: nextFingerprint,
      load: cacheLoad,
    );
    notifyListeners();
    return _PreparedSnapshot(
      uid: uid,
      revision: revision,
      snapshot: nextSnapshot,
      fingerprint: nextFingerprint,
      hasMatchingCache: _insight != null && !_isStale,
    );
  }

  void _applyCache({
    required String uid,
    required FinancialSnapshot snapshot,
    required String fingerprintValue,
    required AiInsightCacheLoadResult load,
  }) {
    final record = load.record;
    if (record == null) {
      _cacheRecord = null;
      _cachedInsight = null;
      _insight = null;
      _isStale = false;
      _status = AiInsightControllerStatus.readyToGenerate;
      return;
    }

    final correctMonth = record.month == _month(snapshot.context.period);
    final evidenceIsCurrent =
        record.result.evidenceKeys.isNotEmpty &&
        record.result.evidenceKeys.length <= AiInsightConfig.maxEvidenceKeys &&
        record.result.evidenceKeys.every(snapshot.hasEvidence);
    final deterministicDataMatches =
        record.mode == snapshot.context.mode &&
        record.result.severity == snapshot.severity &&
        record.result.model == AiInsightConfig.modelName;
    if (!correctMonth || !evidenceIsCurrent || !deterministicDataMatches) {
      _cacheRecord = null;
      _cachedInsight = null;
      _insight = null;
      _isStale = false;
      _status = AiInsightControllerStatus.readyToGenerate;
      _removeInvalidCache(uid, snapshot);
      return;
    }

    _cacheRecord = record;
    _cachedInsight = record.result;
    _isStale = record.fingerprint != fingerprintValue;
    _insight = _isStale ? null : record.result;
    _status = _isStale
        ? AiInsightControllerStatus.readyToGenerate
        : AiInsightControllerStatus.success;
  }

  Future<void> _generate(
    _PreparedSnapshot prepared, {
    required bool isRefresh,
  }) async {
    _status = AiInsightControllerStatus.generating;
    _failureKind = null;
    _userFacingError = null;
    _refreshError = null;
    notifyListeners();

    final service = _service;
    if (service == null) {
      _setGenerationFailure(isRefresh: isRefresh);
      return;
    }
    final AiInsightOutcome outcome;
    try {
      outcome = await service.generateInsight(prepared.snapshot);
    } catch (_) {
      if (_isCurrent(prepared.uid, prepared.revision)) {
        _setGenerationFailure(isRefresh: isRefresh);
      }
      return;
    }
    if (!_isCurrent(prepared.uid, prepared.revision)) return;

    if (outcome case AiInsightSuccess(:final result)) {
      final record = CachedAiInsight(
        month: _month(prepared.snapshot.context.period),
        mode: prepared.snapshot.context.mode,
        fingerprint: prepared.fingerprint,
        result: result,
        generatedAt: _clock(),
      );
      var cacheFailed = false;
      try {
        await _cache.save(uid: prepared.uid, record: record);
      } catch (_) {
        cacheFailed = true;
      }
      if (!_isCurrent(prepared.uid, prepared.revision)) return;
      _cacheRecord = record;
      _cachedInsight = result;
      _insight = result;
      _isStale = false;
      _status = AiInsightControllerStatus.success;
      _failureKind = cacheFailed
          ? AiInsightControllerFailureKind.cacheDecoding
          : null;
      notifyListeners();
      return;
    }

    _setGenerationFailure(
      isRefresh: isRefresh,
      message: (outcome as AiInsightFailure).userMessage,
    );
  }

  void _setSnapshotFailure(FinancialSnapshotCollectionFailure failure) {
    _status = AiInsightControllerStatus.failure;
    _failureKind = AiInsightControllerFailureKind.snapshotCollection;
    _userFacingError = failure.userMessage;
    notifyListeners();
  }

  void _setGenerationFailure({
    required bool isRefresh,
    String message = _unavailableMessage,
  }) {
    _status = AiInsightControllerStatus.failure;
    _failureKind = AiInsightControllerFailureKind.aiGeneration;
    _userFacingError = message;
    if (isRefresh) _refreshError = message;
    notifyListeners();
  }

  void _removeInvalidCache(String uid, FinancialSnapshot snapshot) {
    _cache
        .remove(
          uid: uid,
          month: snapshot.context.period,
          mode: snapshot.context.mode,
        )
        .catchError((_) {});
  }

  bool _isCurrent(String uid, int revision) =>
      _activeUid == uid &&
      _collector.currentUserId == uid &&
      _sessionRevision == revision;

  String _month(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';

  void _clearState({required bool notify}) {
    _status = AiInsightControllerStatus.idle;
    _failureKind = null;
    _snapshot = null;
    _insight = null;
    _cachedInsight = null;
    _cacheRecord = null;
    _snapshotFingerprint = null;
    _userFacingError = null;
    _refreshError = null;
    _isStale = false;
    if (notify) notifyListeners();
  }
}

final class _PreparedSnapshot {
  const _PreparedSnapshot({
    required this.uid,
    required this.revision,
    required this.snapshot,
    required this.fingerprint,
    required this.hasMatchingCache,
  });

  final String uid;
  final int revision;
  final FinancialSnapshot snapshot;
  final String fingerprint;
  final bool hasMatchingCache;
}
