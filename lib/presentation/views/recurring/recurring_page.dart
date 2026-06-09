import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/category_controller.dart';
import '../../../application/controllers/recurring_controller.dart';
import '../../../application/controllers/transaction_controller.dart';
import '../../../core/utils/category_icon_mapper.dart';
import '../../../core/utils/theme.dart';
import '../../../core/models/recurring_plan_model.dart';
import '../../widgets/common/provider_avatar.dart';

class RecurringPage extends StatefulWidget {
  const RecurringPage({super.key});

  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage> {
  bool _bound = false;
  StreamSubscription<List<Map<String, dynamic>>>? _failureSub;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bound) return;
    _bound = true;

    final rc = context.read<RecurringController>();
    rc.bind();
    _failureSub = rc.watchFailureNotifications().listen((rows) async {
      if (!mounted || rows.isEmpty) return;
      final latest = rows.first;
      final title = (latest['title'] ?? 'Auto-Deduction Failed').toString();
      final body = (latest['body'] ?? 'Recurring transaction failed.')
          .toString();
      final id = (latest['id'] ?? '').toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title\n$body'),
          duration: const Duration(seconds: 4),
        ),
      );

      await rc.markFailureNotificationRead(id);
    });
  }

  @override
  void dispose() {
    _failureSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.watch<RecurringController>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.extension<AppThemeColors>()!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
        actions: [
          IconButton(
            onPressed: () async {
              final result = await rc.runTodayCatchUpWithSummary();
              if (!context.mounted) return;

              final s = result['success'] ?? 0;
              final f = result['failed'] ?? 0;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    f > 0
                        ? 'Catch-up done: $s success, $f failed (insufficient balance / invalid account)'
                        : 'Catch-up done: $s success',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_outline_rounded),
            tooltip: 'Run missed schedules',
          ),
        ],
      ),
      body: rc.isLoading
          ? const Center(child: CircularProgressIndicator())
          : rc.plans.isEmpty
          ? const Center(child: Text('No recurring transactions yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rc.plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = rc.plans[i];
                final isIncome = p.type == 'income';
                final isTransfer = p.type == 'transfer';

                final icon = isTransfer
                    ? Icons.swap_horiz_rounded
                    : CategoryIconMapper.icon(p.categoryId);
                final color = isTransfer
                    ? colors.secondary
                    : CategoryIconMapper.color(p.categoryId);
                final completed = !p.active && p.nextRunAt.isAfter(p.endDate);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: color.withValues(alpha: 0.14),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: colors.onSurface,
                                  ),
                                ),
                                Text(
                                  p.type.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            isTransfer
                                ? 'RM ${p.amount.toStringAsFixed(2)}'
                                : '${isIncome ? '+' : '-'} RM ${p.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isTransfer
                                  ? colors.secondary
                                  : (isIncome
                                        ? appColors.positiveAmount
                                        : appColors.negativeAmount),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) =>
                                      _RecurringFormSheet(editing: p),
                                );
                              } else if (v == 'toggle') {
                                await rc.toggleActive(p.id, !p.active);
                              } else if (v == 'delete') {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('Delete recurring item?'),
                                    content: const Text(
                                      'This action cannot be undone.',
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
                                if (yes == true) await rc.deletePlan(p.id);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(p.active ? 'Disable' : 'Enable'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Every ${p.intervalDays} day(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            completed
                                ? 'Completed'
                                : 'Next: ${DateFormat('yyyy-MM-dd').format(p.nextRunAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: completed
                                  ? colors.tertiary
                                  : colors.onSurfaceVariant,
                              fontWeight: completed
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: OutlinedButton.icon(
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _RecurringFormSheet(),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Recurring Transaction'),
        ),
      ),
    );
  }
}

class _RecurringFormSheet extends StatefulWidget {
  final RecurringPlanModel? editing;
  const _RecurringFormSheet({this.editing});

