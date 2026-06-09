import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/controllers/category_controller.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final _name = TextEditingController();
  String _icon = 'tag';
  String _type = 'expense';
  String? _editingId;

  static const List<String> _iconKeys = [
    'tag',
    'category',
    'star',
    'favorite',
    'bookmark',
    'food',
    'coffee',
    'fastfood',
    'cake',
    'drink',
    'transport',
    'car',
    'bus',
    'train',
    'taxi',
    'flight',
    'shopping',
    'shopping_bag',
    'cart',
    'receipt_long',
    'bill',
    'home',
    'health',
    'education',
    'gift',
    'game',
    'phone',
    'salary',
    'payments',
    'wallet',
    'business',
    'trending_up',
    'work',
    'electric',
    'water',
    'wifi',
    'insurance',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CategoryController>().ensureDefaultCategories();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _resetForm() {
    _editingId = null;
    _name.clear();
    _icon = 'tag';
    _type = 'expense';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CategoryController>();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Manage Categories')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                'Category icon will be used by shortcuts automatically.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      items: const [
                        DropdownMenuItem(
                          value: 'expense',
                          child: Text('Expense'),
                        ),
                        DropdownMenuItem(
                          value: 'income',
                          child: Text('Income'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? 'expense'),
                      decoration: const InputDecoration(labelText: 'Type'),
                    ),
                    const SizedBox(height: 10),
                    _iconPickerTile(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final name = _name.text.trim();
                              if (name.isEmpty) return;

                              if (_editingId == null) {
                                await c.addCategory(
                                  name: name,
                                  type: _type,
                                  icon: _icon,
                                );
                              } else {
                                await c.editCategory(
                                  id: _editingId!,
                                  name: name,
                                  type: _type,
                                  icon: _icon,
                                );
                              }

                              if (!mounted) return;
                              _resetForm();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Category updated'),
                                ),
                              );
                            },
                            child: Text(
                              _editingId == null
                                  ? 'Add Category'
                                  : 'Save Changes',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _resetForm,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: c.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: c.categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final cat = c.categories[i];
                        final iconKey = (cat.icon == null || cat.icon!.isEmpty)
                            ? 'tag'
                            : cat.icon!;
                        final iconData = _iconData(iconKey);
                        final iconColor = _iconColor(iconKey);

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: iconColor.withValues(
                                alpha: 0.16,
                              ),
                              child: Icon(iconData, color: iconColor),
                            ),
                            title: Text(cat.name),
                            subtitle: Text(
                              '${cat.type.toUpperCase()} • $iconKey',
                            ),
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () {
                                    _editingId = cat.id;
                                    _name.text = cat.name;
                                    _icon =
                                        (cat.icon == null || cat.icon!.isEmpty)
                                        ? 'tag'
                                        : cat.icon!;
                                    _type = cat.type;
                                    setState(() {});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _onDeleteCategory(cat.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconPickerTile() {
    final colors = Theme.of(context).colorScheme;
    final iconData = _iconData(_icon);
    final iconColor = _iconColor(_icon);

    return InkWell(
      onTap: _pickIconSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          color: colors.surface,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: iconColor.withValues(alpha: 0.16),
              child: Icon(iconData, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Icon: $_icon',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _pickIconSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.72;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose Category Icon',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      itemCount: _iconKeys.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                      itemBuilder: (_, i) {
                        final key = _iconKeys[i];
                        final selected = key == _icon;
                        final color = _iconColor(key);

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(ctx, key),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.16)
                                  : colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? color : colors.outlineVariant,
                                width: selected ? 1.4 : 1,
                              ),
                            ),
                            child: Icon(_iconData(key), color: color),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    setState(() => _icon = picked);
  }

  IconData _iconData(String key) {
    switch (key) {
      case 'tag':
        return Icons.sell_rounded;
      case 'category':
        return Icons.category_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'bookmark':
        return Icons.bookmark_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'coffee':
        return Icons.local_cafe_rounded;
      case 'fastfood':
        return Icons.fastfood_rounded;
      case 'cake':
        return Icons.cake_rounded;
      case 'drink':
        return Icons.local_bar_rounded;
      case 'transport':
      case 'car':
        return Icons.directions_car_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'train':
        return Icons.train_rounded;
      case 'taxi':
        return Icons.local_taxi_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'shopping':
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'cart':
        return Icons.shopping_cart_rounded;
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'bill':
        return Icons.request_page_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'health':
        return Icons.local_hospital_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'game':
        return Icons.sports_esports_rounded;
      case 'phone':
        return Icons.phone_android_rounded;
      case 'salary':
      case 'payments':
        return Icons.payments_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'electric':
        return Icons.electric_bolt_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'insurance':
        return Icons.health_and_safety_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _iconColor(String key) {
    switch (key) {
      case 'food':
      case 'fastfood':
      case 'cake':
      case 'coffee':
      case 'drink':
        return const Color(0xFFEA580C);
      case 'transport':
      case 'car':
      case 'bus':
      case 'train':
      case 'taxi':
      case 'flight':
        return const Color(0xFF2563EB);
      case 'shopping':
      case 'shopping_bag':
      case 'cart':
        return const Color(0xFF7C3AED);
      case 'receipt_long':
      case 'bill':
      case 'electric':
      case 'water':
      case 'wifi':
      case 'insurance':
        return const Color(0xFF4F46E5);
      case 'salary':
      case 'payments':
      case 'wallet':
      case 'business':
      case 'trending_up':
      case 'work':
        return const Color(0xFF16A34A);
      case 'health':
        return const Color(0xFFDC2626);
      case 'education':
      case 'phone':
        return const Color(0xFF0EA5E9);
      case 'home':
      case 'tag':
      case 'category':
        return const Color(0xFF64748B);
      case 'gift':
      case 'game':
      case 'favorite':
      case 'star':
      case 'bookmark':
        return const Color(0xFFDB2777);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Future<void> _onDeleteCategory(String categoryId) async {
    final c = context.read<CategoryController>();
    final categories = c.categories.where((e) => e.id != categoryId).toList();

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        String? reassignTo = categories.isNotEmpty ? categories.first.id : null;

        return StatefulBuilder(
          builder: (_, setS) => Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 10,
              children: [
                const Text(
                  'Delete Category',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const Text(
                  'Choose how to handle transactions under this category.',
                ),
                if (categories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: reassignTo,
                    items: categories
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text('Reassign to: ${e.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => reassignTo = v),
                  ),
                FilledButton(
                  onPressed: categories.isEmpty || reassignTo == null
                      ? null
                      : () => Navigator.pop(ctx, 'reassign:$reassignTo'),
                  child: const Text('Reassign and Delete Category'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'delete_all'),
                  child: const Text('Delete Category + Transactions'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    try {
      if (action.startsWith('reassign:')) {
        final to = action.replaceFirst('reassign:', '');
        await c.deleteCategoryAndReassign(
          categoryId: categoryId,
          toCategoryId: to,
        );
      } else if (action == 'delete_all') {
        await c.deleteCategoryAndDeleteTransactions(categoryId: categoryId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category removed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }
}
