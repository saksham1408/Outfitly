import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme.dart';

/// Step 1 of the AI Look Recreator flow.
///
/// Three jobs, top-to-bottom:
///   1. Pick an inspiration photo (camera or gallery)
///   2. Pick a budget bracket
///   3. Pick the occasion tweak
///
/// Tapping the primary CTA hands a tuple of (File, budget, occasion)
/// off to [AnalyzingLookScreen] via the `extra` payload of the
/// `/recreate-look/analyzing` route. We use `pushReplacement` from the
/// CTA so the back gesture from the analyzer drops the user back at
/// the home tab — not at this empty form they already submitted.
class RecreateLookScreen extends StatefulWidget {
  const RecreateLookScreen({super.key});

  @override
  State<RecreateLookScreen> createState() => _RecreateLookScreenState();
}

/// Carrier for the (image, budget, occasion) tuple handed to the
/// analyzing screen via `state.extra`. A typed value is safer than a
/// `Map<String,dynamic>` — the analyzer screen casts once, not field
/// by field.
class RecreateLookRequest {
  const RecreateLookRequest({
    required this.image,
    required this.budget,
    required this.occasion,
  });

  final File image;
  final String budget;
  final String occasion;
}

class _RecreateLookScreenState extends State<RecreateLookScreen> {
  static const _budgetOptions = <String>[
    'Under ₹2000',
    'Under ₹5000',
    'No Limit',
  ];
  static const _occasionOptions = <String>[
    'Exact Match',
    'Make it Wedding-Appropriate',
    'Make it Casual',
  ];

  File? _image;
  String _budget = _budgetOptions.last;       // "No Limit" — least surprising default
  String _occasion = _occasionOptions.first;  // "Exact Match"
  bool _picking = false;

  Future<void> _pickFromGallery() => _pick(ImageSource.gallery);
  Future<void> _pickFromCamera()  => _pick(ImageSource.camera);

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      // 2048-px cap keeps the upload under a few hundred KB after
      // JPEG re-encode. Quality 88 is invisible-to-the-eye lossy and
      // halves payload size again — meaningful on slower networks.
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _image = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load image: $e')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.primary),
              title: Text('Take a Photo',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFromCamera();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final image = _image;
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an inspiration photo first.')),
      );
      return;
    }
    context.pushReplacement(
      '/recreate-look/analyzing',
      extra: RecreateLookRequest(
        image: image,
        budget: _budget,
        occasion: _occasion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Recreate a Look',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(),
            const SizedBox(height: 24),
            _UploadDropzone(
              image: _image,
              picking: _picking,
              onTap: _chooseSource,
            ),
            const SizedBox(height: 28),
            _SectionLabel('BUDGET LIMIT'),
            const SizedBox(height: 10),
            _ChipRow(
              options: _budgetOptions,
              selected: _budget,
              onSelect: (v) => setState(() => _budget = v),
            ),
            const SizedBox(height: 24),
            _SectionLabel('OCCASION TWEAK'),
            const SizedBox(height: 10),
            _ChipRow(
              options: _occasionOptions,
              selected: _occasion,
              onSelect: (v) => setState(() => _occasion = v),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _image == null ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border.withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                '✨  REVERSE ENGINEER THIS LOOK',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Hero — pitch line at the top of the screen
// ────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.accentContainer, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'AI LOOK RECREATOR',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: AppColors.accentContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Saw a look you love?',
            style: GoogleFonts.newsreader(
              fontSize: 26,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload a photo. Our AI tailor will reverse-engineer the fabric, '
            'collar, and cut — then build you a custom version on budget.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: Colors.white.withAlpha(190),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Upload dropzone — empty state vs. preview
// ────────────────────────────────────────────────────────────
class _UploadDropzone extends StatelessWidget {
  const _UploadDropzone({
    required this.image,
    required this.picking,
    required this.onTap,
  });

  final File? image;
  final bool picking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: picking ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 280,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: image == null
                ? AppColors.accent.withAlpha(80)
                : AppColors.accent,
            width: image == null ? 1.4 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null ? _emptyState() : _previewState(image!),
      ),
    );
  }

  Widget _emptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cloud_upload_outlined,
              color: AppColors.accent, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          'Upload Inspiration Photo',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'A clear, front-on photo works best — celebrity outfits, Pinterest pins, screenshots.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewState(File file) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(file, fit: BoxFit.cover),
        // Bottom gradient so the "tap to change" hint reads on any photo.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withAlpha(0),
                  Colors.black.withAlpha(140),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 14,
          right: 16,
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                'Tap to choose a different photo',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// Section label + chip row
// ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              opt,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
