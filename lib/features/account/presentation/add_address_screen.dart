import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../../addresses/data/address_service.dart';
import '../../addresses/domain/address_prefill.dart';
import '../../addresses/domain/india_locations.dart';
import '../../addresses/models/saved_address.dart';

/// Manual "Add Address" form. The user can reach it from the delivery
/// address picker sheet (via the pink "Add New" pill or the "Use
/// Current Location" card — the latter arrives with an [AddressPrefill]
/// populated from GPS + reverse geocoding).
///
/// On submit we persist via [AddressService] (SharedPreferences-backed)
/// and pop back to whatever screen pushed us. The address picker sheet
/// listens to [AddressService.addresses] so the new card shows up
/// instantly on the next open.
class AddAddressScreen extends StatefulWidget {
  /// Optional snapshot seeded by the caller — typically the GPS result
  /// from the "Use Current Location" flow. Only city/state/pincode are
  /// applied to the form; lat/lng are threaded through to the saved
  /// row so delivery ETAs can use them later.
  final AddressPrefill? prefill;

  const AddAddressScreen({super.key, this.prefill});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers for every structural field — keeps validators
  // simple and lets us dispose them tidily.
  final _recipientCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  // Dropdown selections — null until the user picks (or a prefill
  // supplies them on mount).
  String? _selectedState;
  String? _selectedCity;

