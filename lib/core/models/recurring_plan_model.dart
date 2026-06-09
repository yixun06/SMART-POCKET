import '../utils/constants.dart';

class RecurringPlanModel {
  final String id;
  final String userId;

  final String type; // expense | income | transfer
  final String label;
  final double amount;

  final String accountId;
  final String? toAccountId; // transfer only
  final String? categoryId; // non-transfer should have
  final String? note;

  final int intervalDays; // custom frequency in days
  final DateTime startDate;
  final DateTime endDate;
  final DateTime nextRunAt;

  final bool active;
  final int version; // edit affects future only
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringPlanModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.label,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.note,
    required this.intervalDays,
    required this.startDate,
    required this.endDate,
    required this.nextRunAt,
    required this.active,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      CommonFields.id: id,
      CommonFields.userId: userId,
      'type': type,
      'label': label,
      'amount': amount,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'categoryId': categoryId,
      'note': note,
      'intervalDays': intervalDays,
      'startDate': startDate,
      'endDate': endDate,
      'nextRunAt': nextRunAt,
      'active': active,
      'version': version,
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

  factory RecurringPlanModel.fromMap(
    Map<String, dynamic> m, {
    String? id,
  }) {
    return RecurringPlanModel(
      id: (m[CommonFields.id] ?? id ?? '').toString(),
      userId: (m[CommonFields.userId] ?? '').toString(),
      type: (m['type'] ?? 'expense').toString(),
      label: (m['label'] ?? '').toString(),
      amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      accountId: (m['accountId'] ?? '').toString(),
      toAccountId: m['toAccountId']?.toString(),
      categoryId: m['categoryId']?.toString(),
      note: m['note']?.toString(),
      intervalDays: (m['intervalDays'] as num?)?.toInt() ?? 30,
      startDate: _asDate(m['startDate']),
      endDate: _asDate(m['endDate']),
      nextRunAt: _asDate(m['nextRunAt']),
      active: (m['active'] ?? true) == true,
      version: (m['version'] as num?)?.toInt() ?? 1,
      createdAt: _asDate(m[CommonFields.createdAt]),
      updatedAt: _asDate(m[CommonFields.updatedAt]),
    );
  }
}
