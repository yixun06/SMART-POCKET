import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/constants.dart';

class BudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _budgetRef(String uid) =>
      _db.collection(AppCollections.users).doc(uid).collection(AppCollections.budgets);

  String _monthKey(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

  Future<double> getBudgetForMonth(DateTime month) async {
    final uid = _uid;
    if (uid == null) return 0.0;

    final key = _monthKey(month);
    final doc = await _budgetRef(uid).doc(key).get();
    if (!doc.exists) return 0.0;

    final data = doc.data() ?? {};
    return ((data['amount'] ?? 0) as num).toDouble();
  }

  Future<void> upsertBudgetForMonth({
    required DateTime month,
    required double amount,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    final key = _monthKey(month);
    final ref = _budgetRef(uid).doc(key);

    final now = FieldValue.serverTimestamp();
    final existing = await ref.get();

    final payload = <String, dynamic>{
      CommonFields.id: key,
      CommonFields.userId: uid,
      'month': key,
      'amount': amount,
      CommonFields.updatedAt: now,
    };

    if (!existing.exists) payload[CommonFields.createdAt] = now;

    await ref.set(payload, SetOptions(merge: true));
  }

  Future<void> deleteBudgetForMonth(DateTime month) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    final key = _monthKey(month);
    await _budgetRef(uid).doc(key).delete();
  }
}