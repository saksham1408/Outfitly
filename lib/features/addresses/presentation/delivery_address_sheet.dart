import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/theme.dart';
import '../data/address_service.dart';
import '../domain/address_prefill.dart';
import '../domain/india_locations.dart';
import '../models/saved_address.dart';

/// Brand-scoped "pink" accent for the primary CTA inside the sheet.
/// Picked to pop against the cream background and forest-green primary
/// without leaning into a loud fuchsia.
const Color _pinkAccent = Color(0xFFE91E63);

/// Shows the delivery-address picker as a modal bottom sheet. Returns
/// when the sheet is dismissed — callers don't need the result; the
/// selection is already persisted in [AddressService].
Future<void> showDeliveryAddressSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(120),
    builder: (ctx) => const _DeliveryAddressSheet(),
  );
}

class _DeliveryAddressSheet extends StatelessWidget {
  const _DeliveryAddressSheet();

  @override
  Widget build(BuildContext context) {
    final mediaBottom = MediaQuery.of(context).viewPadding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Drag handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border.withAlpha(150),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),

                // Header — title + pink "Add New" pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Delivery Location',
                          style: GoogleFonts.manrope(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      _AddNewPillButton(
                        onTap: () => _goToAddAddress(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Pick a saved address or add a new one.',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border.withAlpha(60),
                ),

                // Body — saved addresses (scrollable) + bottom CTA
                Expanded(
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverToBoxAdapter(
                        child: _SectionLabel(text: 'Saved addresses'),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      _SavedAddressesList(onCloseSheet: () => _pop(context)),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(
                        child: _UseCurrentLocationCard(
                          onResolved: (prefill) =>
                              _goToAddAddress(context, prefill: prefill),
                          onFallbackTap: () => _goToAddAddress(context),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: 24 + mediaBottom),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goToAddAddress(BuildContext context, {AddressPrefill? prefill}) {
    _pop(context);
    // Short delay lets the bottom sheet close animation finish before
    // the next route pushes — avoids a visual stutter on iOS.
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!context.mounted) return;
      context.pushNamed('addAddress', extra: prefill);
    });
  }

  void _pop(BuildContext context) {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _AddNewPillButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddNewPillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _pinkAccent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                'Add New',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the saved-address list bound to [AddressService]. Empty
/// state is inlined rather than being its own widget — the sheet is
/// short and the copy needs to sit flush with the list padding.
class _SavedAddressesList extends StatelessWidget {
  final VoidCallback onCloseSheet;
  const _SavedAddressesList({required this.onCloseSheet});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<List<SavedAddress>>(
        valueListenable: AddressService.instance.addresses,
        builder: (context, list, _) {
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border.withAlpha(60),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.bookmark_border_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No saved addresses yet. Tap “Add New” to save one.',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ValueListenableBuilder<String?>(
            valueListenable: AddressService.instance.selectedId,
            builder: (context, selectedId, __) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final a in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SavedAddressCard(
                          address: a,
                          isSelected: a.id == selectedId,
                          onTap: () async {
                            await AddressService.instance.select(a.id);
                            if (context.mounted) onCloseSheet();
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  final SavedAddress address;
  final bool isSelected;
  final VoidCallback onTap;

  const _SavedAddressCard({
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _labelIcon => switch (address.label) {
        AddressLabel.home => Icons.home_outlined,
        AddressLabel.work => Icons.work_outline,
        AddressLabel.other => Icons.place_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.primary
        : AppColors.border.withAlpha(80);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon tile
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(isSelected ? 28 : 18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _labelIcon,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),

              // Label + details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          address.label.titleCase,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Badge(text: address.label.displayLabel),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address.recipientName.isNotEmpty
                          ? address.recipientName
                          : 'Saved address',
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _composeSecondaryLine(),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Selected indicator
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _composeSecondaryLine() {
    final parts = <String>[];
    final detail = address.detailLine;
    if (detail.isNotEmpty) parts.add(detail);
    final locality = <String>[
      if (address.city.trim().isNotEmpty) address.city.trim(),
      if ((address.state ?? '').trim().isNotEmpty) address.state!.trim(),
      if (address.pincode.trim().isNotEmpty) address.pincode.trim(),
    ].join(', ');
    if (locality.isNotEmpty) parts.add(locality);
    if (parts.isEmpty) return address.shortLabel;
    return parts.join(' • ');
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// Primary "Use Current Location" card. Tapping runs the live GPS
/// pipeline via [LocationService.resolveOnce] — on success it hands
/// the geocoded [AddressPrefill] back to the sheet so the Add Address
/// form opens pre-filled with city/state/pincode. On failure we fall
/// back to plain manual entry and show the reason in a snackbar.
class _UseCurrentLocationCard extends StatefulWidget {
  /// Fired when GPS resolves — the sheet closes itself and pushes the
  /// Add Address screen with the supplied prefill as `state.extra`.
  final ValueChanged<AddressPrefill> onResolved;

  /// Fallback for permanent-deny / services-off: the sheet still
  /// pushes Add Address, just without any prefill.
  final VoidCallback onFallbackTap;

  const _UseCurrentLocationCard({
    required this.onResolved,
    required this.onFallbackTap,
  });

  @override
  State<_UseCurrentLocationCard> createState() =>
      _UseCurrentLocationCardState();
}

class _UseCurrentLocationCardState extends State<_UseCurrentLocationCard> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return;
    // Capture the messenger *before* we potentially unmount by closing
    // the sheet — showing a snackbar from an unmounted context throws.
    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() => _busy = true);
    try {
      final resolved =
          await LocationService.instance.resolveOnce();
      // Normalise the geocoded values to the seed-dropdown options so
      // the Add Address form shows a matching selection, not raw
      // "MH"/"Maharashtra, India" junk.
      final seedState =
          matchSeedState(resolved.region ?? '') ?? resolved.region;
      final seedCity = seedState == null
          ? null
          : matchSeedCity(seedState, resolved.city) ?? resolved.city;

      final prefill = AddressPrefill(
        city: seedCity,
        state: seedState,
        pincode: resolved.postalCode,
        latitude: resolved.latitude,
        longitude: resolved.longitude,
      );
      if (!mounted) return;
      widget.onResolved(prefill);
    } on StateError catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Text(
            e.message,
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
      if (mounted) widget.onFallbackTap();
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Text(
            'Could not detect location: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
      if (mounted) widget.onFallbackTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(36),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _busy
                            ? 'Detecting location…'
                            : 'Use Current Location',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _busy
                            ? 'Fetching GPS + address'
                            : 'Detect your address using GPS',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withAlpha(220),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
