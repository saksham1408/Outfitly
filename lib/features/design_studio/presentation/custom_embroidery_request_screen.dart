import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme.dart';
import '../data/custom_request_service.dart';
import '../data/design_storage_service.dart';

/// Bespoke "Design Your Own Embroidery" request form.
///
/// Users upload a reference image, pick a base garment, describe their
/// needs, and submit. On success, a row lands in `custom_requests` and
/// the image URL is stored in Supabase Storage — both visible in
/// Directus for the atelier.
class CustomEmbroideryRequestScreen extends StatefulWidget {
  const CustomEmbroideryRequestScreen({super.key});

  @override
  State<CustomEmbroideryRequestScreen> createState() =>
      _CustomEmbroideryRequestScreenState();
}

class _CustomEmbroideryRequestScreenState
    extends State<CustomEmbroideryRequestScreen> {
  final _storage = DesignStorageService();
  final _requestService = CustomRequestService();
  final _notesController = TextEditingController();

  XFile? _image;
  String? _selectedGarment;
  bool _submitting = false;

  static const List<String> _garments = [
    'Kurta',
    'Shirt',
    'Blazer',
    'Saree',
    'Dupatta',
    'Sherwani',
    'Other',
  ];

  bool get _canSubmit =>
      !_submitting &&
      _image != null &&
      _selectedGarment != null &&
      _notesController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _storage.pickFromGallery();
      if (picked == null) return;
      setState(() => _image = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
  }

  void _removeImage() => setState(() => _image = null);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await _requestService.submit(
        image: _image!,
        baseGarment: _selectedGarment!,
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e')),
      );
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Request received',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
        content: Text(
          'Our designers will review your request and reach out with a quote within 24 hours.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
            ),
            child: Text(
              'Done',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.primary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Custom Embroidery',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            _buildIntro(),
            const SizedBox(height: 24),
            _sectionLabel('YOUR DESIGN'),
            const SizedBox(height: 10),
            _buildImageArea(),
            const SizedBox(height: 28),
            _sectionLabel('SELECT BASE ITEM'),
            const SizedBox(height: 10),
            _buildGarmentChips(),
            const SizedBox(height: 28),
            _sectionLabel('DESCRIBE YOUR REQUIREMENTS'),
            const SizedBox(height: 10),
            _buildNotesField(),
            const SizedBox(height: 100),
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
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border.withAlpha(80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'SUBMIT CUSTOM REQUEST',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withAlpha(30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            color: AppColors.accent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bespoke by hand',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send us a reference and we\'ll hand-embroider it on the garment of your choice. Our atelier replies within 24 hours.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.textTertiary,
        ),
      );

  Widget _buildImageArea() {
    if (_image == null) {
      return _DashedUploadBox(onTap: _pickImage);
    }
    return _PickedImagePreview(
      file: _image!,
      onRemove: _removeImage,
      onChange: _pickImage,
    );
  }

  Widget _buildGarmentChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _garments.map((g) {
        final selected = _selectedGarment == g;
        return ChoiceChip(
          label: Text(g),
          selected: selected,
          onSelected: (_) => setState(() => _selectedGarment = g),
          labelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primary,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        );
      }).toList(),
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 5,
      style: GoogleFonts.manrope(fontSize: 14, height: 1.5),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText:
            'E.g., I want this design in gold thread on the left chest pocket…',
        hintStyle: GoogleFonts.manrope(
          color: AppColors.textTertiary,
          fontSize: 13,
          height: 1.5,
        ),
        filled: true,
        fillColor: AppColors.surfaceContainer,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Dashed-border upload call-to-action, shown before any image is chosen.
class _DashedUploadBox extends StatelessWidget {
  final VoidCallback onTap;
  const _DashedUploadBox({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.border,
          radius: 18,
          dashWidth: 6,
          dashSpace: 4,
          strokeWidth: 1.4,
        ),
        child: Container(
          height: 200,
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Upload Your Embroidery Design / Reference',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to browse your photos',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview card shown after an image is picked. Includes Change + Remove.
class _PickedImagePreview extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  final VoidCallback onChange;

  const _PickedImagePreview({
    required this.file,
    required this.onRemove,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return Container(
                  height: 220,
                  color: AppColors.surfaceVariant,
                );
              }
              return Image.memory(
                snap.data!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onChange,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Change'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Paints a rounded-rect dashed border (Flutter doesn't ship one).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace ||
      old.strokeWidth != strokeWidth;
}
