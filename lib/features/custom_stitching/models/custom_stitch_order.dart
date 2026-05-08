/// Stitch My Fabric — domain model and status lifecycle.
///
/// A [CustomStitchOrder] represents a single home-pickup booking
/// where the customer already owns unstitched fabric and wants
/// the tailor to (a) take measurements and (b) collect the
/// fabric for stitching. Tracked separately from
/// `public.orders` (catalog purchases) and
/// `public.tailor_appointments` (the bespoke-design flow) — see
/// migration `039_custom_stitch_orders.sql`.
library;

/// The five-step lifecycle that drives the customer's vertical
/// timeline on the dashboard. The string values match the Postgres
/// CHECK constraint exactly so a round-trip through
/// [fromRow] / [toInsertRow] is lossless.
enum CustomStitchStatus {
  pendingPickup('pending_pickup', 'Tailor Assigned'),
  fabricCollected('fabric_collected', 'Fabric Picked Up'),
  stitching('stitching', 'Stitching in Progress'),
  readyForDelivery('ready_for_delivery', 'Ready for Delivery'),
  delivered('delivered', 'Delivered to You');

  const CustomStitchStatus(this.dbValue, this.displayLabel);

  /// The string we store in `custom_stitch_orders.status`.
  final String dbValue;

  /// Human-readable label rendered on the timeline step.
  final String displayLabel;

  /// Inverse of [dbValue]. Returns [pendingPickup] on an unknown
  /// or null value so a forward-compatible status added by the
  /// atelier doesn't crash the customer client.
  static CustomStitchStatus fromDb(String? value) {
    for (final status in CustomStitchStatus.values) {
      if (status.dbValue == value) return status;
    }
    return CustomStitchStatus.pendingPickup;
  }

  /// Zero-based timeline position. The dashboard fills every step
  /// up to and including this index.
  int get timelineIndex => CustomStitchStatus.values.indexOf(this);
}

/// Catalog of garment types the customer can pick on the booking
/// screen. Free-text on the server (no CHECK), constrained on the
/// client so the dropdown stays clean. Add to this list to expose
/// new garments without a migration.
const List<String> kCustomStitchGarmentTypes = <String>[
  'Kurta',
  'Sherwani',
  'Suit',
  'Shirt',
  'Trousers',
  'Blouse',
  'Saree Blouse',
  'Salwar Kameez',
  'Lehenga Choli',
  'Anarkali',
  'Dupatta',
];

class CustomStitchOrder {
  const CustomStitchOrder({
    required this.id,
    required this.userId,
    required this.garmentType,
    required this.pickupAddress,
    required this.pickupTime,
    required this.status,
    this.tailorId,
    this.referenceImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? tailorId;
  final String garmentType;
  final String pickupAddress;
  final DateTime pickupTime;
  final String? referenceImageUrl;
  final CustomStitchStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Hydrate from a Postgres row (PostgREST returns ISO-8601
  /// strings for timestamptz; we parse + force UTC for stable
  /// comparisons across devices).
  factory CustomStitchOrder.fromRow(Map<String, dynamic> row) {
    return CustomStitchOrder(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      tailorId: row['tailor_id'] as String?,
      garmentType: row['garment_type'] as String,
      pickupAddress: row['pickup_address'] as String,
      pickupTime: DateTime.parse(row['pickup_time'] as String),
      referenceImageUrl: row['reference_image_url'] as String?,
      status: CustomStitchStatus.fromDb(row['status'] as String?),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  /// Payload for the initial INSERT. We intentionally omit
  /// `id`, `user_id`, `created_at`, `updated_at` — Postgres fills
  /// those (id via gen_random_uuid, user_id via auth.uid(), the
  /// timestamps via DEFAULT now()).
  Map<String, dynamic> toInsertRow() {
    return <String, dynamic>{
      'garment_type': garmentType,
      'pickup_address': pickupAddress,
      'pickup_time': pickupTime.toUtc().toIso8601String(),
      if (referenceImageUrl != null) 'reference_image_url': referenceImageUrl,
      // status defaults to 'pending_pickup' on the server side, but
      // sending it explicitly makes the policy match obvious.
      'status': status.dbValue,
    };
  }

  CustomStitchOrder copyWith({
    String? tailorId,
    String? referenceImageUrl,
    CustomStitchStatus? status,
    DateTime? updatedAt,
  }) {
    return CustomStitchOrder(
      id: id,
      userId: userId,
      tailorId: tailorId ?? this.tailorId,
      garmentType: garmentType,
      pickupAddress: pickupAddress,
      pickupTime: pickupTime,
      referenceImageUrl: referenceImageUrl ?? this.referenceImageUrl,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
