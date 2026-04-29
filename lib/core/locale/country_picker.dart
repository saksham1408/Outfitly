import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme.dart';
import 'country_dial_codes.dart';

/// Modal bottom sheet for picking a country. Used in the register flow
/// (drives both phone-prefix and currency) and intentionally
/// stand-alone so a future "currency override" toggle on the profile
/// screen can reuse it verbatim.
///
/// Returns the selected ISO-2 code, or `null` if the user dismissed.
Future<String?> showCountryPicker(
  BuildContext context, {
  String? initialCode,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CountryPickerSheet(initialCode: initialCode),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({this.initialCode});
  final String? initialCode;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Case-insensitive, prefix-friendly match across the country name
  /// and the dial code (so typing "+44" or "uni" both surface the UK).
  List<CountryDialInfo> _filtered() {
    if (_query.isEmpty) return kCountryDialList;
    final q = _query.toLowerCase().trim();
    return kCountryDialList.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.dialCode.contains(q) ||
          c.code.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    // Sheet sized to ~85% so the search field stays above the keyboard
    // when it pops up; FractionallySizedBox is simpler than a custom
    // DraggableScrollableSheet here and we don't need the drag affordance.
    final mediaQuery = MediaQuery.of(context);
    final filtered = _filtered();

    return Padding(
      // Pad for the keyboard so the search field doesn't get covered.
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            // Drag handle.
            Container(
              margin: const EdgeInsets.only(top: 12),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Select Country',
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search field.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by name or code',
                  hintStyle: GoogleFonts.manrope(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh.withAlpha(80),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const Divider(height: 1, thickness: 0.5),

            // List.
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No countries match "$_query"',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        final selected = widget.initialCode == c.code;
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(c.code),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            color: selected
                                ? AppColors.accent.withAlpha(20)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                // Flag emoji — sized big enough to read on
                                // a phone screen but not eating the row.
                                Text(
                                  c.flag,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: GoogleFonts.manrope(
                                          fontSize: 15,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.code,
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          letterSpacing: 1.5,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  c.dialCode,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: AppColors.accent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
