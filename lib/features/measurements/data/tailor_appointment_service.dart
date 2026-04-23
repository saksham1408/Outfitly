import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/tailor_visit.dart';

/// Customer-side data layer for the home-tailor-visit flow.
///
/// INSERTs into the `tailor_appointments` table with `status='pending'`.
/// The Partner app's dispatch radar is subscribed to pending rows over
/// Supabase Realtime, so the very row this service creates will pop a
/// "NEW REQUEST" sheet on every online tailor's phone within a second.
///
/// Also exposes [watchVisit] — the stream that powers the customer's
/// live tracking screen. It merges the appointment row with the
/// assigned tailor's profile as soon as one accepts.
class TailorAppointmentService {
  TailorAppointmentService({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;

  /// Create a pending tailor visit request for the currently-signed-in
  /// customer. Returns the new row's id on success.
  ///
  /// Throws [StateError] if the caller isn't authenticated — callers
  /// should guard at the UI layer, but the assert keeps bugs loud.
  Future<String> requestVisit({
    required String address,
    required DateTime scheduledTime,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to request a tailor visit.');
    }

    final inserted = await _client
        .from('tailor_appointments')
        .insert({
          'user_id': user.id,
          'address': address,
          // Always send UTC — the Postgres column is timestamptz, and
          // the Partner app renders in the tailor's local zone.
          'scheduled_time': scheduledTime.toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }

  /// Live stream of a single tailor visit, merged with the assigned
  /// tailor's profile as soon as one is set.
  ///
  /// Emission model:
  ///   1. Supabase Realtime delivers every row-level change on the
  ///      `tailor_appointments` row matching [appointmentId]. We
  ///      receive the full row each time — pending → accepted →
  ///      completed.
  ///   2. The first time we see a non-null `tailor_id`, we reach over
  ///      to `tailor_profiles` for the name + experience_years and
  ///      cache it on this stream's local state. Subsequent status
  ///      updates re-use the cached profile so we don't re-fetch on
  ///      every UPDATE — the profile is immutable-enough for the
  ///      lifetime of a visit.
  ///
  /// The RLS policy on `tailor_profiles` ("Customers read assigned
  /// tailor profile", migration 025) is what makes the profile SELECT
  /// visible to the customer; without it the fetch would return null.
  Stream<TailorVisit> watchVisit(String appointmentId) async* {
    TailorProfile? cachedProfile;

    final rowStream = _client
        .from('tailor_appointments')
        .stream(primaryKey: ['id'])
        .eq('id', appointmentId);

    await for (final rows in rowStream) {
      if (rows.isEmpty) continue;
      final row = rows.first;
      final tailorId = row['tailor_id'] as String?;

      // Lazy-fetch the profile the first time a tailor claims the
      // row. `maybeSingle` instead of `single` so an RLS miss or a
      // not-yet-registered tailor yields null rather than throwing.
      if (tailorId != null && cachedProfile == null) {
        final profileRow = await _client
            .from('tailor_profiles')
            .select('id, full_name, experience_years')
            .eq('id', tailorId)
            .maybeSingle();
        if (profileRow != null) {
          cachedProfile = TailorProfile.fromMap(profileRow);
        }
      }

      yield TailorVisit.fromMap(row, tailor: cachedProfile);
    }
  }
}
