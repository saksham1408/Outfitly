import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/style_profile_service.dart';
import '../domain/style_profile.dart';

/// 3-step onboarding quiz that captures the bare-minimum signals a
/// stylist needs to start tailoring advice — body type, skin tone,
/// and the occasions the user actually dresses for.
///
/// Driven by a [PageView] (not a Stepper) so each step gets the full
/// screen for breathing room. The user can swipe back to retake a
/// step OR tap the chevron in the AppBar — both routes update the
/// page index, never the underlying selection.
///
/// On completion the answers are upserted into `style_profiles` and
/// `onCompleted` is called with the persisted [StyleProfile]. The
/// gate that hosts this screen (the AI tab) flips to the chat UI on
/// the next frame — we don't navigate ourselves so the host can
/// decide what "after the quiz" means in its context (e.g. push the
/// chat in a subroute or just rebuild the tab body).
class StyleQuizScreen extends StatefulWidget {
  /// Called once with the saved profile when the user finishes the
  /// last step and the upsert succeeds. The widget itself does NOT
  /// pop or navigate — the caller decides what happens next.
  final ValueChanged<StyleProfile>? onCompleted;

  const StyleQuizScreen({super.key, this.onCompleted});

  @override
  State<StyleQuizScreen> createState() => _StyleQuizScreenState();
}

class _StyleQuizScreenState extends State<StyleQuizScreen> {
  final _service = StyleProfileService();
  final _pageController = PageController();

  // ── Step data ──────────────────────────────────────────────
  // Body types are presented as visual cards. We pick a small,
  // self-describing set rather than the full medical taxonomy —
  // a non-fashion-literate user has to recognise themselves at a
  // glance and "Apple" / "Mesomorph" don't pass that bar.
  static const _bodyTypes = <_BodyOption>[
    _BodyOption(
      key: 'Athletic',
      label: 'Athletic',
      blurb: 'Toned, broader shoulders',
      icon: Icons.fitness_center_rounded,
    ),
    _BodyOption(
      key: 'Slim',
      label: 'Slim',
      blurb: 'Lean, lighter frame',
      icon: Icons.straighten_rounded,
    ),
    _BodyOption(
      key: 'Broad',
      label: 'Broad',
      blurb: 'Stronger torso, square build',
      icon: Icons.account_box_rounded,
    ),
    _BodyOption(
      key: 'Curvy',
      label: 'Curvy',
      blurb: 'Defined waist, soft curves',
      icon: Icons.water_drop_rounded,
    ),
    _BodyOption(
      key: 'Plus-Size',
      label: 'Plus-Size',
      blurb: 'Fuller figure, generous fit',
      icon: Icons.favorite_rounded,
    ),
    _BodyOption(
      key: 'Average',
      label: 'Average',
      blurb: 'In-between, no strong shape',
      icon: Icons.accessibility_new_rounded,
    ),
  ];

  // Six skin-tone swatches sampled across a Fitzpatrick-ish scale.
  // Stored by name (not hex) so the chat prompt reads naturally —
  // "warm-medium skin tone" is more useful to Gemini than a hex
  // code Gemini would have to interpret.
  static const _skinTones = <_SkinToneOption>[
    _SkinToneOption(key: 'Fair', swatch: Color(0xFFF8DDC3)),
    _SkinToneOption(key: 'Light', swatch: Color(0xFFEFC7A0)),
    _SkinToneOption(key: 'Warm Medium', swatch: Color(0xFFD9A27E)),
    _SkinToneOption(key: 'Olive', swatch: Color(0xFFB07A52)),
    _SkinToneOption(key: 'Brown', swatch: Color(0xFF8B5A36)),
    _SkinToneOption(key: 'Deep', swatch: Color(0xFF503018)),
  ];

  static const _occasions = <String>[
    'Office',
    'Weddings',
    'Casual',
    'Parties',
    'Festive',
    'Date Night',
    'Travel',
    'Workout',
  ];

  // ── State ──────────────────────────────────────────────────
  int _step = 0;
  String? _bodyType;
  String? _skinTone;
  final Set<String> _selectedOccasions = {};
  bool _saving = false;

  bool get _isLast => _step == 2;

