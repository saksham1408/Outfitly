/// Carries product + measurement + tailor data through the ordering flow.
/// Built up across screens: Catalog → Measurements → Checkout.
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

  /// Public URL of a user-uploaded reference image. Populated from the
  /// Design Studio when a customer attaches a custom design to an
  /// Embroidery-subcategory product. Surfaces in Directus admin so the
  /// atelier can reproduce the design.
  String? customEmbroideryUrl;

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
    this.customEmbroideryUrl,
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
        },
        'tracking_note': measurementMethod == 'tailor'
            ? 'Waiting for admin approval. A tailor will visit on $tailorDate.'
            : 'Waiting for admin approval. Your measurements are on file.',
      };
}
