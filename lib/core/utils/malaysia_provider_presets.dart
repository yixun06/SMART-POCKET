import 'package:flutter/material.dart';

class MalaysiaProviderPreset {
  const MalaysiaProviderPreset({
    required this.providerName,
    required this.type,
    required this.defaultTag,
    required this.isLiquid,
    required this.iconKey,
    required this.icon,
    required this.color,
    this.logoAsset,
    this.logoBgColor,
    this.logoPadding = 2.5,
  });

  final String providerName;
  final String type;
  final String defaultTag;
  final bool isLiquid;
  final String iconKey;
  final IconData icon;
  final Color color;

  final String? logoAsset;
  final Color? logoBgColor;
  final double logoPadding;

  String get colorHex {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class ProviderAutofill {
  const ProviderAutofill({
    required this.type,
    required this.tag,
    required this.isLiquid,
    required this.iconKey,
    required this.icon,
    required this.color,
  });

  final String type;
  final String tag;
  final bool isLiquid;
  final String iconKey;
  final IconData icon;
  final Color color;

  String get colorHex {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class MalaysiaProviderPresets {
  static const String customProviderOption = '__custom_provider__';

  static final List<MalaysiaProviderPreset> _all = [
    // Bank
    const MalaysiaProviderPreset(
      providerName: 'Maybank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFF5A700),
      logoAsset: 'lib/core/utils/provider_logo/maybank.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'CIMB Bank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFCE1F2D),
      logoAsset: 'lib/core/utils/provider_logo/cimb.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Public Bank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFDA1A32),
      logoAsset: 'lib/core/utils/provider_logo/public_bank.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'RHB Bank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF0F7CC0),
      logoAsset: 'lib/core/utils/provider_logo/rhb.jpg',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Hong Leong Bank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF00A1DF),
      logoAsset: 'lib/core/utils/provider_logo/hongleong.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'AmBank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFEB1C2D),
      logoAsset: 'lib/core/utils/provider_logo/ambank.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Bank Islam',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF009A44),
      logoAsset: 'lib/core/utils/provider_logo/bank_islam.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Bank Muamalat',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF0B8F4A),
      logoAsset: 'lib/core/utils/provider_logo/bank_muamalat.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Bank Rakyat',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF00AEEF),
      logoAsset: 'lib/core/utils/provider_logo/bank_rakyat.jpg',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Affin Bank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFED1C24),
      logoAsset: 'lib/core/utils/provider_logo/affin_bank.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Alliance Bank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFEF4123),
      logoAsset: 'lib/core/utils/provider_logo/alliance_bank.jpg',
    ),
    const MalaysiaProviderPreset(
      providerName: 'OCBC Bank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFEE2A24),
      logoAsset: 'lib/core/utils/provider_logo/ocbc.jpg',
    ),
    const MalaysiaProviderPreset(
      providerName: 'UOB Bank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF0055A4),
      logoAsset: 'lib/core/utils/provider_logo/uob.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'HSBC Malaysia',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFFDB0011),
      logoAsset: 'lib/core/utils/provider_logo/hsbc.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Standard Chartered Malaysia',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF00A1DF),
      logoAsset: 'lib/core/utils/provider_logo/standard_charted.jpg',
    ),
    const MalaysiaProviderPreset(
      providerName: 'BSN (Bank Simpanan Nasional)',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF004EA2),
      logoAsset: 'lib/core/utils/provider_logo/bsn.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'GXBank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF00A86B),
      logoAsset: 'lib/core/utils/provider_logo/gxbank.webp',
    ),

    const MalaysiaProviderPreset(
      providerName: 'RYT Bank',
      type: 'bank',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'bank',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF00A86B),
      logoAsset: 'lib/core/utils/provider_logo/ryt.webp',
    ),
    // E-Wallet
    const MalaysiaProviderPreset(
      providerName: "Touch 'n Go eWallet",
      type: 'ewallet',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'ewallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF005BAC),
      logoAsset: 'lib/core/utils/provider_logo/tng.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Boost',
      type: 'ewallet',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'ewallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFE41E2B),
      logoAsset: 'lib/core/utils/provider_logo/boost.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'GrabPay',
      type: 'ewallet',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'ewallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF00B14F),
      logoAsset: 'lib/core/utils/provider_logo/grabpay.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'ShopeePay',
      type: 'ewallet',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'ewallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFEE4D2D),
      logoAsset: 'lib/core/utils/provider_logo/shopee_pay.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'MAE Wallet',
      type: 'ewallet',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'ewallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFF6A700),
      logoAsset: 'lib/core/utils/provider_logo/mae.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'BigPay',
      type: 'ewallet',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'ewallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFB11373),
      logoAsset: 'lib/core/utils/provider_logo/bigpay.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Setel',
      type: 'ewallet',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'ewallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF009F4D),
      logoAsset: 'lib/core/utils/provider_logo/setel.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Wise',
      type: 'ewallet',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'ewallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF00B9FF),
      logoAsset: 'lib/core/utils/provider_logo/wise.jpg',
    ),
    const MalaysiaProviderPreset(
      providerName: 'PayPal',
      type: 'ewallet',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'ewallet',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF003087),
      logoAsset: 'lib/core/utils/provider_logo/paypal.png',
    ),

    // Investment
    const MalaysiaProviderPreset(
      providerName: 'ASNB',
      type: 'investment',
      defaultTag: 'INVESTMENT',
      isLiquid: false,
      iconKey: 'investment',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF1E88E5),
      logoAsset: 'lib/core/utils/provider_logo/asnb.jpg',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Versa',
      type: 'investment',
      defaultTag: 'INVESTMENT',
      isLiquid: false,
      iconKey: 'investment',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF2E7D32),
      logoAsset: 'lib/core/utils/provider_logo/versa.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Moomoo Malaysia',
      type: 'investment',
      defaultTag: 'INVESTMENT',
      isLiquid: false,
      iconKey: 'investment',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF43A047),
      logoAsset: 'lib/core/utils/provider_logo/moomoo.png',
    ),
    const MalaysiaProviderPreset(
      providerName: 'FSMOne',
      type: 'investment',
      defaultTag: 'INVESTMENT',
      isLiquid: false,
      iconKey: 'investment',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF0288D1),
      logoAsset: 'lib/core/utils/provider_logo/fsmone.jpg',
    ),
    const MalaysiaProviderPreset(
      providerName: 'Tabung Haji',
      type: 'investment',
      defaultTag: 'INVESTMENT',
      isLiquid: false,
      iconKey: 'investment',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF2E7D32),
      logoAsset: 'lib/core/utils/provider_logo/tabung_haji.jpg',
    ),
    const MalaysiaProviderPreset(
      providerName: 'SSPN',
      type: 'investment',
      defaultTag: 'INVESTMENT',
      isLiquid: false,
      iconKey: 'investment',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF3949AB),
      logoAsset: 'lib/core/utils/provider_logo/sspn.webp',
    ),
    const MalaysiaProviderPreset(
      providerName: 'KWSP / EPF',
      type: 'investment',
      defaultTag: 'INVESTMENT',
      isLiquid: false,
      iconKey: 'investment',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF00838F),
      logoAsset: 'lib/core/utils/provider_logo/kwsp.png',
    ),

    // Cash
    const MalaysiaProviderPreset(
      providerName: 'Physical Cash',
      type: 'cash',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'cash',
      icon: Icons.payments_rounded,
      color: Color(0xFFFB8C00),
    ),
    const MalaysiaProviderPreset(
      providerName: 'Petty Cash',
      type: 'cash',
      defaultTag: 'DAILY_USE',
      isLiquid: true,
      iconKey: 'cash',
      icon: Icons.payments_rounded,
      color: Color(0xFFEF6C00),
    ),
    const MalaysiaProviderPreset(
      providerName: 'Emergency Cash',
      type: 'cash',
      defaultTag: 'SAVINGS',
      isLiquid: true,
      iconKey: 'cash',
      icon: Icons.payments_rounded,
      color: Color(0xFFD84315),
    ),
  ];

  static List<MalaysiaProviderPreset> providersByType(String type) {
    return _all
        .where((e) => e.type == type.toLowerCase())
        .toList(growable: false);
  }

  static MalaysiaProviderPreset? findByName(
    String providerName, {
    String? type,
  }) {
    final name = providerName.trim().toLowerCase();
    if (name.isEmpty) return null;
    return _all.cast<MalaysiaProviderPreset?>().firstWhere((e) {
      if (e == null) return false;
      final typeMatches = type == null || e.type == type.toLowerCase();
      return typeMatches && e.providerName.trim().toLowerCase() == name;
    }, orElse: () => null);
  }

  static ProviderAutofill defaultsForType(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return const ProviderAutofill(
          type: 'bank',
          tag: 'SAVINGS',
          isLiquid: true,
          iconKey: 'bank',
          icon: Icons.account_balance_rounded,
          color: Color(0xFF2563EB),
        );
      case 'ewallet':
        return const ProviderAutofill(
          type: 'ewallet',
          tag: 'DAILY_USE',
          isLiquid: true,
          iconKey: 'ewallet',
          icon: Icons.account_balance_wallet_rounded,
          color: Color(0xFF10B981),
        );
      case 'investment':
        return const ProviderAutofill(
          type: 'investment',
          tag: 'INVESTMENT',
          isLiquid: false,
          iconKey: 'investment',
          icon: Icons.trending_up_rounded,
          color: Color(0xFF0EA5E9),
        );
      case 'cash':
      default:
        return const ProviderAutofill(
          type: 'cash',
          tag: 'DAILY_USE',
          isLiquid: true,
          iconKey: 'cash',
          icon: Icons.payments_rounded,
          color: Color(0xFFF97316),
        );
    }
  }

  static ProviderAutofill autofillFor({
    required String providerName,
    required String type,
  }) {
    final preset = findByName(providerName, type: type);
    if (preset == null) return defaultsForType(type);
    return ProviderAutofill(
      type: preset.type,
      tag: preset.defaultTag,
      isLiquid: preset.isLiquid,
      iconKey: preset.iconKey,
      icon: preset.icon,
      color: preset.color,
    );
  }

  static IconData iconFromKey(String key) {
    switch (key.trim().toLowerCase()) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'ewallet':
        return Icons.account_balance_wallet_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      case 'cash':
      default:
        return Icons.payments_rounded;
    }
  }

  static Color? colorFromHex(String raw) {
    final hex = raw.trim().toUpperCase();
    if (hex.isEmpty) return null;
    final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}
