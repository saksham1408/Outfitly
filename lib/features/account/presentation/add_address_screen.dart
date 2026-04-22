import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../../addresses/data/address_service.dart';
import '../../addresses/models/saved_address.dart';

/// Manual "Add Address" form. The user can reach it from the delivery
/// address picker sheet (via the pink "Add New" pill or the "Use
/// Current Location" card — GPS fetch is stubbed for Phase 1).
///
/// On submit we persist via [AddressService] (SharedPreferences-backed)
/// and pop back to whatever screen pushed us. The address picker sheet
/// listens to [AddressService.addresses] so the new card shows up
/// instantly on the next open.
class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

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
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  AddressLabel _selectedLabel = AddressLabel.home;
  bool _saving = false;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _phoneCtrl.dispose();
    _houseCtrl.dispose();
    _streetCtrl.dispose();
    _landmarkCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

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
        city: _cityCtrl.text.trim(),
        addressLine1: addressLine1,
        addressLine2: addressLine2.isEmpty ? null : addressLine2,
        state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
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

            // City + State side-by-side. Left as text inputs for
            // Phase 1 — Phase 2 will swap these for dropdowns seeded
            // from the Indian states/cities list served from Supabase.
            Row(
              children: [
                Expanded(
                  child: _LabelledField(
                    label: 'City',
                    child: _inputField(
                      controller: _cityCtrl,
                      hint: 'e.g. Jaipur',
                      textCapitalization: TextCapitalization.words,
                      validator: _requireNonEmpty,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabelledField(
                    label: 'State',
                    child: _inputField(
                      controller: _stateCtrl,
                      hint: 'e.g. Rajasthan',
                      textCapitalization: TextCapitalization.words,
                      validator: _requireNonEmpty,
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
      decoration: InputDecoration(
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
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
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
