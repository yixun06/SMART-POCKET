import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/authentication_controller.dart';
import '../../../application/controllers/config_controller.dart';
import '../../../application/controllers/shortcut_controller.dart';
import '../../../application/controllers/transaction_controller.dart';
import '../../../application/controllers/category_controller.dart';
import '../../../core/utils/category_icon_mapper.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/theme.dart';
import '../../widgets/navigation/bottom_nav_bar.dart';
import '../../widgets/smart_insight/smart_insight_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  IconData _iconForCategoryId(CategoryController cat, String? categoryId) {
    final cid = (categoryId ?? '').trim();
    if (cid.isEmpty) return Icons.category_rounded;
    final hit = cat.categories.where((c) => c.id == cid).toList();
    if (hit.isEmpty) return Icons.category_rounded;
    return CategoryIconMapper.icon(hit.first.icon);
  }

  Color _colorForCategoryId(
    BuildContext context,
    CategoryController cat,
    String? categoryId,
  ) {
    final cid = (categoryId ?? '').trim();
    final colors = Theme.of(context).colorScheme;
    if (cid.isEmpty) return colors.onSurfaceVariant;
    final hit = cat.categories.where((c) => c.id == cid).toList();
    if (hit.isEmpty) return colors.onSurfaceVariant;
    return CategoryIconMapper.color(hit.first.icon);
  }

  String _fallbackTitleByType(String type) {
    final t = type.toLowerCase();
    if (t == 'income') return 'Income';
    if (t == 'transfer') return 'Transfer';
    if (t == 'adjustment') return 'Manual correction';
    return 'Expense';
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  double _liquidAssetsTotal(List<Map<String, dynamic>> accounts) {
    double total = 0;
    for (final a in accounts) {
      final isLiquid = (a['is_liquid'] ?? a['isLiquid'] ?? true) == true;
      if (!isLiquid) continue;
      total += _toDouble(a['balance']);
    }
    return total;
  }

  String? _defaultAccountId(List<Map<String, dynamic>> accounts) {
    for (final a in accounts) {
      if (a[AccountFields.isPrimary] == true) {
        final id = (a['_id'] ?? a['id'] ?? '').toString().trim();
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  bool _hasPrimaryInTag(List<Map<String, dynamic>> accounts, String tag) {
    final normalized = tag.trim().toLowerCase();
    for (final a in accounts) {
      final t = (a[AccountFields.tag] ?? '').toString().trim().toLowerCase();
      if (t == normalized && a[AccountFields.isPrimary] == true) {
        return true;
      }
    }
    return false;
  }

  String? _tagByAccountId(
    List<Map<String, dynamic>> accounts,
    String? accountId,
  ) {
    final id = (accountId ?? '').trim();
    if (id.isEmpty) return null;
    for (final a in accounts) {
      final aid = (a['_id'] ?? a['id'] ?? '').toString().trim();
      if (aid != id) continue;
      final tag = (a[AccountFields.tag] ?? '').toString().trim().toLowerCase();
      if (tag == 'daily_use' || tag == 'savings' || tag == 'investment') {
        return tag;
      }
      return null;
    }
    return null;
  }

  Future<String?> _pickLazyTag(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Select Source Bucket'),
        content: const Text('Choose bucket for this shortcut run.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dCtx, LazyModeConfig.savingsCategory),
            child: const Text('Savings'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dCtx, LazyModeConfig.expensePrimaryCategory),
            child: const Text('Daily Use'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ConfigController>().appMode;
    final auth = context.watch<AuthenticationController>();
    final tx = context.watch<TransactionController>();
    final shortcut = context.watch<ShortcutController>();
    final cat = context.watch<CategoryController>();

    final liquidTotal = _liquidAssetsTotal(tx.accounts);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.extension<AppThemeColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mode.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimaryContainer,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final ok = await auth.logout();
              if (!context.mounted) return;
              if (ok) {
                context.go('/login');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(auth.errorMessage ?? 'Logout failed')),
                );
              }
            },
            icon: Icon(Icons.logout_rounded, color: colors.onSurfaceVariant),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        physics: const BouncingScrollPhysics(), // 添加 iOS 风格的回弹效果，提升手感
        children: [
          _summaryCard(
            context,
            liquidTotal,
            tx.monthlyIncome,
            tx.monthlyExpense,
          ),
          const SizedBox(height: 28), // 加大区块间的间距，让界面呼吸感更强

          const SmartInsightCard(),
          const SizedBox(height: 28),

          _sectionHeader(
            context: context,
            title: 'Quick Shortcuts',
            actionText: 'Manage',
            onActionTap: () => context.push('/shortcuts'),
          ),
          const SizedBox(height: 12),

          if (shortcut.shortcuts.isEmpty)
            _emptyShortcutCard(context)
          else
            GridView.builder(
              itemCount: shortcut.shortcuts.length > 8
                  ? 8
                  : shortcut.shortcuts.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16, // 稍微拉开网格间距
                crossAxisSpacing: 12,
                childAspectRatio: 0.75, // 优化宽高比，防止在小屏幕上文字溢出
              ),
              itemBuilder: (_, i) {
                final s = shortcut.shortcuts[i];
                final cid = (s.categoryId).trim();
                final icon = _iconForCategoryId(cat, cid);
                final iconColor = _colorForCategoryId(context, cat, cid);

                return _shortcutTile(
                  context: context,
                  label: s.label,
                  amount: s.amount,
                  type: s.type,
                  icon: icon,
                  iconColor: iconColor,
                  onTap: () async {
                    String? accountId;
                    String? lazyCategoryTag;
                    if (mode != 'lazy') {
                      if (s.useDefaultAccount) {
                        if (s.requireDetailedReconfirm) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Some shortcuts need default-account reconfirmation in Detailed Mode. Open Shortcuts > edit and save once.',
                              ),
                            ),
                          );
                          return;
                        }
                        accountId = (s.defaultAccountId ?? '').trim().isEmpty
                            ? _defaultAccountId(tx.accounts)
                            : s.defaultAccountId;
                      }
                      if (accountId == null) {
                        accountId = await _pickAccount(context, tx.accounts);
                        if (accountId == null) return;
                      }
                    } else {
                      if (s.useDefaultAccount) {
                        final defaultId =
                            (s.defaultAccountId ?? '').trim().isEmpty
                            ? _defaultAccountId(tx.accounts)
                            : s.defaultAccountId;
                        lazyCategoryTag = _tagByAccountId(
                          tx.accounts,
                          defaultId,
                        );
                        if (lazyCategoryTag == null) {
                          final hasDailyUseDefault = _hasPrimaryInTag(
                            tx.accounts,
                            LazyModeConfig.expensePrimaryCategory,
                          );
                          if (hasDailyUseDefault) {
                            lazyCategoryTag =
                                LazyModeConfig.expensePrimaryCategory;
                          } else {
                            lazyCategoryTag = await _pickLazyTag(context);
                            if (lazyCategoryTag == null) return;
                          }
                        }
                      } else {
                        lazyCategoryTag = await _pickLazyTag(context);
                        if (lazyCategoryTag == null) return;
                      }
                    }
                    final result = await shortcut.executeShortcut(
                      s: s,
                      isLazyMode: mode == 'lazy',
                      accountId: accountId,
                      lazyCategoryTag: lazyCategoryTag,
                    );
                    if (!context.mounted) return;
                    if (!result.success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.errorMessage ?? 'Failed to add transaction',
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      return;
                    }
                    final splitText = result.splitDetails.entries
                        .map((entry) {
                          final account = tx.accounts
                              .cast<Map<String, dynamic>>()
                              .firstWhere(
                                (a) =>
                                    (a['_id'] ?? a['id']).toString() ==
                                    entry.key,
                                orElse: () => {'name': entry.key},
                              );
                          final accountName = (account['name'] ?? entry.key)
                              .toString();
                          return '$accountName RM${entry.value.toStringAsFixed(2)}';
                        })
                        .join(' / ');
                    final actionText = result.type == 'income'
                        ? 'added'
                        : 'deducted';
                    final fallbackText = result.fallbackWarnings.isEmpty
                        ? ''
                        : ' | ${result.fallbackWarnings.join(' | ')}';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Shortcut success: RM${result.amount.toStringAsFixed(2)} $actionText. $splitText$fallbackText',
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

          const SizedBox(height: 28),

          _sectionHeader(
            context: context,
            title: 'Recent Transactions',
            actionText: 'View All',
            onActionTap: () => context.push('/transactions'),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.24)
                      : colors.onSurface.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: tx.recent.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No transactions yet',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tx.recent.take(8).length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      indent: 64,
                      color: colors.outlineVariant.withValues(alpha: 0.35),
                    ),
                    itemBuilder: (_, i) {
                      final e = tx.recent[i];
                      final isIncome = e.type == 'income';
                      final isTransfer = e.type == 'transfer';
                      final isAdjustment = e.type == 'adjustment';
                      final cid = (e.categoryId).trim();
                      final splitCount = e.splitDetails?.length ?? 0;
                      final source = (e.source ?? '').toLowerCase();
                      final note = (e.note ?? '').trim();
                      final isInvestmentValueUpdate =
                          isAdjustment &&
                          note.toLowerCase().contains(
                            'investment value update',
                          );
                      final isProfitEvent =
                          isInvestmentValueUpdate && e.amount >= 0;
                      final isLossEvent =
                          isInvestmentValueUpdate && e.amount < 0;
                      final isManualCorrection =
                          source == 'manual_correction' &&
                          !isInvestmentValueUpdate;

                      final txIcon = isTransfer
                          ? Icons.swap_horiz_rounded
                          : (isProfitEvent
                                ? Icons.trending_up_rounded
                                : (isLossEvent
                                      ? Icons.trending_down_rounded
                                      : (isAdjustment
                                            ? Icons.tune_rounded
                                            : _iconForCategoryId(cat, cid))));
                      final txIconColor = isTransfer
                          ? colors.secondary
                          : (isProfitEvent
                                ? Colors.cyan.shade700
                                : (isLossEvent
                                      ? colors.error
                                      : (isAdjustment
                                            ? colors.onSurfaceVariant
                                            : _colorForCategoryId(
                                                context,
                                                cat,
                                                cid,
                                              ))));

                      final titleText = isInvestmentValueUpdate
                          ? (e.amount >= 0 ? 'Profit' : 'Loss')
                          : (note.isNotEmpty
                                ? note
                                : _fallbackTitleByType(e.type));

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: txIconColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(txIcon, color: txIconColor, size: 20),
                        ),
                        title: Text(
                          titleText,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.datetime.year}-${e.datetime.month.toString().padLeft(2, '0')}-${e.datetime.day.toString().padLeft(2, '0')} '
                                '${e.datetime.hour.toString().padLeft(2, '0')}:${e.datetime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: appColors.textNumberPrimary,
                                ),
                              ),
                              if (splitCount > 1 || isManualCorrection)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Wrap(
                                    spacing: 6,
                                    children: [
                                      if (splitCount > 1)
                                        _txBadge(
                                          'Split x$splitCount',
                                          colors.primary,
                                        ),
                                      if (isManualCorrection)
                                        _txBadge(
                                          'Manual correction',
                                          colors.onSurfaceVariant,
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        trailing: Text(
                          isTransfer
                              ? 'RM ${e.amount.toStringAsFixed(2)}'
                              : '${isIncome ? '+' : (isAdjustment ? (e.amount >= 0 ? '+' : '-') : '-')} RM ${e.amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isTransfer
                                ? colors.onSurfaceVariant
                                : (isProfitEvent
                                      ? Colors.cyan.shade700
                                      : (isLossEvent
                                            ? colors.error
                                            : (isIncome
                                                  ? appColors.positiveAmount
                                                  : (isAdjustment
                                                        ? colors
                                                              .onSurfaceVariant
                                                        : appColors
                                                              .negativeAmount)))),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 0) context.go('/dashboard');
          if (i == 1) context.go('/accounts');
          if (i == 2) context.go('/stats');
          if (i == 3) context.go('/settings');
        },
        onAddTap: () => context.push('/add-transaction'),
      ),
    );
  }

  Widget _sectionHeader({
    required BuildContext context,
    required String title,
    required String actionText,
    required VoidCallback onActionTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: colors.onSurface,
          ),
        ),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionText,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _shortcutTile({
    required BuildContext context,
    required String label,
    required double amount,
    required String type,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.extension<AppThemeColors>()!;
    final isIncome = type == 'income';
    final bg = isIncome
        ? appColors.softSuccessSurface
        : appColors.softWarningSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: iconColor.withValues(alpha: 0.1), // 更有质感的点击反馈
        highlightColor: iconColor.withValues(alpha: 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14), // 去掉固定宽高，改用 padding 自适应
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle, // 圆形通常在网格里显得更协调
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              'RM ${amount.toStringAsFixed(1)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _txBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    double total,
    double income,
    double expense,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.extension<AppThemeColors>()!;
    final isDark = theme.brightness == Brightness.dark;

    final gradient = isDark
        ? [appColors.authGradientStart, appColors.authGradientEnd]
        : [const Color(0xFFEAF1FF), const Color(0xFFF6ECFF)];

    final titleColor = isDark
        ? appColors.authAccentForeground
        : colors.onSurface;
    final numberColor = isDark
        ? appColors.authAccentForeground
        : colors.onSurface;
    final subTextColor = isDark
        ? appColors.authAccentForeground.withValues(alpha: 0.75)
        : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : colors.onSurface.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Liquid Assets',
            style: TextStyle(
              color: subTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'RM ${total.toStringAsFixed(2)}',
            style: TextStyle(
              color: numberColor,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summarySubItem(
                  context: context,
                  title: 'Income',
                  amount: 'RM ${income.toStringAsFixed(2)}',
                  icon: Icons.arrow_downward_rounded,
                  iconColor: const Color(0xFF16A34A),
                  pillColor: isDark
                      ? const Color(0xFF1F3A2B)
                      : const Color(0xFFE8F7EF),
                  textColor: titleColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _summarySubItem(
                  context: context,
                  title: 'Expense',
                  amount: 'RM ${expense.toStringAsFixed(2)}',
                  icon: Icons.arrow_upward_rounded,
                  iconColor: const Color(0xFFDC2626),
                  pillColor: isDark
                      ? const Color(0xFF3B1F25)
                      : const Color(0xFFFFECEC),
                  textColor: titleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summarySubItem({
    required BuildContext context,
    required String title,
    required String amount,
    required IconData icon,
    required Color iconColor,
    required Color pillColor,
    required Color textColor,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          amount,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _emptyShortcutCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.flash_on_rounded, color: colors.onSurfaceVariant),
        ),
        title: Text(
          'No shortcuts yet',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: colors.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Create fixed shortcuts for one-tap record',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
        ),
        trailing: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => context.push('/shortcuts'),
          child: const Text(
            'Create',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Future<String?> _pickAccount(
    BuildContext context,
    List<Map<String, dynamic>> accounts,
  ) async {
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please create an account first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    String selected = (accounts.first['_id'] ?? accounts.first['id'])
        .toString();

    return showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text(
          'Select Account',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: StatefulBuilder(
          builder: (_, setD) => SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: selected,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(dCtx).colorScheme.outline,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(dCtx).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(dCtx).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Theme.of(dCtx).colorScheme.onSurfaceVariant,
              ),
              items: accounts.map((a) {
                final id = (a['_id'] ?? a['id']).toString();
                final name = (a['name'] ?? 'Account').toString();
                final bal = _toDouble(a['balance']);
                return DropdownMenuItem(
                  value: id,
                  child: Text(
                    '$name (RM ${bal.toStringAsFixed(2)})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setD(() => selected = v);
              },
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dCtx).colorScheme.onSurfaceVariant,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, selected),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dCtx).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
