import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../application/controllers/authentication_controller.dart';

class AppLockPage extends StatefulWidget {
  const AppLockPage({super.key});

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> {
  int _failCount = 0;
  bool _running = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      _tryUnlock();
    });
  }

  Future<void> _tryUnlock() async {
    if (_running || _failCount >= 3) return;
    setState(() {
      _running = true;
      _message = null;
    });
    final auth = context.read<AuthenticationController>();
    final result = await auth.signInWithBiometric();
    if (!mounted) return;

    if (result.success) {
      context.go(result.needsSurvey ? '/smart-survey' : '/dashboard');
      return;
    }

    final next = _failCount + 1;
    if (next >= 3) {
      await auth.logout();
      if (!mounted) return;
      setState(() {
        _failCount = next;
        _running = false;
        _message = 'Biometric failed 3 times. Please login with Google or Email/Password.';
      });
      context.go('/login');
      return;
    }

    setState(() {
      _failCount = next;
      _running = false;
      _message = result.errorMessage ?? 'Biometric authentication failed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final iconTileColor = isDark
        ? colors.primary.withValues(alpha: 0.18)
        : colors.primary.withValues(alpha: 0.14);
    final iconColor = isDark
        ? Color.lerp(colors.onPrimary, Colors.white, 0.30)!
        : colors.primary;
    final iconBorderColor = isDark
        ? colors.primary.withValues(alpha: 0.52)
        : colors.primary.withValues(alpha: 0.26);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: iconTileColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: iconBorderColor),
                          boxShadow: isDark
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: 0.22),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: iconColor,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unlock Smart Pocket',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _message ??
                            (_running
                                ? 'Waiting for biometric authentication...'
                                : 'Authenticate with Face ID / Fingerprint to continue.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _message == null
                              ? colors.onSurfaceVariant
                              : colors.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _running ? null : _tryUnlock,
                          icon: _running
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary),
                                )
                              : const Icon(Icons.lock_open_rounded),
                          label: Text(_running ? 'Authenticating...' : 'Try Again'),
                        ),
                      ),
                      if (_failCount > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Failed attempts: $_failCount / 3',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
