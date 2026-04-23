import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';

/// Customer-side data layer for creating tailor home-visit requests.
///
/// INSERTs into the `tailor_appointments` table with `status='pending'`.
/// The Partner app's dispatch radar is subscribed to pending rows over
/// Supabase Realtime, so the very row this service creates will pop a
/// "NEW REQUEST" sheet on every online tailor's phone within a second.
///
/// Deliberately tiny — this service exists only to make the customer
/// app → partner app handshake work end-to-end. Everything else
/// (measurements, address prefill, slot selection) happens in the UI.
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
}
