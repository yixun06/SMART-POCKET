import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/asset_controller.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/malaysia_provider_presets.dart';
import '../../../core/utils/theme.dart';
import '../../widgets/common/provider_avatar.dart';
import '../../widgets/navigation/bottom_nav_bar.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _negativeBalancePromptShown = false;

  void _showNegativeBalancePrompt() {
    if (!mounted || _negativeBalancePromptShown) return;
    _negativeBalancePromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Negative balance detected. Please edit the account and set a non-negative balance.',
          ),
        ),
      );
    });
  }

  Widget _dialogTitle(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color? iconColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor ?? colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  bool _isDerivedLazyOrigin(String origin) {
    final normalized = origin.trim().toLowerCase();
    return normalized == 'derived' || normalized == 'detailed';
  }

  @override
  Widget build(BuildContext context) {
    final asset = context.watch<AssetController>();
    final uid = asset.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: asset.watchUserData(),
      builder: (context, userSnap) {
        final userData = userSnap.data ?? {};
        final settings =
            (userData[UserFields.settings] as Map<String, dynamic>?) ?? {};
        final mode = (settings[UserSettingsFields.appMode] ?? 'lazy')
            .toString();
        final modeOrigin = (settings[UserSettingsFields.appModeOrigin] ?? '')
            .toString();
        final isDerivedLazy =
            mode == 'lazy' && _isDerivedLazyOrigin(modeOrigin);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(title: Text(mode == 'lazy' ? 'Assets' : 'Accounts')),
          body: mode == 'detailed'
              ? _buildDetailedMode(uid)
              : _buildLazyMode(uid, isDerivedLazy: isDerivedLazy),
          floatingActionButton: mode == 'detailed'
              ? FloatingActionButton(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  onPressed: () => _openAccountEditor(),
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: AppBottomNavBar(
            currentIndex: 1,
            onTap: (i) {
              if (i == 0) context.go('/dashboard');
              if (i == 1) context.go('/accounts');
              if (i == 2) context.go('/stats');
              if (i == 3) context.go('/settings');
            },
            onAddTap: () => context.push('/add-transaction'),
          ),
        );
      },
    );
  }

  List<String> _buildDeviationTips({
    required double actualSavings,
    required double targetSavings,
    required double actualInvest,
    required double targetInvest,
    required double actualDaily,
    required double targetDaily,
    double threshold = 8.0,
  }) {
    final tips = <String>[];

    void check(String label, double actual, double target) {
      final diff = actual - target;
      if (diff.abs() >= threshold) {
        final dir = diff > 0 ? 'above' : 'below';
        tips.add('$label ${diff.abs().toStringAsFixed(1)}% $dir target');
      }
    }

    check('Savings', actualSavings, targetSavings);
    check('Investment', actualInvest, targetInvest);
    check('Daily Use', actualDaily, targetDaily);

    return tips;
  }

  Widget _assetAllocationEntryCard(String uid) {
    final asset = context.read<AssetController>();
    return StreamBuilder<Map<String, dynamic>>(
      stream: asset.watchUserData(),
      builder: (context, userSnap) {
        final userData = userSnap.data ?? {};
        final settings =
            (userData[UserFields.settings] as Map<String, dynamic>?) ?? {};
        final goal =
            (settings['allocation_goal'] as Map<String, dynamic>?) ?? {};
        final targets = (goal['targets'] as Map<String, dynamic>?) ?? {};

        final targetSavings = ((targets['savings'] ?? 40) as num).toDouble();
        final targetInvest = ((targets['investment'] ?? 40) as num).toDouble();
        final targetDaily = ((targets['daily_use'] ?? 20) as num).toDouble();

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: asset.watchAccounts(),
          builder: (context, accSnap) {
            final docs = accSnap.data ?? [];

            double total = 0;
            double savingsBal = 0;
            double investBal = 0;
            double dailyBal = 0;

            for (final m in docs) {
              final bal = ((m[AccountFields.balance] ?? 0) as num).toDouble();
              final tag = (m[AccountFields.tag] ?? '')
                  .toString()
                  .toUpperCase()
                  .trim();

              total += bal;
              if (tag == 'SAVINGS') savingsBal += bal;
              if (tag == 'INVESTMENT') investBal += bal;
              if (tag == 'DAILY_USE') dailyBal += bal;
            }

            final actualSavings = total > 0 ? (savingsBal / total * 100) : 0.0;
            final actualInvest = total > 0 ? (investBal / total * 100) : 0.0;
            final actualDaily = total > 0 ? (dailyBal / total * 100) : 0.0;

            double ratio(double actual, double target) {
              if (target <= 0) return 0;
              return (actual / target).clamp(0.0, 1.0);
            }

            final tips = _buildDeviationTips(
              actualSavings: actualSavings,
              targetSavings: targetSavings,
              actualInvest: actualInvest,
              targetInvest: targetInvest,
              actualDaily: actualDaily,
              targetDaily: targetDaily,
            );

            final colors = Theme.of(context).colorScheme;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Color.alphaBlend(
                            colors.primary.withValues(alpha: 0.16),
                            colors.surfaceContainerLow,
                          ),
                          Color.alphaBlend(
                            colors.secondary.withValues(alpha: 0.1),
                            colors.surfaceContainerLowest,
                          ),
                        ]
                      : [
                          Color.alphaBlend(
                            colors.primary.withValues(alpha: 0.07),
                            colors.surface,
                          ),
                          Color.alphaBlend(
                            colors.secondary.withValues(alpha: 0.05),
                            colors.surface,
                          ),
                        ],
                ),
                border: Border.all(
                  color: colors.outlineVariant.withValues(
                    alpha: isDark ? 0.45 : 0.65,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: isDark ? 0.24 : 0.08,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(
                              alpha: isDark ? 0.6 : 0.75,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.pie_chart_outline_rounded,
                            color: colors.onPrimaryContainer,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Asset Allocation',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push('/allocation-goals'),
                          child: const Text('Set Goals'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Actual vs target allocation by category',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _allocRow(
                      context,
                      label: 'Savings',
                      progress: ratio(actualSavings, targetSavings),
                      actual: actualSavings,
                      target: targetSavings,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    _allocRow(
                      context,
                      label: 'Investment',
                      progress: ratio(actualInvest, targetInvest),
                      actual: actualInvest,
                      target: targetInvest,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    _allocRow(
                      context,
                      label: 'Daily Use',
                      progress: ratio(actualDaily, targetDaily),
                      actual: actualDaily,
                      target: targetDaily,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    if (docs.isEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Not enough account data to compute allocation',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (tips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Allocation deviation',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...tips.map(
                              (t) => Text(
                                '- $t',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _allocRow(
    BuildContext context, {
    required String label,
    required double progress,
    required double actual,
    required double target,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;
    final delta = actual - target;
    final deltaText = delta == 0
        ? 'On target'
        : '${delta > 0 ? '+' : '-'}${delta.abs().toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
            Text(
              '${actual.toStringAsFixed(0)}% / ${target.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress.clamp(0.0, 1.0),
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          deltaText,
          style: TextStyle(
            fontSize: 10.5,
            color: delta == 0 ? colors.onSurfaceVariant : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLazyMode(String uid, {required bool isDerivedLazy}) {
    final asset = context.read<AssetController>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: asset.watchAccounts(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load accounts: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = snap.data ?? [];
        double totalAsset = 0;
        double liquidAsset = 0;
        var hasNegativeBalance = false;
        for (final a in accounts) {
          final bal = ((a[AccountFields.balance] ?? 0) as num).toDouble();
          totalAsset += bal;
          final isLiquid = (a[AccountFields.isLiquid] ?? true) == true;
          if (isLiquid) liquidAsset += bal;
          if (bal < 0) hasNegativeBalance = true;
        }
        if (hasNegativeBalance) {
          _showNegativeBalancePrompt();
        } else {
          _negativeBalancePromptShown = false;
        }
        final safeTotalAsset = totalAsset < 0 ? 0.0 : totalAsset;
        final safeLiquidAsset = liquidAsset < 0 ? 0.0 : liquidAsset;

        String normalizeTag(dynamic value) =>
            value == null ? '' : value.toString().trim().toLowerCase();
        final grouped = <String, List<Map<String, dynamic>>>{
          'daily_use': [],
          'savings': [],
          'investment': [],
        };
        for (final a in accounts) {
          final t = normalizeTag(a[AccountFields.tag]);
          if (grouped.containsKey(t)) {
            grouped[t]!.add(a);
          }
        }

        double groupTotal(String key) {
          return grouped[key]!.fold(
            0.0,
            (totalValue, a) =>
                totalValue +
                ((a[AccountFields.balance] ?? 0) as num).toDouble(),
          );
        }

        asset.syncAssetProfile(mode: 'lazy', totalAsset: safeTotalAsset);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _summaryCard(
              context,
              safeTotalAsset,
              safeLiquidAsset,
              accounts.length,
            ),
            const SizedBox(height: 14),
            _assetAllocationEntryCard(uid),
            const SizedBox(height: 14),
            if (isDerivedLazy)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Lazy balances are auto-consolidated from Detailed Mode and cannot be edited here. Update underlying accounts in Detailed Mode to sync.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            if (isDerivedLazy) const SizedBox(height: 12),
            if (grouped['daily_use']!.isEmpty || grouped['savings']!.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Let\'s set up your Lazy Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create at least Daily Use and Savings so transactions and shortcuts can run automatically.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (grouped['daily_use']!.isEmpty)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _createBucketPrimaryAccount(uid, 'daily_use'),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Daily Use'),
                            ),
                          if (grouped['savings']!.isEmpty)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _createBucketPrimaryAccount(uid, 'savings'),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Savings'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            _lazyBucketCard(
              context: context,
              uid: uid,
              title: 'Daily Use',
              tag: 'daily_use',
              total: groupTotal('daily_use'),
              share: totalAsset > 0 ? groupTotal('daily_use') / totalAsset : 0,
              orderHint:
                  'Deduction order: Primary -> others -> Savings (if enabled)',
              accounts: grouped['daily_use']!,
              isDerivedLazy: isDerivedLazy,
            ),
            const SizedBox(height: 10),
            _lazyBucketCard(
              context: context,
              uid: uid,
              title: 'Savings',
              tag: 'savings',
              total: groupTotal('savings'),
              share: totalAsset > 0 ? groupTotal('savings') / totalAsset : 0,
              orderHint: 'Used as fallback when Daily Use is insufficient',
              accounts: grouped['savings']!,
              isDerivedLazy: isDerivedLazy,
            ),
            const SizedBox(height: 10),
            _lazyBucketCard(
              context: context,
              uid: uid,
              title: 'Investment',
              tag: 'investment',
              total: groupTotal('investment'),
              share: totalAsset > 0 ? groupTotal('investment') / totalAsset : 0,
              orderHint: 'Not used for Lazy expense deduction by default',
              accounts: grouped['investment']!,
              isDerivedLazy: isDerivedLazy,
            ),
          ],
        );
      },
    );
  }

  Widget _lazyBucketCard({
    required BuildContext context,
    required String uid,
    required String title,
    required String tag,
    required double total,
    required double share,
    required String orderHint,
    required List<Map<String, dynamic>> accounts,
    required bool isDerivedLazy,
  }) {
    final colors = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppThemeColors>()!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: colors.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(share * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: appColors.textNumberPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'RM ${total.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              orderHint,
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    if (accounts.isEmpty) {
                      await _createBucketPrimaryAccount(uid, tag);
                      return;
                    }
                    if (isDerivedLazy) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This balance is auto-consolidated from Detailed Mode. Please edit Detailed accounts instead.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (tag == 'investment') {
                      await _openLazyInvestmentBucketAdjuster(uid, accounts);
                      return;
                    }
                    await _openBucketPrimaryAdjuster(uid, tag, accounts);
                  },
                  child: Text(
                    accounts.isEmpty
                        ? 'Create Bucket'
                        : (isDerivedLazy
                              ? 'Auto-Consolidated'
                              : 'Adjust Balance'),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _openBucketDetails(title, accounts),
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBucketPrimaryAdjuster(
    String uid,
    String tag,
    List<Map<String, dynamic>> accounts,
  ) async {
    Map<String, dynamic> primary = accounts.first;
    for (final a in accounts) {
      if (a[AccountFields.isPrimary] == true) {
        primary = a;
        break;
      }
    }

    final accountId = (primary['docId'] ?? primary[CommonFields.id]).toString();
    final accountName = (primary[AccountFields.name] ?? 'Primary Account')
        .toString();
    final current = ((primary[AccountFields.balance] ?? 0) as num).toDouble();
    final ctrl = TextEditingController(text: current.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _dialogTitle(
          dCtx,
          icon: Icons.tune_rounded,
          title: 'Adjust $accountName',
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Target Balance (RM)'),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n < 0) return 'Invalid amount';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dCtx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) return;

    final target = double.parse(ctrl.text.trim());
    try {
      await context.read<AssetController>().addAdjustmentTransaction(
        accountId: accountId,
        targetBalance: target,
        note: 'manual correction ($tag)',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance adjusted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _createBucketPrimaryAccount(String uid, String tag) async {
    final name = switch (tag) {
      'daily_use' => 'Daily Use Wallet',
      'savings' => 'Savings Wallet',
      _ => 'Investment Account',
    };

    try {
      await context.read<AssetController>().createBucketPrimaryAccount(tag);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name created')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create bucket: $e')));
    }
  }

  void _openBucketDetails(String title, List<Map<String, dynamic>> accounts) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final appColors = Theme.of(ctx).extension<AppThemeColors>()!;
        final itemWidgets = accounts.isEmpty
            ? <Widget>[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: Text('No account in this bucket yet.')),
                ),
              ]
            : accounts.map((a) {
                final name = (a[AccountFields.name] ?? 'Account').toString();
                final bal = ((a[AccountFields.balance] ?? 0) as num).toDouble();
                final primary = a[AccountFields.isPrimary] == true;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  subtitle: Text(
                    primary ? 'Primary account' : 'Secondary account',
                  ),
                  trailing: Text(
                    'RM ${bal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: appColors.textNumberPrimary,
                    ),
                  ),
                );
              }).toList();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title Details',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemBuilder: (_, i) => itemWidgets[i],
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemCount: itemWidgets.length,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _openTotalAssetEditor(
    String uid,
    List<Map<String, dynamic>> accounts,
  ) async {
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account found for balance update')),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    String selectedAccountId =
        (accounts.first['docId'] ?? accounts.first[CommonFields.id]).toString();
    final selectedAccount = accounts.first;
    final current = ((selectedAccount[AccountFields.balance] ?? 0) as num)
        .toDouble();
    final ctrl = TextEditingController(text: current.toStringAsFixed(2));

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: _dialogTitle(
            dCtx,
            icon: Icons.account_balance_wallet_rounded,
            title: 'Update Account Balance',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountId,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: accounts
                      .map(
                        (a) => DropdownMenuItem<String>(
                          value: (a['docId'] ?? a[CommonFields.id]).toString(),
                          child: Text(
                            (a[AccountFields.name] ?? 'Account').toString(),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final selected = accounts.firstWhere(
                      (a) => (a['docId'] ?? a[CommonFields.id]).toString() == v,
                      orElse: () => accounts.first,
                    );
                    selectedAccountId = v;
                    final newCurrent =
                        ((selected[AccountFields.balance] ?? 0) as num)
                            .toDouble();
                    ctrl.text = newCurrent.toStringAsFixed(2);
                    setModal(() {});
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Target Balance (RM)',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'This will create a manual correction (adjustment transaction).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(dCtx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dCtx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (ok != true) return;

    final n = double.parse(ctrl.text.trim());
    try {
      await context.read<AssetController>().addAdjustmentTransaction(
        accountId: selectedAccountId,
        targetBalance: n,
        note: 'manual correction',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance updated via manual correction')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Widget _buildDetailedMode(String uid) {
    final asset = context.read<AssetController>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: asset.watchAccounts(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Failed to load accounts: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final accounts = snap.data ?? [];
        final hasVirtualGenerated = accounts.any(
          (a) => (a['docId'] ?? a[CommonFields.id] ?? '').toString().startsWith(
            'virtual_',
          ),
        );

        double total = 0;
        double liquid = 0;
        var hasNegativeBalance = false;
        for (final a in accounts) {
          final bal = ((a[AccountFields.balance] ?? 0) as num).toDouble();
          total += bal;
          if ((a[AccountFields.isLiquid] ?? true) == true) liquid += bal;
          if (bal < 0) hasNegativeBalance = true;
        }
        if (hasNegativeBalance) {
          _showNegativeBalancePrompt();
        } else {
          _negativeBalancePromptShown = false;
        }
        final safeTotal = total < 0 ? 0.0 : total;
        final safeLiquid = liquid < 0 ? 0.0 : liquid;

        asset.syncAssetProfile(
          mode: 'detailed',
          totalAsset: safeTotal,
          includeCreatedAt: true,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _summaryCard(context, safeTotal, safeLiquid, accounts.length),
            const SizedBox(height: 14),
            _assetAllocationEntryCard(uid),
            const SizedBox(height: 14),
            if (hasVirtualGenerated)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Base virtual accounts were generated from your previous Lazy Mode balances. You can progressively add real accounts and split or replace these virtual accounts anytime.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            if (hasVirtualGenerated) const SizedBox(height: 12),
            if (accounts.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No accounts yet. Tap + to create one.'),
                ),
              )
            else
              ...accounts.map(_accountTile),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
    BuildContext context,
    double total,
    double liquid,
    int count,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final liquidShare = total > 0 ? (liquid / total).clamp(0.0, 1.0) : 0.0;

    final cardGradient = isDark
        ? [
            Color.alphaBlend(
              colors.primary.withValues(alpha: 0.24),
              colors.surfaceContainerHigh,
            ),
            Color.alphaBlend(
              colors.tertiary.withValues(alpha: 0.14),
              colors.surfaceContainerLowest,
            ),
          ]
        : [const Color(0xFFEDF5FF), const Color(0xFFF6F8FF)];
    final titleColor = isDark ? colors.onSurface : const Color(0xFF34507A);
    final valueColor = isDark ? colors.onSurface : const Color(0xFF18325E);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardGradient,
        ),
        border: Border.all(
          color: isDark
              ? colors.outlineVariant.withValues(alpha: 0.48)
              : const Color(0xFFD2E2FF),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Total Assets',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.primaryContainer.withValues(alpha: 0.4)
                      : const Color(0xFFDCEAFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? colors.primary.withValues(alpha: 0.3)
                        : const Color(0xFFC5DBFF),
                  ),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: isDark
                      ? colors.onPrimaryContainer
                      : const Color(0xFF2C5BAA),
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'RM ${total.toStringAsFixed(2)}',
            style: TextStyle(
              color: valueColor,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Across all linked accounts',
            style: TextStyle(
              color: titleColor.withValues(alpha: isDark ? 0.88 : 0.78),
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: liquidShare,
              backgroundColor: isDark
                  ? colors.surfaceContainerHighest
                  : const Color(0xFFDCE9FF),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? colors.primary : const Color(0xFF3A72D8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryStatTile(
                  context: context,
                  label: 'Liquid',
                  value: 'RM ${liquid.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryStatTile(
                  context: context,
                  label: 'Accounts',
                  value: '$count Account(s)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStatTile({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceContainerHighest.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? colors.outlineVariant.withValues(alpha: 0.36)
              : const Color(0xFFD2E0F7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountTile(Map<String, dynamic> a) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final docId = a['docId'].toString();

    final name = (a[AccountFields.name] ?? 'Account').toString();

    final provider = (a[AccountFields.provider] ?? name).toString();

    final type = (a[AccountFields.type] ?? 'cash').toString().toLowerCase();

    final balance = ((a[AccountFields.balance] ?? 0) as num).toDouble();

    final isLiquid = (a[AccountFields.isLiquid] ?? true) == true;

    final tag = (a[AccountFields.tag] ?? 'DAILY_USE').toString();

    final providerAvatar = ProviderAvatar.providerAvatar(
      context,
      provider,
      type: type,
      size: 58,
    );

    Widget buildChip(String label, {Color? bg, Color? fg}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:
              bg ??
              (isDark
                  ? colors.surfaceContainerHighest
                  : colors.primaryContainer.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg ?? colors.onSurface,
            letterSpacing: .3,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainerLow : colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: isDark ? 0.34 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.14)
                : colors.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          final uid = context.read<AssetController>().uid;
          if (uid == null) return;
          final isInvestmentTagged =
              type == 'investment' || tag.trim().toLowerCase() == 'investment';
          if (isInvestmentTagged) {
            final action = await _pickInvestmentAction(
              accountName:
                  (a[AccountFields.provider] ??
                          a[AccountFields.name] ??
                          'Investment')
                      .toString(),
              currentValue: ((a[AccountFields.balance] ?? 0) as num).toDouble(),
            );
            if (action == null) return;
            if (action == 'update_value') {
              await _openInvestmentBalanceEditor(
                uid: uid,
                accountId: docId,
                existing: a,
              );
            } else {
              await _openInvestmentManualCorrectionEditor(
                uid: uid,
                accountId: docId,
                existing: a,
              );
            }
            return;
          }

          await _openAccountEditor(accountId: docId, existing: a);
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              providerAvatar,

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                        height: 1.15,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      provider,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        height: 1.15,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        buildChip(type.toUpperCase()),

                        buildChip(
                          isLiquid ? 'LIQUID' : 'NON-LIQUID',
                          bg: isLiquid
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          fg: isLiquid
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),

                        buildChip(tag),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Icon(Icons.chevron_right_rounded, color: colors.outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _investmentActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String impactLabel,
    required String impactValue,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? Color.alphaBlend(
            accentColor.withValues(alpha: 0.18),
            colors.surfaceContainerLow,
          )
        : Color.alphaBlend(accentColor.withValues(alpha: 0.08), colors.surface);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.55 : 0.38),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceContainerHigh
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$impactLabel: $impactValue',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.outline),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickInvestmentAction({
    required String accountName,
    required double currentValue,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _dialogTitle(
          dCtx,
          icon: Icons.trending_up_rounded,
          title: 'Investment Action',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              accountName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(dCtx).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Current Investment Value: RM ${currentValue.toStringAsFixed(2)}',
              style: TextStyle(
                color: Theme.of(dCtx).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _investmentActionCard(
              context: dCtx,
              icon: Icons.show_chart_rounded,
              title: 'Update Investment Value',
              subtitle:
                  'Use this for real market movement (growth or decline).',
              impactLabel: 'Investment Performance',
              impactValue: 'Updated and reflected in analytics',
              accentColor: Theme.of(dCtx).colorScheme.primary,
              onTap: () => Navigator.pop(dCtx, 'update_value'),
            ),
            const SizedBox(height: 10),
            _investmentActionCard(
              context: dCtx,
              icon: Icons.build_circle_outlined,
              title: 'Manual Correction',
              subtitle: 'Use this to fix an incorrect balance entry only.',
              impactLabel: 'Investment Performance',
              impactValue: 'Not affected (excluded from analytics)',
              accentColor: Theme.of(dCtx).colorScheme.tertiary,
              onTap: () => Navigator.pop(dCtx, 'manual_correction'),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(dCtx).brightness == Brightness.dark
                    ? Theme.of(
                        dCtx,
                      ).colorScheme.errorContainer.withValues(alpha: 0.75)
                    : Theme.of(
                        dCtx,
                      ).colorScheme.errorContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(
                    dCtx,
                  ).colorScheme.error.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'Please choose carefully. This action updates account records immediately.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(dCtx).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLazyInvestmentBucketAdjuster(
    String uid,
    List<Map<String, dynamic>> accounts,
  ) async {
    Map<String, dynamic> primary = accounts.first;
    for (final a in accounts) {
      if (a[AccountFields.isPrimary] == true) {
        primary = a;
        break;
      }
    }
    final accountId = (primary['docId'] ?? primary[CommonFields.id]).toString();
    if (accountId.trim().isEmpty) return;

    final action = await _pickInvestmentAction(
      accountName:
          (primary[AccountFields.provider] ??
                  primary[AccountFields.name] ??
                  'Investment')
              .toString(),
      currentValue: ((primary[AccountFields.balance] ?? 0) as num).toDouble(),
    );
    if (action == null) return;

    if (action == 'update_value') {
      await _openInvestmentBalanceEditor(
        uid: uid,
        accountId: accountId,
        existing: primary,
      );
      return;
    }

    await _openInvestmentManualCorrectionEditor(
      uid: uid,
      accountId: accountId,
      existing: primary,
    );
  }

  Future<void> _openInvestmentBalanceEditor({
    required String uid,
    required String accountId,
    required Map<String, dynamic> existing,
  }) async {
    final storedBalance = ((existing[AccountFields.balance] ?? 0) as num)
        .toDouble();
    final accountName =
        (existing[AccountFields.provider] ??
                existing[AccountFields.name] ??
                'Investment')
            .toString();

    final formKey = GlobalKey<FormState>();
    final originalCtrl = TextEditingController(
      text: storedBalance.toStringAsFixed(2),
    );
    final currentCtrl = TextEditingController(
      text: storedBalance.toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(dCtx).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Update $accountName',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(dCtx).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: originalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Original Value (RM)',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: currentCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Current Value (RM)',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: Listenable.merge([originalCtrl, currentCtrl]),
                  builder: (_, __) {
                    final o = double.tryParse(originalCtrl.text.trim()) ?? 0;
                    final c = double.tryParse(currentCtrl.text.trim()) ?? 0;
                    final d = c - o;
                    final isProfit = d >= 0;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isProfit
                              ? Theme.of(dCtx).colorScheme.tertiaryContainer
                                    .withValues(alpha: 0.45)
                              : Theme.of(dCtx).colorScheme.errorContainer
                                    .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isProfit
                                ? Theme.of(
                                    dCtx,
                                  ).colorScheme.tertiary.withValues(alpha: 0.25)
                                : Theme.of(
                                    dCtx,
                                  ).colorScheme.error.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          'Estimated P/L: ${isProfit ? '+' : '-'}RM ${d.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isProfit
                                ? Theme.of(dCtx).colorScheme.onTertiaryContainer
                                : Theme.of(dCtx).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(dCtx).colorScheme.error,
                      ),
                      onPressed: () async {
                        final asset = context.read<AssetController>();
                        final navigator = Navigator.of(dCtx);
                        final messenger = ScaffoldMessenger.of(context);
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: _dialogTitle(
                              dCtx,
                              icon: Icons.warning_amber_rounded,
                              iconColor: Theme.of(dCtx).colorScheme.error,
                              title: 'Delete account?',
                            ),
                            content: const Text(
                              'This investment account will be removed.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (yes == true) {
                          await asset.deleteAccount(accountId);
                          if (!mounted) return;
                          navigator.pop(false);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Investment account deleted'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(dCtx, true);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;

    if (ok != true) return;

    final originalValue = double.parse(originalCtrl.text.trim());
    final currentValue = double.parse(currentCtrl.text.trim());
    final diff = currentValue - originalValue;
    final pnlType = diff >= 0 ? 'profit' : 'loss';

    final asset = context.read<AssetController>();

    try {
      await asset.addAdjustmentTransaction(
        accountId: accountId,
        targetBalance: currentValue,
        note: noteCtrl.text.trim().isEmpty
            ? 'investment value update'
            : noteCtrl.text.trim(),
      );

      if (diff != 0) {
        await asset.recordInvestmentPnlLog(
          accountId: accountId,
          accountName: accountName,
          oldBalance: originalValue,
          newBalance: currentValue,
          diff: diff,
          pnlType: pnlType,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            diff == 0
                ? 'Updated. No P/L change.'
                : '${pnlType.toUpperCase()}: ${diff >= 0 ? '+' : '-'}RM ${diff.abs().toStringAsFixed(2)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _openInvestmentManualCorrectionEditor({
    required String uid,
    required String accountId,
    required Map<String, dynamic> existing,
  }) async {
    final current = ((existing[AccountFields.balance] ?? 0) as num).toDouble();
    final accountName =
        (existing[AccountFields.provider] ??
                existing[AccountFields.name] ??
                'Investment')
            .toString();
    final formKey = GlobalKey<FormState>();
    final targetCtrl = TextEditingController(text: current.toStringAsFixed(2));
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _dialogTitle(
          dCtx,
          icon: Icons.build_circle_outlined,
          title: 'Manual Correction: $accountName',
          iconColor: Theme.of(dCtx).colorScheme.tertiary,
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: targetCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Target Balance (RM)',
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n < 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correction Note (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dCtx, true);
            },
            child: const Text('Apply Correction'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) return;

    final target = double.parse(targetCtrl.text.trim());
    try {
      await context.read<AssetController>().addAdjustmentTransaction(
        accountId: accountId,
        targetBalance: target,
        note: noteCtrl.text.trim().isEmpty
            ? 'manual correction (investment)'
            : noteCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Balance corrected. This change will not affect investment performance analytics.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Manual correction failed: $e')));
    }
  }

  Future<void> _openAccountEditor({
    String? accountId,
    Map<String, dynamic>? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final isEdit = existing != null;

    String normalizeEditorTag(dynamic raw) {
      final t = (raw ?? '').toString().trim().toUpperCase();
      switch (t) {
        case 'DAILY_USE':
        case 'SAVINGS':
        case 'INVESTMENT':
          return t;
        default:
          if (t == 'DAILY USE' || t == 'DAILYUSE') return 'DAILY_USE';
          return 'DAILY_USE';
      }
    }

    String normalizeType(dynamic raw) {
      final t = (raw ?? 'bank').toString().trim().toLowerCase();
      if (t == 'bank' || t == 'ewallet' || t == 'investment' || t == 'cash') {
        return t;
      }
      return 'bank';
    }

    bool sameText(String a, String b) =>
        a.trim().toLowerCase() == b.trim().toLowerCase();

    final initialProvider =
        (existing?[AccountFields.provider] ??
                existing?[AccountFields.name] ??
                '')
            .toString();
    final initialName =
        (existing?[AccountFields.name] ??
                existing?[AccountFields.provider] ??
                '')
            .toString();

    final nameCtrl = TextEditingController(text: initialName);
    final providerCtrl = TextEditingController(text: initialProvider);
    final balanceCtrl = TextEditingController(
      text: isEdit
          ? (((existing[AccountFields.balance] ?? 0) as num)
                .toDouble()
                .toString())
          : '',
    );
    final accNumCtrl = TextEditingController(
      text: (existing?[AccountFields.accountNumber] ?? '').toString(),
    );
    final tagCtrl = TextEditingController(
      text: normalizeEditorTag(existing?[AccountFields.tag]),
    );

    String type = normalizeType(existing?[AccountFields.type]);
    bool isLiquid = (existing?[AccountFields.isLiquid] ?? true) == true;
    String selectedProviderOption =
        MalaysiaProviderPresets.customProviderOption;
    ProviderAutofill selectedAutofill = MalaysiaProviderPresets.defaultsForType(
      type,
    );

    MalaysiaProviderPreset? matchProviderForType(
      String selectedType,
      String providerName,
    ) {
      final candidates = MalaysiaProviderPresets.providersByType(selectedType);
      for (final p in candidates) {
        if (sameText(p.providerName, providerName)) return p;
      }
      return null;
    }

    void applyAutofill({
      required ProviderAutofill autofill,
      bool forceTag = false,
    }) {
      selectedAutofill = autofill;
      if (type == 'investment') {
        isLiquid = false;
        tagCtrl.text = 'INVESTMENT';
        return;
      }
      isLiquid = autofill.isLiquid;
      final normalizedTag = normalizeEditorTag(tagCtrl.text);
      if (forceTag || normalizedTag.isEmpty || normalizedTag == 'INVESTMENT') {
        tagCtrl.text = autofill.tag;
      }
    }

    final initialPreset = matchProviderForType(type, providerCtrl.text);
    if (initialPreset != null) {
      selectedProviderOption = initialPreset.providerName;
      selectedAutofill = MalaysiaProviderPresets.autofillFor(
        providerName: initialPreset.providerName,
        type: type,
      );
      if (!isEdit) {
        applyAutofill(autofill: selectedAutofill, forceTag: true);
      }
    } else if (!isEdit) {
      final defaults = MalaysiaProviderPresets.providersByType(type);
      if (defaults.isNotEmpty) {
        selectedProviderOption = defaults.first.providerName;
        providerCtrl.text = defaults.first.providerName;
        if (nameCtrl.text.trim().isEmpty) {
          nameCtrl.text = defaults.first.providerName;
        }
        selectedAutofill = MalaysiaProviderPresets.autofillFor(
          providerName: defaults.first.providerName,
          type: type,
        );
      }
      applyAutofill(autofill: selectedAutofill, forceTag: true);
    } else {
      applyAutofill(autofill: selectedAutofill, forceTag: type == 'investment');
    }

    if (type == 'investment') {
      isLiquid = false;
      tagCtrl.text = 'INVESTMENT';
    }

    final rootColors = Theme.of(context).colorScheme;

    InputDecoration deco(String label, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: rootColors.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: rootColors.outlineVariant),
        ),
      );
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        final colors = theme.colorScheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 28,
          ),
          child: StatefulBuilder(
            builder: (_, setModal) {
              Widget typeBtn(String value, String label, {double? width}) {
                final selected = type == value;
                return SizedBox(
                  width: width,
                  child: GestureDetector(
                    onTap: () => setModal(() {
                      type = value;
                      final providersForType =
                          MalaysiaProviderPresets.providersByType(type);
                      if (providersForType.isNotEmpty) {
                        final matched =
                            matchProviderForType(type, providerCtrl.text) ??
                            providersForType.first;
                        final syncName =
                            nameCtrl.text.trim().isEmpty ||
                            sameText(nameCtrl.text, providerCtrl.text);
                        selectedProviderOption = matched.providerName;
                        providerCtrl.text = matched.providerName;
                        if (syncName) nameCtrl.text = matched.providerName;
                        selectedAutofill = MalaysiaProviderPresets.autofillFor(
                          providerName: matched.providerName,
                          type: type,
                        );
                        applyAutofill(
                          autofill: selectedAutofill,
                          forceTag: true,
                        );
                      } else {
                        selectedProviderOption =
                            MalaysiaProviderPresets.customProviderOption;
                        selectedAutofill =
                            MalaysiaProviderPresets.defaultsForType(type);
                        applyAutofill(
                          autofill: selectedAutofill,
                          forceTag: type == 'investment',
                        );
                      }
                    }),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.surface
                            : colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: selected
                            ? Border.all(color: colors.outlineVariant)
                            : null,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final providersForType = MalaysiaProviderPresets.providersByType(
                type,
              );

              return Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Form(
                  key: formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compactWidth = constraints.maxWidth < 380;
                      final typeBtnWidth =
                          (constraints.maxWidth - 8 - (compactWidth ? 8 : 12)) /
                          (compactWidth ? 2 : 4);
                      final providerColumns = compactWidth ? 1 : 2;
                      final providerAspectRatio = compactWidth ? 4.4 : 2.45;

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isEdit ? 'Edit Account' : 'Add Account',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: colors.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(dialogCtx, false),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  typeBtn('bank', 'Bank', width: typeBtnWidth),
                                  typeBtn(
                                    'ewallet',
                                    'Ewallet',
                                    width: typeBtnWidth,
                                  ),
                                  typeBtn(
                                    'investment',
                                    'Investment',
                                    width: typeBtnWidth,
                                  ),
                                  typeBtn('cash', 'Cash', width: typeBtnWidth),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                14,
                                14,
                                12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.primary.withValues(alpha: 0.09),
                                    colors.secondary.withValues(alpha: 0.06),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.outlineVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Malaysia Provider',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colors.onSurfaceVariant,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: providersForType.length + 1,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: providerColumns,
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 10,
                                          childAspectRatio: providerAspectRatio,
                                        ),
                                    itemBuilder: (_, index) {
                                      final isCustom =
                                          index == providersForType.length;
                                      final String value = isCustom
                                          ? MalaysiaProviderPresets
                                                .customProviderOption
                                          : providersForType[index]
                                                .providerName;
                                      final bool selected =
                                          selectedProviderOption == value;
                                      final preset = isCustom
                                          ? null
                                          : providersForType[index];

                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          onTap: () {
                                            setModal(() {
                                              selectedProviderOption = value;
                                              if (isCustom) {
                                                selectedAutofill =
                                                    MalaysiaProviderPresets.defaultsForType(
                                                      type,
                                                    );
                                                applyAutofill(
                                                  autofill: selectedAutofill,
                                                  forceTag:
                                                      type == 'investment',
                                                );
                                                return;
                                              }

                                              final syncName =
                                                  nameCtrl.text
                                                      .trim()
                                                      .isEmpty ||
                                                  sameText(
                                                    nameCtrl.text,
                                                    providerCtrl.text,
                                                  );
                                              providerCtrl.text = value;
                                              if (syncName) {
                                                nameCtrl.text = value;
                                              }
                                              selectedAutofill =
                                                  MalaysiaProviderPresets.autofillFor(
                                                    providerName: value,
                                                    type: type,
                                                  );
                                              applyAutofill(
                                                autofill: selectedAutofill,
                                                forceTag: true,
                                              );
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 160,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? colors.primary.withValues(
                                                      alpha: 0.14,
                                                    )
                                                  : colors.surface.withValues(
                                                      alpha: 0.86,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: selected
                                                    ? colors.primary
                                                    : colors.outlineVariant
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                width: selected ? 1.4 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 44,
                                                  height: 44,
                                                  child: isCustom
                                                      ? ClipOval(
                                                          child: ColoredBox(
                                                            color: colors
                                                                .surfaceContainerHighest,
                                                            child: Icon(
                                                              Icons
                                                                  .edit_rounded,
                                                              size: 22,
                                                              color: colors
                                                                  .onSurfaceVariant,
                                                            ),
                                                          ),
                                                        )
                                                      : ProviderAvatar.logoWidget(
                                                          context,
                                                          preset!,
                                                          size: 52,
                                                        ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    isCustom
                                                        ? 'Custom Provider'
                                                        : value,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: selected
                                                          ? colors.primary
                                                          : colors.onSurface,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(
                                                  selected
                                                      ? Icons
                                                            .check_circle_rounded
                                                      : Icons.circle_outlined,
                                                  size: 18,
                                                  color: selected
                                                      ? colors.primary
                                                      : colors.outline,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (selectedProviderOption ==
                                MalaysiaProviderPresets
                                    .customProviderOption) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: providerCtrl,
                                decoration: deco(
                                  'Custom Provider Name',
                                  hint: 'e.g. Crypto.com, Local Coop',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: nameCtrl,
                              decoration: deco(
                                'Account Name',
                                hint: 'e.g. Maybank Salary, Wallet Balance',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: balanceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: deco('Balance (RM)'),
                              validator: (v) {
                                final n = double.tryParse((v ?? '').trim());
                                if (n == null || n < 0) return 'Invalid amount';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'tag-$type-${normalizeEditorTag(tagCtrl.text)}',
                              ),
                              initialValue: type == 'investment'
                                  ? 'INVESTMENT'
                                  : normalizeEditorTag(tagCtrl.text),
                              decoration: deco('Allocation Tag'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'DAILY_USE',
                                  child: Text('DAILY_USE'),
                                ),
                                DropdownMenuItem(
                                  value: 'SAVINGS',
                                  child: Text('SAVINGS'),
                                ),
                                DropdownMenuItem(
                                  value: 'INVESTMENT',
                                  child: Text('INVESTMENT'),
                                ),
                              ],
                              onChanged: type == 'investment'
                                  ? null
                                  : (v) => setModal(
                                      () =>
                                          tagCtrl.text = normalizeEditorTag(v),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: accNumCtrl,
                              decoration: deco(
                                'Account Number (Optional)',
                                hint: '**** 1234',
                              ),
                            ),
                            const SizedBox(height: 6),
                            SwitchListTile(
                              value: type == 'investment' ? false : isLiquid,
                              onChanged: type == 'investment'
                                  ? null
                                  : (v) => setModal(() => isLiquid = v),
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Include in liquid assets',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            Row(
                              children: [
                                if (isEdit)
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    onPressed: () async {
                                      final asset = context
                                          .read<AssetController>();
                                      final yes = await showDialog<bool>(
                                        context: context,
                                        builder: (dCtx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: _dialogTitle(
                                            dCtx,
                                            icon: Icons.warning_amber_rounded,
                                            iconColor: Theme.of(
                                              dCtx,
                                            ).colorScheme.error,
                                            title: 'Delete account?',
                                          ),
                                          content: const Text(
                                            'This account will be removed.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dCtx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(dCtx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (yes == true && accountId != null) {
                                        await asset.deleteAccount(accountId);
                                        if (!context.mounted) return;
                                        Navigator.pop(dialogCtx, false);
                                      }
                                    },
                                  )
                                else
                                  const SizedBox(width: 48),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }
                                      Navigator.pop(dialogCtx, true);
                                    },
                                    child: const Text('Save Account'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;
    if (ok != true) return;

    final normalizedProvider =
        selectedProviderOption == MalaysiaProviderPresets.customProviderOption
        ? providerCtrl.text.trim()
        : selectedProviderOption.trim();
    final normalizedName = nameCtrl.text.trim();

    if (normalizedProvider.isEmpty || normalizedName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account name and provider are required')),
      );
      return;
    }

    selectedAutofill = MalaysiaProviderPresets.autofillFor(
      providerName: normalizedProvider,
      type: type,
    );

    final selectedTag = normalizeEditorTag(tagCtrl.text);
    final suggestedTag = selectedAutofill.tag.trim().toUpperCase();
    if (type != 'investment' && selectedTag != suggestedTag) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: _dialogTitle(
            dCtx,
            icon: Icons.info_outline_rounded,
            title: 'Confirm Allocation Tag',
          ),
          content: Text(
            '$normalizedProvider is commonly used as $suggestedTag, but this account is set to $selectedTag. Continue with current tag?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Use Suggested Tag'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Keep Current Tag'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (proceed != true) {
        tagCtrl.text = suggestedTag;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag updated to $suggestedTag based on provider'),
          ),
        );
        return;
      }
    }

    if (type == 'investment') {
      isLiquid = false;
      tagCtrl.text = 'INVESTMENT';
    } else if (!isEdit) {
      isLiquid = selectedAutofill.isLiquid;
    }

    final inputBalance = double.parse(balanceCtrl.text.trim());
    final payload = {
      AccountFields.name: normalizedName,
      AccountFields.provider: normalizedProvider,
      AccountFields.type: type,
      AccountFields.kind: type == 'investment' ? 'investment' : 'standard',
      AccountFields.accountNumber: accNumCtrl.text.trim(),
      AccountFields.tag: type == 'investment'
          ? 'INVESTMENT'
          : normalizeEditorTag(tagCtrl.text),
      AccountFields.isLiquid: type == 'investment' ? false : isLiquid,
      AccountFields.icon: selectedAutofill.iconKey,
      AccountFields.colour: selectedAutofill.colorHex,
    };

    final asset = context.read<AssetController>();

    try {
      if (isEdit && accountId != null) {
        final existingBalance = ((existing[AccountFields.balance] ?? 0) as num)
            .toDouble();
        final balanceChanged =
            (inputBalance - existingBalance).abs() > 0.000001;
        await asset.updateAccountWithPayload(
          accountId: accountId,
          payload: payload,
        );
        if (balanceChanged) {
          await asset.addAdjustmentTransaction(
            accountId: accountId,
            targetBalance: inputBalance,
            note: 'manual correction',
          );
        }
      } else {
        await asset.createAccountWithPayload(
          openingBalance: inputBalance,
          payload: payload,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Account updated' : 'Account created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }
}
