import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_pocket/application/controllers/asset_controller.dart';
import 'package:smart_pocket/core/utils/theme.dart';
import 'package:smart_pocket/presentation/views/account/accounts_page.dart';

class _FakeAssets extends ChangeNotifier implements AssetController {
  _FakeAssets(this.balance);
  final double balance;

  @override
  String? get uid => 'test-user';

  @override
  Stream<Map<String, dynamic>> watchUserData() => Stream.value({
    'settings': {
      'app_mode': 'lazy',
      'app_mode_origin': 'detailed',
      'allocation_goal': {
        'targets': {'savings': 40, 'investment': 35, 'daily_use': 25},
      },
    },
  });

  @override
  Stream<List<Map<String, dynamic>>> watchAccounts() => Stream.value([
    {
      'docId': 'one',
      'name': 'Savings',
      'balance': balance,
      'tag': 'SAVINGS',
      'is_liquid': true,
    },
  ]);

  @override
  Future<void> syncAssetProfile({
    required String mode,
    required double totalAsset,
    bool includeCreatedAt = false,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'zero balance shows targets without deviations (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final assets = _FakeAssets(0);
        addTearDown(assets.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AssetController>.value(
            value: assets,
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: const AccountPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('RM 0.00'), findsWidgets);
        expect(find.text('40% target'), findsOneWidget);
        expect(find.text('35% target'), findsOneWidget);
        expect(find.text('25% target'), findsOneWidget);
        expect(find.text('Allocation deviation'), findsNothing);
        expect(
          find.textContaining('Actual allocation will appear'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('positive balance still shows actual allocation and deviations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final assets = _FakeAssets(100);
    addTearDown(assets.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AssetController>.value(
        value: assets,
        child: MaterialApp(theme: AppTheme.light(), home: const AccountPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('100% / 40%'), findsOneWidget);
    expect(find.text('Allocation deviation'), findsOneWidget);
    expect(find.textContaining('Actual allocation will appear'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final balance in [0.0, 100.0]) {
    testWidgets('assets screen reflows with larger text and balance $balance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final assets = _FakeAssets(balance);
      addTearDown(assets.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AssetController>.value(
          value: assets,
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const AccountPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