  bool get _stepHasSelection {
    switch (_step) {
      case 0:
        return _bodyType != null;
      case 1:
        return _skinTone != null;
      case 2:
        return _selectedOccasions.isNotEmpty;
      default:
        return false;
    }
  }

  void _next() {
    if (!_stepHasSelection) return;

    if (_isLast) {
      _save();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final saved = await _service.save(
        bodyType: _bodyType!,
        skinTone: _skinTone!,
        occasions: _selectedOccasions.toList(),
      );
      if (!mounted) return;
      widget.onCompleted?.call(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save your style profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / 3;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: _back,
              )
            : null,
        title: Text(
          'Step ${_step + 1} of 3',
          style: AppTypography.labelMedium,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Progress bar ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── PageView ──
            // physics is NeverScrollable so the user can't swipe
            // past a step they haven't answered yet — the only way
            // forward is the validated bottom CTA.
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _buildBodyStep(),
                  _buildSkinStep(),
                  _buildOccasionStep(),
                ],
              ),
            ),

            // ── Bottom CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                AppSpacing.lg,
              ),
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      (_stepHasSelection && !_saving) ? _next : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.border.withAlpha(120),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isLast ? 'START STYLING ME' : 'CONTINUE',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Body type ───────────────────────────────────────
  Widget _buildBodyStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        _stepHeader(
          eyebrow: 'YOUR FRAME',
          title: 'How would you describe\nyour body type?',
          subtitle:
              'Pick the silhouette that feels closest to you. We use this to recommend cuts that flatter your shape.',
        ),
        const SizedBox(height: AppSpacing.xl),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.95,
          ),
          itemCount: _bodyTypes.length,
          itemBuilder: (context, i) {
            final opt = _bodyTypes[i];
            final selected = _bodyType == opt.key;
            return _BodyTypeCard(
              option: opt,
              selected: selected,
              onTap: () => setState(() => _bodyType = opt.key),
            );
          },
        ),
      ],
    );
  }

  // ── Step 2: Skin tone ───────────────────────────────────────
  Widget _buildSkinStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        _stepHeader(
          eyebrow: 'YOUR PALETTE',
          title: 'Which swatch is\nclosest to your skin?',
          subtitle:
              'Helps us recommend colours that complement (rather than wash out) your natural tone.',
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _skinTones.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, i) {
              final opt = _skinTones[i];
              final selected = _skinTone == opt.key;
              return _SkinToneSwatch(
                option: opt,
                selected: selected,
                onTap: () => setState(() => _skinTone = opt.key),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Step 3: Occasions ───────────────────────────────────────
  Widget _buildOccasionStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.lg,
      ),
      children: [
        _stepHeader(
          eyebrow: 'YOUR LIFE',
          title: 'Where do you usually\ndress up for?',
          subtitle:
              'Pick everything that applies. The more you tell us, the better we can tailor recommendations.',
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _occasions.map((occ) {
            final selected = _selectedOccasions.contains(occ);
            return ChoiceChip(
              label: Text(occ),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  if (selected) {
                    _selectedOccasions.remove(occ);
                  } else {
                    _selectedOccasions.add(occ);
                  }
                });
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              labelStyle: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? Colors.white : AppColors.textPrimary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _stepHeader({
    required String eyebrow,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: GoogleFonts.newsreader(
            fontSize: 28,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 13,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Step 1 helpers ─────────────────────────────────────────────

class _BodyOption {
  final String key;
  final String label;
  final String blurb;
  final IconData icon;

  const _BodyOption({
    required this.key,
    required this.label,
    required this.blurb,
    required this.icon,
  });
}

class _BodyTypeCard extends StatelessWidget {
  final _BodyOption option;
  final bool selected;
  final VoidCallback onTap;

  const _BodyTypeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withAlpha(12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                option.icon,
                size: 22,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.blurb,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 2 helpers ─────────────────────────────────────────────

class _SkinToneOption {
  final String key;
  final Color swatch;

  const _SkinToneOption({required this.key, required this.swatch});
}

class _SkinToneSwatch extends StatelessWidget {
  final _SkinToneOption option;
  final bool selected;
  final VoidCallback onTap;

  const _SkinToneSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: option.swatch,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(40),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            option.key,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
