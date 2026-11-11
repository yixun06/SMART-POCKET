import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/theme.dart';

const double _desktopBreakpoint = 1024;

class AppAdaptiveBody extends StatelessWidget {
  final int currentIndex;
  final Widget child;

  const AppAdaptiveBody({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < _desktopBreakpoint) return child;
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        SafeArea(
          child: NavigationRail(
            selectedIndex: currentIndex,
            scrollable: true,
            labelType: NavigationRailLabelType.all,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: FloatingActionButton.small(
                heroTag: 'desktop-add-transaction',
                onPressed: () => context.push('/add-transaction'),
                tooltip: 'Add transaction',
                child: const Icon(Icons.add),
              ),
            ),
            onDestinationSelected: (index) => context.go(
              ['/dashboard', '/accounts', '/stats', '/settings'][index],
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_rounded),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: Text('Accounts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.pie_chart_outline_rounded),
                label: Text('Stats'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_rounded),
                label: Text('Settings'),
              ),
            ],
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

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
    if (MediaQuery.sizeOf(context).width >= _desktopBreakpoint) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppThemeColors>()!;
    final scaler = MediaQuery.textScalerOf(context);
    final itemHeight = math.max(56.0, scaler.scale(20) + 4 + scaler.scale(32));
    final barHeight = math.max(74.0, itemHeight + 18);
    Color itemColor(int i) =>
        currentIndex == i ? colors.primary : colors.onSurfaceVariant;

    Widget navItem(int i, IconData icon, String label) {
      return Expanded(
        child: Semantics(
          selected: currentIndex == i,
          child: InkWell(
            onTap: () => onTap(i),
            child: SizedBox(
              height: itemHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: itemColor(i)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: itemColor(i),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        height: barHeight,
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
                    navItem(
                      1,
                      Icons.account_balance_wallet_rounded,
                      'Accounts',
                    ),
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
                child: Semantics(
                  button: true,
                  label: 'Add transaction',
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
            ),
          ],
        ),
      ),
    );
  }
}
