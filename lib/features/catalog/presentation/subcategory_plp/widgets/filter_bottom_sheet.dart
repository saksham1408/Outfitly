import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/theme.dart';
import '../../../models/product_filters.dart';

/// Opens the full-height dual-pane Filter bottom sheet.
/// Returns the new filter state if user taps APPLY, or null if dismissed.
Future<ProductFilters?> showFilterBottomSheet(
  BuildContext context, {
  required ProductFilters current,
}) {
  return showModalBottomSheet<ProductFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final ProductFilters initial;

  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ProductFilters _working;
  FilterCategory _selectedCategory = FilterCategory.quickFilters;

  // Myntra-style pink/red for clear+apply accents.
  static const _accentPink = Color(0xFFE91E63);

  @override
  void initState() {
    super.initState();
    _working = widget.initial.copy();
  }

  void _toggleOption(String option) {
    final set = _working.selectedOptions[_selectedCategory]!;
    setState(() {
      if (_selectedCategory.isSingleSelect) {
        // Radio behavior — replace
        set
          ..clear()
          ..add(option);
      } else {
        if (set.contains(option)) {
          set.remove(option);
        } else {
          set.add(option);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withAlpha(120),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _working.clearAll()),
                  style: TextButton.styleFrom(
                    foregroundColor: _accentPink,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    'CLEAR ALL',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: _accentPink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body (Dual Pane) ──
          Expanded(
            child: Row(
              children: [
                // Left pane: filter categories
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey[100],
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: FilterCategory.values.length,
                      itemBuilder: (context, index) {
                        final cat = FilterCategory.values[index];
                        final isSelected = cat == _selectedCategory;
                        final selectedCount =
                            _working.selectedOptions[cat]?.length ?? 0;

                        return InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : null,
                              border: Border(
                                left: BorderSide(
                                  color: isSelected
                                      ? _accentPink
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.label,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                if (selectedCount > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '$selectedCount selected',
                                    style: GoogleFonts.manrope(
                                      fontSize: 11,
                                      color: _accentPink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Right pane: options for selected category
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.white,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _selectedCategory.options.length,
                      itemBuilder: (context, index) {
                        final option = _selectedCategory.options[index];
                        final isSelected = _working
                                .selectedOptions[_selectedCategory]
                                ?.contains(option) ??
                            false;

                        if (_selectedCategory.isSingleSelect) {
                          return RadioListTile<String>(
                            value: option,
                            groupValue: _working
                                .selectedOptions[_selectedCategory]
                                ?.firstOrNull,
                            onChanged: (v) {
                              if (v != null) _toggleOption(v);
                            },
                            title: Text(
                              option,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            activeColor: _accentPink,
                            controlAffinity: ListTileControlAffinity.trailing,
                            dense: true,
                          );
                        }

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => _toggleOption(option),
                          title: Text(
                            option,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          activeColor: _accentPink,
                          checkColor: Colors.white,
                          controlAffinity: ListTileControlAffinity.trailing,
                          dense: true,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Footer ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: AppColors.border.withAlpha(120),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: Center(
                          child: Text(
                            'CLOSE',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.border.withAlpha(120),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(_working),
                        child: Center(
                          child: Text(
                            'APPLY',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: _accentPink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
