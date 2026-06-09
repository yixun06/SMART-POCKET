import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../application/controllers/authentication_controller.dart';
import '../../../core/utils/constants.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/forms/custom_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _showPassword = false;
  bool _autoBiometricTriggered = false;
  int _biometricFailCount = 0;
  bool _biometricLocked = false;
  bool _autoBiometricRunning = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_autoBiometricTriggered) return;

    _autoBiometricTriggered = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final c = context.read<AuthenticationController>();

      final shouldAuto = await c.shouldAutoTriggerBiometric();

      if (!mounted || !shouldAuto) return;

      await _runAutoBiometricFlow(c);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login(AuthenticationController c) async {
    final result = await c.signInWithEmail(
      _email.text.trim(),
      _password.text.trim(),
    );

    if (!mounted) return;

    if (result.success) {
      context.go(result.needsSurvey ? '/smart-survey' : '/dashboard');
    }
  }

  Future<void> _google(AuthenticationController c) async {
    final result = await c.signInWithGoogle();

    if (!mounted) return;

    if (result.success) {
      context.go(result.needsSurvey ? '/smart-survey' : '/dashboard');
    } else if (c.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(c.errorMessage!)));
    }
  }

  Future<void> _biometric(
    AuthenticationController c, {
    bool silentOnFailure = false,
  }) async {
    if (_biometricLocked) {
      if (!silentOnFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric failed 3 times. Please login with Google or Email/Password.',
            ),
          ),
        );
      }

      return;
    }

    final result = await c.signInWithBiometric();

    if (!mounted) return;

    if (result.success) {
      _biometricFailCount = 0;
      _biometricLocked = false;

      context.go(result.needsSurvey ? '/smart-survey' : '/dashboard');

      return;
    }

    _biometricFailCount += 1;

    if (_biometricFailCount >= 3) {
      _biometricLocked = true;
    }

    if (silentOnFailure) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.errorMessage ??
              c.errorMessage ??
              'Biometric authentication failed.',
        ),
      ),
    );
  }

  Future<void> _runAutoBiometricFlow(AuthenticationController c) async {
    if (_autoBiometricRunning || _biometricLocked) return;

    _autoBiometricRunning = true;

    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;

      await _biometric(c, silentOnFailure: true);

      if (!mounted) return;

      if (_biometricLocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric failed 3 times. Please use Google or Email/Password.',
            ),
          ),
        );
      }
    } finally {
      _autoBiometricRunning = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AuthenticationController>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const _BrandHeader(),

                  const SizedBox(height: 20),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Welcome Back',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: colors.onSurface,
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Sign in to continue managing your wallet.',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),

                          const SizedBox(height: 16),

                          CustomTextField(
                            label: 'Email',
                            hintText: 'you@example.com',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 12),

                          CustomTextField(
                            label: 'Password',
                            hintText: '••••••••',
                            controller: _password,
                            obscureText: !_showPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          PrimaryButton(
                            label: 'Sign In',
                            loading: c.isLoading,
                            onPressed: c.isLoading ? null : () => _login(c),
                          ),

                          const SizedBox(height: 8),

                          OutlinedButton.icon(
                            onPressed: c.isLoading ? null : () => _google(c),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Sign In with Google'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          OutlinedButton.icon(
                            onPressed: (c.isLoading || _biometricLocked)
                                ? null
                                : () => _biometric(c),
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('Sign In with Biometrics'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          if (_biometricLocked)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Biometric disabled after 3 failed attempts. Use Google or Email/Password.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.error,
                                ),
                              ),
                            ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: c.isLoading
                                    ? null
                                    : () => context.go('/register'),
                                child: const Text('Create account'),
                              ),
                              TextButton(
                                onPressed: c.isLoading
                                    ? null
                                    : () => context.push('/forgot-password'),
                                child: const Text('Forgot password?'),
                              ),
                            ],
                          ),

                          if (c.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                c.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          width: 184,
          height: 184,
          child: Image.asset(
            AppAssets.getAppLogo(isDark),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              AppAssets.appLogoLight,
              fit: BoxFit.contain,
            ),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Smart Pocket',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: colors.onSurface,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          'Track. Plan. Grow.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