  @override
  State<_RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends State<_RecurringFormSheet> {
  late final TextEditingController _label;
  late final TextEditingController _amount;
  late final TextEditingController _interval;
  late final TextEditingController _note;

  String _type = 'expense';
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 180));

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _label = TextEditingController(text: e?.label ?? '');
    _amount = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(2),
    );
    _interval = TextEditingController(text: (e?.intervalDays ?? 1).toString());
    _note = TextEditingController(text: e?.note ?? '');

    if (e != null) {
      _type = e.type;
      _accountId = e.accountId;
      _toAccountId = e.toAccountId;
      _categoryId = e.categoryId;
      _start = e.startDate;
      _end = e.endDate;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _interval.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tx = context.watch<TransactionController>();
    final cat = context.watch<CategoryController>();
    final rc = context.read<RecurringController>();

    final accounts = tx.accounts;
    final cats = cat.categories.where((c) => c.type == _type).toList();
    final isTransfer = _type == 'transfer';

    final accountIds = accounts
        .map((a) => (a['_id'] ?? a['id']).toString())
        .toList();
    if (_accountId == null || !accountIds.contains(_accountId)) {
      _accountId = accountIds.isNotEmpty ? accountIds.first : null;
    }

    if (isTransfer) {
      if (_toAccountId == null ||
          !accountIds.contains(_toAccountId) ||
          _toAccountId == _accountId) {
        _toAccountId = accountIds.firstWhere(
          (id) => id != _accountId,
          orElse: () => '',
        );
        if (_toAccountId == '') _toAccountId = null;
      }
    } else {
      _toAccountId = null;
    }

    final catIds = cats.map((c) => c.id).toList();
    if (!isTransfer) {
      if (_categoryId == null || !catIds.contains(_categoryId)) {
        _categoryId = catIds.isNotEmpty ? catIds.first : null;
      }
    } else {
      _categoryId = null;
    }

    final canSave = _canSave(
      isTransfer: isTransfer,
      accountId: _accountId,
      toAccountId: _toAccountId,
      categoryId: _categoryId,
      amountText: _amount.text,
      intervalText: _interval.text,
      start: _start,
      end: _end,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.editing == null ? 'Add Recurring' : 'Edit Recurring',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),

                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                    ButtonSegment(value: 'transfer', label: Text('Transfer')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: _label,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount'),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(
                    labelText: 'Source Account',
                  ),
                  items: accounts.map((a) {
                    final id = (a['_id'] ?? a['id']).toString();
                    final name = (a['name']?.toString() ?? 'Account');
                    final provider = (a['provider'] ?? a['name'] ?? '')
                        .toString();
                    final type = (a['type'] ?? 'cash').toString().toLowerCase();

                    return DropdownMenuItem<String>(
                      value: id,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: ProviderAvatar.providerAvatar(
                              context,
                              provider,
                              type: type,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(name, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _accountId = v),
                ),

                if (isTransfer) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _toAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Destination Account',
                    ),
                    items: accounts.map((a) {
                      final id = (a['_id'] ?? a['id']).toString();
                      final name = (a['name']?.toString() ?? 'Account');
                      final provider = (a['provider'] ?? a['name'] ?? '')
                          .toString();
                      final type = (a['type'] ?? 'cash')
                          .toString()
                          .toLowerCase();

                      return DropdownMenuItem<String>(
                        value: id,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: ProviderAvatar.providerAvatar(
                                context,
                                provider,
                                type: type,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(name, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _toAccountId = v),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: cats.map((c) {
                      final iconKey = (c.icon ?? '').trim().isEmpty
                          ? c.id
                          : c.icon!;
                      final iconData = CategoryIconMapper.icon(iconKey);
                      final color = CategoryIconMapper.color(iconKey);

                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: color.withValues(alpha: 0.14),
                              child: Icon(iconData, size: 14, color: color),
                            ),
                            const SizedBox(width: 8),
                            Text(c.name, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ],

                const SizedBox(height: 8),

                TextField(
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Every N days'),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: _start,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (p != null) setState(() => _start = p);
                        },
                        child: Text(
                          'Start: ${DateFormat('yyyy-MM-dd').format(_start)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: _end,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (p != null) setState(() => _end = p);
                        },
                        child: Text(
                          'End: ${DateFormat('yyyy-MM-dd').format(_end)}',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_saving || !canSave)
                        ? null
                        : () async {
                            final interval =
                                int.tryParse(_interval.text.trim()) ?? 0;
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            final recurringController = context
                                .read<RecurringController>();

                            setState(() => _saving = true);

                            bool ok;
                            if (widget.editing == null) {
                              ok = await rc.createPlan(
                                type: _type,
                                label: _label.text.trim(),
                                amountText: _amount.text.trim(),
                                accountId: _accountId!,
                                toAccountId: isTransfer ? _toAccountId : null,
                                categoryId: isTransfer ? null : _categoryId,
                                note: _note.text.trim().isEmpty
                                    ? null
                                    : _note.text.trim(),
                                intervalDays: interval,
                                startDate: _start,
                                endDate: _end,
                              );
                            } else {
                              ok = await rc.updatePlan(
                                id: widget.editing!.id,
                                type: _type,
                                label: _label.text.trim(),
                                amountText: _amount.text.trim(),
                                accountId: _accountId!,
                                toAccountId: isTransfer ? _toAccountId : null,
                                categoryId: isTransfer ? null : _categoryId,
                                note: _note.text.trim().isEmpty
                                    ? null
                                    : _note.text.trim(),
                                intervalDays: interval,
                                startDate: _start,
                                endDate: _end,
                              );
                            }

                            if (!mounted) return;
                            setState(() => _saving = false);

                            if (!ok) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    recurringController.errorMessage ??
                                        'Failed',
                                  ),
                                ),
                              );
                              return;
                            }

                            navigator.pop();
                          },
                    child: Text(
                      widget.editing == null
                          ? 'Save Recurring'
                          : 'Update Recurring',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canSave({
    required bool isTransfer,
    required String? accountId,
    required String? toAccountId,
    required String? categoryId,
    required String amountText,
    required String intervalText,
    required DateTime start,
    required DateTime end,
  }) {
    final amount = double.tryParse(amountText.trim());
    final interval = int.tryParse(intervalText.trim());

    if (accountId == null) return false;
    if (amount == null || amount <= 0) return false;
    if (interval == null || interval <= 0) return false;
    if (end.isBefore(start)) return false;

    if (isTransfer) {
      if (toAccountId == null) return false;
      if (toAccountId == accountId) return false;
    } else {
      if (categoryId == null) return false;
    }

    return true;
  }
}
