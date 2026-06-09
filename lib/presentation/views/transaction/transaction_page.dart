import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/category_controller.dart';
import '../../../application/controllers/transaction_controller.dart';
import '../../../core/utils/category_icon_mapper.dart';
import '../../../core/utils/theme.dart';

enum TxFilterMode { month, day }

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  TxFilterMode filterMode = TxFilterMode.month;
  DateTime selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  String selectedType = 'all';

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  Future<void> _pickMonthFriendly() async {
    final now = DateTime.now();
    int y = selectedMonth.year;
    int m = selectedMonth.month;

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final years = List.generate(now.year - 2019, (i) => 2020 + i);
            const monthNames = [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec',
            ];

            int maxMonth = 12;
            if (y == now.year) maxMonth = now.month;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Month',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Year:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: y,
                          items: years
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text('$e'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() {
                              y = v;
                              final maxM = y == now.year ? now.month : 12;
                              if (m > maxM) m = maxM;
                            });
                          },
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Month:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(maxMonth, (i) {
                      final month = i + 1;
                      return ChoiceChip(
                        label: Text(monthNames[i]),
                        selected: month == m,
                        onSelected: (_) => setLocal(() => m = month),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(ctx, DateTime(y, m, 1)),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (picked == null) return;
    setState(() => selectedMonth = DateTime(picked.year, picked.month, 1));
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select Day',
    );
    if (picked == null) return;
    setState(
      () => selectedDay = DateTime(picked.year, picked.month, picked.day),
    );
  }

  String _defaultTitleByType(String type) {
    final t = type.toLowerCase();
    if (t == 'income') return 'Income';
    if (t == 'transfer') return 'Transfer';
    if (t == 'adjustment') return 'Manual correction';
    if (t == 'pnl') return 'Investment P/L';
    return 'Expense';
  }

  Future<void> _showEditDialog({
    required Map<String, dynamic> tx,
    required TransactionController txCtrl,
    required CategoryController catCtrl,
  }) async {
    final originalType = (tx['type'] ?? '').toString().trim();
    if (originalType != 'income' &&
        originalType != 'expense' &&
        originalType != 'transfer') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This transaction type is not editable yet.'),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(
      text: _toDouble(tx['amount']).toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController(text: (tx['note'] ?? '').toString());

    String type = originalType;
    String accountId = (tx['accountId'] ?? '').toString();
    String? toAccountId = (tx['toAccountId'] ?? '').toString().trim().isEmpty
        ? null
        : (tx['toAccountId'] ?? '').toString();
    String categoryId = (tx['categoryId'] ?? '').toString();
    DateTime when = tx['datetime'] is DateTime
        ? tx['datetime'] as DateTime
        : DateTime.now();

    final accounts = txCtrl.accounts
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final categories = catCtrl.categories;

    String accountLabel(String id) {
      final hit = accounts
          .where((a) => (a['_id'] ?? a['id']).toString() == id)
          .toList();
      if (hit.isEmpty) return id;
      return (hit.first['name'] ?? id).toString();
    }

    Future<void> pickDate(StateSetter setLocal) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: when,
        firstDate: DateTime(2020, 1, 1),
        lastDate: DateTime(2100, 12, 31),
      );
      if (picked == null) return;
      if (!mounted) return;
      setLocal(() {
        when = DateTime(
          picked.year,
          picked.month,
          picked.day,
          when.hour,
          when.minute,
        );
      });
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final colors = Theme.of(dialogCtx).colorScheme;
        return StatefulBuilder(
          builder: (_, setLocal) {
            final visibleCategories = categories
                .where((c) => c.type == type)
                .toList();
            if (type != 'transfer' &&
                visibleCategories.isNotEmpty &&
                visibleCategories.every((c) => c.id != categoryId)) {
              categoryId = visibleCategories.first.id;
            }

            return AlertDialog(
              title: const Text('Edit Transaction'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'expense',
                            child: Text('Expense'),
                          ),
                          DropdownMenuItem(
                            value: 'income',
                            child: Text('Income'),
                          ),
                          DropdownMenuItem(
                            value: 'transfer',
                            child: Text('Transfer'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => type = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: accountId.isEmpty ? null : accountId,
                        decoration: const InputDecoration(
                          labelText: 'Account',
                          border: OutlineInputBorder(),
                        ),
                        items: accounts
                            .map(
                              (a) => DropdownMenuItem<String>(
                                value: (a['_id'] ?? a['id']).toString(),
                                child: Text(
                                  (a['name'] ?? 'Account').toString(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => accountId = v);
                        },
                      ),
                      if (type == 'transfer') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: toAccountId,
                          decoration: const InputDecoration(
                            labelText: 'To Account',
                            border: OutlineInputBorder(),
                          ),
                          items: accounts
                              .map(
                                (a) => DropdownMenuItem<String>(
                                  value: (a['_id'] ?? a['id']).toString(),
                                  child: Text(
                                    (a['name'] ?? 'Account').toString(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setLocal(() => toAccountId = v),
                        ),
                      ],
                      if (type != 'transfer') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: categoryId.isEmpty ? null : categoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: visibleCategories
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() => categoryId = v);
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount (RM)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse((v ?? '').trim());
                          if (n == null || n <= 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => pickDate(setLocal),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.outlineVariant),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Date: ${DateFormat('yyyy-MM-dd').format(when)}',
                          ),
                        ),
                      ),
                      if (type == 'transfer' &&
                          accountId.isNotEmpty &&
                          toAccountId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${accountLabel(accountId)} -> ${accountLabel(toAccountId!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final confirmDelete = await showDialog<bool>(
                      context: dialogCtx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Delete Transaction?'),
                        content: const Text(
                          'This will permanently remove the transaction and revert its balance impact.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmDelete != true) return;
                    final deleted = await txCtrl.deleteTransaction(
                      (tx['id'] ?? '').toString(),
                    );
                    if (!mounted) return;
                    if (!deleted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            txCtrl.errorMessage ??
                                'Failed to delete transaction',
                          ),
                        ),
                      );
                      return;
                    }
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction deleted')),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  child: const Text('Delete'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    if (type == 'transfer' &&
                        (toAccountId ?? '').trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Destination account is required'),
                        ),
                      );
                      return;
                    }
                    if (type == 'transfer' &&
                        accountId == (toAccountId ?? '')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Source and destination cannot be same',
                          ),
                        ),
                      );
                      return;
                    }

                    final ok = await txCtrl.editTransaction(
                      txId: (tx['id'] ?? '').toString(),
                      type: type,
                      amountText: amountCtrl.text.trim(),
                      accountId: accountId,
                      categoryId: type == 'transfer' ? 'transfer' : categoryId,
                      toAccountId: type == 'transfer' ? toAccountId : null,
                      note: noteCtrl.text.trim(),
                      datetime: when,
                    );
                    if (!mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            txCtrl.errorMessage ?? 'Failed to edit transaction',
                          ),
                        ),
                      );
                      return;
                    }
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaction updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catCtrl = context.watch<CategoryController>();
    final txCtrl = context.watch<TransactionController>();

    if (!txCtrl.hasUser) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    final colors = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppThemeColors>()!;

    String catNameById(String id) {
      if (id.isEmpty) return '-';
      if (id == 'transfer') return 'Transfer';
      if (id == 'investment_pnl') return 'Investment';
      if (id == 'account_adjustment' || id == 'adjustment') return 'Adjustment';
      final hit = catCtrl.categories.where((c) => c.id == id).toList();
      return hit.isEmpty ? id : hit.first.name;
    }

    String? catIconKeyById(String id) {
      if (id.isEmpty ||
          id == 'transfer' ||
          id == 'investment_pnl' ||
          id == 'account_adjustment' ||
          id == 'adjustment')
        {
          return null;
        }
      final hit = catCtrl.categories.where((c) => c.id == id).toList();
      return hit.isEmpty ? null : hit.first.icon;
    }

    final stream = filterMode == TxFilterMode.month
        ? txCtrl.watchMonthlyTransactions(selectedMonth)
        : txCtrl.watchTransactionsByDay(selectedDay);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          if (txCtrl.canUndoLastEdit)
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Undo Last Edit?'),
                    content: const Text(
                      'This will restore the previous transaction data and account balances.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Undo'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                final ok = await txCtrl.undoLastEditTransaction();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Last edit has been undone'
                          : (txCtrl.errorMessage ?? 'Undo failed'),
                    ),
                  ),
                );
              },
              child: const Text('Undo Edit'),
            ),
          TextButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Back'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<TxFilterMode>(
                        segments: const [
                          ButtonSegment(
                            value: TxFilterMode.month,
                            label: Text('Month'),
                          ),
                          ButtonSegment(
                            value: TxFilterMode.day,
                            label: Text('Day'),
                          ),
                        ],
                        selected: {filterMode},
                        onSelectionChanged: (v) {
                          setState(() => filterMode = v.first);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: filterMode == TxFilterMode.month
                            ? _pickMonthFriendly
                            : _pickDay,
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                        ),
                        label: Text(
                          filterMode == TxFilterMode.month
                              ? DateFormat('MMM yyyy').format(selectedMonth)
                              : DateFormat('yyyy-MM-dd').format(selectedDay),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('All Type'),
                          ),
                          DropdownMenuItem(
                            value: 'income',
                            child: Text('Income'),
                          ),
                          DropdownMenuItem(
                            value: 'expense',
                            child: Text('Expense'),
                          ),
                          DropdownMenuItem(
                            value: 'transfer',
                            child: Text('Transfer'),
                          ),
                          DropdownMenuItem(
                            value: 'adjustment',
                            child: Text('Adjustment'),
                          ),
                          DropdownMenuItem(
                            value: 'pnl',
                            child: Text('Investment P/L'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => selectedType = v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var rows = snap.data ?? [];

                if (selectedType != 'all') {
                  rows = rows
                      .where(
                        (e) => (e['type'] ?? '').toString() == selectedType,
                      )
                      .toList();
                }

                if (rows.isEmpty) {
                  final emptyText = filterMode == TxFilterMode.day
                      ? 'No transactions on ${DateFormat('yyyy-MM-dd').format(selectedDay)}'
                      : 'No transactions in ${DateFormat('MMM yyyy').format(selectedMonth)}';
                  return Center(child: Text(emptyText));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemBuilder: (context, i) {
                    final t = rows[i];

                    final type = (t['type'] ?? '').toString();
                    final amount = _toDouble(t['amount']);
                    final date = (t['date'] ?? '').toString();
                    final note = (t['note'] ?? '').toString().trim();
                    final source = (t['source'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                    final splitRaw = t['splitDetails'];
                    final splitMap = splitRaw is Map ? splitRaw : null;
                    final splitCount = splitMap == null ? 0 : splitMap.length;

                    final categoryId =
                        (t['categoryId'] ??
                                t['category_id'] ??
                                t['category'] ??
                                '')
                            .toString()
                            .trim();
                    final categoryName = catNameById(categoryId);
                    final categoryIconKey = catIconKeyById(categoryId);

                    final isIncome = type == 'income';
                    final isTransfer = type == 'transfer';
                    final isAdjustment = type == 'adjustment';
                    final isPnl = type == 'pnl';
                    final isInvestmentValueUpdate =
                        isAdjustment &&
                        note.toLowerCase().contains('investment value update');
                    final isProfitEvent =
                        isInvestmentValueUpdate && amount >= 0;
                    final isLossEvent = isInvestmentValueUpdate && amount < 0;
                    final isManualCorrection =
                        source == 'manual_correction' &&
                        !isInvestmentValueUpdate;
                    final titleText = isInvestmentValueUpdate
                        ? (amount >= 0 ? 'Profit' : 'Loss')
                        : (note.isNotEmpty ? note : _defaultTitleByType(type));

                    final sign = isTransfer
                        ? ''
                        : (isIncome
                              ? '+'
                              : (isPnl
                                    ? (note.toLowerCase().contains('loss')
                                          ? '-'
                                          : '+')
                                    : (isAdjustment
                                          ? (amount >= 0 ? '+' : '-')
                                          : '-')));
                    final amountColor = isTransfer
                        ? colors.secondary
                        : (isProfitEvent
                              ? Colors.cyan.shade700
                              : (isLossEvent
                                    ? colors.error
                                    : (isIncome
                                          ? appColors.positiveAmount
                                          : (isPnl
                                                ? (note.toLowerCase().contains(
                                                        'loss',
                                                      )
                                                      ? appColors.negativeAmount
                                                      : appColors
                                                            .positiveAmount)
                                                : (isAdjustment
                                                      ? colors.onSurfaceVariant
                                                      : appColors
                                                            .negativeAmount)))));

                    final iconData = isTransfer
                        ? Icons.swap_horiz_rounded
                        : (isProfitEvent
                              ? Icons.trending_up_rounded
                              : (isLossEvent
                                    ? Icons.trending_down_rounded
                                    : (isAdjustment
                                          ? Icons.tune_rounded
                                          : (isPnl
                                                ? Icons.trending_up_rounded
                                                : CategoryIconMapper.icon(
                                                    categoryIconKey,
                                                  )))));
                    final iconColor = isTransfer
                        ? colors.secondary
                        : (isProfitEvent
                              ? Colors.cyan.shade700
                              : (isLossEvent
                                    ? colors.error
                                    : (isAdjustment
                                          ? colors.onSurfaceVariant
                                          : (isPnl
                                                ? colors.secondary
                                                : CategoryIconMapper.color(
                                                    categoryIconKey,
                                                  )))));

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showEditDialog(
                        tx: t,
                        txCtrl: txCtrl,
                        catCtrl: catCtrl,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: iconColor.withValues(
                                alpha: 0.16,
                              ),
                              child: Icon(iconData, size: 18, color: iconColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: date,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: appColors.textNumberPrimary,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '  •  ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        TextSpan(
                                          text: categoryName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '  •  ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        TextSpan(
                                          text: type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (splitCount > 1 || isManualCorrection)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (splitCount > 1)
                                            _txTag(
                                              'Split x$splitCount',
                                              colors.primary,
                                            ),
                                          if (isManualCorrection)
                                            _txTag(
                                              'Manual correction',
                                              colors.onSurfaceVariant,
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$sign RM ${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: amountColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to edit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: rows.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _txTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
