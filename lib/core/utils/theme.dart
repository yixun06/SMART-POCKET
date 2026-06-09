import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color success = Color(0xFF06B6D4);
  static const Color danger = Color(0xFFDC2626);
}

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color navBarBackground;
  final Color navBarBorder;
  final Color navFabBackground;
  final Color navFabForeground;
  final Color authGradientStart;
  final Color authGradientEnd;
  final Color authAccentSurface;
  final Color authAccentForeground;
  final Color softSuccessSurface;
  final Color softWarningSurface;
  final Color positiveAmount;
  final Color negativeAmount;
  final Color textNumberPrimary;

  const AppThemeColors({
    required this.navBarBackground,
    required this.navBarBorder,
    required this.navFabBackground,
    required this.navFabForeground,
    required this.authGradientStart,
    required this.authGradientEnd,
    required this.authAccentSurface,
    required this.authAccentForeground,
    required this.softSuccessSurface,
    required this.softWarningSurface,
    required this.positiveAmount,
    required this.negativeAmount,
    required this.textNumberPrimary,
  });

  @override
  AppThemeColors copyWith({
    Color? navBarBackground,
    Color? navBarBorder,
    Color? navFabBackground,
    Color? navFabForeground,
    Color? authGradientStart,
    Color? authGradientEnd,
    Color? authAccentSurface,
    Color? authAccentForeground,
    Color? softSuccessSurface,
    Color? softWarningSurface,
    Color? positiveAmount,
    Color? negativeAmount,
    Color? textNumberPrimary,
  }) {
    return AppThemeColors(
      navBarBackground: navBarBackground ?? this.navBarBackground,
      navBarBorder: navBarBorder ?? this.navBarBorder,
      navFabBackground: navFabBackground ?? this.navFabBackground,
      navFabForeground: navFabForeground ?? this.navFabForeground,
      authGradientStart: authGradientStart ?? this.authGradientStart,
      authGradientEnd: authGradientEnd ?? this.authGradientEnd,
      authAccentSurface: authAccentSurface ?? this.authAccentSurface,
      authAccentForeground: authAccentForeground ?? this.authAccentForeground,
      softSuccessSurface: softSuccessSurface ?? this.softSuccessSurface,
      softWarningSurface: softWarningSurface ?? this.softWarningSurface,
      positiveAmount: positiveAmount ?? this.positiveAmount,
      negativeAmount: negativeAmount ?? this.negativeAmount,
      textNumberPrimary: textNumberPrimary ?? this.textNumberPrimary,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      navBarBackground: Color.lerp(
        navBarBackground,
        other.navBarBackground,
        t,
      )!,
      navBarBorder: Color.lerp(navBarBorder, other.navBarBorder, t)!,
      navFabBackground: Color.lerp(
        navFabBackground,
        other.navFabBackground,
        t,
      )!,
      navFabForeground: Color.lerp(
        navFabForeground,
        other.navFabForeground,
        t,
      )!,
      authGradientStart: Color.lerp(
        authGradientStart,
        other.authGradientStart,
        t,
      )!,
      authGradientEnd: Color.lerp(authGradientEnd, other.authGradientEnd, t)!,
      authAccentSurface: Color.lerp(
        authAccentSurface,
        other.authAccentSurface,
        t,
      )!,
      authAccentForeground: Color.lerp(
        authAccentForeground,
        other.authAccentForeground,
        t,
      )!,
      softSuccessSurface: Color.lerp(
        softSuccessSurface,
        other.softSuccessSurface,
        t,
      )!,
      softWarningSurface: Color.lerp(
        softWarningSurface,
        other.softWarningSurface,
        t,
      )!,
      positiveAmount: Color.lerp(positiveAmount, other.positiveAmount, t)!,
      negativeAmount: Color.lerp(negativeAmount, other.negativeAmount, t)!,
      textNumberPrimary: Color.lerp(
        textNumberPrimary,
        other.textNumberPrimary,
        t,
      )!,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
    );

    return base.copyWith(
      extensions: const [
        AppThemeColors(
          navBarBackground: Colors.white,
          navBarBorder: Color(0xFFE2E8F0),
          navFabBackground: Color(0xFF0F172A),
          navFabForeground: Colors.white,
          authGradientStart: Color(0xFF6366F1),
          authGradientEnd: Color(0xFF8B5CF6),
          authAccentSurface: Color(0xFFF3F0FF),
          authAccentForeground: Color(0xFFFFFFFF),
          softSuccessSurface: Color(0xFFDCFCE7),
          softWarningSurface: Color(0xFFFEF3C7),
          positiveAmount: Color(0xFF10B981),
          negativeAmount: Color(0xFFEF4444),
          textNumberPrimary: Color(0xFF000000),
        ),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0.4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          foregroundColor: AppColors.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData dark() {
    const background = Color(0xFF09111F);
    const surface = Color(0xFF101A2B);
    const surfaceAlt = Color(0xFF162235);
    const border = Color(0xFF26354D);
    const textPrimary = Color(0xFFF3F7FF);
    const textSecondary = Color(0xFF9AA8BF);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.dark,
          ).copyWith(
            surface: surface,
            primary: const Color(0xFF60A5FA),
            secondary: const Color(0xFF38BDF8),
          ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
    );

    return base.copyWith(
      extensions: const [
        AppThemeColors(
          navBarBackground: Color(0xFF101827),
          navBarBorder: Color(0xFF1E2A40),
          navFabBackground: Color(0xFFEAF2FF),
          navFabForeground: Color(0xFF0F1B2D),
          authGradientStart: Color(0xFF0F172A),
          authGradientEnd: Color(0xFF4338CA),
          authAccentSurface: Color(0xFF172554),
          authAccentForeground: Color(0xFFFFFFFF),
          softSuccessSurface: Color(0xFF0F2A20),
          softWarningSurface: Color(0xFF31230C),
          positiveAmount: Color(0xFF34D399),
          negativeAmount: Color(0xFFF87171),
          textNumberPrimary: Color(0xFFFFFFFF),
        ),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 0.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.4),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: border),
          foregroundColor: textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFEAF2FF),
        contentTextStyle: const TextStyle(color: Color(0xFF0F172A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}
