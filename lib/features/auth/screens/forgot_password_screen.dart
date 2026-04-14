import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../services/auth_service.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.resetPassword(email);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = 'Failed to send reset email. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),

              // ── Icon ──
              Icon(
                _sent ? Icons.check_circle_outline : Icons.lock_reset_rounded,
                size: 56,
                color: _sent ? AppColors.success : AppColors.accent,
              ),
              const SizedBox(height: AppSpacing.xl),

              if (!_sent) ...[
                Text(
                  'Forgot your password?',
                  style: AppTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enter your email and we\'ll send you\na link to reset your password.',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AuthTextField(
                  controller: _emailController,
                  hintText: 'Email Address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],

              if (_sent) ...[
                Text(
                  'Check your email',
                  style: AppTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'We\'ve sent a password reset link to\n${_emailController.text.trim()}',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],

              // ── Error ──
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── CTA ──
              if (!_sent)
                AuthButton(
                  label: 'Send Reset Link',
                  isLoading: _loading,
                  onPressed: _sendResetEmail,
                ),

              if (_sent)
                AuthButton(
                  label: 'Back to Login',
                  onPressed: () => context.go('/login'),
                ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
