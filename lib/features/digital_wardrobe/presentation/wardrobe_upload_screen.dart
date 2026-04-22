import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme.dart';
import '../data/wardrobe_repository.dart';
import '../models/wardrobe_item.dart';

/// The "add a garment" flow:
///
///   1. If no photo yet → show a big capture card with Camera + Gallery
///      affordances.
///   2. Once a photo is captured → show a preview + ChoiceChip form
///      for Category / Color / Style.
///   3. Save → repository upload → success haptic + pop.
///
/// We keep camera + picker in the same screen (rather than pushing a
/// separate capture screen) so a user who realises the angle is bad
/// can re-shoot in one tap.
class WardrobeUploadScreen extends StatefulWidget {
  const WardrobeUploadScreen({super.key});

  @override
  State<WardrobeUploadScreen> createState() => _WardrobeUploadScreenState();
}

class _WardrobeUploadScreenState extends State<WardrobeUploadScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  XFile? _capturedFile;

  String _category = kWardrobeCategories.first; // Top
  String _color = kWardrobeColors.first; // Black
  String _style = kWardrobeStyles.first; // Casual

  bool _saving = false;
  bool _justSaved = false; // drives the success animation

  late final AnimationController _successCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
      if (file == null) return;
      if (!mounted) return;
      setState(() => _capturedFile = file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    final file = _capturedFile;
    if (file == null || _saving) return;
    setState(() => _saving = true);
    try {
      await WardrobeRepository.instance.uploadFromXFile(
        file: file,
        category: _category,
        color: _color,
        styleType: _style,
      );
      if (!mounted) return;

      // Play the success animation, then pop after it finishes so the
      // user sees the confirmation before being returned to the grid.
      setState(() => _justSaved = true);
      _successCtrl.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Upload failed: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
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
          'Add to Closet',
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
          _capturedFile == null ? _buildCaptureStart() : _buildPreviewForm(),
          if (_justSaved) _SuccessOverlay(controller: _successCtrl),
        ],
      ),
    );
  }

  /// First state: no photo yet. Two giant tap targets + tips so the
  /// user knows to lay the garment flat or hang it up.
  Widget _buildCaptureStart() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          height: 280,
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
                Icons.checkroom_rounded,
                size: 56,
                color: AppColors.primary.withAlpha(180),
              ),
              const SizedBox(height: 14),
              Text(
                'Photograph a piece from your closet',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Lay it flat on a bed or hang it on a door',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _CaptureButton(
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
                onTap: () => _pick(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CaptureButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => _pick(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _TipRow(
          icon: Icons.wb_sunny_outlined,
          text: 'Good light — natural daylight works best.',
        ),
        _TipRow(
          icon: Icons.crop_free_rounded,
          text: 'Fill the frame. Crop out furniture and clutter.',
        ),
        _TipRow(
          icon: Icons.texture_rounded,
          text: 'Plain background helps the AI pick colors correctly.',
        ),
      ],
    );
  }

  /// Second state: photo captured. Preview + categorize + save.
  Widget _buildPreviewForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Photo preview with a retake affordance in the corner.
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: Image.file(
                  File(_capturedFile!.path),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black.withAlpha(140),
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _saving
                      ? null
                      : () => setState(() => _capturedFile = null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Retake',
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

        _SectionHeader(title: 'Category'),
        const SizedBox(height: 8),
        _ChipGroup(
          options: kWardrobeCategories,
          selected: _category,
          onSelected: (v) => setState(() => _category = v),
        ),

        const SizedBox(height: 22),
        _SectionHeader(title: 'Color'),
        const SizedBox(height: 8),
        _ChipGroup(
          options: kWardrobeColors,
          selected: _color,
          onSelected: (v) => setState(() => _color = v),
          dense: true,
        ),

        const SizedBox(height: 22),
        _SectionHeader(title: 'Style'),
        const SizedBox(height: 8),
        _ChipGroup(
          options: kWardrobeStyles,
          selected: _style,
          onSelected: (v) => setState(() => _style = v),
        ),

        const SizedBox(height: 32),
        SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withAlpha(150),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
                    'Save to Digital Closet',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CaptureButton({
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

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.textTertiary,
      ),
    );
  }
}

/// Reusable ChoiceChip row with wrap-on-overflow. Used for Category,
/// Color, and Style pickers — deliberately simple so all three feel
/// visually identical.
class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool dense;

  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opt in options)
          ChoiceChip(
            label: Text(
              opt,
              style: GoogleFonts.manrope(
                fontSize: dense ? 12 : 12.5,
                fontWeight: FontWeight.w700,
                color:
                    opt == selected ? Colors.white : AppColors.primary,
              ),
            ),
            selected: opt == selected,
            onSelected: (_) => onSelected(opt),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: opt == selected
                  ? AppColors.primary
                  : AppColors.primary.withAlpha(50),
            ),
            showCheckmark: false,
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 10 : 12,
              vertical: dense ? 4 : 6,
            ),
          ),
      ],
    );
  }
}

/// Full-screen confirmation overlay played after a successful save.
/// Scales a check icon up from zero, fades the backdrop in, then the
/// parent pops — the user sees the "it worked" beat before being
/// returned to the closet.
class _SuccessOverlay extends StatelessWidget {
  final AnimationController controller;
  const _SuccessOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          final scale = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
          return Container(
            color: AppColors.primary.withAlpha((200 * t).toInt()),
            alignment: Alignment.center,
            child: Transform.scale(
              scale: 0.4 + 0.6 * scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 54,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Text(
                      'Added to your closet',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
