import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

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
                icon: Icon(CupertinoIcons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(CupertinoIcons.creditcard),
                label: Text('Accounts'),
              ),
              NavigationRailDestination(
                icon: Icon(CupertinoIcons.chart_bar),
                label: Text('Stats'),
              ),
              NavigationRailDestination(
                icon: Icon(CupertinoIcons.gear),
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
    Widget item(int index, IconData icon, String label) {
      final active = currentIndex == index;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          excludeSemantics: true,
          onTap: () => onTap(index),
          label: label,
          child: InkWell(
            onTap: () => onTap(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: active ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      color: active ? colors.primary : colors.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .5),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: .12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            item(0, CupertinoIcons.home, 'Home'),
            item(1, CupertinoIcons.creditcard, 'Accounts'),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Add transaction',
                excludeSemantics: true,
                onTap: onAddTap,
                child: InkWell(
                  onTap: onAddTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.add,
                            size: 20,
                            color: colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            item(2, CupertinoIcons.chart_bar, 'Stats'),
            item(3, CupertinoIcons.gear, 'Settings'),
          ],
        ),
      ),
    );
  }
}
