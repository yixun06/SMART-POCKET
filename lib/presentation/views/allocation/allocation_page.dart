import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/allocation_controller.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/theme.dart';

class AllocationGoalPage extends StatefulWidget {
  const AllocationGoalPage({super.key});

  @override
  State<AllocationGoalPage> createState() => _AllocationGoalPageState();
}

class _AllocationGoalPageState extends State<AllocationGoalPage> {
  final _dailyCtrl = TextEditingController();
  final _savingsCtrl = TextEditingController();
  final _investCtrl = TextEditingController();

  bool _enabled = true;
  double _tolerance = 1.0;
  bool _loading = true;
  bool _saving = false;
  bool _showTotalError = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentGoals();
  }

  @override
  void dispose() {
    _dailyCtrl.dispose();
    _savingsCtrl.dispose();
    _investCtrl.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0.0;

  Future<void> _loadCurrentGoals() async {
    try {
      final goal = await context.read<AllocationController>().loadGoals();
      final targets =
          (goal[AllocationFields.targets] as Map<String, dynamic>?) ?? {};

      setState(() {
        _enabled = goal[AllocationFields.enabled] == null
            ? true
            : goal[AllocationFields.enabled] == true;
        _tolerance = ((goal[AllocationFields.tolerance] ?? 1.0) as num)
            .toDouble();

        _dailyCtrl.text = ((targets[AllocationFields.dailyUse] ?? 20) as num)
            .toDouble()
            .toStringAsFixed(0);
        _savingsCtrl.text = ((targets[AllocationFields.savings] ?? 40) as num)
            .toDouble()
            .toStringAsFixed(0);
        _investCtrl.text = ((targets[AllocationFields.investment] ?? 40) as num)
            .toDouble()
            .toStringAsFixed(0);
        _loading = false;
        _showTotalError = false;
      });
    } catch (_) {
      setState(() {
        _dailyCtrl.text = '20';
        _savingsCtrl.text = '40';
        _investCtrl.text = '40';
        _loading = false;
        _showTotalError = false;
      });
    }
  }

  void _loadTemplateValues(String template) {
    if (template == 'conservative') {
      _dailyCtrl.text = '20';
      _savingsCtrl.text = '60';
      _investCtrl.text = '20';
    } else if (template == 'balanced') {
      _dailyCtrl.text = '20';
      _savingsCtrl.text = '40';
      _investCtrl.text = '40';
    } else {
      _dailyCtrl.text = '10';
      _savingsCtrl.text = '20';
      _investCtrl.text = '70';
    }
    setState(() {});
  }

  bool _validateTotal() {
    final total = _num(_dailyCtrl) + _num(_savingsCtrl) + _num(_investCtrl);
    return (total - 100).abs() < 0.0001;
  }

  Future<void> _saveGoals() async {
    final d = _num(_dailyCtrl);
    final s = _num(_savingsCtrl);
    final i = _num(_investCtrl);

    setState(() => _saving = true);
    try {
      await context.read<AllocationController>().saveGoals(
        enabled: _enabled,
        tolerance: _tolerance,
        dailyUse: d,
        savings: s,
        investment: i,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showTagSuggestionDialogAndHandle() async {
    try {
      final allocation = context.read<AllocationController>();
      final suggestions = await allocation.suggestTags();
      if (!mounted) return;

      final mutable = suggestions.map((e) => e.copy()).toList();

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dCtx) {
          return StatefulBuilder(
            builder: (_, setModal) {
              return AlertDialog(
                title: const Text('Suggested Account Tags'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Review and confirm tag suggestions:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...mutable.map((s) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.accountName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: s.suggestedTag,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'DAILY_USE',
                                      child: Text('DAILY_USE'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'SAVINGS',
                                      child: Text('SAVINGS'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'INVESTMENT',
                                      child: Text('INVESTMENT'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'OTHER',
                                      child: Text('OTHER'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setModal(() {
                                      s.suggestedTag = v;
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: const Text('Skip'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dCtx, true),
                    child: const Text('Apply Tags'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed == true) {
        await allocation.applyTags(mutable);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allocation goals saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goals saved, but tag suggestion failed: $e')),
      );
    }
  }

  Future<void> _onTapSave() async {
    if (!_validateTotal()) {
      setState(() => _showTotalError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allocation percentages must total 100%')),
      );
      return;
    }

    setState(() => _showTotalError = false);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await _saveGoals();

    if (!mounted) return;

    final wantSuggest = await showDialog<bool>(
      context: navigator.context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Suggest tags now?'),
        content: const Text(
          'Generate account tag suggestions based on current balances?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Suggest'),
          ),
        ],
      ),
    );

    if (wantSuggest == true) {
      await _showTagSuggestionDialogAndHandle();
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Allocation goals saved')),
      );
    }
  }

  Widget _field(String label, TextEditingController c) {
    final colors = Theme.of(context).colorScheme;
    final isInvalid = _showTotalError && !_validateTotal();
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: '$label (%)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isInvalid ? colors.error : colors.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isInvalid ? colors.error : colors.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error, width: 1.8),
        ),
        errorText: isInvalid ? 'All three values must total 100%' : null,
      ),
      onChanged: (_) => setState(() {
        if (_validateTotal()) _showTotalError = false;
      }),
    );
  }

  Widget _row({
    required String label,
    required double actual,
    required double target,
    required Color color,
  }) {
    final ratio = target <= 0 ? 0.0 : (actual / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              '${actual.toStringAsFixed(1)}% / ${target.toStringAsFixed(1)}%',
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: ratio,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppThemeColors>()!;
    final allocation = context.watch<AllocationController>();
    if (allocation.uid == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final targetDaily = _num(_dailyCtrl);
    final targetSavings = _num(_savingsCtrl);
    final targetInvest = _num(_investCtrl);
    final total = targetDaily + targetSavings + targetInvest;
    final isTotalValid = (total - 100).abs() <= _tolerance;
    final showTotalError = _showTotalError && !isTotalValid;

    return Scaffold(
      appBar: AppBar(title: const Text('Asset Allocation Goals')),
      body: StreamBuilder<Map<String, double>>(
        stream: allocation.watchActualAllocation(),
        builder: (context, snap) {
          final actual =
              snap.data ??
              {
                'daily_use': 0.0,
                'savings': 0.0,
                'investment': 0.0,
                '_hasData': 0.0,
              };

          final hasData = (actual['_hasData'] ?? 0) > 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable Allocation Goal'),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _loadTemplateValues('conservative'),
                      child: const Text('Conservative'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _loadTemplateValues('balanced'),
                      child: const Text('Balanced'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _loadTemplateValues('aggressive'),
                      child: const Text('Aggressive'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _field('Daily Use', _dailyCtrl),
              const SizedBox(height: 10),
              _field('Savings', _savingsCtrl),
              const SizedBox(height: 10),
              _field('Investment', _investCtrl),

              const SizedBox(height: 8),
              Text(
                'Total: ${total.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isTotalValid
                      ? appColors.positiveAmount
                      : appColors.negativeAmount,
                ),
              ),
              if (showTotalError) ...[
                const SizedBox(height: 4),
                Text(
                  'Allocation percentages must total 100%',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Must total exactly 100%',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current vs Target',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _row(
                        label: 'Daily Use',
                        actual: actual['daily_use'] ?? 0,
                        target: targetDaily,
                        color: colors.secondary,
                      ),
                      const SizedBox(height: 10),
                      _row(
                        label: 'Savings',
                        actual: actual['savings'] ?? 0,
                        target: targetSavings,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 10),
                      _row(
                        label: 'Investment',
                        actual: actual['investment'] ?? 0,
                        target: targetInvest,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      if (!hasData) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Not enough account data to compute allocation',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _onTapSave,
                  child: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Save Goals'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
