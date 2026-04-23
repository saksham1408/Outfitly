/// Customer-side value types for the "Home Tailor Visit" tracking
/// screen.
///
/// [TailorVisit] bundles the live [tailor_appointments] row with an
/// optional [TailorProfile] — the profile is nullable because the row
/// starts life with `tailor_id = null` (pending state) and only gets
/// populated once a Partner accepts the request. The UI renders a
/// "Finding a tailor..." placeholder while [tailor] is null and swaps
/// in the real name + years-of-experience the moment one lands.
library;

/// The four states a visit row can be in — mirrors the CHECK
/// constraint on `tailor_appointments.status`.
enum TailorVisitStatus {
  pending,
  accepted,
  completed,
  cancelled;

  static TailorVisitStatus fromString(String raw) {
    switch (raw) {
      case 'pending':
        return TailorVisitStatus.pending;
      case 'accepted':
        return TailorVisitStatus.accepted;
      case 'completed':
        return TailorVisitStatus.completed;
      case 'cancelled':
        return TailorVisitStatus.cancelled;
      default:
        // Unknown statuses get normalised to `pending` so the UI
        // doesn't crash if the backend adds a new state before the
        // client catches up — the worst-case rendering is a fresh
        // "Finding a tailor..." card which is safe.
        return TailorVisitStatus.pending;
    }
  }

  /// Human-facing label shown on the status pill.
  String get label {
    switch (this) {
      case TailorVisitStatus.pending:
        return 'Finding a tailor';
      case TailorVisitStatus.accepted:
        return 'Dispatched';
      case TailorVisitStatus.completed:
        return 'Completed';
      case TailorVisitStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Partner-facing profile fields the customer is allowed to see once
/// a tailor has accepted their request (guarded by RLS migration 025).
class TailorProfile {
  const TailorProfile({
    required this.id,
    required this.fullName,
    required this.experienceYears,
  });

  final String id;
  final String fullName;
  final int experienceYears;

  factory TailorProfile.fromMap(Map<String, dynamic> map) {
    return TailorProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      // Postgres `smallint` comes through as `int` under the current
      // supabase-flutter build, but coerce defensively in case a
      // future driver returns `num`.
      experienceYears: (map['experience_years'] as num).toInt(),
    );
  }
}

/// Snapshot of a single tailor visit — the appointment row plus, if
/// one has accepted, the assigned tailor's profile.
class TailorVisit {
  const TailorVisit({
    required this.id,
    required this.userId,
    required this.tailorId,
    required this.address,
    required this.scheduledTime,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.tailor,
  });

  final String id;
  final String userId;
  final String? tailorId;
  final String address;
  final DateTime scheduledTime;
  final TailorVisitStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null while the visit is pending; populated once the service has
  /// fetched the accepted tailor's profile.
  final TailorProfile? tailor;

  bool get isPending   => status == TailorVisitStatus.pending;
  bool get isAccepted  => status == TailorVisitStatus.accepted;
  bool get isCompleted => status == TailorVisitStatus.completed;
  bool get isCancelled => status == TailorVisitStatus.cancelled;

  factory TailorVisit.fromMap(
    Map<String, dynamic> map, {
    TailorProfile? tailor,
  }) {
    return TailorVisit(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      tailorId: map['tailor_id'] as String?,
      address: map['address'] as String,
      scheduledTime: DateTime.parse(map['scheduled_time'] as String).toLocal(),
      status: TailorVisitStatus.fromString(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      tailor: tailor,
    );
  }

  TailorVisit copyWith({TailorProfile? tailor}) {
    return TailorVisit(
      id: id,
      userId: userId,
      tailorId: tailorId,
      address: address,
      scheduledTime: scheduledTime,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tailor: tailor ?? this.tailor,
    );
  }
}
