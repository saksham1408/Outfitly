import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../models/promo_offer.dart';

/// Customer-side data layer for the Marketing & Promotions engine.
///
/// Two surfaces:
///   * [fetchActive] — one-shot read used at screen mount.
///   * [watchActive] — Supabase Realtime stream so a freshly-
///     published offer flips onto the dashboard within a second
///     of the marketing team toggling `is_active = true`.
///
/// All reads are gated by RLS — the SELECT policy added in
/// migration 038 grants any authenticated user read access to
/// `promo_offers`, and the client filters down to live offers
/// in the query string.
class PromotionsRepository {
  PromotionsRepository({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;

  static const String _table = 'promo_offers';

  /// Fetch every currently-live offer in one round trip. "Live"
  /// means `is_active = true` AND `end_date > now()`. Sorted by
  /// `end_date ASC` so the most-urgent offer is at the top of
  /// the dashboard — the standard "buy before time runs out"
  /// merchandising beat.
  Future<List<PromoOffer>> fetchActive() async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .gt('end_date', DateTime.now().toUtc().toIso8601String())
          .order('end_date', ascending: true);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(PromoOffer.fromMap)
          .toList(growable: false);
    } catch (e, st) {
      // Empty offers list is a soft failure — the dashboard
      // already handles the "no live offers" state, so we'd
      // rather render that than crash the screen on a transient
      // network blip.
      debugPrint('PromotionsRepository.fetchActive failed — $e\n$st');
      return const [];
    }
  }

  /// Realtime feed of live offers. Streams the FULL set on every
  /// mutation — the client doesn't have to merge deltas, just
  /// re-render. We can't push the `gt('end_date', ...)` filter
  /// down to Realtime (Supabase only supports `.eq()` on
  /// streams) so the client filters in-Dart, dropping
  /// expired-but-active rows the moment they roll past the
  /// current time.
  ///
  /// The dashboard rebuilds about once per Realtime event —
  /// expected cardinality is tiny (a handful of active offers
  /// at any moment), so the cost is negligible.
  Stream<List<PromoOffer>> watchActive() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('end_date', ascending: true)
        .map((rows) {
          final now = DateTime.now();
          return rows
              .map(PromoOffer.fromMap)
              .where((offer) => offer.endDate.isAfter(now))
              .toList(growable: false);
        });
  }
}
