import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/locale/country_dial_codes.dart';
import '../../../core/locale/country_picker.dart';
import '../../../core/locale/money.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../auth/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final data = await AppSupabase.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Open the country picker and, if the user picks something new,
  /// (a) persist it to their profile row, and (b) flip Money's
  /// override so prices across the app repaint instantly.
  ///
  /// This is the "I registered as France by mistake" recovery path —
  /// without this, the only way to switch currency was to delete and
  /// recreate the account.
  Future<void> _changeCountry() async {
    final current = (_profile?['country'] as String?) ??
        Money.instance.overrideCountry ??
        kDefaultCountryCode;

    final picked = await showCountryPicker(context, initialCode: current);
    if (picked == null || picked == current) return;
    if (!mounted) return;

    // Apply locally first so the catalog repaints in the new currency
    // immediately — even if the DB update fails, the user still gets
    // the right currency on this device.
    await Money.instance.setOverrideCountry(picked);

    // Optimistically reflect the new country in the menu subtitle.
    // We update _profile regardless of whether the DB update succeeds
    // because the local override is the actual source of truth for
    // what the user sees; the DB row is just for cross-device sync.
    setState(() {
      _profile = {...?_profile, 'country': picked};
    });

    String message =
        'Country updated to ${dialInfoForCountry(picked).name}';
    Color? bg;

    try {
      final user = _authService.currentUser;
      if (user != null) {
        await AppSupabase.client.from('profiles').update({
          'country': picked,
        }).eq('id', user.id);
      }
    } catch (e) {
      final raw = e.toString();
      // Detect the specific "country column missing" case — this
      // happens when migration 030 hasn't been applied yet. We don't
      // treat it as a hard error: the local override still holds, the
      // catalog still repaints; the user just won't sync this choice
      // to other devices until the migration runs.
      final isMigrationMissing = raw.contains('PGRST204') ||
          (raw.contains("'country'") && raw.contains('schema cache'));
      if (isMigrationMissing) {
        message =
            'Currency switched on this device. Apply migration 030 to sync your country across devices.';
        bg = AppColors.primary;
      } else {
        message = 'Saved locally. Couldn\'t sync to your profile: $e';
        bg = AppColors.error;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bg,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      24, MediaQuery.of(context).padding.top + 24, 24, 32,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accentContainer,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              (_profile?['full_name'] as String?)
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  '?',
                              style: GoogleFonts.newsreader(
                                fontSize: 32,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _profile?['full_name'] ?? 'User',
                          style: GoogleFonts.newsreader(
                            fontSize: 24,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _profile?['email'] ??
                              _authService.currentUser?.email ??
                              '',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: Colors.white.withAlpha(180),
                          ),
                        ),
                        if (_profile?['phone'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _profile!['phone'],
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.white.withAlpha(140),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Menu Items ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACCOUNT',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _menuTile(
                          Icons.edit_outlined,
                          'Edit Profile',
                          'Update your name, phone, location',
                          onTap: () {},
                        ),
                        _menuTile(
                          Icons.straighten_outlined,
                          'My Measurements',
                          'View & edit saved measurements',
                          onTap: () => context.push('/measurements/manual'),
                        ),
                        _menuTile(
                          Icons.style_outlined,
                          'Style Preferences',
                          'Update your style quiz answers',
                          onTap: () => context.push('/style-quiz'),
                        ),
                        _menuTile(
                          Icons.public_outlined,
                          'Country & Currency',
                          _countrySubtitle(),
                          onTap: _changeCountry,
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'ORDERS',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _menuTile(
                          Icons.shopping_bag_outlined,
                          'Order History',
                          'Track past and current orders',
                          onTap: () {},
                        ),
                        _menuTile(
                          Icons.favorite_outline,
                          'My Wishlist',
                          'Saved products and fabrics',
                          onTap: () {},
                        ),

                        const SizedBox(height: 24),
                        Text(
                          'SUPPORT',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _menuTile(
                          Icons.help_outline,
                          'Help & Support',
                          'FAQ, contact us, return policy',
                          onTap: () {},
                        ),
                        _menuTile(
                          Icons.info_outline,
                          'About VASTRAHUB',
                          'Version 1.0.4 · Crafting Phase',
                          onTap: () {},
                        ),

                        const SizedBox(height: 24),

                        // ── Logout ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _authService.signOut();
                              if (context.mounted) context.go('/login');
                            },
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: Text(
                              'SIGN OUT',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error.withAlpha(60)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Build the subtitle shown under "Country & Currency" — e.g.
  /// `India · ₹ INR`. We prefer the saved profile country first,
  /// falling back to whatever Money is currently rendering with so
  /// pre-migration accounts (no `profiles.country` value) still show
  /// something honest instead of an empty subtitle.
  String _countrySubtitle() {
    final saved = (_profile?['country'] as String?) ??
        Money.instance.overrideCountry;
    final info = dialInfoForCountry(saved);
    final c = Money.instance.currency;
    return '${info.name} · ${c.symbol} ${c.code}';
  }

  Widget _menuTile(IconData icon, String title, String subtitle,
      {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
