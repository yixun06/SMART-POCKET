import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/budget_controller.dart';
import '../../../application/controllers/category_controller.dart';
import '../../../application/controllers/config_controller.dart';
import '../../../application/controllers/transaction_controller.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/category_icon_mapper.dart';
import '../../../core/models/allocation_result.dart';
import '../../widgets/common/provider_avatar.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();

  String _type = 'expense';
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  DateTime _selectedDate = DateTime.now();

  bool _submitting = false;
  bool _lazyFocusedOnce = false;
  String _lazyPreviewCacheKey = '';
  Future<AllocationResult?>? _lazyPreviewFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLazyMode = context.read<ConfigController>().appMode == 'lazy';
    if (isLazyMode && !_lazyFocusedOnce) {
      _lazyFocusedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _amountFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  double? get _parsedAmount => double.tryParse(_amount.text.trim());

  bool _canSubmit({
    required bool isTransfer,
    required bool hasAccount,
    required bool hasToAccount,
    required bool hasCategory,
    required bool amountValid,
  }) {
    if (!hasAccount || !amountValid) return false;
    if (isTransfer) return hasToAccount;
    return hasCategory;
  }

  Map<String, dynamic>? _findAccountById(List<dynamic> accounts, String? id) {
    if (id == null) return null;
    for (final raw in accounts) {
      final a = Map<String, dynamic>.from(raw as Map);
      final aid = (a['_id'] ?? a['id']).toString();
      if (aid == id) return a;
    }
    return null;
  }

  bool _isInvestmentAccount(Map<String, dynamic>? a) {
    if (a == null) return false;
    return (a['type'] ?? '').toString().toLowerCase() == 'investment';
  }

  Widget _accountAvatar(Map<String, dynamic> a, {double size = 30}) {
    final type = (a['type'] ?? '').toString().toLowerCase();
    final provider = (a['provider'] ?? a['name'] ?? 'Account').toString();
    return ProviderAvatar.providerAvatar(
      context,
      provider,
      type: type.isEmpty ? 'cash' : type,
      size: size < 34 ? 34 : size,
    );
  }

  Widget _accountMenuItem(Map<String, dynamic> a, {double avatarSize = 30}) {
    final name = (a['name'] ?? 'Account').toString();
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        _accountAvatar(a, size: avatarSize),
        const SizedBox(width: 10),
        Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  String _lazyCategoryTagForType() {
    return _type == 'income'
        ? LazyModeConfig.incomePrimaryCategory
        : LazyModeConfig.expensePrimaryCategory;
  }

  String _buildLazyPreviewCacheKey() {
    final amountText = _amount.text.trim();
    final tag = _lazyCategoryTagForType();
    return '$_type|$tag|$amountText';
  }

  Future<AllocationResult?> _getLazyPreviewFuture(TransactionController tx) {
    if ((_parsedAmount ?? 0) <= 0 || _type == 'transfer') {
      _lazyPreviewCacheKey = '';
      _lazyPreviewFuture = Future<AllocationResult?>.value(null);
      return _lazyPreviewFuture!;
    }
    final key = _buildLazyPreviewCacheKey();
    if (_lazyPreviewFuture == null || _lazyPreviewCacheKey != key) {
      _lazyPreviewCacheKey = key;
      _lazyPreviewFuture = tx.previewAllocation(
        type: _type,
        amountText: _amount.text.trim(),
        categoryTag: _lazyCategoryTagForType(),
      );
    }
    return _lazyPreviewFuture!;
  }

  void _appendAmountInput(String value) {
    final t = _amount.text;
    if (value == '.') {
      if (t.contains('.')) return;
      _amount.text = t.isEmpty ? '0.' : '$t.';
      setState(() {});
      return;
    }
    if (t == '0') {
      _amount.text = value;
    } else {
      final next = '$t$value';
      final dot = next.indexOf('.');
      if (dot >= 0 && next.length - dot - 1 > 2) return;
      _amount.text = next;
    }
    setState(() {});
  }

  void _backspaceAmountInput() {
    final t = _amount.text;
    if (t.isEmpty) return;
    _amount.text = t.substring(0, t.length - 1);
    setState(() {});
  }

  void _clearAmountInput() {
    _amount.clear();
    setState(() {});
  }

  Widget _keypadButton(
    String label,
    VoidCallback onTap, {
    Color? bg,
    Color? fg,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: bg ?? colors.surfaceContainerHighest,
          foregroundColor: fg ?? colors.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildLazyQuickAmount() {
    final colors = Theme.of(context).colorScheme;
    final display = _amount.text.trim().isEmpty ? '0.00' : _amount.text.trim();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Text('Quick Add Amount', style: _labelStyle(context)),
              const SizedBox(height: 8),
              TextField(
                controller: _amount,
                focusNode: _amountFocus,
                readOnly: true,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  prefixText: 'RM ',
                ),
              ),
              if (display == '0.00')
                Text(
                  'Enter amount below',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final q in const ['5', '10', '20'])
              ActionChip(
                label: Text('RM$q'),
                onPressed: () {
                  _amount.text = q;
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.8,
          children: [
            _keypadButton('1', () => _appendAmountInput('1')),
            _keypadButton('2', () => _appendAmountInput('2')),
            _keypadButton('3', () => _appendAmountInput('3')),
            _keypadButton('4', () => _appendAmountInput('4')),
            _keypadButton('5', () => _appendAmountInput('5')),
            _keypadButton('6', () => _appendAmountInput('6')),
            _keypadButton('7', () => _appendAmountInput('7')),
            _keypadButton('8', () => _appendAmountInput('8')),
            _keypadButton('9', () => _appendAmountInput('9')),
            _keypadButton('.', () => _appendAmountInput('.')),
            _keypadButton('0', () => _appendAmountInput('0')),
            _keypadButton('⌫', _backspaceAmountInput),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _clearAmountInput,
            child: const Text('Clear'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = context.watch<TransactionController>();
    final cat = context.watch<CategoryController>();
    final config = context.watch<ConfigController>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLazyMode = config.appMode == 'lazy';
    if (isLazyMode && _type == 'transfer') {
      _type = 'expense';
    }

    final allAccounts = tx.accounts
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final categories = cat.categories.where((c) => c.type == _type).toList();

    final eligibleAccounts = allAccounts
        .where(
          (a) => (a['type'] ?? '').toString().toLowerCase() != 'investment',
        )
        .toList();

    final sourcePool = eligibleAccounts;

    if (!isLazyMode) {
      if (_accountId == null && sourcePool.isNotEmpty) {
        _accountId = (sourcePool.first['_id'] ?? sourcePool.first['id'])
            .toString();
      }
    }

    if (_toAccountId == null && allAccounts.length > 1) {
      final fallback = allAccounts.firstWhere(
        (a) => (a['_id'] ?? a['id']).toString() != _accountId,
        orElse: () => allAccounts.first,
      );
      _toAccountId = (fallback['_id'] ?? fallback['id']).toString();
    }

    if (_categoryId == null && categories.isNotEmpty) {
      _categoryId = categories.first.id;
    } else if (_categoryId != null &&
        categories.every((c) => c.id != _categoryId)) {
      _categoryId = categories.isNotEmpty ? categories.first.id : null;
    }

    final selectedSource = _findAccountById(allAccounts, _accountId);
    if (!isLazyMode &&
        _type == 'expense' &&
        _isInvestmentAccount(selectedSource)) {
      _accountId = eligibleAccounts.isNotEmpty
          ? (eligibleAccounts.first['_id'] ?? eligibleAccounts.first['id'])
                .toString()
          : null;
    }

    final isTransfer = _type == 'transfer';
    final hasAccount = isLazyMode || _accountId != null;
    final hasToAccount = _toAccountId != null && _toAccountId != _accountId;
    final hasCategory = isLazyMode || _categoryId != null;
    final amountValid = (_parsedAmount ?? 0) > 0;

    final enabled =
        !_submitting &&
        _canSubmit(
          isTransfer: isTransfer,
          hasAccount: hasAccount,
          hasToAccount: hasToAccount,
          hasCategory: hasCategory,
          amountValid: amountValid,
        );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          'New Transaction',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Close'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SegmentedButton<String>(
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        side: WidgetStateProperty.all(BorderSide.none),
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          return states.contains(WidgetState.selected)
                              ? theme.cardColor
                              : colors.surfaceContainerHigh;
                        }),
                      ),
                      segments: isLazyMode
                          ? const [
                              ButtonSegment(
                                value: 'expense',
                                label: Text('Expense'),
                              ),
                              ButtonSegment(
                                value: 'income',
                                label: Text('Income'),
                              ),
                            ]
                          : const [
                              ButtonSegment(
                                value: 'expense',
                                label: Text('Expense'),
                              ),
                              ButtonSegment(
                                value: 'income',
                                label: Text('Income'),
                              ),
                              ButtonSegment(
                                value: 'transfer',
                                label: Text('Transfer'),
                              ),
                            ],
                      selected: {_type},
                      onSelectionChanged: (s) {
                        setState(() {
                          _type = s.first;
                          if (isLazyMode && _type == 'transfer') {
                            _type = 'expense';
                          }
                          if (_type != 'transfer') {
                            _toAccountId = null;
                          }
                        });

                        if (_type == 'expense') {
                          final selected = _findAccountById(
                            tx.accounts,
                            _accountId,
                          );
                          if (_isInvestmentAccount(selected)) {
                            final candidates = tx.accounts
                                .map((e) => Map<String, dynamic>.from(e as Map))
                                .where(
                                  (a) =>
                                      (a['type'] ?? '')
                                          .toString()
                                          .toLowerCase() !=
                                      'investment',
                                )
                                .toList();

                            setState(() {
                              _accountId = candidates.isNotEmpty
                                  ? (candidates.first['_id'] ??
                                            candidates.first['id'])
                                        .toString()
                                  : null;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Investment account cannot be used for expense',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isLazyMode) ...[
                    _buildLazyQuickAmount(),
                  ] else ...[
                    Text('AMOUNT', style: _labelStyle(context)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'RM',
                          style: TextStyle(
                            fontSize: 38,
                            height: 1,
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _amount,
                            focusNode: _amountFocus,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _noteFocus.requestFocus(),
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            style: const TextStyle(
                              fontSize: 38,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!amountValid && _amount.text.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Please enter valid amount',
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                    ),
                  const Divider(height: 22),

                  if (!isTransfer && !isLazyMode) ...[
                    Row(
                      children: [
                        Text('CATEGORY', style: _labelStyle(context)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push('/categories'),
                          child: const Text('Manage'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _categoryQuickPicker(
                      categories: categories,
                      selectedId: _categoryId,
                      onSelect: (id) => setState(() => _categoryId = id),
                    ),
                    if (!hasCategory)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Please select category',
                          style: TextStyle(color: colors.error, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],

                  if (!isLazyMode) ...[
                    Text('SOURCE ACCOUNT', style: _labelStyle(context)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      isExpanded: true,
                      decoration: _inputDeco(),
                      items: sourcePool
                          .map(
                            (a) => DropdownMenuItem(
                              value: (a['_id'] ?? a['id']).toString(),
                              child: _accountMenuItem(a),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    if (_type == 'expense')
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Investment accounts cannot be used for expense.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ] else if (isLazyMode && !isTransfer) ...[
                    _buildLazyModePreview(context, tx),
                  ],

                  if (isTransfer) ...[
                    const SizedBox(height: 12),
                    Text('DESTINATION ACCOUNT', style: _labelStyle(context)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _toAccountId,
                      isExpanded: true,
                      decoration: _inputDeco(),
                      items: allAccounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: (a['_id'] ?? a['id']).toString(),
                              child: _accountMenuItem(a),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _toAccountId = v),
                    ),
                    if (_toAccountId == _accountId && _toAccountId != null)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Source and destination cannot be same',
                          style: TextStyle(color: colors.error, fontSize: 12),
                        ),
                      ),
                  ],

                  if (!isLazyMode) ...[
                    const SizedBox(height: 14),
                    Text('NOTE', style: _labelStyle(context)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _note,
                      focusNode: _noteFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (enabled) _onSave();
                      },
                      decoration: _inputDeco(hint: "What's this for?"),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date'),
                      subtitle: Text(
                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (!mounted) return;
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: enabled
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: enabled ? _onSave : null,
                  child: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(
                          isLazyMode
                              ? (_type == 'income'
                                    ? 'Add Income'
                                    : 'Add Expense')
                              : 'Save Transaction',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLazyModePreview(BuildContext context, TransactionController tx) {
    final colors = Theme.of(context).colorScheme;
    final accounts = tx.accounts;

    return FutureBuilder<AllocationResult?>(
      future: _getLazyPreviewFuture(tx),
      builder: (context, snap) {
        final allocation = snap.data?.allocation ?? const <String, double>{};
        final order = snap.data?.deductionOrder ?? const <String>[];
        final warnings = snap.data?.fallbackWarnings ?? const <String>[];
        final hasPlan = snap.data?.success == true && allocation.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LAZY MODE RULE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _type == 'income'
                    ? 'Income -> savings primary account'
                    : 'Expense deduction order: daily_use primary -> daily_use others -> savings (if enabled)',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Text(
                'DEDUCTION PLAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              if ((_parsedAmount ?? 0) <= 0)
                Text(
                  'Enter amount to preview allocation.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                )
              else if (!hasPlan)
                Text(
                  snap.data?.errorMessage ?? 'Unable to build allocation plan.',
                  style: TextStyle(fontSize: 12, color: colors.error),
                )
              else ...[
                ...order.map((accountId) {
                  final planned = allocation[accountId] ?? 0.0;
                  final account = _findAccountById(accounts, accountId);
                  final accountName = (account?['name'] ?? accountId)
                      .toString();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          accountName,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          'RM ${planned.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.error,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colors.tertiary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: warnings
                          .map(
                            (w) => Text(
                              '• $w',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onTertiaryContainer,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitLazyQuickAdd(
    BuildContext context,
    TransactionController tx,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final amount = _parsedAmount;
    if (amount == null || amount <= 0) return;
    final tag = _lazyCategoryTagForType();
    final AllocationResult? preview = await _getLazyPreviewFuture(tx);
    if (!mounted) return;
    if (preview == null || !preview.success || preview.allocation.isEmpty) {
      final message = (preview?.errorMessage ?? 'Allocation preview failed')
          .toString();
      final friendly = tx.isTransientError(message)
          ? 'Network is temporarily unavailable. Please check connection and retry.'
          : message;
      messenger.showSnackBar(SnackBar(content: Text(friendly)));
      return;
    }

    setState(() => _submitting = true);

    try {
      final ok = await tx.addTxLazyMode(
        categoryTag: tag,
        categoryId: null,
        type: _type,
        amountText: _amount.text.trim(),
        note: null,
        datetime: DateTime.now(),
        source: 'manual',
      );

      if (!mounted) return;

      if (!ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(tx.errorMessage ?? 'Failed to add transaction'),
          ),
        );
        return;
      }

      final split = tx.lastCommittedAllocation ?? preview.allocation;
      final fallback =
          tx.lastCommittedFallbackWarnings ?? preview.fallbackWarnings;
      final splitText = preview.deductionOrder
          .map((accountId) {
            final account = _findAccountById(tx.accounts, accountId);
            final accountName = (account?['name'] ?? accountId).toString();
            final value = split[accountId] ?? 0.0;
            return '$accountName RM${value.toStringAsFixed(2)}';
          })
          .join(' / ');
      final actionText = _type == 'income' ? 'added' : 'deducted';
      final fallbackText = fallback.isEmpty ? '' : ' | ${fallback.join(' | ')}';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'RM${amount.toStringAsFixed(2)} $actionText. $splitText$fallbackText',
          ),
        ),
      );
      _amount.clear();
      setState(() {});
      navigator.pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  TextStyle _labelStyle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 11,
      letterSpacing: 0.5,
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
  }

  InputDecoration _inputDeco({String? hint}) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    );
  }

  Widget _categoryQuickPicker({
    required List<dynamic> categories,
    required String? selectedId,
    required ValueChanged<String> onSelect,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = categories[i];
          final selected = c.id == selectedId;
          final icon = CategoryIconMapper.icon(c.icon);
          final color = CategoryIconMapper.color(c.icon);

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(c.id),
            child: SizedBox(
              width: 74,
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.18)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? color : colors.outlineVariant,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onSave() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final amount = _parsedAmount;
    final config = context.read<ConfigController>();
    final isLazyMode = config.appMode == 'lazy';

    if (isLazyMode && _type != 'transfer') {
      if (amount == null || amount <= 0) return;
      await _submitLazyQuickAdd(context, context.read<TransactionController>());
      return;
    }

    if (_accountId == null || amount == null || amount <= 0) return;

    final txc = context.read<TransactionController>();
    final src = _findAccountById(txc.accounts, _accountId);
    final srcType = (src?['type'] ?? '').toString().toLowerCase();

    if (_type == 'expense' && srcType == 'investment') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Investment account cannot be used for expense'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      if (_type == 'expense') {
        final b = context.read<BudgetController>().monthlyBudget;
        final mExpense = context.read<TransactionController>().monthlyExpense;
        if (b > 0 && (mExpense + amount) > b) {
          final cont = await showDialog<bool>(
            context: context,
            builder: (dCtx) => AlertDialog(
              title: const Text('Budget Exceed'),
              content: const Text(
                'This expense may exceed your monthly budget. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          );
          if (cont != true) return;
        }
      }

      bool ok;
      if (_type == 'transfer') {
        if (_toAccountId == null || _toAccountId == _accountId) return;
        ok = await txc.addTransfer(
          fromAccountId: _accountId!,
          toAccountId: _toAccountId!,
          amountText: _amount.text.trim(),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          datetime: _selectedDate,
          source: 'manual',
        );
      } else {
        if (_categoryId == null) return;
        ok = await txc.addTx(
          accountId: _accountId!,
          categoryId: _categoryId!,
          type: _type,
          amountText: _amount.text.trim(),
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          datetime: _selectedDate,
          source: 'manual',
        );
      }

      if (!mounted) return;
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(content: Text(txc.errorMessage ?? 'Failed')),
        );
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction added')),
      );
      navigator.pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
