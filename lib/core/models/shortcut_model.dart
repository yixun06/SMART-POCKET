import '../utils/constants.dart';

class ShortcutModel {
  final String id;
  final String userId;
  final String label;
  final String categoryId;
  final double amount;
  final String type; // expense | income
  final bool useDefaultAccount;
  final String? defaultAccountId;
  final String? defaultPoolTag;
  final String? detailedDefaultAccountId;
  final bool requireDetailedReconfirm;
  final String? icon; // compatibility with legacy data
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShortcutModel({
    required this.id,
    required this.userId,
    required this.label,
    required this.categoryId,
    required this.amount,
    required this.type,
    this.useDefaultAccount = true,
    this.defaultAccountId,
    this.defaultPoolTag,
    this.detailedDefaultAccountId,
    this.requireDetailedReconfirm = false,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      CommonFields.id: id,
      CommonFields.userId: userId,
      ShortcutFields.label: label,
      ShortcutFields.categoryId: categoryId,
      ShortcutFields.amount: amount,
      ShortcutFields.type: type,
      ShortcutFields.useDefaultAccount: useDefaultAccount,
      ShortcutFields.defaultAccountId: defaultAccountId,
      ShortcutFields.defaultPoolTag: defaultPoolTag,
      ShortcutFields.detailedDefaultAccountId: detailedDefaultAccountId,
      ShortcutFields.requireDetailedReconfirm: requireDetailedReconfirm,
      ShortcutFields.icon: icon,
      CommonFields.createdAt: createdAt,
      CommonFields.updatedAt: updatedAt,
    };
  }

  static DateTime _asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value != null) {
      try {
        final dynamic v = value;
        final maybe = v.toDate();
        if (maybe is DateTime) return maybe;
      } catch (_) {}
    }
    return DateTime.now();
  }

  factory ShortcutModel.fromMap(
    Map<String, dynamic> m, {
    String? id,
  }) {
    return ShortcutModel(
      id: (m[CommonFields.id] as String?) ?? (id ?? ''),
      userId: (m[CommonFields.userId] as String?) ?? '',
      label: (m[ShortcutFields.label] as String?) ?? '',
      categoryId: (m[ShortcutFields.categoryId] as String?) ?? '',
      amount: (m[ShortcutFields.amount] as num?)?.toDouble() ?? 0.0,
      type: (m[ShortcutFields.type] as String?) ?? 'expense',
      useDefaultAccount: (m[ShortcutFields.useDefaultAccount] as bool?) ?? true,
      defaultAccountId: m[ShortcutFields.defaultAccountId] as String?,
      defaultPoolTag: m[ShortcutFields.defaultPoolTag] as String?,
      detailedDefaultAccountId:
          m[ShortcutFields.detailedDefaultAccountId] as String?,
      requireDetailedReconfirm:
          (m[ShortcutFields.requireDetailedReconfirm] as bool?) ?? false,
      icon: m[ShortcutFields.icon] as String?,
      createdAt: _asDate(m[CommonFields.createdAt]),
      updatedAt: _asDate(m[CommonFields.updatedAt]),
    );
  }
}
