import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  // Style selections
  final Set<String> _selectedStyles = {};
  String? _selectedInterest;

  static const _styleOptions = ['Traditional', 'Modern', 'Fusion'];
  static const _interestOptions = [
    ('Suiting', 'Formal & Business', Icons.architecture_rounded),
    ('Separates', 'Casual Tailoring', Icons.straighten_rounded),
  ];

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final fullName = _nameController.text.trim();
      final phone = '+91${_phoneController.text.trim()}';

      final location = _locationController.text.trim();

      final response = await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      final userId = response.user?.id;

      if (userId != null) {
        await _authService.upsertProfile(
          fullName: fullName,
          phone: phone,
          email: email,
          location: location.isNotEmpty ? location : null,
          preferredStyle: _selectedStyles.isNotEmpty
              ? _selectedStyles.toList()
              : null,
          initialInterest: _selectedInterest,
          userId: userId,
        );
      }

      if (!mounted) return;

      if (response.session != null) {
        context.go('/style-quiz');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Check your email to confirm, then login.',
            ),
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('already registered')) {
        setState(
          () => _error = 'This email is already registered. Try logging in.',
        );
      } else {
        setState(() => _error = 'Registration failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
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
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background ──
          Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuCbo2WxG0RLJ4PvFPdgpxEQIKNng8idyqUh4fSifS7ScOiWmPMzhNfE78Yk0lUOcD3-EfCs4o-jSf-NcULg9erJ278dEy0yzV9Y6oqqqY-49j3idzh2mcZUxp5RRrSO4D_xgXEBrGfpjsHhhSCW-EeNoLfcbJFd56vLOtcTDhsEj30cceETjEDVM_cHJnbWJoSFlBzmn9JUC95S-Ag8OmxTSa6uEbfmWFNxu1UWVTvgIl0AkDAy9fMEjMnJGW1VBsw8kYKx_cPzuW0',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: AppColors.background),
          ),

          // ── Content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Mobile Brand Header ──
                  Center(
                    child: Text(
                      'VASTRAHUB',
                      style: GoogleFonts.newsreader(
                        fontSize: 32,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Glass Panel ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.glassBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.glassBorder),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(12),
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
                              // ── Header ──
                              Text(
                                'Sign Up',
                                style: GoogleFonts.newsreader(
                                  fontSize: 34,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enter your details to begin your bespoke experience.',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Stitch line
                              Container(
                                height: 1,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.accent,
                                      width: 1,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── Full Name ──
                              _label('Full Name'),
                              TextFormField(
                                controller: _nameController,
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: _inputDecoration('Alexander McQueen'),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),

                              const SizedBox(height: 20),

                              // ── Email ──
                              _label('Email Address'),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.textPrimary,
                                ),
                                decoration:
                                    _inputDecoration('alexander@savilerow.com'),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (!v.contains('@')) return 'Invalid email';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // ── Phone ──
                              _label('Phone Number'),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      '+91',
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w300,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w300,
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration:
                                          _inputDecoration('98765 43210')
                                              .copyWith(counterText: ''),
                                      validator: (v) {
                                        if (v == null || v.trim().length != 10) {
                                          return 'Enter 10-digit number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ── Location ──
                              _label('Location / City'),
                              TextFormField(
                                controller: _locationController,
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: _inputDecoration('Mumbai, India'),
                              ),

                              const SizedBox(height: 20),

                              // ── Password ──
                              _label('Password'),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.textPrimary,
                                ),
                                decoration:
                                    _inputDecoration('••••••••').copyWith(
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
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
                                  if (v == null || v.length < 6) {
                                    return 'Min 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 28),

                              // ── Preferred Style ──
                              _label('Preferred Style'),
                              Row(
                                children: _styleOptions.map((style) {
                                  final selected =
                                      _selectedStyles.contains(style);
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (selected) {
                                            _selectedStyles.remove(style);
                                          } else {
                                            _selectedStyles.add(style);
                                          }
                                        });
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          right:
                                              style != _styleOptions.last
                                                  ? 8
                                                  : 0,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.surfaceContainerHigh
                                                  .withAlpha(130)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.accent
                                                : AppColors.border,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            style.toUpperCase(),
                                            style: GoogleFonts.manrope(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1,
                                              color: selected
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 24),

                              // ── Initial Interest ──
                              Text(
                                'INITIAL INTEREST',
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: _interestOptions.map((opt) {
                                  final selected =
                                      _selectedInterest == opt.$1;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(
                                        () => _selectedInterest = opt.$1,
                                      ),
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          right: opt != _interestOptions.last
                                              ? 12
                                              : 0,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? Colors.white.withAlpha(180)
                                              : Colors.white.withAlpha(100),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.accent
                                                : Colors.white.withAlpha(50),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              opt.$3,
                                              size: 20,
                                              color: AppColors.accent,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              opt.$1,
                                              style: GoogleFonts.manrope(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            Text(
                                              opt.$2,
                                              style: GoogleFonts.manrope(
                                                fontSize: 10,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
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
                                ),
                              ],

                              const SizedBox(height: 24),

                              // ── Sign Up Button ──
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 8,
                                    shadowColor:
                                        AppColors.primaryLight.withAlpha(50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
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
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'SIGN UP',
                                              style: GoogleFonts.manrope(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 3,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── Login Link ──
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account? ',
                                      style: GoogleFonts.manrope(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.go('/login'),
                                      child: Text(
                                        'Login',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accent,
                                          decoration:
                                              TextDecoration.underline,
                                          decorationThickness: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── Footer ──
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_user_outlined,
                                        size: 18,
                                        color: AppColors.border,
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          'Secured via VASTRAHUB Encrypted Protocol',
                                          style: GoogleFonts.manrope(
                                            fontSize: 9,
                                            color: AppColors.textSecondary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 32,
                                    color: AppColors.border.withAlpha(80),
                                  ),
                                  Text(
                                    'V 1.0.4 - CRAFTING PHASE',
                                    style: GoogleFonts.manrope(
                                      fontSize: 9,
                                      letterSpacing: 0.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
