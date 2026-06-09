import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/category_model.dart';
import '../../core/utils/constants.dart';

class CategorySeed {
  final String name;
  final String type;
  final String? icon;
  const CategorySeed({required this.name, required this.type, this.icon});
}

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _catRef(String uid) => _db
      .collection(AppCollections.users)
      .doc(uid)
      .collection(AppCollections.categories);

  CollectionReference<Map<String, dynamic>> _txRef(String uid) => _db
      .collection(AppCollections.users)
      .doc(uid)
      .collection(AppCollections.transactions);

  Future<List<CategoryModel>> getAllCategories() async {
    final uid = _uid;
    if (uid == null) return [];

    final snap = await _catRef(uid).orderBy('name').get();
    return snap.docs.map((d) {
      final m = d.data();
      DateTime toDate(dynamic v) {
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        return DateTime.now();
      }

      return CategoryModel(
        id: (m[CommonFields.id] ?? d.id).toString(),
        userId: (m[CommonFields.userId] ?? uid).toString(),
        name: (m['name'] ?? '').toString(),
        type: (m['type'] ?? 'expense').toString(),
        icon: m['icon']?.toString(),
        createdAt: toDate(m[CommonFields.createdAt]),
        updatedAt: toDate(m[CommonFields.updatedAt]),
      );
    }).toList();
  }

  Future<void> ensureDefaultCategories(List<CategorySeed> defaults) async {
    final uid = _uid;
    if (uid == null) return;

    final existingSnap = await _catRef(uid).get();
    final existing = existingSnap.docs
        .map((d) => ((d.data()['name'] ?? '') as String).trim().toLowerCase())
        .toSet();

    final batch = _db.batch();
    for (final seed in defaults) {
      final key = seed.name.trim().toLowerCase();
      if (existing.contains(key)) continue;

      final doc = _catRef(uid).doc();
      batch.set(doc, {
        CommonFields.id: doc.id,
        CommonFields.userId: uid,
        'name': seed.name.trim(),
        'type': seed.type,
        'icon': seed.icon,
        CommonFields.createdAt: FieldValue.serverTimestamp(),
        CommonFields.updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> addCategory({
    required String name,
    required String type,
    String? icon,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    final doc = _catRef(uid).doc();
    await doc.set({
      CommonFields.id: doc.id,
      CommonFields.userId: uid,
      'name': name.trim(),
      'type': type,
      'icon': icon,
      CommonFields.createdAt: FieldValue.serverTimestamp(),
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String type,
    String? icon,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    await _catRef(uid).doc(id).update({
      'name': name.trim(),
      'type': type,
      'icon': icon,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategoryAndReassign({
    required String categoryId,
    required String toCategoryId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');
    if (categoryId == toCategoryId) {
      throw Exception('Cannot reassign to same category');
    }

    while (true) {
      final txSnap = await _txRef(uid)
          .where(TransactionFields.categoryId, isEqualTo: categoryId)
          .limit(300)
          .get();

      if (txSnap.docs.isEmpty) break;

      final b = _db.batch();
      for (final d in txSnap.docs) {
        b.update(d.reference, {
          TransactionFields.categoryId: toCategoryId,
          CommonFields.updatedAt: FieldValue.serverTimestamp(),
        });
      }
      await b.commit();
    }

    await _catRef(uid).doc(categoryId).delete();
  }

  Future<void> deleteCategoryAndDeleteTransactions({
    required String categoryId,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    while (true) {
      final txSnap = await _txRef(uid)
          .where(TransactionFields.categoryId, isEqualTo: categoryId)
          .limit(300)
          .get();

      if (txSnap.docs.isEmpty) break;

      final b = _db.batch();
      for (final d in txSnap.docs) {
        b.delete(d.reference);
      }
      await b.commit();
    }

    await _catRef(uid).doc(categoryId).delete();
  }
}
