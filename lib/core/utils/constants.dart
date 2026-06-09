class AppCollections {
  static const String users = 'users';
  static const String accounts = 'accounts';
  static const String transactions = 'transactions';
  static const String categories = 'categories';
  static const String budgets = 'budgets';
  static const String shortcuts = 'shortcuts';
  static const String recurring = 'recurring';
  static const String backups = 'backups';
  static const String recurringPlans = 'recurring_plans';
  static const String recurringExecutions = 'recurring_executions';
  static const String systemNotifications = 'system_notifications';

  static const String assetProfiles = 'asset_profiles';
  static const String investmentPnlLogs = 'investment_pnl_logs';
}

class CommonFields {
  static const String id = '_id';
  static const String userId = 'user_id';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class UserFields {
  static const String id = '_id';
  static const String email = 'email';
  static const String displayName = 'display_name';
  static const String settings = 'settings';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String onboarding = 'onboarding';
}

class UserSettingsFields {
  static const String appMode = 'app_mode';
  static const String appModeOrigin = 'app_mode_origin';
  static const String isBiometricEnabled = 'is_biometric_enabled';
  static const String lazyAllowSavingsFallback = 'lazy_allow_savings_fallback';
}

class OnboardingFields {
  static const String surveyCompleted = 'survey_completed';
  static const String surveyScore = 'survey_score';
}

class AccountFields {
  static const String name = 'name';
  static const String balance = 'balance';
  static const String type = 'type';
  static const String isLiquid = 'is_liquid';
  static const String tag = 'tag';
  static const String icon = 'icon';
  static const String colour = 'colour';
  static const String provider = 'provider';
  static const String accountNumber = 'account_number';

  static const String kind = 'kind';

  static const String isPrimary = 'is_primary';
  static const String isVirtual = 'is_virtual';
}

class AssetProfileFields {
  static const String mode = 'mode';
  static const String totalAsset = 'total_asset';
  static const String lastConsolidatedAt = 'last_consolidated_at';
  static const String consolidationVersion = 'consolidation_version';
}

class InvestmentPnlFields {
  static const String accountId = 'account_id';
  static const String accountName = 'account_name';
  static const String oldBalance = 'old_balance';
  static const String newBalance = 'new_balance';
  static const String diff = 'diff';
  static const String pnlType = 'pnl_type';
  static const String note = 'note';
}

class TransactionFields {
  static const String accountId = 'account_id';
  static const String toAccountId = 'to_account_id';
  static const String categoryId = 'category_id';
  static const String type = 'type';
  static const String amount = 'amount';
  static const String note = 'note';
  static const String source = 'source';
  static const String datetime = 'datetime';

  static const String splitDetails = 'split_details';
  static const String splits = 'splits';
}

class BudgetFields {
  static const String monthKey = 'month_key';
  static const String amount = 'amount';
  static const String note = 'note';
}

class ShortcutFields {
  static const String label = 'label';
  static const String categoryId = 'category_id';
  static const String amount = 'amount';
  static const String icon = 'icon';
  static const String type = 'type';
  static const String useDefaultAccount = 'use_default_account';
  static const String defaultAccountId = 'default_account_id';
  static const String defaultPoolTag = 'default_pool_tag';
  static const String detailedDefaultAccountId = 'detailed_default_account_id';
  static const String requireDetailedReconfirm = 'require_detailed_reconfirm';
}

class LocalKeys {
  static const String appMode = 'app_mode';
  static const String themeMode = 'theme_mode';
  static const String isBiometricEnabled = 'is_biometric_enabled';
  static const String language = 'language';
}

class AllocationFields {
  static const String enabled = 'enabled';
  static const String tolerance = 'tolerance';
  static const String targets = 'targets';
  static const String dailyUse = 'daily_use';
  static const String savings = 'savings';
  static const String investment = 'investment';
}

class LazyModeConfig {
  static const String expensePrimaryCategory = 'daily_use';
  static const String incomePrimaryCategory = 'savings';
  static const String savingsCategory = 'savings';

  static const int maxSplitAccounts = 10;
}

class AppAssets {
  static const String appLogoLight = 'assets/appLogo_light.png';
  static const String appLogoDark = 'assets/appLogo_dark.png';

  static String getAppLogo(bool isDarkMode) {
    return isDarkMode ? appLogoDark : appLogoLight;
  }
}
