import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../services/auth_service.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  String get _email => _emailController.text.trim();

  Future<void> _sendOtp() async {
    if (_email.isEmpty || !_email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.sendOtp(_email);
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = 'Failed to send OTP. Try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();
    if (token.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.verifyOtp(_email, token);

      if (!mounted) return;

      final onboarded = await _authService.isOnboardingComplete();
      if (!mounted) return;

      context.go(onboarded ? '/home' : '/style-quiz');
    } catch (e) {
      setState(() => _error = 'Invalid OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Login with OTP'),
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
                Icons.mark_email_read_outlined,
                size: 56,
                color: AppColors.accent,
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Email Input ──
              if (!_otpSent) ...[
                Text(
                  'Enter your email',
                  style: AppTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'We\'ll send a 6-digit code to your email',
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthTextField(
                  controller: _emailController,
                  hintText: 'you@example.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],

              // ── OTP Input ──
              if (_otpSent) ...[
                Text(
                  'Check your email',
                  style: AppTypography.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'OTP sent to $_email',
                        style: AppTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _otpSent = false;
                        _otpController.clear();
                        _error = null;
                      }),
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthTextField(
                  controller: _otpController,
                  hintText: '6-digit OTP',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
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
              AuthButton(
                label: _otpSent ? 'Verify OTP' : 'Send OTP',
                isLoading: _loading,
                onPressed: _otpSent ? _verifyOtp : _sendOtp,
              ),

              if (_otpSent)
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _sendOtp,
                    child: const Text('Resend OTP'),
                  ),
                ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
