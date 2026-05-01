import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/tailor_review.dart';

/// Customer-side data layer for the tailor-rating loop.
///
/// Two methods cover the lifecycle:
///   * [fetchByAppointment] — has the customer already left a
///     review for this visit? Drives the visibility of the "Rate
///     your tailor" CTA on the tracking screen.
///   * [submitReview] — INSERT a new row. The recompute trigger
///     on `tailor_reviews` updates the tailor's aggregate rating
///     + review count automatically.
///
/// Errors propagate from the underlying Supabase client; the UI
/// catches them and surfaces a friendly message.
class TailorReviewService {
  TailorReviewService({SupabaseClient? client})
      : _client = client ?? AppSupabase.client;

  final SupabaseClient _client;

  static const String _table = 'tailor_reviews';

  /// Returns the existing review for [appointmentId] if the
  /// signed-in customer already left one, or null otherwise.
  /// The UNIQUE constraint on `appointment_id` guarantees there's
  /// at most one row per appointment.
  Future<TailorReview?> fetchByAppointment(String appointmentId) async {
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('appointment_id', appointmentId)
          .maybeSingle();
      if (row == null) return null;
      return TailorReview.fromMap(row);
    } catch (e) {
      debugPrint('TailorReviewService.fetchByAppointment failed — $e');
      return null;
    }
  }

  /// Submit a fresh review. Returns the persisted [TailorReview]
  /// (with server-issued id + timestamp) so the caller can
  /// optimistically render the "Thanks!" beat without a refetch.
  ///
  /// RLS guarantees:
  ///   * The signed-in user is the appointment's owner.
  ///   * The appointment's status is 'completed'.
  ///   * The tailor_id matches the appointment row's tailor_id.
  ///
  /// If any guard fails, Supabase throws and we let the exception
  /// bubble up — the UI surfaces the error text.
  Future<TailorReview> submitReview({
    required String appointmentId,
    required String tailorId,
    required int rating,
    String? reviewText,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }

    final inserted = await _client
        .from(_table)
        .insert({
          'appointment_id': appointmentId,
          'tailor_id': tailorId,
          'rating': rating,
          if (reviewText != null && reviewText.trim().isNotEmpty)
            'review_text': reviewText.trim(),
        })
        .select()
        .single();

    return TailorReview.fromMap(inserted);
  }

  /// Pull the most recent reviews for a single tailor. Drives a
  /// future "read all reviews" list on the tailor profile; the
  /// marketplace card already reads the precomputed
  /// `tailor_profiles.rating` / `total_reviews` columns.
  Future<List<TailorReview>> fetchForTailor(
    String tailorId, {
    int limit = 20,
  }) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('tailor_id', tailorId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(TailorReview.fromMap)
          .toList(growable: false);
    } catch (e) {
      debugPrint('TailorReviewService.fetchForTailor failed — $e');
      return const [];
    }
  }
}
