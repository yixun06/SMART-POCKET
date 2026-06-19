import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/constants.dart';
import '../../core/models/investment_pnl_point.dart';

class AccountService {
  final _db = FirebaseFirestore.instance;
  String _normalizeTag(String tag) => tag.trim().toLowerCase();
  String _validatedTag(String? tag) {
    final normalized = _normalizeTag(tag ?? '');
    if (normalized != 'daily_use' &&
        normalized != 'savings' &&
        normalized != 'investment') {
      throw Exception('Invalid allocation tag');
    }
    return normalized;
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection(AppCollections.users).doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _accounts(String uid) {
    return _userDoc(uid).collection(AppCollections.accounts);
  }

  DocumentReference<Map<String, dynamic>> _assetProfile(String uid) {
    return _userDoc(uid).collection(AppCollections.assetProfiles).doc('main');
  }

  CollectionReference<Map<String, dynamic>> _investmentPnl(String uid) {
    return _userDoc(uid).collection(AppCollections.investmentPnlLogs);
  }

  Stream<Map<String, dynamic>> watchUserData(String uid) {
    return _userDoc(uid).snapshots().map((s) => s.data() ?? {});
  }

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception('User not logged in');
    return u.uid;
  }

  Future<void> ensureDefaultAccount(String uid) async {
    final ref = _accounts(uid).doc('default_cash');
    DocumentSnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await ref.get();
    } catch (_) {
      snap = null;
    }
    final data = snap?.data();
    final payload = <String, dynamic>{
      CommonFields.id: 'default_cash',
      CommonFields.userId: uid,
      AccountFields.name: 'Cash',
      AccountFields.provider: 'Cash',
      AccountFields.type: 'cash',
      AccountFields.kind: 'standard',
      AccountFields.tag: 'daily_use',
      AccountFields.isLiquid: true,
      AccountFields.balance: FieldValue.increment(0),
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    };
    if (snap != null &&
        (!snap.exists || data?[CommonFields.createdAt] == null)) {
      payload[CommonFields.createdAt] = FieldValue.serverTimestamp();
    }
    await ref.set(payload, SetOptions(merge: true));
  }

  Future<void> ensureAssetProfile(String uid) async {
    final ref = _assetProfile(uid);
    final s = await ref.get();
    if (!s.exists) {
      await ref.set({
        CommonFields.id: 'main',
        CommonFields.userId: uid,
        AssetProfileFields.mode: 'detailed',
        AssetProfileFields.totalAsset: 0.0,
        CommonFields.createdAt: FieldValue.serverTimestamp(),
        CommonFields.updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<Map<String, dynamic>> watchAssetProfile(String uid) {
    return _assetProfile(uid).snapshots().map((s) {
      final m = s.data() ?? {};
      return {
        'mode': (m[AssetProfileFields.mode] ?? 'detailed').toString(),
        'total_asset': ((m[AssetProfileFields.totalAsset] ?? 0) as num)
            .toDouble(),
      };
    });
  }

  Future<void> setAssetMode(String uid, String mode) async {
    if (mode != 'lazy' && mode != 'detailed') {
      throw Exception('Invalid mode');
    }
    await ensureAssetProfile(uid);
    await _assetProfile(uid).set({
      AssetProfileFields.mode: mode,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setTotalAsset(String uid, double amount) async {
    if (amount < 0) throw Exception('Invalid total asset');
    await ensureAssetProfile(uid);
    await _assetProfile(uid).set({
      AssetProfileFields.totalAsset: amount,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncAssetProfile({
    required String uid,
    required String mode,
    required double totalAsset,
    bool includeCreatedAt = false,
  }) async {
    final data = <String, dynamic>{
      CommonFields.id: 'main',
      CommonFields.userId: uid,
      AssetProfileFields.mode: mode,
      AssetProfileFields.totalAsset: totalAsset,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    };
    if (mode == 'lazy') {
      data[AssetProfileFields.lastConsolidatedAt] =
          FieldValue.serverTimestamp();
      data[AssetProfileFields.consolidationVersion] = 2;
    }
    if (includeCreatedAt) {
      data[CommonFields.createdAt] = FieldValue.serverTimestamp();
    }
    await _assetProfile(uid).set(data, SetOptions(merge: true));
  }

  Future<void> createBucketPrimaryAccount({
    required String uid,
    required String tag,
  }) async {
    final id = 'lazy_${tag}_primary';
    final isInvestment = tag == 'investment';
    final name = switch (tag) {
      'daily_use' => 'Daily Use Wallet',
      'savings' => 'Savings Wallet',
      _ => 'Investment Account',
    };
    await _accounts(uid).doc(id).set({
      CommonFields.id: id,
      CommonFields.userId: uid,
      AccountFields.name: name,
      AccountFields.provider: name,
      AccountFields.type: isInvestment ? 'investment' : 'cash',
      AccountFields.kind: isInvestment ? 'investment' : 'standard',
      AccountFields.balance: 0.0,
      AccountFields.tag: tag,
      AccountFields.isPrimary: true,
      AccountFields.isLiquid: !isInvestment,
      CommonFields.createdAt: FieldValue.serverTimestamp(),
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> watchAccounts(String uid) {
    return _accounts(uid).snapshots().map((s) {
      final rows = s.docs.map((d) {
        final m = d.data();
        final type = (m[AccountFields.type] ?? 'cash').toString();
        final createdRaw = m[CommonFields.createdAt];
        int createdAtMillis = 0;
        if (createdRaw is Timestamp) {
          createdAtMillis = createdRaw.millisecondsSinceEpoch;
        } else if (createdRaw is DateTime) {
          createdAtMillis = createdRaw.millisecondsSinceEpoch;
        } else if (createdRaw is num) {
          createdAtMillis = createdRaw.toInt();
        }
        return {
          'docId': d.id,
          '_id': d.id,
          ...m,
          AccountFields.balance: ((m[AccountFields.balance] ?? 0) as num)
              .toDouble(),
          AccountFields.kind:
              (m[AccountFields.kind] ??
                      (type == 'investment' ? 'investment' : 'standard'))
                  .toString(),
          'createdAtMillis': createdAtMillis,
        };
      }).toList();
      rows.sort((a, b) {
        final aMillis = (a['createdAtMillis'] as num?)?.toInt() ?? 0;
        final bMillis = (b['createdAtMillis'] as num?)?.toInt() ?? 0;
        final timeCompare = aMillis.compareTo(bMillis);
        if (timeCompare != 0) return timeCompare;
        return (a['_id'] ?? '').toString().compareTo(
          (b['_id'] ?? '').toString(),
        );
      });
      return rows;
    });
  }

  Future<String> createAccountWithPayload({
    required String uid,
    required double openingBalance,
    required Map<String, dynamic> payload,
  }) async {
    final doc = _accounts(uid).doc();
    await doc.set({
      CommonFields.id: doc.id,
      CommonFields.userId: uid,
      AccountFields.balance: openingBalance,
      ...payload,
      CommonFields.createdAt: FieldValue.serverTimestamp(),
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateAccountWithPayload({
    required String uid,
    required String accountId,
    required Map<String, dynamic> payload,
  }) async {
    await _accounts(uid).doc(accountId).update({
      ...payload,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<String> createAccount({
    required String name,
    required String type,
    required double openingBalance,
    bool isLiquid = true,
    String? accountNumber,
    String? tag,
  }) async {
    if (openingBalance < 0) throw Exception('Invalid balance');
    final normalizedTag = _validatedTag(tag);
    final id = const Uuid().v4();
    final kind = type == 'investment' ? 'investment' : 'standard';
    final finalLiquid = type == 'investment' ? false : isLiquid;

    await _accounts(_uid).doc(id).set({
      CommonFields.id: id,
      CommonFields.userId: _uid,
      AccountFields.name: name.trim(),
      AccountFields.provider: name.trim(),
      AccountFields.type: type,
      AccountFields.kind: kind,
      AccountFields.balance: openingBalance,
      AccountFields.accountNumber: accountNumber ?? '',
      AccountFields.tag: normalizedTag,
      AccountFields.isLiquid: finalLiquid,
      CommonFields.createdAt: FieldValue.serverTimestamp(),
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
    return id;
  }

  Future<void> updateAccount({
    required String accountId,
    required String name,
    required String type,
    required double balance,
    required bool isLiquid,
    String? accountNumber,
    String? tag,
  }) async {
    if (balance < 0) throw Exception('Invalid balance');
    final normalizedTag = _validatedTag(tag);
    final kind = type == 'investment' ? 'investment' : 'standard';
    final finalLiquid = type == 'investment' ? false : isLiquid;

    await _accounts(_uid).doc(accountId).update({
      AccountFields.name: name.trim(),
      AccountFields.provider: name.trim(),
      AccountFields.type: type,
      AccountFields.kind: kind,
      AccountFields.balance: balance,
      AccountFields.accountNumber: accountNumber ?? '',
      AccountFields.tag: normalizedTag,
      AccountFields.isLiquid: finalLiquid,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAccount(String accountId) async {
    await _accounts(_uid).doc(accountId).delete();
  }

  Future<void> updateInvestmentBalance({
    required String accountId,
    required double newBalance,
    String? note,
  }) async {
    if (newBalance < 0) throw Exception('Invalid amount');

    final accRef = _accounts(_uid).doc(accountId);
    final pnlRef = _investmentPnl(_uid).doc();
    final txRef = _userDoc(
      _uid,
    ).collection(AppCollections.transactions).doc(const Uuid().v4());

    await _db.runTransaction((trx) async {
      final accSnap = await trx.get(accRef);
      if (!accSnap.exists) throw Exception('Account not found');

      final m = accSnap.data() as Map<String, dynamic>;
      final type = (m[AccountFields.type] ?? '').toString();
      final kind = (m[AccountFields.kind] ?? '').toString();

      if (type != 'investment' && kind != 'investment') {
        throw Exception('Selected account is not investment account');
      }

      final oldBalance = ((m[AccountFields.balance] ?? 0) as num).toDouble();
      final diff = newBalance - oldBalance;

      trx.update(accRef, {
        AccountFields.balance: newBalance,
        AccountFields.isLiquid: false,
        AccountFields.kind: 'investment',
        CommonFields.updatedAt: FieldValue.serverTimestamp(),
      });

      if (diff != 0) {
        trx.set(txRef, {
          CommonFields.id: txRef.id,
          CommonFields.userId: _uid,
          TransactionFields.accountId: accountId,
          TransactionFields.categoryId: 'adjustment',
          TransactionFields.type: 'adjustment',
          TransactionFields.amount: diff,
          TransactionFields.note: note ?? 'manual correction (investment)',
          TransactionFields.source: 'manual_correction',
          TransactionFields.splits: {accountId: diff},
          TransactionFields.splitDetails: {accountId: diff},
          TransactionFields.datetime: FieldValue.serverTimestamp(),
          CommonFields.createdAt: FieldValue.serverTimestamp(),
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });

        trx.set(pnlRef, {
          CommonFields.id: pnlRef.id,
          CommonFields.userId: _uid,
          InvestmentPnlFields.accountId: accountId,
          InvestmentPnlFields.accountName:
              (m[AccountFields.name] ?? 'Investment').toString(),
          InvestmentPnlFields.oldBalance: oldBalance,
          InvestmentPnlFields.newBalance: newBalance,
          InvestmentPnlFields.diff: diff.abs(),
          InvestmentPnlFields.pnlType: diff > 0 ? 'profit' : 'loss',
          InvestmentPnlFields.note: note,
          CommonFields.createdAt: FieldValue.serverTimestamp(),
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Stream<List<Map<String, dynamic>>> watchInvestmentPnlLogs(
    String uid, {
    int limit = 50,
  }) {
    return _investmentPnl(uid)
        .orderBy(CommonFields.createdAt, descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'_id': d.id, ...d.data()}).toList());
  }

  Future<void> recordInvestmentPnlLog({
    required String uid,
    required String accountId,
    required String accountName,
    required double oldBalance,
    required double newBalance,
    required double diff,
    required String pnlType,
    String? note,
  }) async {
    final logDoc = _investmentPnl(uid).doc();
    await logDoc.set({
      CommonFields.id: logDoc.id,
      CommonFields.userId: uid,
      InvestmentPnlFields.accountId: accountId,
      InvestmentPnlFields.accountName: accountName,
      InvestmentPnlFields.oldBalance: oldBalance,
      InvestmentPnlFields.newBalance: newBalance,
      InvestmentPnlFields.diff: diff,
      InvestmentPnlFields.pnlType: pnlType,
      InvestmentPnlFields.note: note,
      CommonFields.createdAt: FieldValue.serverTimestamp(),
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
      'eventAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Stream<List<InvestmentPnlPoint>> watchInvestmentPnlPoints(
    String uid, {
    int limit = 500,
  }) {
    return watchInvestmentPnlLogs(uid, limit: limit).map(
      (rows) => rows
          .map(_toInvestmentPnlPoint)
          .whereType<InvestmentPnlPoint>()
          .toList(growable: false),
    );
  }

  InvestmentPnlPoint? _toInvestmentPnlPoint(Map<String, dynamic> row) {
    final timestamp =
        row['eventAt'] ??
        row[CommonFields.createdAt] ??
        row[CommonFields.updatedAt];
    DateTime? date;
    if (timestamp is Timestamp) date = timestamp.toDate();
    if (timestamp is DateTime) date = timestamp;
    if (date == null) return null;
    return InvestmentPnlPoint(
      date: date,
      diff: _toDouble(row[InvestmentPnlFields.diff]),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0.0;
    return 0.0;
  }

  Future<List<Map<String, dynamic>>> getAccountsByTag(
    String uid,
    String tag, {
    bool excludeInvestment = false,
  }) async {
    final normalizedTarget = _normalizeTag(tag);
    final snap = await _accounts(uid).get();

    final filtered = snap.docs
        .where((d) {
          final m = d.data();
          final accountTag = _normalizeTag(
            (m[AccountFields.tag] ?? '').toString(),
          );
          if (accountTag != normalizedTarget) return false;
          if (!excludeInvestment) return true;
          final type = (m[AccountFields.type] ?? '').toString().toLowerCase();
          final kind = (m[AccountFields.kind] ?? '').toString().toLowerCase();
          return type != 'investment' && kind != 'investment';
        })
        .map((d) {
          final m = d.data();
          return {
            '_id': d.id,
            ...m,
            AccountFields.balance: ((m[AccountFields.balance] ?? 0) as num)
                .toDouble(),
            AccountFields.isPrimary:
                (m[AccountFields.isPrimary] as bool?) ?? false,
          };
        })
        .toList();

    filtered.sort((a, b) {
      final ap = (a[AccountFields.isPrimary] as bool?) == true ? 1 : 0;
      final bp = (b[AccountFields.isPrimary] as bool?) == true ? 1 : 0;
      final primaryCmp = bp.compareTo(ap);
      if (primaryCmp != 0) return primaryCmp;
      final aCreated = a[CommonFields.createdAt];
      final bCreated = b[CommonFields.createdAt];
      final aMillis = aCreated is Timestamp
          ? aCreated.millisecondsSinceEpoch
          : 0;
      final bMillis = bCreated is Timestamp
          ? bCreated.millisecondsSinceEpoch
          : 0;
      final timeCompare = aMillis.compareTo(bMillis);
      if (timeCompare != 0) return timeCompare;
      return (a['_id'] ?? '').toString().compareTo((b['_id'] ?? '').toString());
    });
    return filtered;
  }

  Future<Map<String, dynamic>?> getPrimaryAccountByTag(
    String uid,
    String tag, {
    bool excludeInvestment = false,
  }) async {
    final accounts = await getAccountsByTag(
      uid,
      tag,
      excludeInvestment: excludeInvestment,
    );
    for (final a in accounts) {
      if ((a[AccountFields.isPrimary] as bool?) == true) return a;
    }
    return null;
  }

  Future<void> setPrimaryAccount(String uid, String accountId) async {
    await _accounts(uid).doc(accountId).update({
      AccountFields.isPrimary: true,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> replaceAccounts({
    required String uid,
    required List<String> deleteIds,
    required List<Map<String, dynamic>> newAccounts,
  }) async {
    final batch = _db.batch();

    for (final id in deleteIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      batch.delete(_accounts(uid).doc(trimmed));
    }

    final now = FieldValue.serverTimestamp();
    for (final raw in newAccounts) {
      final payload = Map<String, dynamic>.from(raw);
      final id = (payload[CommonFields.id] ?? payload['id'] ?? '').toString();
      if (id.isEmpty) continue;
      payload.remove('id');
      payload[CommonFields.id] = id;
      payload[CommonFields.userId] = uid;
      payload[CommonFields.createdAt] = now;
      payload[CommonFields.updatedAt] = now;
      batch.set(_accounts(uid).doc(id), payload);
    }

    await batch.commit();
  }
}
