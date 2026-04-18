import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme.dart';
import '../../catalog/catalog_service.dart';
import '../../catalog/models/product_model.dart';
import '../../checkout/models/order_payload.dart';
import '../data/design_storage_service.dart';
import '../models/customization_options.dart';
import '../models/design_selection.dart';
import '../widgets/fabric_selector.dart';
import '../widgets/option_tile.dart';

class DesignStudioScreen extends StatefulWidget {
  final String productId;

  const DesignStudioScreen({super.key, required this.productId});

  @override
  State<DesignStudioScreen> createState() => _DesignStudioScreenState();
}

class _DesignStudioScreenState extends State<DesignStudioScreen> {
  final _catalogService = CatalogService();
  final _storageService = DesignStorageService();
  late final DesignSelection _selection;

  ProductModel? _product;
  bool _loading = true;

  // Upload state (only used when the product is in Embroidery)
  XFile? _pickedImage;
  bool _uploading = false;

  // 0 = fabric, 1..N = customization steps, N+1 = upload (embroidery only)
  int _currentStep = 0;

  bool get _hasUploadStep => _product?.isEmbroidery ?? false;

  int get _totalSteps =>
      1 + allCustomizationSteps.length + (_hasUploadStep ? 1 : 0);

  bool get _isUploadStep =>
      _hasUploadStep && _currentStep == 1 + allCustomizationSteps.length;

  @override
  void initState() {
    super.initState();
    _selection = DesignSelection(productId: widget.productId);
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final p = await _catalogService.getProduct(widget.productId);
    if (!mounted) return;
    setState(() {
      _product = p;
      _loading = false;
    });
  }

  void _setStepSelection(int step, String id) {
    setState(() {
      if (step == 0) {
        _selection.fabricId = id;
      } else {
        final customStep = allCustomizationSteps[step - 1];
        if (customStep == collarOptions) _selection.collarId = id;
        if (customStep == sleeveOptions) _selection.sleeveId = id;
        if (customStep == pocketOptions) _selection.pocketId = id;
        if (customStep == fitOptions) _selection.fitId = id;
        if (customStep == monogramOptions) _selection.monogramId = id;
      }
    });
  }

  String? _getStepSelection(int step) {
    if (step == 0) return _selection.fabricId;
    if (step - 1 >= allCustomizationSteps.length) return null;
    final customStep = allCustomizationSteps[step - 1];
    if (customStep == collarOptions) return _selection.collarId;
    if (customStep == sleeveOptions) return _selection.sleeveId;
    if (customStep == pocketOptions) return _selection.pocketId;
    if (customStep == fitOptions) return _selection.fitId;
    if (customStep == monogramOptions) return _selection.monogramId;
    return null;
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _goToMeasurements();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _pickAndUpload() async {
    try {
      final picked = await _storageService.pickFromGallery();
      if (picked == null) return;

      setState(() {
        _pickedImage = picked;
        _uploading = true;
      });

      final url = await _storageService.uploadCustomDesign(picked);
      if (!mounted) return;

      setState(() {
        _selection.customEmbroideryUrl = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pickedImage = null;
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  void _removeCustomImage() {
    setState(() {
      _pickedImage = null;
      _selection.customEmbroideryUrl = null;
    });
  }

  void _goToMeasurements() {
    final product = _product;
    if (product == null) return;

    // Fold the design choices into an OrderPayload so the rest of the
    // funnel (measurements → cart → checkout) operates on a single
    // typed contract.
    final payload = OrderPayload(
      productName: product.name,
      price: product.basePrice,
      fabric: _selection.fabricId,
      imageUrl: product.images.isNotEmpty ? product.images.first : null,
      customEmbroideryUrl: _selection.customEmbroideryUrl,
    );
    context.push('/measurements/decision', extra: payload);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _product == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final product = _product!;
    final progress = (_currentStep + 1) / _totalSteps;

    // On the upload step the user can always proceed — uploading is
    // optional. On the other steps we require a selection.
    final hasSelection =
        _isUploadStep ? !_uploading : _getStepSelection(_currentStep) != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _back,
        ),
        title: Text(
          'Design Studio',
          style: AppTypography.titleLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.base),
            child: Text(
              '${_currentStep + 1}/$_totalSteps',
              style: AppTypography.labelMedium,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress ──
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
          ),

          // ── Preview Area ──
          Container(
            height: 240,
            width: double.infinity,
            margin: const EdgeInsets.all(AppSpacing.screenPadding),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.checkroom_rounded,
                  size: 80,
                  color: AppColors.textTertiary.withAlpha(60),
                ),
                Positioned(
                  bottom: AppSpacing.base,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(180),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Text(
                      product.name,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
                if (_selection.fabricId != null)
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _selection.fabricId!,
                        style: AppTypography.labelSmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Step Content ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: _buildStepBody(product),
            ),
          ),

          // ── Bottom CTA ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hasSelection ? _next : null,
                  child: Text(_ctaLabel()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ctaLabel() {
    if (_currentStep == _totalSteps - 1) return 'Next: Measurements';
    return 'Continue';
  }

  Widget _buildStepBody(ProductModel product) {
    if (_currentStep == 0) return _buildFabricStep(product);
    if (_isUploadStep) return _buildUploadStep();
    return _buildCustomizationStep(
      allCustomizationSteps[_currentStep - 1],
    );
  }

  Widget _buildFabricStep(ProductModel product) {
    return SingleChildScrollView(
      child: FabricSelector(
        fabrics: product.fabricOptions,
        selectedFabric: _selection.fabricId,
        onSelected: (fabric) => _setStepSelection(0, fabric),
      ),
    );
  }

  Widget _buildCustomizationStep(CustomizationStep step) {
    final selected = _getStepSelection(_currentStep);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step.title, style: AppTypography.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(step.subtitle, style: AppTypography.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.85,
            ),
            itemCount: step.options.length,
            itemBuilder: (context, index) {
              final option = step.options[index];
              return OptionTile(
                option: option,
                selected: selected == option.id,
                onTap: () => _setStepSelection(_currentStep, option.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUploadStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Custom Design (Optional)',
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Attach a reference image or artwork you want embroidered onto your garment. Our atelier will match colours, thread, and placement by hand.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_pickedImage == null)
            _UploadButton(onTap: _pickAndUpload)
          else
            _ThumbnailPreview(
              file: _pickedImage!,
              uploading: _uploading,
              onRemove: _removeCustomImage,
            ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.accent.withAlpha(30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'High-resolution PNG or JPG works best. Skip this step if you\'d prefer one of our house motifs.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Upload from Gallery',
              style: AppTypography.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Tap to browse your photos',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailPreview extends StatelessWidget {
  final XFile file;
  final bool uploading;
  final VoidCallback onRemove;

  const _ThumbnailPreview({
    required this.file,
    required this.uploading,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: _ThumbnailImage(file: file),
            ),
            if (uploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(110),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            if (!uploading)
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                uploading ? 'Uploading…' : 'Custom design ready',
                style: AppTypography.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  final XFile file;
  const _ThumbnailImage({required this.file});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: 96,
            height: 96,
            color: AppColors.surfaceVariant,
          );
        }
        return Image.memory(
          snapshot.data!,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
