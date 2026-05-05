import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';

/// Top-of-screen step indicator shared by every wizard page.
/// Three dots — Garments / Fabric / Sizes — with the current
/// step expanded into a pill so users always know where they
/// are in the flow.
///
/// `currentStep` is 0-indexed: 0 = Garments, 1 = Fabric, 2 = Size.
class ComboWizardSteps extends StatelessWidget {
  const ComboWizardSteps({super.key, required this.currentStep});

  final int currentStep;

  static const List<String> _labels = [
    'Garments',
    'Fabric',
    'Sizes',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            _StepDot(
              index: i,
              label: _labels[i],
              state: i == currentStep
                  ? _DotState.current
                  : i < currentStep
                      ? _DotState.done
                      : _DotState.upcoming,
            ),
            if (i < _labels.length - 1)
              Container(
                width: 14,
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppColors.primary.withAlpha(40),
              ),
          ],
        ],
      ),
    );
  }
}

enum _DotState { done, current, upcoming }

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.state,
  });

  final int index;
  final String label;
  final _DotState state;

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == _DotState.current;
    final isDone = state == _DotState.done;
    final color = isCurrent || isDone
        ? AppColors.primary
        : AppColors.primary.withAlpha(40);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCurrent ? 12 : 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isCurrent ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: !isCurrent ? Border.all(color: color) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDone)
            const Icon(Icons.check_rounded, size: 12, color: AppColors.primary)
          else
            Text(
              '${index + 1}',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isCurrent ? Colors.white : color,
              ),
            ),
          if (isCurrent) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared bottom-of-screen primary action used on every wizard
/// step. Renders disabled (greyed + secondary copy explaining
/// what's missing) until the parent's `enabled` flag flips
/// true. Floating so it always sits above the keyboard / home
/// indicator.
class ComboWizardFooter extends StatelessWidget {
  const ComboWizardFooter({
    super.key,
    required this.primary,
    required this.secondary,
    required this.enabled,
    required this.onTap,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String primary;
  final String secondary;
  final bool enabled;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.primary
                  : AppColors.primary.withAlpha(70),
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(60),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        primary,
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        secondary,
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
