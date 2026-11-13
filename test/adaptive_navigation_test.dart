import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_pocket/core/utils/theme.dart';
import 'package:smart_pocket/presentation/widgets/navigation/bottom_nav_bar.dart';

void main() {
  Widget app(GoRouter router) => MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
      );

  GoRouter router() => GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => Scaffold(
              body: const AppAdaptiveBody(
                currentIndex: 0,
                child: Center(child: Text('Dashboard content')),
              ),
              bottomNavigationBar: AppBottomNavBar(
                currentIndex: 0,
                onTap: (index) => context.go('/accounts'),
                onAddTap: () => context.push('/add-transaction'),
              ),
            ),
          ),
          for (final path in ['accounts', 'stats', 'settings', 'add-transaction'])
            GoRoute(
              path: '/$path',
              builder: (context, state) => Scaffold(body: Text('$path page')),
            ),
        ],
      );

  testWidgets('phone navigation exposes an accessible add action', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final routes = router();
    addTearDown(routes.dispose);
    await tester.pumpWidget(app(routes));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.bySemanticsLabel('Add transaction'), findsOneWidget);
    final addButton = find.bySemanticsLabel('Add transaction');
    final top = tester.getTopLeft(addButton);
    await tester.tapAt(top + const Offset(28, 5));
    await tester.pumpAndSettle();
    expect(find.text('add-transaction page'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('desktop rail changes destination and hides bottom bar', (tester) async {
    tester.view.physicalSize = const Size(1280, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final routes = router();
    addTearDown(routes.dispose);
    await tester.pumpWidget(app(routes));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('accounts page'), findsOneWidget);
  });

  testWidgets('phone navigation remains usable with larger text', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(375, 812), textScaler: TextScaler.linear(2)),
        child: Scaffold(
          bottomNavigationBar: AppBottomNavBar(currentIndex: 0, onTap: (_) {}, onAddTap: () {}),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Accounts'), findsOneWidget);
  });
}
