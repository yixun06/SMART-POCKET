import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../application/controllers/authentication_controller.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/forms/custom_text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register(AuthenticationController c) async {
    if (_password.text.trim() != _confirmPassword.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password confirmation does not match.')),
      );
      return;
    }

    final result =
        await c.registerWithEmail(_email.text.trim(), _password.text.trim());

    if (!mounted) return;

    if (result.success) {
      context.go(result.needsSurvey ? '/smart-survey' : '/dashboard');
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
              child: Card(
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
                          'Create Account',
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
                          'Start your Smart Pocket journey.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                          ),
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
                        hintText:
                            'At least 8 characters with letters and numbers',
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

                      const SizedBox(height: 12),

                      CustomTextField(
                        label: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        controller: _confirmPassword,
                        obscureText: !_showConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _showConfirmPassword =
                                  !_showConfirmPassword;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      PrimaryButton(
                        label: 'Create Account',
                        loading: c.isLoading,
                        onPressed:
                            c.isLoading ? null : () => _register(c),
                      ),

                      TextButton(
                        onPressed:
                            c.isLoading ? null : () => context.go('/login'),
                        child: const Text('Back to login'),
                      ),

                      if (c.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            c.errorMessage!,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
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