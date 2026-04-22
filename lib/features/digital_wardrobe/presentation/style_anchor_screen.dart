import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme.dart';
import '../models/outfit_anchor_analysis.dart';
import '../services/outfit_designer_service.dart';

/// "Style a New Piece" — user uploads a single garment photo and the
/// Gemini Vision stylist returns 3 complete outfit ideas designed
/// around it.
///
/// Screen states:
///   * picking   — no image yet; show camera + gallery tap targets
///   * picked    — preview + "Design My Outfits" CTA
///   * analyzing — spinner + "Consulting your stylist…"
///   * results   — anchor summary + 3 outfit cards (vertical stack)
///
/// The results view is deliberately text-first with a color palette
/// row — we don't have imagery for AI-suggested items, and a clean
/// descriptive layout with the palette gives users enough to visualize
/// the look at a glance.
class StyleAnchorScreen extends StatefulWidget {
  const StyleAnchorScreen({super.key});

  @override
  State<StyleAnchorScreen> createState() => _StyleAnchorScreenState();
}

class _StyleAnchorScreenState extends State<StyleAnchorScreen> {
  final ImagePicker _picker = ImagePicker();
  final OutfitDesignerService _service = OutfitDesignerService();

  XFile? _picked;
  bool _analyzing = false;
  OutfitAnchorAnalysis? _result;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() {
        _picked = file;
        _result = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _analyze() async {
    final pick = _picked;
    if (pick == null || _analyzing) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      final bytes = await File(pick.path).readAsBytes();
      final mime = _mimeFor(pick.path);
      final analysis = await _service.designOutfitsAroundPiece(
        imageBytes: bytes,
        mimeType: mime,
      );
      if (!mounted) return;
      setState(() {
        _result = analysis;
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = 'Could not design outfits: $e';
      });
    }
  }

  void _reset() {
    setState(() {
      _picked = null;
      _result = null;
      _error = null;
    });
  }

  String _mimeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
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
          'Style a New Piece',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_analyzing) const _AnalyzingOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_result != null) return _buildResults(_result!);
    if (_picked == null) return _buildPicker();
    return _buildPreview();
  }

  // ── State 1: picker ─────────────────────────────────────────
  Widget _buildPicker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        // Hero card explaining the flow so users understand they're
        // NOT uploading to their wardrobe — this is about inspiration.
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent,
                AppColors.accent.withAlpha(215),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withAlpha(70),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI Outfit Builder',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Got a shirt, pant or shoes in mind?\nSnap it. We\'ll design 3 full looks around it.',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withAlpha(30),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 52,
                color: AppColors.primary.withAlpha(180),
              ),
              const SizedBox(height: 14),
              Text(
                'Upload one garment',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Works best with a clean, well-lit shot',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _PickTile(
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
                onTap: () => _pick(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PickTile(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => _pick(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── State 2: preview + design CTA ───────────────────────────
  Widget _buildPreview() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: Image.file(
                  File(_picked!.path),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withAlpha(140),
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _reset,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Change',
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _analyzing ? null : _analyze,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              'Design My Outfits',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'We\'ll suggest 3 complete outfit ideas designed around this piece.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }

  // ── State 3: results ────────────────────────────────────────
  Widget _buildResults(OutfitAnchorAnalysis analysis) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Anchor summary — small photo thumbnail + detection chips.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_picked != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 74,
                  height: 92,
                  child: Image.file(
                    File(_picked!.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your piece',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${analysis.anchor.color} ${analysis.anchor.type}',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _DetectChip(label: analysis.anchor.color),
                      _DetectChip(label: analysis.anchor.style),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SectionHeader(
          title: '${analysis.outfits.length} Outfit ideas',
          subtitle: 'Tailored around your piece',
        ),
        const SizedBox(height: 14),
        for (final outfit in analysis.outfits) ...[
          _OutfitIdeaCard(idea: outfit),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Try another piece',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withAlpha(40),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetectChip extends StatelessWidget {
  final String label;
  const _DetectChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withAlpha(100)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _OutfitIdeaCard extends StatelessWidget {
  final OutfitIdea idea;
  const _OutfitIdeaCard({required this.idea});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withAlpha(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idea.title,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    if (idea.occasion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        idea.occasion,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (idea.paletteColors.isNotEmpty)
                _PaletteStrip(colors: idea.paletteColors),
            ],
          ),
          const SizedBox(height: 14),
          if (idea.top != null)
            _PieceRow(slot: 'Top', description: idea.top!),
          if (idea.bottom != null)
            _PieceRow(slot: 'Bottom', description: idea.bottom!),
          if (idea.shoes != null)
            _PieceRow(slot: 'Shoes', description: idea.shoes!),
          if (idea.accessories.isNotEmpty)
            _PieceRow(
              slot: 'Accessories',
              description: idea.accessories.join(' · '),
            ),
          if (idea.reasoning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(28),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined,
                      size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      idea.reasoning,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.primary.withAlpha(220),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  final String slot;
  final String description;
  const _PieceRow({required this.slot, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              slot.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteStrip extends StatelessWidget {
  final List<int> colors;
  const _PaletteStrip({required this.colors});

  @override
  Widget build(BuildContext context) {
    const double dot = 16;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in colors.take(4))
          Container(
            width: dot,
            height: dot,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withAlpha(40),
                width: 1,
              ),
            ),
          ),
      ],
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: AppColors.background.withAlpha(210),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Consulting your stylist…',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Designing 3 looks around your piece',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
