import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/constants.dart';
import '../../core/models/shortcut_model.dart';

class ShortcutService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ShortcutService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  String? get _uidOrNull {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  String get _uid {
    final uid = _uidOrNull;
    if (uid == null) throw Exception('User not logged in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection(AppCollections.users).doc(uid).collection(AppCollections.shortcuts);

  Stream<List<ShortcutModel>> watchShortcuts() {
    final uid = _uidOrNull;
    if (uid == null) {
      return Stream<List<ShortcutModel>>.value(const []);
    }
    return _col(uid)
      .orderBy(CommonFields.createdAt, descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
          .map((d) => ShortcutModel.fromMap(d.data(), id: d.id))
          .toList(),
      );
  }

  Future<List<ShortcutModel>> getShortcutsOnce() async {
    final uid = _uidOrNull;
    if (uid == null) return const [];
    final snap = await _col(uid).orderBy(CommonFields.createdAt, descending: true).get();
    return snap.docs
      .map((d) => ShortcutModel.fromMap(d.data(), id: d.id))
      .toList();
  }

  Future<void> createShortcut({
    required String label,
    required String categoryId,
    required double amount,
    required String type,
    required bool useDefaultAccount,
    String? defaultAccountId,
  }) async {
    final uid = _uid;
    final ref = _col(uid).doc();
    final now = DateTime.now();

    final model = ShortcutModel(
      id: ref.id,
      userId: uid,
      label: label,
      categoryId: categoryId,
      amount: amount,
      type: type,
      useDefaultAccount: useDefaultAccount,
      defaultAccountId: defaultAccountId,
      detailedDefaultAccountId: useDefaultAccount ? defaultAccountId : null,
      defaultPoolTag: null,
      requireDetailedReconfirm: false,
      icon: null,
      createdAt: now,
      updatedAt: now,
    );

    await ref.set(model.toMap());
  }

  Future<void> updateShortcut({
    required String id,
    required String label,
    required String categoryId,
    required double amount,
    required String type,
    required bool useDefaultAccount,
    String? defaultAccountId,
  }) async {
    final uid = _uid;
    await _col(uid).doc(id).update({
      ShortcutFields.label: label,
      ShortcutFields.categoryId: categoryId,
      ShortcutFields.amount: amount,
      ShortcutFields.type: type,
      ShortcutFields.useDefaultAccount: useDefaultAccount,
      ShortcutFields.defaultAccountId: defaultAccountId,
      ShortcutFields.detailedDefaultAccountId: useDefaultAccount ? defaultAccountId : null,
      ShortcutFields.requireDetailedReconfirm: false,
      CommonFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteShortcut(String id) async {
    final uid = _uid;
    await _col(uid).doc(id).delete();
  }

  Future<void> batchUpdateShortcuts(List<Map<String, dynamic>> updates) async {
    final uid = _uidOrNull;
    if (uid == null || updates.isEmpty) return;

    final batch = _db.batch();
    for (final raw in updates) {
      final id = (raw['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final data = raw['data'];
      if (data is! Map) continue;
      final patch = Map<String, dynamic>.from(data);
      patch[CommonFields.updatedAt] = FieldValue.serverTimestamp();
      batch.update(_col(uid).doc(id), patch);
    }

    await batch.commit();
  }
}
