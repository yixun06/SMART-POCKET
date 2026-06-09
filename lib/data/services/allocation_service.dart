import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/constants.dart';
import '../../core/models/account_tag_suggestion.dart';

class AssetAllocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(AppCollections.users).doc(uid);

  CollectionReference<Map<String, dynamic>> _accounts(String uid) =>
      _userDoc(uid).collection(AppCollections.accounts);

  Future<Map<String, dynamic>> loadGoals(String uid) async {
    final snap = await _userDoc(uid).get();
    final data = snap.data() ?? {};
    final settings = (data[UserFields.settings] as Map<String, dynamic>?) ?? {};
    final goal = (settings['allocation_goal'] as Map<String, dynamic>?) ?? {};

    final targets =
        (goal[AllocationFields.targets] as Map<String, dynamic>?) ?? {};
    return {
      AllocationFields.enabled: goal[AllocationFields.enabled] ?? true,
      AllocationFields.tolerance:
          (goal[AllocationFields.tolerance] ?? 1.0) as num,
      AllocationFields.targets: {
        AllocationFields.dailyUse: (targets[AllocationFields.dailyUse] ?? 40)
            .toDouble(),
        AllocationFields.savings: (targets[AllocationFields.savings] ?? 30)
            .toDouble(),
        AllocationFields.investment:
            (targets[AllocationFields.investment] ?? 30).toDouble(),
      },
    };
  }

  Future<void> saveGoals(String uid, Map<String, dynamic> goal) async {
    await _userDoc(uid).set({
      UserFields.settings: {
        'allocation_goal': {
          AllocationFields.enabled: goal[AllocationFields.enabled],
          AllocationFields.tolerance: goal[AllocationFields.tolerance],
          AllocationFields.targets: goal[AllocationFields.targets],
        },
      },
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<AccountTagSuggestion>> suggestAccountTags(String uid) async {
    final snap = await _accounts(uid).get();
    final docs = snap.docs;
    if (docs.isEmpty) {
      throw Exception('Not enough account data to compute allocation');
    }

    double total = 0;
    final rows = <_AccountSuggestionRow>[];

    for (final d in docs) {
      final data = d.data();
      final balance = ((data[AccountFields.balance] ?? 0) as num).toDouble();
      final type = (data[AccountFields.type] ?? '').toString().toLowerCase();
      final provider =
          (data[AccountFields.provider] ??
                  data[AccountFields.name] ??
                  'Account')
              .toString();
      total += balance;
      rows.add(
        _AccountSuggestionRow(
          id: d.id,
          name: provider,
          type: type,
          balance: balance,
        ),
      );
    }

    if (total <= 0) {
      throw Exception('Not enough account data to compute allocation');
    }

    final liquidCandidates =
        rows
            .where(
              (e) =>
                  e.type == 'bank' || e.type == 'ewallet' || e.type == 'cash',
            )
            .toList()
          ..sort((a, b) => b.balance.compareTo(a.balance));

    final dailyUseIds = <String>{};
    for (var i = 0; i < liquidCandidates.length && i < 2; i++) {
      dailyUseIds.add(liquidCandidates[i].id);
    }

    return rows
        .map((row) {
          final tag = row.type == 'investment'
              ? 'INVESTMENT'
              : dailyUseIds.contains(row.id)
              ? 'DAILY_USE'
              : 'SAVINGS';
          return AccountTagSuggestion(
            accountId: row.id,
            accountName: row.name,
            suggestedTag: tag,
          );
        })
        .toList(growable: false);
  }

  Future<void> applyAccountTagSuggestions(
    String uid,
    List<AccountTagSuggestion> suggestions,
  ) async {
    final batch = _db.batch();
    for (final suggestion in suggestions) {
      batch.update(_accounts(uid).doc(suggestion.accountId), {
        AccountFields.tag: suggestion.suggestedTag,
        CommonFields.updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Stream<Map<String, double>> watchActualAllocation(String uid) {
    return _accounts(uid).snapshots().map((snap) {
      if (snap.docs.isEmpty) {
        return {
          AllocationFields.dailyUse: 0,
          AllocationFields.savings: 0,
          AllocationFields.investment: 0,
          '_hasData': 0,
        };
      }

      double total = 0;
      double daily = 0;
      double savings = 0;
      double invest = 0;

      for (final d in snap.docs) {
        final m = d.data();
        final bal = ((m[AccountFields.balance] ?? 0) as num).toDouble();
        final tag = (m[AccountFields.tag] ?? 'OTHER').toString().toUpperCase();

        total += bal;
        if (tag == 'DAILY_USE') daily += bal;
        if (tag == 'SAVINGS') savings += bal;
        if (tag == 'INVESTMENT') invest += bal;
      }

      if (total <= 0) {
        return {
          AllocationFields.dailyUse: 0,
          AllocationFields.savings: 0,
          AllocationFields.investment: 0,
          '_hasData': 0,
        };
      }

      return {
        AllocationFields.dailyUse: daily / total * 100,
        AllocationFields.savings: savings / total * 100,
        AllocationFields.investment: invest / total * 100,
        '_hasData': 1,
      };
    });
  }
}

class _AccountSuggestionRow {
  const _AccountSuggestionRow({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
  });

  final String id;
  final String name;
  final String type;
  final double balance;
}
