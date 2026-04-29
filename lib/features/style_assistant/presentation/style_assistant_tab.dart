import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/style_profile_service.dart';
import '../domain/style_profile.dart';
import 'ai_chat_screen.dart';
import 'style_quiz_screen.dart';

/// Force-quiz gate that backs the "VASTRAHUB AI" bottom-nav tab.
///
/// On first paint we ask Supabase whether the signed-in user has a
/// [StyleProfile] row. The answer drives a tiny three-state machine:
///
///   • [_GateStatus.loading] → centred spinner while we fetch.
///   • [_GateStatus.quiz]    → render [StyleQuizScreen]. We hand it
///                             a callback so when the quiz writes
///                             the profile we flip to chat in place
///                             (no navigation, no flicker).
///   • [_GateStatus.chat]    → render [AiChatScreen] with the
///                             freshly-loaded profile. The chat's
///                             "retake quiz" tune-icon flips us
///                             back to the quiz state so the user
///                             can update their answers.
///
/// Why a gate (instead of a route guard): the bottom nav lives
/// inside [MainShell.IndexedStack], so swapping the child here is
/// instant and preserves siblings' state. A redirect would tear
/// down the shell on every tap, which feels wrong when the user
/// is just toggling between Home and the assistant.
///
/// Failure posture: if Supabase blows up (no auth, network down)
/// we surface a small inline retry rather than spinning forever —
/// the user can re-pull and try again without restarting the app.
class StyleAssistantTab extends StatefulWidget {
  const StyleAssistantTab({super.key});

  @override
  State<StyleAssistantTab> createState() => _StyleAssistantTabState();
}

enum _GateStatus { loading, quiz, chat, error }

class _StyleAssistantTabState extends State<StyleAssistantTab> {
  // Single shared service instance — fetchMine and (later) any
  // refetch after a quiz retake both go through the same client.
  final StyleProfileService _service = StyleProfileService();

  _GateStatus _status = _GateStatus.loading;
  StyleProfile? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// One-shot fetch on mount. We deliberately don't refetch on
  /// every tab-tap — the IndexedStack keeps this state widget
  /// alive across tab switches, so once we've decided "you have
  /// a profile, here's the chat" we stay there until either the
  /// user retakes the quiz (which writes a new row + flips us
  /// locally) or they sign out (which destroys the shell).
  Future<void> _bootstrap() async {
    try {
      final profile = await _service.fetchMine();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _status = profile == null ? _GateStatus.quiz : _GateStatus.chat;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _GateStatus.error;
        _error = e.toString();
      });
    }
  }

  /// Quiz finished — hold the freshly-saved profile and hand it
  /// to the chat. No navigator pop/push: we just swap the child.
  void _onQuizCompleted(StyleProfile saved) {
    setState(() {
      _profile = saved;
      _status = _GateStatus.chat;
    });
  }

  /// User tapped the tune icon in the chat AppBar — pull them
  /// back to the quiz screen. We DO NOT clear `_profile` because
  /// the quiz screen prefills nothing today; if a retake fails or
  /// the user cancels, our cached profile is still valid for the
  /// chat. We only overwrite it when [_onQuizCompleted] fires.
  void _onRetakeQuiz() {
    setState(() {
      _status = _GateStatus.quiz;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _GateStatus.loading:
        return const _LoadingScaffold();
      case _GateStatus.error:
        return _ErrorScaffold(
          message: _error ?? 'Something went wrong loading your style profile.',
          onRetry: () {
            setState(() => _status = _GateStatus.loading);
            _bootstrap();
          },
        );
      case _GateStatus.quiz:
        return StyleQuizScreen(onCompleted: _onQuizCompleted);
      case _GateStatus.chat:
        // _profile is non-null whenever we land in this branch —
        // either fetchMine returned it or _onQuizCompleted just
        // set it. The bang is safe and documents that invariant.
        return AiChatScreen(
          profile: _profile!,
          onRetakeQuiz: _onRetakeQuiz,
        );
    }
  }
}

/// Loading state — branded spinner over the app background so the
/// transition into the eventual quiz/chat surface is seamless.
class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Personalising your stylist…',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny error state — Supabase fetch tripped (auth, network).
/// We don't try to be clever: one line of context + a retry pill
/// that re-runs [_bootstrap]. If the user is genuinely signed
/// out the global router will yank them to /login on the next
/// frame anyway.
class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScaffold({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 36,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  "Couldn't load your style profile",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'TRY AGAIN',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
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
