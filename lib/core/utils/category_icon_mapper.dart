import 'package:flutter/material.dart';

class CategoryIconMapper {
  static IconData icon(String? key) {
    switch ((key ?? '').trim().toLowerCase()) {
      case 'tag':
        return Icons.sell_rounded;
      case 'category':
        return Icons.category_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'bookmark':
        return Icons.bookmark_rounded;

      case 'food':
        return Icons.restaurant_rounded;
      case 'coffee':
        return Icons.local_cafe_rounded;
      case 'fastfood':
        return Icons.fastfood_rounded;
      case 'cake':
        return Icons.cake_rounded;
      case 'drink':
        return Icons.local_bar_rounded;

      case 'transport':
      case 'car':
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'train':
        return Icons.train_rounded;
      case 'taxi':
        return Icons.local_taxi_rounded;
      case 'flight':
        return Icons.flight_rounded;

      case 'shopping':
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'cart':
        return Icons.shopping_cart_rounded;
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'bill':
        return Icons.request_page_rounded;

      case 'home':
        return Icons.home_rounded;
      case 'health':
        return Icons.local_hospital_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'game':
        return Icons.sports_esports_rounded; // ✅
      case 'phone':
        return Icons.phone_android_rounded; // ✅

      case 'salary':
      case 'payments':
        return Icons.payments_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'trending_up':
      case 'investment':
        return Icons.trending_up_rounded;
      case 'work':
        return Icons.work_rounded;

      case 'electric':
        return Icons.electric_bolt_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'insurance':
        return Icons.health_and_safety_rounded;

      default:
        return Icons.category_rounded;
    }
  }

  static Color color(String? key) {
    switch ((key ?? '').trim().toLowerCase()) {
      case 'food':
      case 'fastfood':
      case 'cake':
      case 'coffee':
      case 'drink':
        return const Color(0xFFEA580C);

      case 'transport':
      case 'car':
      case 'directions_car':
      case 'bus':
      case 'train':
      case 'taxi':
      case 'flight':
        return const Color(0xFF2563EB);

      case 'shopping':
      case 'shopping_bag':
      case 'cart':
        return const Color(0xFF7C3AED);

      case 'receipt_long':
      case 'bill':
      case 'electric':
      case 'water':
      case 'wifi':
      case 'insurance':
        return const Color(0xFF4F46E5);

      case 'salary':
      case 'payments':
      case 'wallet':
      case 'business':
      case 'trending_up':
      case 'investment':
      case 'work':
        return const Color(0xFF16A34A);

      case 'health':
        return const Color(0xFFDC2626);

      case 'education':
      case 'phone':
        return const Color(0xFF0EA5E9); // ✅ phone 蓝色

      case 'home':
      case 'tag':
      case 'category':
        return const Color(0xFF64748B);

      case 'gift':
      case 'game':
      case 'favorite':
      case 'star':
      case 'bookmark':
        return const Color(0xFFDB2777); // ✅ game 粉色

      default:
        return const Color(0xFF6B7280);
    }
  }
}