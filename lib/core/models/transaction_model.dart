import '../utils/constants.dart';

class TransactionModel {
  final String id;
  final String userId;
  final String accountId;
  final String categoryId;
  final String type;
  final double amount;
  final String? note;
  final String? source;
  final DateTime datetime;
  final DateTime createdAt;
  final DateTime updatedAt;

  final Map<String, double>? splitDetails;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.amount,
    this.note,
    this.source,
    required this.datetime,
    required this.createdAt,
    required this.updatedAt,
    this.splitDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      CommonFields.id: id,
      CommonFields.userId: userId,
      TransactionFields.accountId: accountId,
      TransactionFields.categoryId: categoryId,
      TransactionFields.type: type,
      TransactionFields.amount: amount,
      TransactionFields.note: note,
      TransactionFields.source: source,
      TransactionFields.datetime: datetime,
      CommonFields.createdAt: createdAt,
      CommonFields.updatedAt: updatedAt,
      if (splitDetails != null) TransactionFields.splitDetails: splitDetails,
      if (splitDetails != null) TransactionFields.splits: splitDetails,
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

  factory TransactionModel.fromMap(Map<String, dynamic> m, {String? id}) {
    final rawCategoryId =
        (m[TransactionFields.categoryId] ??
                m['category_id'] ??
                m['categoryId'] ??
                m['category'] ??
                '')
            .toString();

    return TransactionModel(
      id: (m[CommonFields.id] ?? id ?? '').toString(),
      userId: (m[CommonFields.userId] ?? '').toString(),
      accountId: (m[TransactionFields.accountId] ?? 'default_cash').toString(),
      categoryId: rawCategoryId,
      type: (m[TransactionFields.type] ?? 'expense').toString(),
      amount: (m[TransactionFields.amount] as num?)?.toDouble() ?? 0.0,
      note: m[TransactionFields.note]?.toString(),
      source: m[TransactionFields.source]?.toString(),
      datetime: _asDate(m[TransactionFields.datetime]),
      createdAt: _asDate(m[CommonFields.createdAt]),
      updatedAt: _asDate(m[CommonFields.updatedAt]),
      splitDetails: _parseSplitDetails(
        m[TransactionFields.splits] ?? m[TransactionFields.splitDetails],
      ),
    );
  }

  static Map<String, double>? _parseSplitDetails(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    try {
      return Map<String, double>.from(
        raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      );
    } catch (_) {
      return null;
    }
  }
}
