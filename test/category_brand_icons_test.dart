import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pocket/core/utils/category_icon_mapper.dart';
import 'package:smart_pocket/core/utils/malaysia_provider_presets.dart';

void main() {
  testWidgets('brand assets load within the requested icon size', (tester) async {
    for (final key in CategoryIconMapper.brandKeys) {
      await tester.pumpWidget(MaterialApp(home: Center(child: CategoryIconMapper.display(key, fallback: Icons.category, color: Colors.black, size: 24))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: key);
      expect(tester.getSize(find.byType(Image)), const Size(24, 24));
    }
  });
  testWidgets('existing category icons remain Material icons', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CategoryIconMapper.display('food', fallback: Icons.restaurant, color: Colors.black)));
    expect(find.byIcon(Icons.restaurant), findsOneWidget);
  });
  testWidgets('telecom providers appear as e-wallets with loadable logos', (tester) async {
    for (final name in ['Hotlink', 'XOX']) {
      final preset = MalaysiaProviderPresets.findByName(name, type: 'ewallet');
      expect(preset, isNotNull);
      await tester.pumpWidget(MaterialApp(home: Image.asset(preset!.logoAsset!)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      expect(preset.defaultTag, 'DAILY_USE');
    }
  });
}
