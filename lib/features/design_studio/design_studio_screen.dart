import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme.dart';
import '../catalog/catalog_service.dart';
import '../catalog/models/product_model.dart';
import 'models/customization_options.dart';
import 'models/design_selection.dart';
import 'widgets/fabric_selector.dart';
import 'widgets/option_tile.dart';

class DesignStudioScreen extends StatefulWidget {
  final String productId;

  const DesignStudioScreen({super.key, required this.productId});

  @override
  State<DesignStudioScreen> createState() => _DesignStudioScreenState();
}

class _DesignStudioScreenState extends State<DesignStudioScreen> {
  final _catalogService = CatalogService();
  late final DesignSelection _selection;

  ProductModel? _product;
  bool _loading = true;

  // 0 = fabric, 1..N = customization steps
  int _currentStep = 0;
  int get _totalSteps => allCustomizationSteps.length + 1; // +1 for fabric

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

  void _goToMeasurements() {
    context.push('/measurements/decision', extra: _selection);
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
    final hasSelection = _getStepSelection(_currentStep) != null;

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
                // Show selected fabric swatch
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
              child: _currentStep == 0
                  ? _buildFabricStep(product)
                  : _buildCustomizationStep(
                      allCustomizationSteps[_currentStep - 1],
                    ),
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
                  child: Text(
                    _currentStep == _totalSteps - 1
                        ? 'Next: Measurements'
                        : 'Continue',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
}
