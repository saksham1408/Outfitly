import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/tailor_visit.dart';

/// Read-only data layer for the customer-side tailor marketplace.
///
/// `TailorAppointmentService` continues to own the *write* side of
/// the booking flow (INSERTing rows into `tailor_appointments`,
/// streaming a single visit). This repository owns the *browse*
/// side: pulling rated tailor profiles for the new selection
/// screen.
///
/// Why a separate file: the appointment service is already pulling
/// its weight (Realtime streams, lazy profile fetch, request
/// dispatch). Splitting browse off keeps each layer focused and the
/// imports tidy.
class TailorRepository {
  TailorRepository({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;

  /// Fetch tailors nearby [location] (a pincode or free-text city
  /// name), sorted by rating descending so the highest-rated cards
  /// land at the top.
  ///
  /// MVP behaviour: ignore [location] and return every tailor in
  /// the table, capped at [limit]. Later iterations can layer in a
  /// pincode → service-area join, geographic radius queries, or a
  /// `service_areas text[]` column on `tailor_profiles`. Keeping
  /// the parameter on the signature now means swapping the body
  /// later doesn't ripple into call sites.
  ///
  /// Sort order:
  ///   1. `rating` desc — highest stars first.
  ///   2. `total_reviews` desc — break ties toward more-reviewed
  ///      tailors so a single 5★ rating doesn't outrank 4.9 over
  ///      200 reviews.
  ///   3. `created_at` asc — final tie-breaker, oldest first
  ///      (favouring established profiles).
  ///
  /// We deliberately request only the marketplace-safe columns —
  /// `phone` and `total_earnings` are never sent over the wire to
  /// the customer client. RLS migration 036 still allows broader
  /// reads, but a tight column projection is a second line of
  /// defence.
  Future<List<TailorProfile>> fetchNearbyTailors({
    String? location,
    int limit = 50,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await _client
          .from('tailor_profiles')
          .select(
            'id, full_name, experience_years, rating, '
            'total_reviews, specialties, is_verified',
          )
          .order('rating', ascending: false)
          .order('total_reviews', ascending: false)
          .order('created_at', ascending: true)
          .limit(limit);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(TailorProfile.fromMap)
          .toList(growable: false);
    } catch (e, st) {
      // Deliberate non-throw: an empty marketplace is uncomfortable
      // but recoverable (the UI shows an "all tailors busy / try
      // again" empty state). Propagating the error would crash the
      // selection screen for a cosmetic problem.
      debugPrint('TailorRepository.fetchNearbyTailors failed — $e\n$st');
      return const [];
    }
  }
}
