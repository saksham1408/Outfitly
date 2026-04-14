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
      };

  bool get isComplete =>
      fabricId != null &&
      collarId != null &&
      sleeveId != null &&
      pocketId != null &&
      fitId != null;
}
