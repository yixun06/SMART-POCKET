import 'package:flutter/material.dart';

import '../../../core/utils/theme.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppThemeColors>()!;
    Color itemColor(int i) =>
        currentIndex == i ? colors.primary : colors.onSurfaceVariant;

    Widget navItem(int i, IconData icon, String label) {
      return Expanded(
        child: InkWell(
          onTap: () => onTap(i),
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: itemColor(i)),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: itemColor(i), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 74,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: appColors.navBarBackground,
                  border: Border(
                    top: BorderSide(color: appColors.navBarBorder),
                  ),
                ),
                child: Row(
                  children: [
                    navItem(0, Icons.home_rounded, 'Home'),
                    navItem(1, Icons.account_balance_wallet_rounded, 'Accounts'),
                    const SizedBox(width: 72),
                    navItem(2, Icons.pie_chart_outline_rounded, 'Stats'),
                    navItem(3, Icons.settings_rounded, 'Settings'),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -14,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAddTap,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: appColors.navFabBackground,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      color: appColors.navFabForeground,
                      size: 30,
                    ),
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
