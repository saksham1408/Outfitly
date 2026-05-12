import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/social_repository.dart';
import '../models/friend_connection.dart';

/// Modal bottom sheet that searches for a user by exact email or
/// phone, shows the match (or "no match"), and lets the caller
/// fire a friend request with one tap.
///
/// Pop result:
///   * `true`  → a request was sent, parent should refresh.
///   * `false` / `null` → dismissed without action.
class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key});

  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final _controller = TextEditingController();
  final _social = SocialRepository.instance;

  /// Tri-state UI: idle (nothing searched yet), searching, settled.
  /// We keep the result alongside `_settled = true` rather than
  /// relying on `result == null` because "settled with no match" and
  /// "haven't searched yet" need different copy.
  bool _searching = false;
  bool _settled = false;
  FriendProfile? _result;

  bool _sending = false;
  String? _error;

  Future<void> _runSearch() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _settled = false;
      _result = null;
      _error = null;
    });

    final hit = await _social.findProfileByContact(q);

    if (!mounted) return;
    setState(() {
      _result = hit;
      _searching = false;
      _settled = true;
    });
  }

  Future<void> _sendRequest() async {
    final r = _result;
    if (r == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _social.sendFriendRequest(r.id);
      if (!mounted) return;
      // Pop with the recipient's uid so the caller can deep-link
      // straight into a chat thread with them — the user just
      // told us who they want to talk to, the least we can do
      // is open that conversation.
      Navigator.of(context).pop(r.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // The most common failure mode is the canonical-pair UNIQUE
        // index — a row already exists for this pair (in either
        // direction). Surface a friendly hint instead of the raw
        // Postgres message.
        final raw = e.toString();
        _error = raw.contains('canonical_pair') || raw.contains('unique')
            ? 'You already have a connection with this person.'
            : 'Couldn\'t send: $e';
        _sending = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add a friend',
              style: GoogleFonts.newsreader(
                fontSize: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Find someone by their exact email address or phone number.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Search input + button.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    onSubmitted: (_) => _runSearch(),
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'friend@email.com or +91…',
                      hintStyle: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _searching ? null : _runSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Search',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Result row.
            if (_settled) _buildResult(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final r = _result;
    if (r == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_off_rounded,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No one matches that. Double-check the email or phone.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withAlpha(15),
              image: r.avatarUrl != null && r.avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(r.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: r.avatarUrl == null || r.avatarUrl!.isEmpty
                ? Text(
                    r.initial,
                    style: GoogleFonts.newsreader(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              r.fullName,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _sending ? null : _sendRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _sending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Add',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
