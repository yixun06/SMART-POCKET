import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/controllers/budget_controller.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final _amountCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final budget = context.read<BudgetController>();
    budget.init().then((_) {
      if (!mounted) return;
      final b = budget.monthlyBudget;
      _amountCtrl.text = b == 0 ? '' : b.toStringAsFixed(2);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<BudgetController>();
    final m = c.selectedMonth;

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Budget')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  final prev = DateTime(m.year, m.month - 1, 1);
                  final budget = context.read<BudgetController>();
                  await budget.changeMonth(prev);
                  if (!mounted) return;
                  final b = budget.monthlyBudget;
                  _amountCtrl.text = b == 0 ? '' : b.toStringAsFixed(2);
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${m.month.toString().padLeft(2, '0')}-${m.year}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final next = DateTime(m.year, m.month + 1, 1);
                  final thisMonth = DateTime(now.year, now.month, 1);
                  if (!next.isAfter(thisMonth)) {
                    final budget = context.read<BudgetController>();
                    await budget.changeMonth(next);
                    if (!mounted) return;
                    final b = budget.monthlyBudget;
                    _amountCtrl.text = b == 0 ? '' : b.toStringAsFixed(2);
                  }
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Set budget for selected month', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Budget Amount (RM)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: c.isLoading
                              ? null
                              : () async {
                                  final budget = context.read<BudgetController>();
                                  final messenger = ScaffoldMessenger.of(context);
                                  await budget.saveBudget(_amountCtrl.text.trim());
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(budget.errorMessage ?? 'Budget saved')),
                                  );
                                },
                          child: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: c.isLoading
                              ? null
                              : () async {
                                  final budget = context.read<BudgetController>();
                                  final messenger = ScaffoldMessenger.of(context);
                                  await budget.deleteCurrentMonthBudget();
                                  if (!mounted) return;
                                  _amountCtrl.clear();
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Budget deleted for selected month')),
                                  );
                                },
                          child: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              title: const Text('Current Month Budget'),
              subtitle: Text('RM ${c.monthlyBudget.toStringAsFixed(2)}'),
            ),
          ),
        ],
      ),
    );
  }
}