import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../models/combo_catalog.dart';
import '../models/combo_draft.dart';
import 'combo_wizard_widgets.dart';

/// Step 2 of 3 — pick a single fabric for the entire coordinated
/// set. The whole point of a combo is that everyone wears the
/// same cloth (just cut to their silhouette), so we
/// deliberately don't allow per-member fabric overrides — that
/// would dilute the "matching family" framing.
class FabricSelectionScreen extends StatefulWidget {
  const FabricSelectionScreen({super.key, required this.draft});

  final ComboDraft draft;

  @override
  State<FabricSelectionScreen> createState() =>
      _FabricSelectionScreenState();
}

class _FabricSelectionScreenState extends State<FabricSelectionScreen> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.draft.fabric;
  }

  void _select(String name) => setState(() => _selected = name);

  void _continue() {
    final next = widget.draft.copyWith(fabric: _selected);
    context.push('/combos/size', extra: next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Fabric',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const ComboWizardSteps(currentStep: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                children: [
                  Text(
                    'Pick the cloth',
                    style: GoogleFonts.newsreader(
                      fontSize: 26,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                      height: 1.1,
                    ),
                  ),
                  Container(
                    height: 2,
                    width: 56,
                    margin: const EdgeInsets.only(top: 6),
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'One fabric for the whole roster — that\'s how the look stays coordinated.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Two-column grid of swatch cards. GridView
                  // shrinks to content because we're inside a
                  // ListView — `shrinkWrap: true` and
                  // `NeverScrollableScrollPhysics` so the outer
                  // list owns scrolling.
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: kFabricCatalog.length,
                    itemBuilder: (context, i) {
                      final fabric = kFabricCatalog[i];
                      return _FabricCard(
                        fabric: fabric,
                        selected: _selected == fabric.name,
                        onTap: () => _select(fabric.name),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ComboWizardFooter(
        primary: 'Continue · Pick sizes',
        secondary: _selected == null
            ? 'Pick a fabric to continue'
            : 'Set in $_selected — feels right',
        enabled: _selected != null,
        onTap: _continue,
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// One fabric swatch card. Top half is the colour swatch with
/// a glossy gradient so the cloth reads as material rather than
/// a flat colour chip. Bottom half is the name + tagline.
class _FabricCard extends StatelessWidget {
  const _FabricCard({
    required this.fabric,
    required this.selected,
    required this.onTap,
  });

  final FabricSwatch fabric;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Color(fabric.paletteColor);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : AppColors.primary.withAlpha(20),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Swatch — gradient over the palette colour gives
              // the cloth a sense of weight/depth without us
              // shipping per-fabric photography.
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              palette,
                              Color.alphaBlend(
                                Colors.black.withAlpha(60),
                                palette,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fabric.name,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fabric.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
