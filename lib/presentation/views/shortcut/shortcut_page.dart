import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/category_controller.dart';
import '../../../application/controllers/config_controller.dart';
import '../../../application/controllers/shortcut_controller.dart';
import '../../../application/controllers/transaction_controller.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/category_icon_mapper.dart';
import '../../../core/models/shortcut_model.dart';
import '../../widgets/common/provider_avatar.dart';
import '../../widgets/dialogs/confirm_dialog.dart';

class ShortcutsPage extends StatefulWidget {
  const ShortcutsPage({super.key});

  @override
  State<ShortcutsPage> createState() => _ShortcutsPageState();
}

class _ShortcutsPageState extends State<ShortcutsPage> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  String _type = 'expense';
  bool _useDefaultAccount = true;
  String? _defaultAccountIdForShortcut;
  String? _categoryId;
  ShortcutModel? _editing;

  String? _defaultAccountId(List<Map<String, dynamic>> accounts) {
    for (final a in accounts) {
      if (a['is_primary'] == true) {
        final id = (a['_id'] ?? a['id'] ?? '').toString().trim();
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  String _poolAccountIdByTag(String tag) {
    switch (tag.trim().toLowerCase()) {
      case 'savings':
        return 'virtual_savings_pool';
      case 'investment':
        return 'virtual_investment_pool';
      case 'daily_use':
      default:
        return 'virtual_daily_use_wallet';
    }
  }

  String _poolTagByAccountId(List<Map<String, dynamic>> accounts, String? accountId) {
    final id = (accountId ?? '').trim();
    if (id.isEmpty) return 'daily_use';
    if (id == 'virtual_savings_pool') return 'savings';
    if (id == 'virtual_investment_pool') return 'investment';
    if (id == 'virtual_daily_use_wallet') return 'daily_use';
    for (final a in accounts) {
      final aid = (a['_id'] ?? a['id'] ?? '').toString().trim();
      if (aid != id) continue;
      final tag = (a[AccountFields.tag] ?? '').toString().trim().toLowerCase();
      if (tag == 'savings' || tag == 'investment' || tag == 'daily_use') {
        return tag;
      }
    }
    return 'daily_use';
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

  String? _tagByAccountId(List<Map<String, dynamic>> accounts, String? accountId) {
    final id = (accountId ?? '').trim();
    if (id.isEmpty) return null;
    for (final a in accounts) {
      final aid = (a['_id'] ?? a['id'] ?? '').toString().trim();
      if (aid != id) continue;
      final tag = (a[AccountFields.tag] ?? '').toString().trim().toLowerCase();
      if (tag == 'daily_use' || tag == 'savings' || tag == 'investment') return tag;
      return null;
    }
    return null;
  }

  Widget _accountAvatar(Map<String, dynamic> account, {double size = 30}) {
    final type = (account[AccountFields.type] ?? '').toString().toLowerCase();
    final provider =
        (account[AccountFields.provider] ??
                account[AccountFields.name] ??
                'Account')
            .toString();
    return ProviderAvatar.providerAvatar(
      context,
      provider,
      type: type.isEmpty ? 'cash' : type,
      size: size < 34 ? 34 : size,
    );
  }

  Widget _accountMenuItem(
    Map<String, dynamic> account, {
    double avatarSize = 30,
    bool showBalance = false,
  }) {
    final name = (account[AccountFields.name] ?? 'Account').toString();
    final bal = ((account[AccountFields.balance] ?? 0) as num).toDouble();
    final label = showBalance ? '$name (RM ${bal.toStringAsFixed(2)})' : name;

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        _accountAvatar(account, size: avatarSize),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String? _validDefaultAccountForEdit(
    ShortcutModel shortcut,
    List<Map<String, dynamic>> accounts,
    bool isLazyMode,
  ) {
    if (!shortcut.useDefaultAccount) return null;

    if (isLazyMode) {
      final lazyTag = shortcut.defaultPoolTag ??
          _poolTagByAccountId(
            accounts,
            shortcut.defaultAccountId ?? shortcut.detailedDefaultAccountId,
          );
      return _poolAccountIdByTag(lazyTag);
    }

    final candidate = (shortcut.detailedDefaultAccountId ?? shortcut.defaultAccountId)
        ?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      final isVirtualPool = candidate == 'virtual_daily_use_wallet' ||
          candidate == 'virtual_savings_pool' ||
          candidate == 'virtual_investment_pool';
      if (!isVirtualPool) {
        final exists = accounts.any(
          (a) => (a['_id'] ?? a['id']).toString().trim() == candidate,
        );
        if (exists) return candidate;
      }
    }

    return _defaultAccountId(accounts);
  }

  void _beginEditShortcut(
    ShortcutModel shortcut,
    bool isLazyMode,
    List<Map<String, dynamic>> accounts,
  ) {
    setState(() {
      _editing = shortcut;
      _label.text = shortcut.label;
      _amount.text = shortcut.amount.toStringAsFixed(2);
      _type = shortcut.type;
      _useDefaultAccount = shortcut.useDefaultAccount;
      _defaultAccountIdForShortcut = _validDefaultAccountForEdit(
        shortcut,
        accounts,
        isLazyMode,
      );
      _categoryId = shortcut.categoryId;
    });
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLazyMode = context.watch<ConfigController>().appMode == 'lazy';
    final shortcut = context.watch<ShortcutController>();
    final category = context.watch<CategoryController>();
    final tx = context.watch<TransactionController>();
    final accounts = tx.accounts.map((e) => Map<String, dynamic>.from(e)).toList(growable: false);

    final cats = category.categories.where((e) => e.type == _type).toList();
    if (_categoryId == null && cats.isNotEmpty) _categoryId = cats.first.id;

    IconData iconForCategoryId(String? id) {
      final c = category.categories.where((e) => e.id == id).toList();
      if (c.isEmpty) return Icons.category_rounded;
      return CategoryIconMapper.icon(c.first.icon);
    }

    Color colorForCategoryId(String? id) {
      final c = category.categories.where((e) => e.id == id).toList();
      if (c.isEmpty) return Theme.of(context).colorScheme.onSurfaceVariant;
      return CategoryIconMapper.color(c.first.icon);
    }

    String categoryNameById(String? id) {
      final c = category.categories.where((e) => e.id == id).toList();
      if (c.isEmpty) return 'Unknown Category';
      return c.first.name;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Shortcuts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _label,
                    decoration: const InputDecoration(labelText: 'Label'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'expense', child: Text('Expense')),
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _type = v;
                        _categoryId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: cats.map((c) {
                      final icon = CategoryIconMapper.icon(c.icon);
                      final color = CategoryIconMapper.color(c.icon);
                      return DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: color),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Icon follows selected category',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use Default Account'),
                    subtitle: Text(
                      'If off, select source account each time in detailed mode.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: _useDefaultAccount,
                    onChanged: (v) => setState(() => _useDefaultAccount = v),
                  ),
                  if (_useDefaultAccount) ...[
                    if (!isLazyMode)
                      DropdownButtonFormField<String>(
                        initialValue: _defaultAccountIdForShortcut,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Default Account'),
                        items: accounts
                            .map(
                              (a) => DropdownMenuItem<String>(
                                value: (a['_id'] ?? a['id']).toString(),
                                child: _accountMenuItem(a),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _defaultAccountIdForShortcut = v),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _poolTagByAccountId(accounts, _defaultAccountIdForShortcut),
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Default Pool'),
                        items: const [
                          DropdownMenuItem(value: 'daily_use', child: Text('Daily Use Pool')),
                          DropdownMenuItem(value: 'savings', child: Text('Savings Pool')),
                          DropdownMenuItem(value: 'investment', child: Text('Investment Pool')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _defaultAccountIdForShortcut = _poolAccountIdByTag(v));
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (isLazyMode &&
                          _useDefaultAccount &&
                          (_defaultAccountIdForShortcut ?? '').trim().isEmpty) {
                        _defaultAccountIdForShortcut = _poolAccountIdByTag('daily_use');
                      }
                      if (_categoryId == null) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Please select category')),
                        );
                        return;
                      }
                      if (_useDefaultAccount &&
                          (_defaultAccountIdForShortcut ?? '').trim().isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Please select default account')),
                        );
                        return;
                      }

                      final wasEditing = _editing != null;
                      if (!wasEditing) {
                        await shortcut.addShortcut(
                          label: _label.text.trim(),
                          categoryId: _categoryId!,
                          amountText: _amount.text.trim(),
                          type: _type,
                          useDefaultAccount: _useDefaultAccount,
                          defaultAccountId: _useDefaultAccount ? _defaultAccountIdForShortcut : null,
                        );
                      } else {
                        await shortcut.updateShortcut(
                          id: _editing!.id,
                          label: _label.text.trim(),
                          categoryId: _categoryId!,
                          amountText: _amount.text.trim(),
                          type: _type,
                          useDefaultAccount: _useDefaultAccount,
                          defaultAccountId: _useDefaultAccount ? _defaultAccountIdForShortcut : null,
                        );
                      }

                      if (!mounted) return;
                      if (shortcut.errorMessage != null) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(shortcut.errorMessage!)),
                        );
                        return;
                      }

                      _clearForm();
                      messenger.showSnackBar(
                        SnackBar(content: Text(wasEditing ? 'Shortcut updated' : 'Shortcut added')),
                      );
                    },
                    child: Text(_editing == null ? 'Save Shortcut' : 'Update Shortcut'),
                  ),
                  if (_editing != null)
                    TextButton(
                      onPressed: _clearForm,
                      child: const Text('Cancel edit'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (shortcut.shortcuts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No shortcuts yet'),
              ),
            )
          else
            ...shortcut.shortcuts.map(
              (s) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorForCategoryId(s.categoryId).withValues(alpha: 0.16),
                    child: Icon(iconForCategoryId(s.categoryId), color: colorForCategoryId(s.categoryId)),
                  ),
                  title: Text(s.label),
                  subtitle: Text(
                    '${s.type.toUpperCase()} | ${categoryNameById(s.categoryId)} | RM ${s.amount.toStringAsFixed(2)} | ${s.useDefaultAccount ? 'Default account' : 'Manual account select'}${s.requireDetailedReconfirm ? ' | Needs reconfirmation' : ''}',
                  ),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    String? accountId;
                    String? lazyCategoryTag;
                    if (!isLazyMode) {
                      if (s.useDefaultAccount) {
                        if (s.requireDetailedReconfirm) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please confirm this shortcut default account after switching back to Detailed Mode.',
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
                        accountId = await _pickAccountId(context, tx.accounts);
                        if (accountId == null) return;
                      }
                    } else {
                      if (s.useDefaultAccount) {
                        final defaultId = (s.defaultAccountId ?? '').trim().isEmpty
                            ? _defaultAccountId(tx.accounts)
                            : s.defaultAccountId;
                        lazyCategoryTag = _tagByAccountId(tx.accounts, defaultId);
                        if (lazyCategoryTag == null) {
                          final hasDailyUseDefault = _hasPrimaryInTag(
                            tx.accounts,
                            LazyModeConfig.expensePrimaryCategory,
                          );
                          if (hasDailyUseDefault) {
                            lazyCategoryTag = LazyModeConfig.expensePrimaryCategory;
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
                      isLazyMode: isLazyMode,
                      accountId: accountId,
                      lazyCategoryTag: lazyCategoryTag,
                    );
                    if (!mounted) return;
                    if (!result.success) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(result.errorMessage ?? 'Failed')),
                      );
                      return;
                    }
                    final splitText = result.splitDetails.entries
                        .map((entry) {
                          final account = tx.accounts.cast<Map<String, dynamic>>().firstWhere(
                                (a) => (a['_id'] ?? a['id']).toString() == entry.key,
                                orElse: () => {'name': entry.key},
                              );
                          final accountName = (account['name'] ?? entry.key).toString();
                          return '$accountName RM${entry.value.toStringAsFixed(2)}';
                        })
                        .join(' / ');
                    final actionText = result.type == 'income' ? 'added' : 'deducted';
                    final fallbackText = result.fallbackWarnings.isEmpty
                        ? ''
                        : ' | ${result.fallbackWarnings.join(' | ')}';
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Shortcut success: RM${result.amount.toStringAsFixed(2)} $actionText. $splitText$fallbackText',
                        ),
                      ),
                    );
                  },
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _beginEditShortcut(s, isLazyMode, accounts),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final confirmed = await showConfirmDialog(
                            context,
                            'Delete Shortcut',
                            'Delete "${s.label}"? This action cannot be undone.',
                          );
                          if (confirmed != true) return;

                          await shortcut.deleteShortcut(s.id);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text('Shortcut "${s.label}" deleted')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _editing = null;
      _label.clear();
      _amount.clear();
      _type = 'expense';
      _useDefaultAccount = true;
      _defaultAccountIdForShortcut = null;
      _categoryId = null;
    });
  }

  Future<String?> _pickLazyTag(BuildContext context) {
    String selected = LazyModeConfig.expensePrimaryCategory;
    return showDialog<String>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setState) => AlertDialog(
          title: const Text('Select Source Bucket'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose bucket for this shortcut run.'),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selected = v);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        value: LazyModeConfig.expensePrimaryCategory,
                        title: const Text('Daily Use'),
                        subtitle: const Text('Use daily spending bucket'),
                      ),
                      RadioListTile<String>(
                        value: LazyModeConfig.savingsCategory,
                        title: const Text('Savings'),
                        subtitle: const Text('Use savings pool'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(dCtx, selected), child: const Text('Use')),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickAccountId(BuildContext context, List<Map<String, dynamic>> accounts) {
    final messenger = ScaffoldMessenger.of(context);
    if (accounts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No account found')),
      );
      return Future.value(null);
    }

    String selected = (accounts.first['_id'] ?? accounts.first['id']).toString();

    return showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Select Account'),
        content: StatefulBuilder(
          builder: (_, setD) => SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: selected,
              items: accounts.map((a) {
                final id = (a['_id'] ?? a['id']).toString();
                return DropdownMenuItem(
                  value: id,
                  child: _accountMenuItem(a, showBalance: true),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setD(() => selected = v);
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, selected), child: const Text('Use')),
        ],
      ),
    );
  }
}
