import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/config_controller.dart';
import '../../../core/utils/theme.dart';

class ModePage extends StatefulWidget {
  const ModePage({super.key});

  @override
  State<ModePage> createState() => _ModePageState();
}

class _ModePageState extends State<ModePage> {
  String _selectedMode = 'lazy';
  bool _inited = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      final c = context.read<ConfigController>();
      _selectedMode = c.appMode;
      _inited = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDetailed = _selectedMode == 'detailed';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Operating Mode')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          _currentModeCard(isDetailed: isDetailed),
          const SizedBox(height: 14),

          _modeOptionCard(
            title: 'Lazy Mode',
            subtitle: 'Quick asset tracking with total balance only',
            icon: Icons.flash_on_rounded,
            selected: !isDetailed,
            badgeText: 'Recommended for quick setup',
            onTap: _saving ? null : () => _confirmAndSwitch('lazy'),
          ),
          const SizedBox(height: 10),
          _modeOptionCard(
            title: 'Detailed Mode',
            subtitle: 'Manage individual accounts and allocation',
            icon: Icons.tune_rounded,
            selected: isDetailed,
            badgeText: 'Recommended for advanced tracking',
            onTap: _saving ? null : () => _confirmAndSwitch('detailed'),
          ),

          const SizedBox(height: 14),
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSwitch(String target) async {
    if (target == _selectedMode) return;

    final targetLabel = target == 'detailed' ? 'Detailed' : 'Lazy';
    final messenger = ScaffoldMessenger.of(context);
    final c = context.read<ConfigController>();

    final yes = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Confirm mode switch'),
        content: Text('Switch to $targetLabel Mode?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    setState(() {
      _selectedMode = target;
      _saving = true;
    });

    final ok = await c.switchMode(target);

    if (!mounted) return;

    setState(() => _saving = false);

    if (!ok) {
      setState(() => _selectedMode = c.appMode);
      messenger.showSnackBar(
        SnackBar(content: Text(c.errorMessage ?? 'Failed to switch mode')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('Switched to $targetLabel Mode')),
    );

    if (target == 'detailed') {
      await showDialog<void>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Shortcut Account Reconfirm Required'),
          content: const Text(
            'Shortcuts are now back in Detailed Mode. Please review each shortcut default account to ensure it points to the correct real account.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _currentModeCard({required bool isDetailed}) {
    final appColors = Theme.of(context).extension<AppThemeColors>()!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [appColors.authGradientStart, appColors.authGradientEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, color: appColors.authAccentForeground),
          const SizedBox(width: 8),
          Text(
            'Current: ${isDetailed ? 'Detailed' : 'Lazy'} Mode',
            style: TextStyle(
              color: appColors.authAccentForeground,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required String badgeText,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final iconBg = selected
        ? (isDark
              ? Color.alphaBlend(
                  colors.primary.withValues(alpha: 0.28),
                  colors.surfaceContainerHigh,
                )
              : Color.alphaBlend(
                  colors.primary.withValues(alpha: 0.14),
                  colors.surface,
                ))
        : (isDark
              ? colors.surfaceContainerHigh
              : colors.surfaceContainerHighest);
    final iconFg = selected
        ? (isDark ? colors.onPrimaryContainer : colors.primary)
        : colors.onSurfaceVariant;
    final iconBorder = selected
        ? colors.primary.withValues(alpha: isDark ? 0.75 : 0.45)
        : colors.outlineVariant.withValues(alpha: isDark ? 0.65 : 1);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: iconBorder),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(
                                alpha: isDark ? 0.22 : 0.12,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(icon, size: 18, color: iconFg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDark ? colors.primaryContainer : colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: isDark
                          ? colors.onPrimaryContainer
                          : colors.onPrimary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
