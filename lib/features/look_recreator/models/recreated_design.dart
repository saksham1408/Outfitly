/// Typed representation of Gemini Vision's reverse-engineering output.
///
/// The Gemini system prompt asks for a strict JSON object with six
/// keys; this model is the typed handle the rest of the app uses.
/// Two normalisations happen at parse time:
///
///   1. **Free-text fabric.** `fabric_type` is left as-is — Gemini
///      suggests a real-world fabric name ("cotton-silk blend",
///      "premium linen") and the recreated-studio surface displays
///      that string directly. We deliberately do not try to match it
///      against any product's `fabricOptions` because the AI flow
///      isn't tied to a single SKU.
///
///   2. **ID-mapped enums.** `collar_style`, `sleeve_design`, and
///      `fit_type` are coerced to the canonical IDs the design
///      studio uses (`spread`, `button_down`, `slim`, …). The model
///      almost always returns one of those IDs verbatim because the
///      prompt nudges it that way, but we still normalise + fuzzy
///      match on read so a slip like `"Spread Collar"` resolves
///      cleanly to `spread`.
///
/// A [fallback] singleton lets the UI render something safe if the
/// Gemini call fails entirely (no API key, network blip, malformed
/// JSON). The fallback is intentionally generic — a "neutral classic"
/// — so the user gets a coherent first canvas rather than an error
/// dialog.
class RecreatedDesign {
  const RecreatedDesign({
    required this.fabricType,
    required this.collarStyle,
    required this.sleeveDesign,
    required this.fitType,
    required this.estimatedPrice,
    required this.stylistNotes,
  });

  final String fabricType;
  final String collarStyle;   // one of collar option IDs
  final String sleeveDesign;  // one of sleeve option IDs
  final String fitType;       // one of fit option IDs
  final int    estimatedPrice;
  final String stylistNotes;

  static const RecreatedDesign fallback = RecreatedDesign(
    fabricType: 'Premium Cotton',
    collarStyle: 'spread',
    sleeveDesign: 'long_barrel',
    fitType: 'regular',
    estimatedPrice: 2499,
    stylistNotes:
        'We couldn\'t reach our AI stylist right now, so we\'ve loaded a '
        'classic cotton silhouette as a starting point. Tap any option below '
        'to make it your own.',
  );

  factory RecreatedDesign.fromJson(Map<String, dynamic> json) {
    return RecreatedDesign(
      fabricType: _readString(json, 'fabric_type', fallback.fabricType),
      collarStyle: _normaliseId(
        json['collar_style'],
        valid: _kCollarIds,
        defaultId: fallback.collarStyle,
      ),
      sleeveDesign: _normaliseId(
        json['sleeve_design'],
        valid: _kSleeveIds,
        defaultId: fallback.sleeveDesign,
      ),
      fitType: _normaliseId(
        json['fit_type'],
        valid: _kFitIds,
        defaultId: fallback.fitType,
      ),
      estimatedPrice: _readInt(json, 'estimated_price', fallback.estimatedPrice),
      stylistNotes: _readString(json, 'stylist_notes', fallback.stylistNotes),
    );
  }
}

// ── Canonical ID sets — kept in sync with
//    features/design_studio/models/customization_options.dart ──
const _kCollarIds = {
  'spread', 'button_down', 'mandarin', 'cutaway', 'club', 'wingtip',
};
const _kSleeveIds = {
  'long_barrel', 'long_french', 'half', 'three_quarter', 'rolled',
};
const _kFitIds = {
  'slim', 'regular', 'relaxed',
};

String _readString(Map<String, dynamic> json, String key, String fallback) {
  final v = json[key];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return fallback;
}

int _readInt(Map<String, dynamic> json, String key, int fallback) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

/// Coerce whatever Gemini handed us into one of [valid] IDs.
///
/// Match priority:
///   1. Exact ID after lowercasing + space → underscore
///   2. Substring containment (`"Spread Collar"` → `spread`)
///   3. [defaultId] as the absolute floor
String _normaliseId(
  Object? raw, {
  required Set<String> valid,
  required String defaultId,
}) {
  if (raw is! String) return defaultId;
  final cleaned = raw.trim().toLowerCase().replaceAll(' ', '_');
  if (cleaned.isEmpty) return defaultId;
  if (valid.contains(cleaned)) return cleaned;
  for (final id in valid) {
    if (cleaned.contains(id) || id.contains(cleaned)) return id;
  }
  return defaultId;
}
