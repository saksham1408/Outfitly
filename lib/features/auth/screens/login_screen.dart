import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/money.dart';
import '../../../core/theme/theme.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _staySignedIn = false;
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Apply the country saved on the user's profile to Money before
      // navigating off the auth flow. We pass the value through
      // unconditionally — `null` is meaningful here, it tells Money to
      // *clear* any leftover override (e.g. from a previous user's
      // session on the same device) and fall back to device locale.
      // Without this, an Indian user logging in on a phone that last
      // hosted a French registration would keep seeing € prices.
      final savedCountry = await _authService.fetchSavedCountry();
      await Money.instance.setOverrideCountry(savedCountry);

      if (!mounted) return;
      final onboarded = await _authService.isOnboardingComplete();
      if (!mounted) return;
      context.go(onboarded ? '/home' : '/style-quiz');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid') || msg.contains('credentials')) {
        setState(() => _error = 'Invalid email or password');
      } else {
        setState(() => _error = 'Login failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        color: AppColors.border,
        fontWeight: FontWeight.w300,
        fontSize: 16,
      ),
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.error, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background Image ──
          Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuC5dWY5Ev0J_6xZjdFuutLvkuDtVql2dZjDQi4A1YnwglEBJMbMsEJ_7f6Eh_cM59K_4YkswXOWAhDw6wwLzNR8YJ2YMCUL8g97E7Rx577rXhYl0Em0rxrgyZ_1iQFutjhpXmav3QDTl0G34k7aKCU-4GB4z-aB8tTOrRWHRDzpDHS4Gefh0PFCJhv3iSJ7JFvNNrmTZOsQz5q2PwMu4JmX9Wrv95x063eb-JfJAu1Z557-5SMRRjwjnONtv9iiZlKEY_mFmWUBPxU',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: AppColors.primary),
          ),
          // ── Dark overlay ──
          Container(color: Colors.black.withAlpha(50)),

          // ── Content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // ── Brand ──
                  Text(
                    'VASTRAHUB',
                    style: GoogleFonts.newsreader(
                      fontSize: 48,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      height: 0.9,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(height: 2, width: 96, color: AppColors.accent),
                  const SizedBox(height: 16),
                  Text(
                    'Measured twice, cut once. Returning to your private collection of refined measurements and timeless silhouettes.',
                    style: GoogleFonts.newsreader(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withAlpha(230),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Glass Card ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.glassBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.glassBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Title ──
                              Text(
                                'Login',
                                style: GoogleFonts.newsreader(
                                  fontSize: 30,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Access your measurements and order history.',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),

                              const SizedBox(height: 32),

                              // ── Email ──
                              Text(
                                'EMAIL ADDRESS',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: _inputDecoration('tailor@atelier.com'),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (!v.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // ── Password ──
                              Text(
                                'PASSWORD OR OTP',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: _inputDecoration('••••••••').copyWith(
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // ── Stay Signed In + Forgot ──
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _staySignedIn = !_staySignedIn,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            value: _staySignedIn,
                                            onChanged: (v) => setState(
                                              () => _staySignedIn = v ?? false,
                                            ),
                                            activeColor: AppColors.primary,
                                            side: const BorderSide(
                                              color: AppColors.border,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Stay Signed In',
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.push('/forgot-password'),
                                    child: Text(
                                      'Forgot Code?',
                                      style: GoogleFonts.manrope(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // ── Error ──
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    color: AppColors.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],

                              const SizedBox(height: 24),

                              // ── Login Button ──
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 8,
                                    shadowColor: AppColors.primary.withAlpha(80),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'LOGIN',
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 3,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── Divider ──
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: AppColors.border.withAlpha(80),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'OR CONTINUE WITH',
                                      style: GoogleFonts.manrope(
                                        fontSize: 10,
                                        letterSpacing: 2,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: AppColors.border.withAlpha(80),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ── Social / OTP Buttons ──
                              Row(
                                children: [
                                  Expanded(
                                    child: _socialButton(
                                      icon: Icons.mail_outline,
                                      label: 'EMAIL OTP',
                                      onTap: () => context.push('/otp-login'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _socialButton(
                                      icon: Icons.g_mobiledata_rounded,
                                      label: 'GOOGLE',
                                      onTap: () {},
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 28),

                              // ── Sign Up Link ──
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'New to the Atelier? ',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.go('/register'),
                                      child: Text(
                                        'Sign up',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                          decoration: TextDecoration.underline,
                                          decorationColor:
                                              AppColors.accent.withAlpha(80),
                                          decorationThickness: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Footer ──
                  Center(
                    child: Text(
                      '© MMXXIV VASTRAHUB • BESPOKE TAILORING',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        letterSpacing: 4,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(50)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
