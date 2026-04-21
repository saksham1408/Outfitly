/// Structured outfit suggestion returned by the Gemini-powered AI
/// stylist. The shape is the contract the model MUST honour — the
/// prompt pins these exact keys so we can decode straight into this
/// class without defensive normalisation.
class OutfitRecommendation {
  final String top;
  final String bottom;
  final String shoes;
  final String accessories;
  final String reasoning;

  const OutfitRecommendation({
    required this.top,
    required this.bottom,
    required this.shoes,
    required this.accessories,
    required this.reasoning,
  });

  factory OutfitRecommendation.fromJson(Map<String, dynamic> json) {
    return OutfitRecommendation(
      top: (json['top'] as String? ?? '').trim(),
      bottom: (json['bottom'] as String? ?? '').trim(),
      shoes: (json['shoes'] as String? ?? '').trim(),
      accessories: (json['accessories'] as String? ?? '').trim(),
      reasoning: (json['reasoning'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'top': top,
        'bottom': bottom,
        'shoes': shoes,
        'accessories': accessories,
        'reasoning': reasoning,
      };

  /// The offline copy used when Gemini is unreachable or returns
  /// something we can't parse — keeps the screen useful instead of
  /// throwing the user into an error state.
  static const OutfitRecommendation fallback = OutfitRecommendation(
    top: 'Crisp White Oxford Shirt',
    bottom: 'Well-fitted Indigo Jeans',
    shoes: 'White Leather Sneakers',
    accessories: 'Minimal Steel Watch',
    reasoning:
        'Our AI is currently busy styling a runway, but we recommend a classic white shirt and jeans — a timeless pairing that works for almost any mood, event, or weather.',
  );
}
