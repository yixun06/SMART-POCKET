import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/constants.dart';

class BackupPreview {
  final int accountCount;
  final int transactionCount;
  final DateTime? lastBackupAt;

  const BackupPreview({
    required this.accountCount,
    required this.transactionCount,
    required this.lastBackupAt,
  });
}

class BackupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(AppCollections.users).doc(uid);

  CollectionReference<Map<String, dynamic>> _col(String uid, String name) =>
      _userDoc(uid).collection(name);

  List<String> get _backupCollections => const [
        AppCollections.accounts,
        AppCollections.transactions,
        AppCollections.categories,
        AppCollections.budgets,
        AppCollections.shortcuts,
        AppCollections.assetProfiles,
        AppCollections.investmentPnlLogs,
        AppCollections.recurring,
        AppCollections.recurringPlans,
        AppCollections.recurringExecutions,
        AppCollections.systemNotifications,
      ];

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {'__ts': value.millisecondsSinceEpoch};
    }
    if (value is DateTime) {
      return {'__ts': value.millisecondsSinceEpoch};
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _encodeValue(v)));
    }
    if (value is List) {
      return value.map(_encodeValue).toList(growable: false);
    }
    return value;
  }

  dynamic _decodeValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      if (value.length == 1 && value.containsKey('__ts')) {
        final ms = value['__ts'];
        if (ms is num) return Timestamp.fromMillisecondsSinceEpoch(ms.toInt());
        return value;
      }
      return value.map((k, v) => MapEntry(k, _decodeValue(v)));
    }
    if (value is List) {
      return value.map(_decodeValue).toList(growable: false);
    }
    return value;
  }

  Future<List<Map<String, dynamic>>> _readCollectionDocs(String uid, String name) async {
    final snap = await _col(uid, name).get();
    return snap.docs
        .map((d) => {'id': d.id, 'data': _encodeValue(d.data())})
        .toList(growable: false);
  }

  Future<BackupPreview> buildPreview(String uid) async {
    final accSnap = await _col(uid, AppCollections.accounts).get();
    final txSnap = await _col(uid, AppCollections.transactions).get();
    final lastBackupSnap = await _col(uid, AppCollections.backups)
        .orderBy(CommonFields.createdAt, descending: true)
        .limit(1)
        .get();

    DateTime? lastBackupAt;
    if (lastBackupSnap.docs.isNotEmpty) {
      final data = lastBackupSnap.docs.first.data();
      final ts = data[CommonFields.createdAt];
      if (ts is Timestamp) lastBackupAt = ts.toDate();
    }

    return BackupPreview(
      accountCount: accSnap.size,
      transactionCount: txSnap.size,
      lastBackupAt: lastBackupAt,
    );
  }

  Future<Map<String, dynamic>> buildBackupPayload(String uid) async {
    final userSnap = await _userDoc(uid).get();
    final userData = userSnap.data() ?? {};
    final settings = (userData[UserFields.settings] as Map<String, dynamic>?) ?? {};
    final onboarding = (userData[UserFields.onboarding] as Map<String, dynamic>?) ?? {};

    final collections = <String, dynamic>{};
    for (final name in _backupCollections) {
      collections[name] = await _readCollectionDocs(uid, name);
    }

    final payload = <String, dynamic>{
      'schema_version': 2,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'uid': uid,
      'user': {
        UserFields.settings: _encodeValue(settings),
        UserFields.onboarding: _encodeValue(onboarding),
      },
      'collections': collections,
    };
    return payload;
  }

  Future<String> exportBackupJson(String uid) async {
    final payload = await buildBackupPayload(uid);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> createCloudBackup(String uid) async {
    final payload = await buildBackupPayload(uid);
    final backups = _col(uid, AppCollections.backups);
    final doc = backups.doc();
    final collections = (payload['collections'] as Map<String, dynamic>);
    final accountCount = (collections[AppCollections.accounts] as List).length;
    final txCount = (collections[AppCollections.transactions] as List).length;

    await doc.set({
      CommonFields.id: doc.id,
      CommonFields.userId: uid,
      CommonFields.createdAt: FieldValue.serverTimestamp(),
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
      'schema_version': 2,
      'account_count': accountCount,
      'transaction_count': txCount,
      'payload': payload,
    });
  }

  Future<void> restoreFromLatestCloudBackup(String uid) async {
    final snap = await _col(uid, AppCollections.backups)
        .orderBy(CommonFields.createdAt, descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      throw Exception('No cloud backup found');
    }
    final data = snap.docs.first.data();
    final payload = data['payload'];
    if (payload is! Map<String, dynamic>) {
      throw Exception('Invalid backup payload');
    }
    await restoreFromPayload(uid, payload);
  }

  Future<void> restoreFromBackupJson(String uid, String jsonText) async {
    final raw = jsonDecode(jsonText);
    if (raw is! Map<String, dynamic>) throw Exception('Invalid backup JSON');
    await restoreFromPayload(uid, raw);
  }

  Future<void> restoreFromPayload(String uid, Map<String, dynamic> payload) async {
    final collections = (payload['collections'] as Map<String, dynamic>?);
    if (collections == null) throw Exception('Invalid backup collections');

    Future<void> clearCollection(String name) async {
      final ref = _col(uid, name);
      while (true) {
        final s = await ref.limit(300).get();
        if (s.docs.isEmpty) break;
        final b = _db.batch();
        for (final d in s.docs) {
          b.delete(d.reference);
        }
        await b.commit();
      }
    }

    for (final name in _backupCollections) {
      await clearCollection(name);
    }

    final user = (payload['user'] as Map<String, dynamic>?) ?? {};
    final settings = _decodeValue((user[UserFields.settings] ?? const <String, dynamic>{}));
    final onboarding = _decodeValue((user[UserFields.onboarding] ?? const <String, dynamic>{}));
    await _userDoc(uid).set({
      CommonFields.id: uid,
      UserFields.settings: settings,
      UserFields.onboarding: onboarding,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final entry in collections.entries) {
      final name = entry.key;
      final docs = entry.value;
      if (docs is! List) continue;
      final ref = _col(uid, name);
      for (var i = 0; i < docs.length; i += 300) {
        final chunk = docs.sublist(i, i + 300 > docs.length ? docs.length : i + 300);
        final b = _db.batch();
        for (final rawDoc in chunk) {
          if (rawDoc is! Map<String, dynamic>) continue;
          final id = (rawDoc['id'] ?? '').toString().trim();
          final rawData = rawDoc['data'];
          if (id.isEmpty || rawData is! Map<String, dynamic>) continue;
          final decoded = _decodeValue(rawData) as Map<String, dynamic>;
          b.set(ref.doc(id), decoded, SetOptions(merge: false));
        }
        await b.commit();
      }
    }

    await _postRestoreNormalize(uid);
  }

  Future<void> _postRestoreNormalize(String uid) async {
    final userSnap = await _userDoc(uid).get();
    final userData = userSnap.data() ?? {};
    final settings = (userData[UserFields.settings] as Map<String, dynamic>?) ?? {};
    final mode = (settings[UserSettingsFields.appMode] ?? 'lazy').toString().toLowerCase();
    final origin = (settings[UserSettingsFields.appModeOrigin] ?? '').toString().toLowerCase();

    final accountSnap = await _col(uid, AppCollections.accounts).get();
    final accounts = accountSnap.docs.map((e) => {'id': e.id, ...e.data()}).toList();

    double total = 0;
    for (final a in accounts) {
      final bal = a[AccountFields.balance];
      total += bal is num ? bal.toDouble() : 0.0;
    }

    await _col(uid, AppCollections.assetProfiles).doc('main').set({
      CommonFields.id: 'main',
      CommonFields.userId: uid,
      AssetProfileFields.mode: mode == 'detailed' ? 'detailed' : 'lazy',
      AssetProfileFields.totalAsset: total < 0 ? 0.0 : total,
      AssetProfileFields.lastConsolidatedAt: FieldValue.serverTimestamp(),
      AssetProfileFields.consolidationVersion: 2,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final shouldRebuildVirtual = mode == 'lazy' && (origin == 'standalone' || origin == 'lazy' || origin.isEmpty);
    if (!shouldRebuildVirtual) return;

    bool hasTag(String tag) => accounts.any(
          (a) => (a[AccountFields.tag] ?? '').toString().trim().toLowerCase() == tag,
        );
    if (hasTag('daily_use') && hasTag('savings') && hasTag('investment')) return;

    final now = FieldValue.serverTimestamp();
    final ref = _col(uid, AppCollections.accounts);
    final virtuals = <Map<String, dynamic>>[
      {
        'id': 'virtual_daily_use_wallet',
        'name': 'Daily Use Wallet',
        'provider': 'Daily Use Wallet',
        'type': 'cash',
        'kind': 'standard',
        'tag': 'daily_use',
        'is_liquid': true,
      },
      {
        'id': 'virtual_savings_pool',
        'name': 'Savings Pool',
        'provider': 'Savings Pool',
        'type': 'bank',
        'kind': 'standard',
        'tag': 'savings',
        'is_liquid': true,
      },
      {
        'id': 'virtual_investment_pool',
        'name': 'Investment Pool',
        'provider': 'Investment Pool',
        'type': 'investment',
        'kind': 'investment',
        'tag': 'investment',
        'is_liquid': false,
      },
    ];

    final batch = _db.batch();
    for (final v in virtuals) {
      if (hasTag((v['tag'] as String))) continue;
      final id = v['id'] as String;
      batch.set(ref.doc(id), {
        CommonFields.id: id,
        CommonFields.userId: uid,
        AccountFields.name: v['name'],
        AccountFields.provider: v['provider'],
        AccountFields.type: v['type'],
        AccountFields.kind: v['kind'],
        AccountFields.tag: v['tag'],
        AccountFields.accountNumber: '',
        AccountFields.isLiquid: v['is_liquid'],
        AccountFields.isPrimary: true,
        AccountFields.isVirtual: true,
        AccountFields.balance: 0.0,
        CommonFields.createdAt: now,
        CommonFields.updatedAt: now,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
