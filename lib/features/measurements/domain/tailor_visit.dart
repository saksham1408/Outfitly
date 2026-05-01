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

/// The states a visit row can be in — mirrors the CHECK constraint
/// on `tailor_appointments.status` (migration 023 → 026 → 036).
///
/// Two booking modes share this enum:
///
///   * **Auto-dispatch (legacy)** — kept for backward compatibility:
///     pending → accepted → enRoute → arrived → completed
///   * **User-selected marketplace** — a specific tailor is chosen
///     before the row is even inserted:
///     pendingTailorApproval → accepted → enRoute → arrived → completed
///
/// Either branch can short-circuit to `cancelled`. The Partner app
/// surfaces only `pending` rows to the broadcast radar; rows that
/// land in `pendingTailorApproval` go straight to the chosen
/// tailor's inbox via the per-tailor RLS scope added in 036.
enum TailorVisitStatus {
  pending,
  pendingTailorApproval,
  accepted,
  enRoute,
  arrived,
  completed,
  cancelled;

  static TailorVisitStatus fromString(String raw) {
    switch (raw) {
      case 'pending':
        return TailorVisitStatus.pending;
      case 'pending_tailor_approval':
        return TailorVisitStatus.pendingTailorApproval;
      case 'accepted':
        return TailorVisitStatus.accepted;
      case 'en_route':
        return TailorVisitStatus.enRoute;
      case 'arrived':
        return TailorVisitStatus.arrived;
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

  /// Wire string used in INSERT / UPDATE payloads.
  String get wire {
    switch (this) {
      case TailorVisitStatus.pendingTailorApproval:
        return 'pending_tailor_approval';
      case TailorVisitStatus.enRoute:
        return 'en_route';
      case TailorVisitStatus.pending:
      case TailorVisitStatus.accepted:
      case TailorVisitStatus.arrived:
      case TailorVisitStatus.completed:
      case TailorVisitStatus.cancelled:
        return name;
    }
  }

  /// Human-facing label shown on the status pill.
  String get label {
    switch (this) {
      case TailorVisitStatus.pending:
        return 'Finding a tailor';
      case TailorVisitStatus.pendingTailorApproval:
        return 'Awaiting tailor';
      case TailorVisitStatus.accepted:
        return 'Confirmed';
      case TailorVisitStatus.enRoute:
        return 'On the way';
      case TailorVisitStatus.arrived:
        return 'Arrived';
      case TailorVisitStatus.completed:
        return 'Completed';
      case TailorVisitStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Position along the happy-path progression — used by the
  /// timeline to decide which steps render as filled (≤ current)
  /// vs. ghosted (> current). Both pending variants share index 0
  /// because they're functionally the same step from the customer's
  /// perspective ("waiting for a tailor"). `cancelled` returns -1
  /// so the timeline collapses cleanly.
  int get progressIndex {
    switch (this) {
      case TailorVisitStatus.pending:
      case TailorVisitStatus.pendingTailorApproval:
        return 0;
      case TailorVisitStatus.accepted:
        return 1;
      case TailorVisitStatus.enRoute:
        return 2;
      case TailorVisitStatus.arrived:
        return 3;
      case TailorVisitStatus.completed:
        return 4;
      case TailorVisitStatus.cancelled:
        return -1;
    }
  }
}

/// Public-facing tailor profile — the columns the customer marketplace
/// + accepted-tailor cards are allowed to read.
///
/// Migration 024 created the base row (id / full_name / phone /
/// experience_years); migration 028 added the marketplace credibility
/// fields (rating, total_reviews, specialties, is_verified,
/// total_earnings); migration 025 unlocked the customer-side SELECT
/// once an appointment exists; migration 036 adds the broader
/// "browse" SELECT that powers the selection screen before any
/// appointment exists.
///
/// We deliberately don't model `phone` or `total_earnings` here —
/// those stay on the server-only side of the wire. The client query
/// only requests the safe columns listed below.
class TailorProfile {
  const TailorProfile({
    required this.id,
    required this.fullName,
    required this.experienceYears,
    this.rating = 0,
    this.totalReviews = 0,
    this.specialties = const <String>[],
    this.isVerified = false,
  });

  final String id;
  final String fullName;
  final int experienceYears;

  /// 0.00 → 5.00. Stored as numeric(3,2) server-side; arrives as
  /// `num` over the wire and we coerce defensively.
  final double rating;

  /// Number of customer reviews this tailor has accumulated. Doubles
  /// as a "jobs completed" proxy on the marketplace card — every
  /// completed visit is reviewable, so the count tracks lifetime
  /// throughput closely enough for an MVP.
  final int totalReviews;

  /// Free-form labels the tailor self-tags — "Suits", "Sherwanis",
  /// "Bridal", etc. Drives the chips row on the selection card.
  final List<String> specialties;

  /// Identity-verified by the Outfitly atelier. Renders as a small
  /// blue check next to the name on the card.
  final bool isVerified;

  /// First letter of the display name, uppercased — fallback avatar
  /// glyph when no portrait image exists. tailor_profiles doesn't
  /// have an `avatar_url` column today; we'll render the initial
  /// inside a tinted circle, matching the Loop / Friend Profile
  /// pattern.
  String get initial =>
      fullName.isEmpty ? '?' : fullName.substring(0, 1).toUpperCase();

  factory TailorProfile.fromMap(Map<String, dynamic> map) {
    return TailorProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      // Postgres `smallint` comes through as `int` under the current
      // supabase-flutter build, but coerce defensively in case a
      // future driver returns `num`.
      experienceYears: (map['experience_years'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (map['total_reviews'] as num?)?.toInt() ?? 0,
      specialties: (map['specialties'] as List?)?.cast<String>() ??
          const <String>[],
      isVerified: map['is_verified'] as bool? ?? false,
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
  bool get isEnRoute   => status == TailorVisitStatus.enRoute;
  bool get isArrived   => status == TailorVisitStatus.arrived;
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
