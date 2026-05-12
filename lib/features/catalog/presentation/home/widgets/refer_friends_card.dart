import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/network/supabase_client.dart';
import '../../../../../core/theme/theme.dart';

/// "Refer & Earn" hero card on the home feed.
///
/// Drops a premium gradient card that hands the user a shareable
/// referral code derived from their user id — no new backend
/// table required. The card has two affordances:
///
///   * **Share invite** — opens the native share sheet via
///     `share_plus` with a pre-composed message ("Get ₹500 off
///     your first Outfitly order — use code <code>").
///   * **Copy code** — tappable code chip that lands the code
///     on the clipboard with a confirmation snackbar.
///
/// Long-term this should land as a real `referrals` table with
/// per-code credits + redemption tracking, but the in-product
/// hook ships first so we can validate engagement before the
/// schema work.
class ReferFriendsCard extends StatelessWidget {
  const ReferFriendsCard({super.key});

  /// Six-character referral code derived deterministically from
  /// the user's UID. Same user always generates the same code so
  /// they can re-share it across channels. Falls back to a
  /// neutral marketing code for signed-out callers — the card
  /// stays useful even in pre-auth flows.
  String get _code {
    final uid = AppSupabase.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return 'OUTFIT500';
    // Strip non-alphanumerics + uppercase + slice. UUIDs are
    // alphanumeric + dashes, so .replaceAll keeps us safe even
    // if the format changes.
    final cleaned =
        uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.length < 6) return 'OUTFIT500';
    return cleaned.substring(0, 6);
  }

  String get _shareMessage =>
      'I\'m loving Outfitly — bespoke ethnic wear stitched to your measurements. '
      'Use my code $_code at checkout for ₹500 off your first order.\n\n'
      'Download: https://outfitly.app';

  Future<void> _share() async {
    await Share.share(_shareMessage, subject: 'Outfitly — ₹500 off');
  }

  Future<void> _copyCode(BuildContext context) async {
    final code = _code;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
        content: Text(
          'Code $code copied — share it with a friend.',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _share,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A1D24),
                  Color(0xFFA6735C),
                  Color(0xFFD4AF37),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A1D24).withAlpha(90),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Two decorative blurred circles — same depth
                // treatment used by The Edit + Atelier Story so
                // the visual rhythm carries across the home feed.
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(30),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -30,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(18),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(50),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.card_giftcard_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius:
                                  BorderRadius.circular(999),
                            ),
                            child: Text(
                              'REFER & EARN',
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Give ₹500.\nGet ₹500.',
                        style: GoogleFonts.newsreader(
                          fontSize: 26,
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          height: 1.05,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share Outfitly with a friend. When they place their first order, you both get ₹500 off.',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          color: Colors.white.withAlpha(225),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _CopyCodeChip(
                            code: _code,
                            onTap: () => _copyCode(context),
                          ),
                          const SizedBox(width: 10),
                          _SharePill(onTap: _share),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CopyCodeChip extends StatelessWidget {
  const _CopyCodeChip({required this.code, required this.onTap});

  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(120)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.content_copy_rounded,
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                code,
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharePill extends StatelessWidget {
  const _SharePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share invite',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.ios_share_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
