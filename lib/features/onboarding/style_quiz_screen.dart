import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/supabase_client.dart';
import '../../core/theme/theme.dart';
import 'style_quiz_data.dart';

class StyleQuizScreen extends StatefulWidget {
  const StyleQuizScreen({super.key});

  @override
  State<StyleQuizScreen> createState() => _StyleQuizScreenState();
}

class _StyleQuizScreenState extends State<StyleQuizScreen> {
  final _client = AppSupabase.client;
  int _currentStep = 0;
  bool _saving = false;

  // Selections: one set per step.
  final List<Set<String>> _selections = List.generate(
    quizSteps.length,
    (_) => <String>{},
  );

  QuizStep get _step => quizSteps[_currentStep];
  bool get _isLastStep => _currentStep == quizSteps.length - 1;
  bool get _isBudgetStep => _step.dbField == 'budget_range';

  void _toggleOption(String option) {
    setState(() {
      if (_isBudgetStep) {
        // Single select for budget.
        _selections[_currentStep] = {option};
      } else {
        final set = _selections[_currentStep];
        if (set.contains(option)) {
          set.remove(option);
        } else {
          set.add(option);
        }
      }
    });
  }

  void _next() {
    if (_selections[_currentStep].isEmpty) return;

    if (_isLastStep) {
      _saveAndContinue();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _saveAndContinue() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      // Ensure profile row exists (in case trigger didn't fire).
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
      });

      final Map<String, dynamic> data = {'user_id': user.id};
      for (int i = 0; i < quizSteps.length; i++) {
        final step = quizSteps[i];
        if (step.dbField == 'budget_range') {
          data[step.dbField] = _selections[i].first;
        } else {
          data[step.dbField] = _selections[i].toList();
        }
      }

      await _client
          .from('style_preferences')
          .upsert(data, onConflict: 'user_id');

      // Mark onboarding complete.
      await _client
          .from('profiles')
          .update({'onboarding_complete': true})
          .eq('id', user.id);

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      debugPrint('Style quiz save error: $e');
      if (!mounted) return;

      // Still navigate to home — preferences can be set later.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferences saved partially. You can update later.'),
        ),
      );
      context.go('/home');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / quizSteps.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: _back,
              )
            : null,
        title: Text(
          '${_currentStep + 1} of ${quizSteps.length}',
          style: AppTypography.labelMedium,
        ),
        actions: [
          if (!_isLastStep)
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text(
                'Skip',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Progress Bar ──
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Title ──
            Text(_step.title, style: AppTypography.displaySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _step.subtitle,
              style: AppTypography.bodyMedium,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Options Grid ──
            Expanded(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _step.options.map((option) {
                  final selected =
                      _selections[_currentStep].contains(option);
                  return ChoiceChip(
                    label: Text(option),
                    selected: selected,
                    onSelected: (_) => _toggleOption(option),
                    selectedColor: AppColors.primary,
                    labelStyle: AppTypography.labelLarge.copyWith(
                      color: selected
                          ? AppColors.textOnPrimary
                          : AppColors.textPrimary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── CTA ──
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _selections[_currentStep].isEmpty || _saving
                    ? null
                    : _next,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : Text(_isLastStep ? 'Finish' : 'Continue'),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
