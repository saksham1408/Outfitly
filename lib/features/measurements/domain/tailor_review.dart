import 'package:flutter/foundation.dart';

/// Customer's rating of a single completed tailor visit.
///
/// One row per appointment (the table enforces this with a UNIQUE
/// constraint), so the `appointment_id` doubles as a "have I
/// already reviewed this visit?" check — no separate state flag
/// needed.
@immutable
class TailorReview {
  const TailorReview({
    required this.id,
    required this.appointmentId,
    required this.tailorId,
    required this.reviewerId,
    required this.rating,
    required this.createdAt,
    this.reviewText,
  });

  final String id;
  final String appointmentId;
  final String tailorId;
  final String reviewerId;

  /// 1 → 5. The DB CHECK constraint pins this server-side too,
  /// so the value is always renderable as a star count.
  final int rating;

  /// Optional free-text comment (≤500 chars).
  final String? reviewText;

  final DateTime createdAt;

  factory TailorReview.fromMap(Map<String, dynamic> map) {
    return TailorReview(
      id: map['id'] as String,
      appointmentId: map['appointment_id'] as String,
      tailorId: map['tailor_id'] as String,
      reviewerId: map['reviewer_id'] as String,
      rating: (map['rating'] as num).toInt(),
      reviewText: map['review_text'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}
