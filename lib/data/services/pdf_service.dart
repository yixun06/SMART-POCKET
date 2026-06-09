import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  String _money(double v) => 'RM ${v.toStringAsFixed(2)}';

  String _short(dynamic v, {int max = 28}) {
    final s = (v ?? '').toString().replaceAll('\n', ' ');
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }

  Future<String> exportMonthlyPdf({
    required DateTime month,
    required List<Map<String, dynamic>> rows,
    required double income,
    required double expense,
    required double budget,
    required double totalAssets,
    required List<Map<String, dynamic>> accounts,
  }) async {
    final doc = pw.Document();

    final monthLabel = DateFormat('yyyy-MM').format(month);
    final generatedAt = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final net = income - expense;
    final savingsRate = income <= 0 ? 0.0 : (net / income * 100);
    final budgetUsed = budget <= 0 ? 0.0 : (expense / budget * 100);
    final expenseIncomeRatio = income <= 0 ? 0.0 : (expense / income * 100);

    final sorted = [
      ...rows,
    ]..sort((a, b) => _toDouble(b['amount']).compareTo(_toDouble(a['amount'])));
    final top20 = sorted.take(20).toList();

    final insight = () {
      if (income <= 0 && expense > 0) {
        return 'No income recorded, but expenses exist.';
      }
      if (budget > 0 && expense > budget) {
        return 'Spending exceeded the monthly budget.';
      }
      if (net < 0) return 'Net cash flow is negative this month.';
      if (savingsRate >= 20) return 'Healthy savings rate this month.';
      return 'Financial performance is stable.';
    }();

    final totalAccountBalance = accounts.fold<double>(
      0.0,
      (p, a) => p + _toDouble(a['balance']),
    );

    doc.addPage(
      pw.MultiPage(
        maxPages: 10,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'Smart Pocket Monthly Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Month: $monthLabel'),
          pw.Text('Generated: $generatedAt'),
          pw.SizedBox(height: 12),

          pw.Text(
            '1) Monthly Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Income: ${_money(income)}'),
                pw.Text('Expense: ${_money(expense)}'),
                pw.Text('Net Cash Flow: ${_money(net)}'),
                pw.Text('Budget: ${_money(budget)}'),
                pw.Text('Budget Used: ${budgetUsed.toStringAsFixed(1)}%'),
                pw.Text('Total Assets: ${_money(totalAssets)}'),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          pw.Text(
            '2) Data Analysis',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Bullet(text: 'Savings Rate: ${savingsRate.toStringAsFixed(1)}%'),
          pw.Bullet(
            text:
                'Expense/Income Ratio: ${income <= 0 ? 'N/A' : '${expenseIncomeRatio.toStringAsFixed(1)}%'}',
          ),
          pw.Bullet(text: 'Insight: $insight'),

          pw.SizedBox(height: 12),

          pw.Text(
            '3) Accounts Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (accounts.isEmpty)
            pw.Text('No account data.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Account', 'Type', 'Balance'],
              data: accounts.map((a) {
                final name = (a['name'] ?? a['accountName'] ?? 'Unnamed')
                    .toString();
                final type = (a['type'] ?? a['accountType'] ?? '-').toString();
                final balance = _toDouble(a['balance']);
                return [name, type, _money(balance)];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Accounts Total Balance: ${_money(totalAccountBalance)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 12),

          pw.Text(
            '4) Top Transactions (Max 20)',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (top20.isEmpty)
            pw.Text('No transactions for this month.')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Type', 'Category', 'Amount', 'Note'],
              data: top20.map((e) {
                return [
                  (e['date'] ?? '').toString(),
                  (e['type'] ?? '').toString(),
                  (e['category'] ?? '').toString(),
                  _money(_toDouble(e['amount'])),
                  _short(e['note']),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/smart_pocket_report_$monthLabel.pdf');
    await file.writeAsBytes(await doc.save(), flush: true);
    return file.path;
  }
}
