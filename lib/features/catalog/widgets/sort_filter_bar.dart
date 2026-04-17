import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';

/// Sticky bottom action bar with SORT + FILTER — reusable across any PLP.
class SortFilterBar extends StatelessWidget {
  final VoidCallback onSortTap;
  final VoidCallback onFilterTap;
  final int activeFilterCount;

  const SortFilterBar({
    super.key,
    required this.onSortTap,
    required this.onFilterTap,
    this.activeFilterCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withAlpha(100), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Expanded(
                child: _BarButton(
                  icon: Icons.swap_vert_rounded,
                  label: 'SORT',
                  onTap: onSortTap,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppColors.border.withAlpha(100),
              ),
              Expanded(
                child: _BarButton(
                  icon: Icons.filter_alt_outlined,
                  label: 'FILTER',
                  badge: activeFilterCount > 0 ? '$activeFilterCount' : null,
                  onTap: onFilterTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: 10,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  badge!,
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
