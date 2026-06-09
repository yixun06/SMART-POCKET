import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/authentication_controller.dart';
import '../../widgets/buttons/primary_button.dart';

class SmartSurveyPage extends StatefulWidget {
  const SmartSurveyPage({super.key});

  @override
  State<SmartSurveyPage> createState() => _SmartSurveyPageState();
}

class _SmartSurveyPageState extends State<SmartSurveyPage> {
  int _q1 = 3;
  int _q2 = 3;
  int _q3 = 3;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    final score = _q1 + _q2 + _q3;
    try {
      await context.read<AuthenticationController>().completeSurvey(score: score);
      if (!mounted) return;
      context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Survey')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Welcome to Smart Pocket',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Please complete this short survey before entering dashboard.'),
          const SizedBox(height: 16),
          _question(
            title: 'How confident are you in tracking expenses?',
            value: _q1,
            onChanged: (v) => setState(() => _q1 = v),
          ),
          _question(
            title: 'How often do you save money monthly?',
            value: _q2,
            onChanged: (v) => setState(() => _q2 = v),
          ),
          _question(
            title: 'How familiar are you with budgeting?',
            value: _q3,
            onChanged: (v) => setState(() => _q3 = v),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Submit Survey',
            loading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _question({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: value.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$value',
              onChanged: (v) => onChanged(v.round()),
            ),
          ],
        ),
      ),
    );
  }
}

