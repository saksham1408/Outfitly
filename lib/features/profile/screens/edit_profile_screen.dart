import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';

/// Edit Profile screen — pushed from `ProfileScreen`'s
/// "Edit Profile" tile (`/profile/edit`).
///
/// Editable fields, mirroring the columns on `public.profiles`:
///   * `full_name`
///   * `phone`
///   * `gender` (chip selector — male / female / non-binary /
///     prefer-not-to-say; matches the CHECK from migration 004)
///   * `avatar_url` (uploaded via image_picker → Storage bucket
///     `avatars` → public URL stamped onto the row; bucket is
///     created in migration 045)
///
/// Email is shown read-only because it's tied to the auth row
/// and changing it requires a verification round-trip we don't
/// scope here. Country is its own dedicated tile on the parent
/// screen with locale-aware currency switching, so we don't
/// duplicate it here.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _client = AppSupabase.client;
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  String? _gender;
  String? _email;
  String? _avatarUrl;

  /// Locally-picked avatar file before save. Once saved, this is
  /// uploaded to Storage and `_avatarUrl` is updated; until then
  /// we render this preview so the user sees the change
  /// immediately.
  XFile? _pickedAvatar;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _hydrate();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = (row?['full_name'] as String?) ?? '';
        _phoneCtrl.text = (row?['phone'] as String?) ?? '';
        _gender = row?['gender'] as String?;
        _email = (row?['email'] as String?) ?? user.email;
        _avatarUrl = (row?['avatar_url'] as String?)?.trim().isEmpty ?? true
            ? null
            : (row?['avatar_url'] as String).trim();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 88,
      );
      if (picked == null) return;
      setState(() => _pickedAvatar = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t open the gallery: $e')),
      );
    }
  }

  /// Upload [_pickedAvatar] to the `avatars` Storage bucket.
  /// Returns the public URL so the caller can stamp it onto the
  /// `profiles.avatar_url` column. Path layout:
  /// `${uid}/${uuid}.${ext}` — first segment is the uid so the
  /// folder-scoped INSERT policy in migration 045 passes.
  Future<String?> _uploadAvatarIfPicked(String userId) async {
    final pick = _pickedAvatar;
    if (pick == null) return null;
    final bytes = await pick.readAsBytes();
    final ext = _extractExt(pick.path);
    final id = const Uuid().v4();
    final path = '$userId/$id.$ext';
    try {
      final storage = _client.storage.from('avatars');
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: _mimeFor(ext),
          upsert: false,
        ),
      );
      return storage.getPublicUrl(path);
    } catch (e) {
      // Non-fatal: we keep the existing avatar_url and surface
      // the error to the user in a snackbar.
      debugPrint('EditProfileScreen avatar upload failed — $e');
      rethrow;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    String? newAvatarUrl = _avatarUrl;
    try {
      if (_pickedAvatar != null) {
        newAvatarUrl = await _uploadAvatarIfPicked(user.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar upload failed: $e')),
      );
      setState(() => _saving = false);
      return;
    }

    try {
      await _client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (_gender != null) 'gender': _gender,
        if (newAvatarUrl != null) 'avatar_url': newAvatarUrl,
      }).eq('id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          content: Text(
            'Profile updated',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      // Pop back to the profile screen with `true` so it can
      // re-pull the updated row and repaint the header.
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _extractExt(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _AvatarBlock(
                      avatarUrl: _avatarUrl,
                      pickedFile: _pickedAvatar,
                      fallbackInitial: _initial(),
                      onChange: _pickAvatar,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel('PERSONAL'),
                    const SizedBox(height: 8),
                    _Field(
                      label: 'Full name',
                      controller: _nameCtrl,
                      hint: 'Your name as it should appear',
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Please enter your name';
                        if (t.length < 2) return 'That seems too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      label: 'Phone',
                      controller: _phoneCtrl,
                      hint: '+91 98xxxxxxxx',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return null; // optional
                        // Soft validation only — we accept
                        // anything that's at least 8 digits long.
                        final digits = t.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 8) return 'Please enter a valid phone';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _ReadOnlyField(
                      label: 'Email',
                      value: _email ?? '—',
                      hint: 'Email is tied to your sign-in.',
                    ),
                    const SizedBox(height: 28),
                    _SectionLabel('IDENTITY'),
                    const SizedBox(height: 8),
                    _GenderChips(
                      selected: _gender,
                      onChange: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 36),
                    _SaveButton(
                      loading: _saving,
                      onTap: _save,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// First letter of the user's name, used as the avatar fallback
  /// when no photo has been uploaded yet.
  String _initial() {
    final n = _nameCtrl.text.trim();
    if (n.isEmpty) return '?';
    return n.substring(0, 1).toUpperCase();
  }
}

// ────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.avatarUrl,
    required this.pickedFile,
    required this.fallbackInitial,
    required this.onChange,
  });

  final String? avatarUrl;
  final XFile? pickedFile;
  final String fallbackInitial;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final hasImage = pickedFile != null || avatarUrl != null;
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onChange,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentContainer,
                      width: 2,
                    ),
                    image: hasImage
                        ? DecorationImage(
                            image: pickedFile != null
                                ? FileImage(File(pickedFile!.path))
                                : NetworkImage(avatarUrl!) as ImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? null
                      : Center(
                          child: Text(
                            fallbackInitial,
                            style: GoogleFonts.newsreader(
                              fontSize: 36,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.background,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onChange,
            child: Text(
              hasImage ? 'Change photo' : 'Add a photo',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.primary.withAlpha(30)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.primary.withAlpha(30)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.error.withAlpha(120)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withAlpha(15)),
          ),
          child: Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _GenderChips extends StatelessWidget {
  const _GenderChips({required this.selected, required this.onChange});

  final String? selected;
  final ValueChanged<String?> onChange;

  static const _options = <(String value, String label)>[
    ('male', 'Male'),
    ('female', 'Female'),
    ('non-binary', 'Non-binary'),
    ('prefer-not-to-say', 'Rather not say'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in _options)
          _Chip(
            label: option.$2,
            selected: selected == option.$1,
            // Tapping the already-selected chip clears it —
            // matches how the legacy onboarding chip set
            // behaved.
            onTap: () => onChange(
              selected == option.$1 ? null : option.$1,
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withAlpha(35),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'SAVE CHANGES',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
      ),
    );
  }
}
