/// Carries product + measurement + tailor data through the ordering flow.
/// Built up across screens: Catalog → Measurements → Checkout.
///
/// Two entry points populate this:
///   * The catalog → product → design studio path, where [productName]
///     is the actual catalog row name and [fabric] is the pre-selected
///     swatch.
///   * The AI Look Recreator, where Gemini's reverse-engineered design
///     is crystallised into the same payload shape so we reuse the
///     single CartScreen → orders INSERT seam. In that flow the AI
///     fields ([collarStyle], [sleeveDesign], [fitType], [stylistNotes])
///     are populated and [isRecreatedLook] is set, so the atelier can
///     spot these orders in Directus without breaking the existing
///     catalog-order format.
class OrderPayload {
  // Product info (set from Catalog)
  final String productName;
  final String? fabric;
  final double price;
  final String? imageUrl;

  // Measurement method
  String? measurementMethod; // 'manual' or 'tailor'

  // Manual measurements (if method == 'manual')
  Map<String, double>? measurements;

  // Tailor booking (if method == 'tailor')
  String? tailorAddress;
  String? tailorPincode;
  String? tailorDate;
  String? tailorTimeSlot;

  /// Real DateTime backing [tailorDate] + [tailorTimeSlot]. We carry it
  /// purely so the cart's `_placeOrder` can dispatch a `tailor_appointments`
  /// row to the Partner radar with a precise timestamptz — without having
  /// to round-trip through the human-readable strings (which lose the
  /// year on rollover dates like "Mon, 01 Jan"). NOT serialised into
  /// `orders.design_choices` because the formatted strings are what the
  /// atelier dashboard reads.
  DateTime? tailorScheduledTime;

  /// Public URL of a user-uploaded reference image. Populated from the
  /// Design Studio when a customer attaches a custom design to an
  /// Embroidery-subcategory product. Surfaces in Directus admin so the
  /// atelier can reproduce the design.
  String? customEmbroideryUrl;

  // ── AI Look Recreator fields ──
  // Set only when the order originates from the AI Look Recreator
  // flow (see /recreate-look). They flow through to orders
  // .design_choices so the atelier can reproduce the garment.
  final String? collarStyle;   // canonical ID, e.g. 'spread'
  final String? sleeveDesign;  // canonical ID, e.g. 'long_barrel'
  final String? fitType;       // canonical ID, e.g. 'slim'
  final String? stylistNotes;  // Gemini's free-text rationale
  final bool isRecreatedLook;  // true → AI flow; false → catalog flow

  OrderPayload({
    required this.productName,
    required this.price,
    this.fabric,
    this.imageUrl,
    this.measurementMethod,
    this.measurements,
    this.tailorAddress,
    this.tailorPincode,
    this.tailorDate,
    this.tailorTimeSlot,
    this.tailorScheduledTime,
    this.customEmbroideryUrl,
    this.collarStyle,
    this.sleeveDesign,
    this.fitType,
    this.stylistNotes,
    this.isRecreatedLook = false,
  });

  Map<String, dynamic> toOrderJson(String userId) => {
        'user_id': userId,
        'product_name': productName,
        'fabric': fabric,
        'total_price': price,
        'status': 'pending_admin_approval',
        'estimated_delivery':
            DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T')[0],
        if (customEmbroideryUrl != null)
          'custom_embroidery_url': customEmbroideryUrl,
        'design_choices': {
          'measurement_method': measurementMethod,
          if (measurements != null) 'measurements': measurements,
          if (tailorAddress != null) 'tailor_address': tailorAddress,
          if (tailorPincode != null) 'tailor_pincode': tailorPincode,
          if (tailorDate != null) 'tailor_date': tailorDate,
          if (tailorTimeSlot != null) 'tailor_time_slot': tailorTimeSlot,
          if (customEmbroideryUrl != null)
            'custom_embroidery_url': customEmbroideryUrl,
          // AI fields — nested under `ai_recreated` so the atelier
          // dashboard can spot these orders at a glance without us
          // having to add a top-level column to the orders table.
          if (isRecreatedLook)
            'ai_recreated': {
              'collar_style': collarStyle,
              'sleeve_design': sleeveDesign,
              'fit_type': fitType,
              'stylist_notes': stylistNotes,
            },
        },
        'tracking_note': _trackingNote(),
      };

  /// Copy-constructor-ish helper so the measurements decision screen
  /// can thread AI fields through to the next step without having to
  /// know every field on the payload. Only the mutable-ish
  /// measurement fields get overrides; the AI fields are immutable
  /// (`final`) so they carry through unchanged.
  OrderPayload withMeasurements({
    required String method,
    Map<String, double>? measurements,
    String? tailorAddress,
    String? tailorPincode,
    String? tailorDate,
    String? tailorTimeSlot,
    DateTime? tailorScheduledTime,
  }) {
    final p = OrderPayload(
      productName: productName,
      price: price,
      fabric: fabric,
      imageUrl: imageUrl,
      customEmbroideryUrl: customEmbroideryUrl,
      collarStyle: collarStyle,
      sleeveDesign: sleeveDesign,
      fitType: fitType,
      stylistNotes: stylistNotes,
      isRecreatedLook: isRecreatedLook,
    );
    p.measurementMethod = method;
    p.measurements = measurements;
    p.tailorAddress = tailorAddress;
    p.tailorPincode = tailorPincode;
    p.tailorDate = tailorDate;
    p.tailorTimeSlot = tailorTimeSlot;
    p.tailorScheduledTime = tailorScheduledTime;
    return p;
  }

  String _trackingNote() {
    if (isRecreatedLook) {
      return measurementMethod == 'tailor'
          ? 'AI-recreated look queued for review. A tailor will visit on $tailorDate.'
          : 'AI-recreated look queued for review. Your measurements are on file.';
    }
    return measurementMethod == 'tailor'
        ? 'Waiting for admin approval. A tailor will visit on $tailorDate.'
        : 'Waiting for admin approval. Your measurements are on file.';
  }
}