  AddressLabel _selectedLabel = AddressLabel.home;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _applyPrefill(widget.prefill);
  }

  void _applyPrefill(AddressPrefill? p) {
    if (p == null) return;
    if ((p.pincode ?? '').isNotEmpty) _pincodeCtrl.text = p.pincode!;

    final seededState =
        p.state != null ? matchSeedState(p.state!) ?? p.state : null;
    if (seededState != null && indianStates.contains(seededState)) {
      _selectedState = seededState;
      if ((p.city ?? '').isNotEmpty) {
        final matchedCity = matchSeedCity(seededState, p.city!);
        if (matchedCity != null) _selectedCity = matchedCity;
      }
    }
  }

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _phoneCtrl.dispose();
    _houseCtrl.dispose();
    _streetCtrl.dispose();
    _landmarkCtrl.dispose();
    _areaCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedState == null || _selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          content: Text(
            'Please pick a state and city.',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final addressLine1 = <String>[
        _houseCtrl.text.trim(),
        _streetCtrl.text.trim(),
      ].where((s) => s.isNotEmpty).join(', ');

      final addressLine2 = <String>[
        if (_landmarkCtrl.text.trim().isNotEmpty)
          'Near ${_landmarkCtrl.text.trim()}',
        if (_areaCtrl.text.trim().isNotEmpty) _areaCtrl.text.trim(),
      ].join(' · ');

      await AddressService.instance.add(
        label: _selectedLabel,
        recipientName: _recipientCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        city: _selectedCity!,
        addressLine1: addressLine1,
        addressLine2: addressLine2.isEmpty ? null : addressLine2,
        state: _selectedState,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        latitude: widget.prefill?.latitude ?? 0,
        longitude: widget.prefill?.longitude ?? 0,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          content: Text(
            'Address saved',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Could not save: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefilled = widget.prefill != null &&
        (widget.prefill!.city != null || widget.prefill!.state != null);
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
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Add Address',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (prefilled) _PrefillBanner(prefill: widget.prefill!),
            if (prefilled) const SizedBox(height: 20),

            _SectionHeader(title: 'Contact details'),
            const SizedBox(height: 10),
            _LabelledField(
              label: 'Full name',
              child: _inputField(
                controller: _recipientCtrl,
                hint: 'e.g. Aarav Sharma',
                textCapitalization: TextCapitalization.words,
                validator: _requireNonEmpty,
              ),
            ),
            const SizedBox(height: 14),
            _LabelledField(
              label: 'Phone number',
              child: _inputField(
                controller: _phoneCtrl,
                hint: '10-digit mobile number',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: _validatePhone,
              ),
            ),

            const SizedBox(height: 28),
            _SectionHeader(title: 'Address'),
            const SizedBox(height: 10),

            // Two short fields sharing a row — tighter on mobile.
            Row(
              children: [
                Expanded(
                  child: _LabelledField(
                    label: 'House / Flat No.',
                    child: _inputField(
                      controller: _houseCtrl,
                      hint: 'e.g. B-302',
                      validator: _requireNonEmpty,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabelledField(
                    label: 'Pincode',
                    child: _inputField(
                      controller: _pincodeCtrl,
                      hint: '6-digit code',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: _validatePincode,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LabelledField(
              label: 'Street / Road',
              child: _inputField(
                controller: _streetCtrl,
                hint: 'Street name, number',
                textCapitalization: TextCapitalization.words,
                validator: _requireNonEmpty,
              ),
            ),
            const SizedBox(height: 14),
            _LabelledField(
              label: 'Landmark (optional)',
              child: _inputField(
                controller: _landmarkCtrl,
                hint: 'e.g. Opposite SBI Bank',
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(height: 14),
            _LabelledField(
              label: 'Area / Locality',
              child: _inputField(
                controller: _areaCtrl,
                hint: 'e.g. Vaishali Nagar',
                textCapitalization: TextCapitalization.words,
                validator: _requireNonEmpty,
              ),
            ),
            const SizedBox(height: 14),

            // State + City — non-editable dropdowns seeded from
            // `india_locations.dart`. State drives the city list; we
            // clear the city whenever state changes so stale pairings
            // can't sneak through.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LabelledField(
                    label: 'State',
                    child: _StateDropdown(
                      value: _selectedState,
                      onChanged: (s) {
                        setState(() {
                          _selectedState = s;
                          _selectedCity = null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabelledField(
                    label: 'City',
                    child: _CityDropdown(
                      state: _selectedState,
                      value: _selectedCity,
                      onChanged: (c) => setState(() => _selectedCity = c),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            _SectionHeader(title: 'Save as'),
            const SizedBox(height: 10),
            _LabelPicker(
              selected: _selectedLabel,
              onChanged: (l) => setState(() => _selectedLabel = l),
            ),
            const SizedBox(height: 36),

            // Primary CTA — full-width, high-contrast.
            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _handleSave,
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
                        'Save Address',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── validators ─────────────────────

  String? _requireNonEmpty(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (v.trim().length != 10) return 'Enter a 10-digit number';
    return null;
  }

  String? _validatePincode(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (v.trim().length != 6) return 'Enter a 6-digit pincode';
    return null;
  }

  // ───────────────────── factored input ─────────────────────

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.manrope(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: _decoration(hint),
    );
  }
}

/// Shared `InputDecoration` so every field (text + dropdown) lines up
/// pixel-for-pixel.
InputDecoration _decoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        fontSize: 13,
        color: AppColors.textTertiary,
      ),
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border.withAlpha(80)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
      errorStyle: GoogleFonts.manrope(
        fontSize: 11,
        color: AppColors.error,
      ),
    );

class _StateDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _StateDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: AppColors.textSecondary,
      ),
      decoration: _decoration('Select state'),
      style: GoogleFonts.manrope(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      items: [
        for (final s in indianStates)
          DropdownMenuItem<String>(
            value: s,
            child: Text(
              s,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _CityDropdown extends StatelessWidget {
  final String? state;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _CityDropdown({
    required this.state,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = state == null ? const <String>[] : citiesFor(state!);
    final enabled = state != null;

    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color:
            enabled ? AppColors.textSecondary : AppColors.textTertiary,
      ),
      decoration: _decoration(
        enabled ? 'Select city' : 'Pick a state first',
      ),
      style: GoogleFonts.manrope(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      items: [
        for (final c in options)
          DropdownMenuItem<String>(
            value: c,
            child: Text(
              c,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
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

class _LabelledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabelledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _LabelPicker extends StatelessWidget {
  final AddressLabel selected;
  final ValueChanged<AddressLabel> onChanged;

  const _LabelPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final l in AddressLabel.values) ...[
          Expanded(
            child: _LabelChoice(
              label: l,
              isSelected: l == selected,
              onTap: () => onChanged(l),
            ),
          ),
          if (l != AddressLabel.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _LabelChoice extends StatelessWidget {
  final AddressLabel label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LabelChoice({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon => switch (label) {
        AddressLabel.home => Icons.home_outlined,
        AddressLabel.work => Icons.work_outline,
        AddressLabel.other => Icons.place_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected ? AppColors.primary : AppColors.border.withAlpha(90),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label.titleCase,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A soft confirmation banner shown at the top of the form when the
/// user arrived via "Use Current Location" — lets them see at a glance
/// that pincode/city/state have been pre-filled, and whether they need
/// to correct anything.
class _PrefillBanner extends StatelessWidget {
  final AddressPrefill prefill;
  const _PrefillBanner({required this.prefill});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if ((prefill.city ?? '').isNotEmpty) parts.add(prefill.city!);
    if ((prefill.state ?? '').isNotEmpty) parts.add(prefill.state!);
    if ((prefill.pincode ?? '').isNotEmpty) parts.add(prefill.pincode!);
    final summary = parts.isEmpty ? 'location detected' : parts.join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.my_location_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prefilled from your location',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
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
}
