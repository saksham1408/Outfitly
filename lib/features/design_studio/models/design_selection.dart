/// Holds the user's design choices for a single product customization.
class DesignSelection {
  final String productId;
  String? fabricId;
  String? collarId;
  String? sleeveId;
  String? pocketId;
  String? fitId;
  String? monogramId;
  String? monogramText;

  /// Public URL of a user-uploaded reference image. Only used for
  /// products in the Embroidery subcategory, where the customer can
  /// attach a design they want stitched onto the garment.
  String? customEmbroideryUrl;

  DesignSelection({required this.productId});

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'fabric': fabricId,
        'collar': collarId,
        'sleeve': sleeveId,
        'pocket': pocketId,
        'fit': fitId,
        'monogram': monogramId,
        'monogram_text': monogramText,
        if (customEmbroideryUrl != null)
          'custom_embroidery_url': customEmbroideryUrl,
      };

  bool get isComplete =>
      fabricId != null &&
      collarId != null &&
      sleeveId != null &&
      pocketId != null &&
      fitId != null;
}
