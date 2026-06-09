import '../utils/constants.dart';

class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String? icon;
  final String type; // expense | income
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      CommonFields.id: id,
      CommonFields.userId: userId,
      'name': name,
      'icon': icon,
      'type': type,
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

  factory CategoryModel.fromMap(
    Map<String, dynamic> m, {
    String? id,
  }) {
    return CategoryModel(
      id: (m[CommonFields.id] ?? id ?? '').toString(),
      userId: (m[CommonFields.userId] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      icon: m['icon']?.toString(),
      type: (m['type'] ?? 'expense').toString(),
      createdAt: _asDate(m[CommonFields.createdAt]),
      updatedAt: _asDate(m[CommonFields.updatedAt]),
    );
  }
}
