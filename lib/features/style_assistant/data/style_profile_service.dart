import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/style_profile.dart';

/// Reads + writes the user's [StyleProfile] in Supabase.
///
/// Two public methods, both narrowly scoped:
///   • [fetchMine]   — returns the current user's profile or null
///                     if they haven't taken the quiz yet. The
///                     null path is what the chat-tab gate uses
///                     to decide whether to force the quiz.
///   • [save]        — upserts on `user_id`. Quiz retakes are
///                     idempotent updates, never duplicates.
///
/// Failures bubble up as exceptions so the caller can show a
/// snackbar — unlike the Gemini services which silently fall
/// back, a Supabase write failure here means we'd lose the
/// user's quiz answers and that's worth surfacing.
class StyleProfileService {
  final SupabaseClient _client;

  StyleProfileService({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  /// Returns the signed-in user's style profile, or `null` if
  /// they have no row yet. Throws only on auth failure (no user)
  /// or unrecoverable network errors — a missing row is normal.
  Future<StyleProfile?> fetchMine() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Cannot fetch style profile: no signed-in user');
    }

    final row = await _client
        .from('style_profiles')
        .select()
        .eq('user_id', user.id)
        // `maybeSingle` returns null instead of throwing when no
        // row matches — exactly what we want for a "first-time"
        // user who hasn't taken the quiz yet.
        .maybeSingle();

    if (row == null) return null;
    return StyleProfile.fromJson(row);
  }

  /// Upsert the profile on `user_id`. Returns the persisted
  /// version (with whatever defaults Postgres filled in). The
  /// caller almost always already has the same data in hand;
  /// returning the round-tripped row is purely so the UI can
  /// show the canonical state without a follow-up SELECT.
  Future<StyleProfile> save({
    required String bodyType,
    required String skinTone,
    required List<String> occasions,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Cannot save style profile: no signed-in user');
    }

    final payload = StyleProfile(
      userId: user.id,
      bodyType: bodyType,
      skinTone: skinTone,
      occasions: occasions,
    ).toUpsertJson();

    try {
      final row = await _client
          .from('style_profiles')
          .upsert(payload, onConflict: 'user_id')
          .select()
          .single();
      return StyleProfile.fromJson(row);
    } catch (e, st) {
      // Log and re-throw — the quiz screen catches this and
      // shows a snackbar so the user can retry without losing
      // the answers they already typed in.
      debugPrint('StyleProfileService.save failed: $e\n$st');
      rethrow;
    }
  }
}
