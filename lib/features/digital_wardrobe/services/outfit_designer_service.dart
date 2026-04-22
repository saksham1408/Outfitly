import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/outfit_anchor_analysis.dart';

/// Wraps Gemini Vision to turn a single garment photo (the "anchor"
/// piece) into 3 complete outfit ideas that pair with it.
///
/// Unlike [DailyStylistService] — which is constrained to items the
/// user already owns — this service is *generative*: it suggests what
/// to wear alongside the anchor, so the output is descriptive text
/// plus a color palette rather than references back to wardrobe rows.
///
/// Design notes:
///   * We deliberately use `gemini-1.5-flash` (multimodal) with a
///     `DataPart` for the image — avoids uploading the image to
///     storage just to style it.
///   * Temperature is nudged to 0.8 because we *want* three visibly
///     distinct outfits. Daily stylist keeps it at 0.7.
///   * Never throws — every failure path resolves to a static
///     fallback so the UI doesn't have to special-case errors.
class OutfitDesignerService {
  static const String _modelName = 'gemini-1.5-flash';

  GenerativeModel? _build() {
    final key = dotenv.maybeGet('GEMINI_API_KEY');
    if (key == null || key.isEmpty || key == 'your_key_here') {
      debugPrint('OutfitDesignerService: GEMINI_API_KEY missing.');
      return null;
    }
    return GenerativeModel(
      model: _modelName,
      apiKey: key,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.85,
        maxOutputTokens: 1024,
      ),
    );
  }

  /// Analyze [imageBytes] and return a 3-outfit [OutfitAnchorAnalysis].
  /// Returns a static fallback if Gemini is unavailable so the caller
  /// can render the results page unconditionally.
  Future<OutfitAnchorAnalysis> designOutfitsAroundPiece({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final model = _build();
    if (model == null) return _staticFallback();

    const prompt = '''
You are an elite personal stylist. Analyze the garment in the attached image.

STEP 1 — Identify the anchor piece:
  "type":  one of "Top", "Bottom", "Shoes", "Jacket", "Dress", or "Accessory"
  "color": the dominant color (e.g. "Navy", "Cream", "Forest Green")
  "style": one of "Casual", "Smart-Casual", "Formal", "Sporty", "Bohemian",
           "Streetwear", or "Minimalist"

STEP 2 — Design EXACTLY 3 complete outfit ideas that pair beautifully with
this anchor. Each outfit should target a distinct occasion (e.g. Work,
Weekend, Date Night, Travel, Festive).

For each outfit fill every pairing slot: top, bottom, shoes, and 1–2
accessories. The anchor itself goes verbatim into its matching slot as
"Your uploaded <color> <type>" — do NOT replace it. The other slots
should describe the complementary pieces in specific, actionable language
(color + fabric + cut, e.g. "Slim-fit white oxford cotton shirt").

Return a SINGLE raw JSON object. No markdown. No backticks. Shape:

{
  "anchor": { "type": "...", "color": "...", "style": "..." },
  "outfits": [
    {
      "title": "Smart Office",
      "occasion": "Monday meeting",
      "pairing": {
        "top": "Crisp white cotton oxford shirt",
        "bottom": "Charcoal wool straight-leg trousers",
        "shoes": "Black leather oxfords",
        "accessories": ["Slim brown leather belt", "Minimal silver watch"]
      },
      "reasoning": "Neutral tailoring lets the anchor pop without clashing.",
      "paletteHex": ["#1b2a49", "#f6f6f6", "#101010", "#7a5534"]
    },
    { ... second outfit ... },
    { ... third  outfit ... }
  ]
}

Output JSON only — no prose before or after.
''';

    try {
      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes),
        ]),
      ]);
      final raw = response.text;
      if (raw == null || raw.isEmpty) {
        debugPrint('OutfitDesignerService: empty Gemini response.');
        return _staticFallback();
      }
      final decoded = _decode(raw);
      if (decoded == null) {
        debugPrint('OutfitDesignerService: non-JSON response:\n$raw');
        return _staticFallback();
      }
      return _parse(decoded);
    } catch (e, st) {
      debugPrint('OutfitDesignerService: Gemini call failed — $e\n$st');
      return _staticFallback();
    }
  }

  // ── internals ───────────────────────────────────────────────

  OutfitAnchorAnalysis _parse(Map<String, dynamic> j) {
    final anchor =
        AnchorPiece.fromJson(j['anchor'] as Map<String, dynamic>? ?? const {});
    final outfitsRaw = j['outfits'];
    final outfits = <OutfitIdea>[];
    if (outfitsRaw is List) {
      for (final o in outfitsRaw) {
        if (o is Map<String, dynamic>) outfits.add(OutfitIdea.fromJson(o));
      }
    }
    return OutfitAnchorAnalysis(anchor: anchor, outfits: outfits);
  }

  /// Tolerant JSON decoder — strips markdown fences if Gemini slips
  /// despite the response_mime_type hint.
  Map<String, dynamic>? _decode(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?'), '').trim();
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    }
    try {
      final obj = jsonDecode(cleaned);
      return obj is Map<String, dynamic> ? obj : null;
    } catch (_) {
      return null;
    }
  }

  /// Shown when the API key is missing or Gemini is unreachable. The
  /// outfits are generic but plausible so first-time users still see
  /// something useful while they configure Gemini.
  OutfitAnchorAnalysis _staticFallback() {
    return const OutfitAnchorAnalysis(
      anchor: AnchorPiece(
        type: 'Piece',
        color: 'Neutral',
        style: 'Casual',
      ),
      outfits: [
        OutfitIdea(
          title: 'Weekend Casual',
          occasion: 'Brunch with friends',
          top: 'Crisp white cotton tee',
          bottom: 'Dark straight-leg jeans',
          shoes: 'Clean white leather sneakers',
          accessories: ['Brown leather card holder'],
          reasoning:
              'Neutral base keeps the focus on your uploaded piece while '
              'staying effortlessly pulled together.',
          paletteColors: [0xFFF5F5F5, 0xFF1B1B1B, 0xFF8A5A3B],
        ),
        OutfitIdea(
          title: 'Smart Office',
          occasion: 'Monday meeting',
          top: 'Pale blue cotton button-up',
          bottom: 'Charcoal wool tailored trousers',
          shoes: 'Black leather loafers',
          accessories: ['Slim black leather belt', 'Minimal watch'],
          reasoning: 'Tailored basics elevate the anchor without competing '
              'for attention.',
          paletteColors: [0xFFB7C8DA, 0xFF3C3F4A, 0xFF101010],
        ),
        OutfitIdea(
          title: 'Evening Out',
          occasion: 'Dinner date',
          top: 'Textured black knit',
          bottom: 'Dark-wash slim denim',
          shoes: 'Chelsea boots',
          accessories: ['Leather bracelet'],
          reasoning:
              'Moody tones for a confident night look that lets the anchor '
              'do the talking.',
          paletteColors: [0xFF1C1C1C, 0xFF2B2B36, 0xFF4A2B1F],
        ),
      ],
    );
  }
}
